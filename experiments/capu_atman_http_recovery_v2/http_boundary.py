"""Loopback HTTP recovery lab. NOT a deployed or bypass-resistant actuator.

The device owns its database. Controller workers receive only a URL and their
own state directory. A separate stdlib-only observer reads the device ledger.
Public fixture keys and synthetic A7 receipts are unchanged from v1.
"""
from __future__ import annotations

import argparse
from dataclasses import asdict
import hashlib
import http.client
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
import json
from pathlib import Path
import socket
import sqlite3
import sys
import threading
from urllib.parse import urlsplit

ROOT = Path(__file__).resolve().parent
V1 = ROOT.parent / 'capu_atman_recovery_v1'
PINS = {
    'bootstrap.py': 'cf66f576ca5d6a67815805261c949a3a87dd890832c81ac386c0600d98d21fcb',
    'proof.py': 'b948f9903f9abec5b6cabbfb5131e5854eb79cfc8b6b9ef0833fe96968b89520',
}
for name, expected in PINS.items():
    if hashlib.sha256((V1 / name).read_bytes()).hexdigest() != expected:
        raise RuntimeError('v1 source mismatch: ' + name)
sys.path.insert(0, str(V1))
from proof import (A6, A7, ISSUER_PUBLIC, Lab, baseline_dispatch, decode_store,
                   encoded, fixture_receipt, token)  # noqa: E402

MAX_BODY = 65536
FAULTS = ('normal', 'drop_before_effect', 'drop_after_effect',
          'http503_after_effect', 'malformed_after_effect', 'hold_after_effect')


def endpoint(url: str) -> tuple[str, int]:
    parts = urlsplit(url)
    if (parts.scheme != 'http' or parts.hostname != '127.0.0.1' or
            parts.username or parts.password or parts.path or parts.query or
            parts.fragment or parts.port is None):
        raise ValueError('only explicit http://127.0.0.1:PORT lab endpoints allowed')
    return parts.hostname, parts.port


def exchange(url: str, route: str, body: dict, timeout: float = 2.0) -> dict:
    """Exactly one HTTP request, no retry/redirect/proxy handling."""
    host, port = endpoint(url)
    connection = http.client.HTTPConnection(host, port, timeout=timeout)
    try:
        connection.request('POST', route, encoded(body), {'Content-Type': 'application/json'})
        response = connection.getresponse()
        payload = response.read(MAX_BODY + 1)
        if response.status != 200:
            return {'transport': 'HTTP_ERROR', 'status': response.status}
        if len(payload) > MAX_BODY:
            return {'transport': 'INVALID_RESPONSE'}
        data = json.loads(payload)
        if not isinstance(data, dict):
            return {'transport': 'INVALID_RESPONSE'}
        return {'transport': 'RESPONSE_RECEIVED', 'body': data}
    except (OSError, http.client.HTTPException, ValueError, UnicodeError):
        return {'transport': 'NO_USABLE_ACK'}
    finally:
        connection.close()


class HTTPController(Lab):
    def __init__(self, root: str | Path, engine: str, url: str):
        endpoint(url)  # Reject unexpected destinations BEFORE reserving work.
        super().__init__(root, engine)
        self.url = url

    def initialize(self):
        # Initialize controller state only; never create/open the device database.
        self.root.mkdir(parents=True, exist_ok=True)
        if self.control.exists():
            raise FileExistsError('refusing to overwrite controller state')
        store = A6.PersistentOutcomeStore()
        if not store.provision(token()):
            raise RuntimeError('provision failed')
        initial = dict(store=asdict(store), trust=asdict(A7.TrustedDeviceStore(60, 2, 0xBEEF)),
                       generation=1, state_version='state/1', engine=self.engine,
                       issuer_key=ISSUER_PUBLIC.hex())
        db = self.connect(self.control, create=True)
        try:
            db.execute('CREATE TABLE state(id INTEGER PRIMARY KEY CHECK(id=1), value TEXT NOT NULL)')
            db.execute('CREATE TABLE audit(id INTEGER PRIMARY KEY, event TEXT NOT NULL, detail TEXT NOT NULL)')
            db.execute('INSERT INTO state VALUES(1, ?)', (encoded(initial),))
        finally:
            db.close()

    def dispatch(self, bundle: dict, *, now: int = 20, timeout: float = 2.0) -> dict:
        # Same admission transaction as pinned v1; only post-commit I/O is changed.
        with self.transaction(self.control) as db:
            data = self._get(db)
            try:
                t = A6.AuthorityToken(**bundle['token'])
                reasons = self.check_authority(bundle, t, data, now)
            except (KeyError, TypeError, ValueError, AttributeError):
                reasons = ('MALFORMED_AUTHORITY',)
            if reasons:
                result = dict(forwarded=False, reason='AUTHORITY', details=list(reasons))
            else:
                if self.engine == 'native':
                    store = decode_store(data['store'])
                    controller = A6.A6Controller(store)
                    if not controller.load(t):
                        raise RuntimeError('fresh-controller load failed')
                    decision = controller.dispatch(t, commit_effect=False)
                    data['store'] = asdict(store)
                    reason = decision.reject_code.name
                else:
                    reason = baseline_dispatch(data['store'], t)
                result = dict(forwarded=reason == 'NONE', reason=reason)
            event = 'AUTHORIZATION_COMMITTED' if result['forwarded'] else 'DISPATCH_REJECTED'
            self._save(db, data, event, {'result': result, 'request': bundle})
        if result['forwarded']:
            # The reservation survives all transport errors. Never infer a negative.
            result['http'] = exchange(self.url, '/effect', {'token': bundle['token']}, timeout)
        return result

    def recover(self, t: dict) -> dict:
        received = exchange(self.url, '/receipt', {'token': t})
        if received['transport'] != 'RESPONSE_RECEIVED':
            return {'applied': False, 'reason': 'NO_RECEIPT', 'http': received}
        body = received['body']
        if body.get('status') != 'COMMITTED' or not isinstance(body.get('receipt'), dict):
            return {'applied': False, 'reason': 'NO_POSITIVE_RECEIPT', 'http': received}
        # A7 checks device/epoch/sequence/tag AND the stored unresolved identity.
        return self.reconcile(body['receipt'])

    def observation(self) -> dict:
        data = self.state()
        return dict(outcome=data['store']['last_outcome'],
                    next_attempt=data['store']['next_attempt'],
                    next_receipt_seq=data['trust']['next_receipt_seq'],
                    terminal=data['store']['terminal_committed'])


class Device(ThreadingHTTPServer):
    daemon_threads = True

    def __init__(self, root: Path, fault: str):
        if fault not in FAULTS:
            raise ValueError('unknown fault')
        root.mkdir(parents=True, exist_ok=True)
        self.path, self.fault = root / 'effects.sqlite', fault
        self.release = threading.Event()
        db = self.connect()
        try:
            db.execute('CREATE TABLE IF NOT EXISTS requests(id INTEGER PRIMARY KEY, token TEXT NOT NULL)')
            # NO UNIQUE constraint or deduplication by token, operation or attempt.
            db.execute('CREATE TABLE IF NOT EXISTS effects(id INTEGER PRIMARY KEY, token TEXT NOT NULL, receipt TEXT NOT NULL)')
        finally:
            db.close()
        super().__init__(('127.0.0.1', 0), Handler)

    def connect(self):
        db = sqlite3.connect(self.path, isolation_level=None, timeout=10)
        db.execute('PRAGMA synchronous=FULL')
        return db


class Handler(BaseHTTPRequestHandler):
    def log_message(self, *args):
        pass

    def answer(self, value: dict, status: int = 200):
        payload = encoded(value).encode()
        try:
            self.send_response(status)
            self.send_header('Content-Type', 'application/json')
            self.send_header('Content-Length', str(len(payload)))
            self.end_headers()
            self.wfile.write(payload)
        except (BrokenPipeError, ConnectionResetError):
            pass

    def drop(self):
        self.close_connection = True
        try:
            self.connection.shutdown(socket.SHUT_RDWR)
        except OSError:
            pass
        self.connection.close()

    def do_POST(self):
        try:
            size = int(self.headers.get('Content-Length', '0'))
            if not 0 < size <= MAX_BODY:
                raise ValueError('bad body size')
            body = json.loads(self.rfile.read(size))
            if self.path == '/release':
                self.server.release.set()
                return self.answer({'released': True})
            t = A6.AuthorityToken(**body['token'])
            identity = encoded(asdict(t))
        except (KeyError, TypeError, ValueError, UnicodeError):
            return self.answer({'error': 'invalid request'}, 400)
        db = self.server.connect()
        try:
            if self.path == '/receipt':
                rows = db.execute('SELECT receipt FROM effects WHERE token=? ORDER BY id', (identity,)).fetchall()
                if len(rows) != 1:
                    # Missing data is NOT a negative receipt; duplicates are a conflict.
                    return self.answer({'status': 'UNKNOWN' if not rows else 'CONFLICT', 'count': len(rows)})
                return self.answer({'status': 'COMMITTED', 'receipt': json.loads(rows[0][0])})
            if self.path != '/effect':
                return self.answer({'error': 'not found'}, 404)
            db.execute('INSERT INTO requests(token) VALUES(?)', (identity,))
            fault = self.server.fault
            if fault == 'drop_before_effect':
                return self.drop()
            receipt = fixture_receipt(t)
            # This durable ledger insertion IS the effect; no cross-system atomicity.
            db.execute('INSERT INTO effects(token,receipt) VALUES(?,?)', (identity, encoded(receipt)))
            if fault == 'drop_after_effect':
                return self.drop()
            if fault == 'hold_after_effect' and not self.server.release.wait(10):
                return self.drop()
            if fault == 'http503_after_effect':
                return self.answer({'error': 'injected after COMMIT'}, 503)
            if fault == 'malformed_after_effect':
                self.send_response(200)
                self.send_header('Content-Length', '1')
                self.end_headers()
                self.wfile.write(b'{')
                return
            return self.answer({'status': 'COMMITTED', 'receipt': receipt})
        finally:
            db.close()


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('mode', choices=('serve', 'init', 'dispatch', 'recover', 'reconcile', 'observe', 'context'))
    parser.add_argument('--root', type=Path, required=True)
    parser.add_argument('--url')
    parser.add_argument('--engine', choices=('native', 'baseline'), default='native')
    parser.add_argument('--fault', choices=FAULTS, default='normal')
    parser.add_argument('--input', type=Path)
    parser.add_argument('--timeout', type=float, default=2.0)
    args = parser.parse_args()
    if args.mode == 'serve':
        server = Device(args.root, args.fault)
        print(encoded({'url': f'http://127.0.0.1:{server.server_port}'}), flush=True)
        server.serve_forever(poll_interval=0.05)
        return
    controller = HTTPController(args.root, args.engine, args.url)
    value = json.loads(args.input.read_text()) if args.input else {}
    if args.mode == 'dispatch':
        result = controller.dispatch(value, timeout=args.timeout)
    elif args.mode == 'recover':
        result = controller.recover(value)
    elif args.mode == 'reconcile':
        result = controller.reconcile(value)
    elif args.mode == 'context':
        controller.context(**value)
        result = controller.observation()
    elif args.mode == 'init':
        controller.initialize()
        result = controller.observation()
    else:
        result = controller.observation()
    print(encoded(result), flush=True)


if __name__ == '__main__':
    main()

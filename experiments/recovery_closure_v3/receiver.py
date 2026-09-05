"""Experimental receiver policies. SQLite INSERT is the effect, not a remote API.

snapshot_negative and admission_fence deliberately violate the stronger closure
contract. They are mutation controls, not behaviors attributed to upstream v2.
No production crypto, device authentication, or access-control boundary here.
"""
from __future__ import annotations
import argparse
from contextlib import contextmanager
from dataclasses import asdict
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
import json
from pathlib import Path
import socket
import sqlite3
import threading
from source_pins import prepare

HTTP = prepare()
from proof import A6, encoded, fixture_receipt  # noqa: E402

POLICIES = ('hold', 'snapshot_negative', 'admission_fence', 'atomic_fence', 'operation_idempotency')
GATES = ('normal', 'before_check', 'after_check', 'drop_before_effect')


class Server(ThreadingHTTPServer):
    daemon_threads = True
    def __init__(self, root, policy, gate):
        if policy not in POLICIES or gate not in GATES:
            raise ValueError('invalid experiment policy/gate')
        root.mkdir(parents=True, exist_ok=True)
        self.path, self.policy, self.gate = root / 'receiver.sqlite', policy, gate
        self.arrived, self.release, self.finished = (threading.Event() for _ in range(3))
        with self.tx() as db:
            db.execute('CREATE TABLE IF NOT EXISTS calls(id INTEGER PRIMARY KEY, token TEXT NOT NULL)')
            db.execute('CREATE TABLE IF NOT EXISTS effects(id INTEGER PRIMARY KEY, operation TEXT NOT NULL, attempt INTEGER NOT NULL, UNIQUE(operation,attempt))')
            db.execute('CREATE TABLE IF NOT EXISTS closed(operation TEXT NOT NULL, attempt INTEGER NOT NULL, PRIMARY KEY(operation,attempt))')
            db.execute('CREATE TABLE IF NOT EXISTS receipts(token TEXT PRIMARY KEY, value TEXT NOT NULL)')
            db.execute('CREATE TABLE IF NOT EXISTS meta(id INTEGER PRIMARY KEY CHECK(id=1), seq INTEGER NOT NULL)')
            db.execute('INSERT OR IGNORE INTO meta VALUES(1,0)')
        super().__init__(('127.0.0.1', 0), Handler)

    @contextmanager
    def tx(self):
        db = sqlite3.connect(self.path, timeout=10, isolation_level=None)
        db.execute('PRAGMA synchronous=FULL')
        try:
            db.execute('BEGIN IMMEDIATE')
            yield db
            db.commit()
        except BaseException:
            db.rollback()
            raise
        finally:
            db.close()

    @staticmethod
    def key(t):
        return encoded(list(t.lineage())), t.attempt_id

    @staticmethod
    def blocked(db, key):
        return db.execute('SELECT 1 FROM closed WHERE operation=? AND attempt=?', key).fetchone() is not None

    def resolve(self, t):
        key = self.key(t)
        identity = encoded(asdict(t))
        with self.tx() as db:
            existing = db.execute('SELECT value FROM receipts WHERE token=?', (identity,)).fetchone()
            if existing:
                receipt = json.loads(existing[0])
                result = {'status': receipt['outcome'], 'receipt': receipt}
            else:
                exists = db.execute('SELECT 1 FROM effects WHERE operation=? AND attempt=?', key).fetchone()
                if exists:
                    status = 'COMMITTED'
                elif self.policy in ('hold', 'operation_idempotency'):
                    status = 'UNKNOWN'
                else:
                    status = 'NOT_COMMITTED'
                    if self.policy in ('admission_fence', 'atomic_fence'):
                        db.execute('INSERT OR IGNORE INTO closed VALUES(?,?)', key)
                result = {'status': status}
                if status != 'UNKNOWN':
                    seq = db.execute('SELECT seq FROM meta WHERE id=1').fetchone()[0]
                    receipt = fixture_receipt(t, seq=seq, outcome=status)
                    db.execute('UPDATE meta SET seq=seq+1 WHERE id=1')
                    db.execute('INSERT INTO receipts VALUES(?,?)', (identity, encoded(receipt)))
                    result['receipt'] = receipt
        # The receipt leaves this function ONLY AFTER the database commit.
        return result

    def apply(self, t):
        key = self.key(t)
        is_initial = t.attempt_id == 0
        with self.tx() as db:
            db.execute('INSERT INTO calls(token) VALUES(?)', (encoded(asdict(t)),))
        if is_initial and self.gate == 'drop_before_effect':
            self.arrived.set()
            self.finished.set()
            return {'status': 'DROPPED'}
        if is_initial and self.gate == 'before_check':
            self.arrived.set()
            if not self.release.wait(15):
                self.finished.set()
                return {'status': 'HARNESS_GATE_TIMEOUT'}
        with self.tx() as db:
            allowed = not self.blocked(db, key)
        if is_initial and self.gate == 'after_check':
            self.arrived.set()
            if not self.release.wait(15):
                self.finished.set()
                return {'status': 'HARNESS_GATE_TIMEOUT'}
        try:
            with self.tx() as db:
                # Deliberate mutation: admission_fence uses only the earlier check.
                if not allowed or (self.policy == 'atomic_fence' and self.blocked(db, key)):
                    result = {'status': 'CLOSED_REJECTED'}
                elif (self.policy == 'operation_idempotency' and
                      db.execute('SELECT 1 FROM effects WHERE operation=?', (key[0],)).fetchone()):
                    result = {'status': 'OPERATION_REPLAY'}
                else:
                    before = db.total_changes
                    db.execute('INSERT OR IGNORE INTO effects(operation,attempt) VALUES(?,?)', key)
                    result = {'status': 'EFFECT' if db.total_changes > before else 'ATTEMPT_REPLAY'}
            return result
        finally:
            if is_initial:
                self.finished.set()


class Handler(BaseHTTPRequestHandler):
    def log_message(self, *args):
        pass

    def answer(self, result, status=200):
        payload = encoded(result).encode()
        try:
            self.send_response(status)
            self.send_header('Content-Length', str(len(payload)))
            self.send_header('Content-Type', 'application/json')
            self.end_headers()
            self.wfile.write(payload)
        except (BrokenPipeError, ConnectionResetError):
            pass

    def do_POST(self):
        try:
            size = int(self.headers.get('Content-Length', 0))
            if not 0 < size <= 65536:
                raise ValueError('body limit')
            body = json.loads(self.rfile.read(size))
            if self.path == '/gate':
                return self.answer({'arrived': self.server.arrived.is_set(), 'finished': self.server.finished.is_set()})
            if self.path == '/release':
                self.server.release.set()
                return self.answer({'released': True})
            t = A6.AuthorityToken(**body['token'])
            if self.path in ('/resolve', '/receipt'):
                return self.answer(self.server.resolve(t))
            if self.path == '/effect':
                result = self.server.apply(t)
                if result['status'] == 'DROPPED':
                    self.close_connection = True
                    try:
                        self.connection.shutdown(socket.SHUT_RDWR)
                    except OSError:
                        pass
                    self.connection.close()
                    return
                return self.answer(result)
            return self.answer({'error': 'route'}, 404)
        except (KeyError, TypeError, ValueError):
            return self.answer({'error': 'invalid input'}, 400)


if __name__ == '__main__':
    p = argparse.ArgumentParser()
    p.add_argument('--root', type=Path, required=True)
    p.add_argument('--policy', choices=POLICIES, required=True)
    p.add_argument('--gate', choices=GATES, required=True)
    a = p.parse_args()
    s = Server(a.root, a.policy, a.gate)
    print(encoded({'url': f'http://127.0.0.1:{s.server_port}'}), flush=True)
    s.serve_forever(poll_interval=0.01)

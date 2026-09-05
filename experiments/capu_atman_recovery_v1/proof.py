"""Bounded CaPU A6/A7 + ATMAN authority composition with process-crash tests.

Experiment only. One trusted controller/device/lineage. The A7 receipt tag is
synthetic. Dispatch admission, not physical actuation, is the policy cut-off.
"""
from __future__ import annotations
import argparse
from contextlib import contextmanager
from dataclasses import asdict
import json
import os
from pathlib import Path
import sqlite3
from typing import Any, Iterator
from cryptography.hazmat.primitives.asymmetric.ed25519 import Ed25519PrivateKey
from cryptography.hazmat.primitives import serialization
from bootstrap import load

A6, A7, AUTH = load()
ROLE, SCOPE = 'effect.execute', 'mock/counter'
# Public, deterministic test fixtures. NEVER use these keys outside this lab.
ISSUER = Ed25519PrivateKey.from_private_bytes(bytes(range(32)))
ACTOR = Ed25519PrivateKey.from_private_bytes(bytes(range(32, 64)))
ISSUER_PUBLIC = ISSUER.public_key().public_bytes(
    serialization.Encoding.Raw, serialization.PublicFormat.Raw)
CRASH_CODES = {'before_commit': 91, 'after_commit': 92, 'after_effect': 93,
               'during_reconcile': 94, 'after_reconcile': 95}


def encoded(value: Any) -> str:
    return json.dumps(value, sort_keys=True, separators=(',', ':'))


def token(attempt: int = 0, **changes: Any):
    fields = dict(authority_tag=167, incarnation=2, queue_epoch=7, slot_id=1,
                  command_id=9, attempt_id=attempt, effect_id=12, committed=True)
    fields.update(changes)
    return A6.AuthorityToken(**fields)


def action_for(t, state_version: str) -> dict:
    return {'domain': 'capu-atman-recovery-lab/v1', 'operation': 'counter.increment',
            'delta': 1, 'state_version': state_version, 'token': asdict(t)}


def fixture_bundle(t=None, *, generation=1, state_version='state/1',
                   role=ROLE, scope=SCOPE, signed_at=10, valid_until=100) -> dict:
    t = token() if t is None else t
    action = action_for(t, state_version)
    grant = AUTH.issue_authority_grant(
        grant_id='lab-grant', subject_ref='lab-actor', subject_key_id='actor-key',
        subject_public_key=ACTOR.public_key(), roles=(role,), scopes=(scope,),
        policy_generation=generation, valid_from=1, valid_until=valid_until,
        issuer_ref='lab-issuer', issuer_key_id='issuer-key', issuer_private_key=ISSUER)
    proof = AUTH.sign_authorized_action(grant, private_key=ACTOR, role=role,
                                       scope=scope, action=action, signed_at=signed_at)
    return {'token': asdict(t), 'action': action, 'grant': asdict(grant), 'proof': asdict(proof)}


def fixture_receipt(t=None, *, seq=0, outcome='COMMITTED', **changes) -> dict:
    t = token() if t is None else t
    fields = {k: v for k, v in asdict(t).items() if k != 'committed'}
    fields.update(device_id=60, key_epoch=2, receipt_seq=seq, outcome=A6.Outcome(outcome))
    fields.update(changes)
    return asdict(A7.DeviceReceipt.signed(secret=0xBEEF, **fields))


def decode_store(data: dict):
    data = dict(data)
    if data['lineage_value'] is not None:
        data['lineage_value'] = tuple(data['lineage_value'])
    data['last_outcome'] = A6.Outcome(data['last_outcome'])
    return A6.PersistentOutcomeStore(**data)


def baseline_dispatch(s: dict, t) -> str:
    """Independent ordinary FSM; same inputs and guarantees as the native arm."""
    if not t.committed:
        return 'UNCOMMITTED'
    if s['lineage_value'] is None:
        return 'PERSISTENT_MISSING'
    if tuple(s['lineage_value']) != t.lineage():
        return 'PERSISTENT_LINEAGE'
    if s['terminal_committed']:
        return 'TERMINAL_COMMITTED'
    if s['terminal_conflict']:
        return 'TERMINAL_CONFLICT'
    if s['unresolved_valid']:
        return 'OUTCOME_UNKNOWN'
    if t.attempt_id != s['next_attempt']:
        return 'PERSISTENT_FRONTIER'
    if s['next_attempt'] == (1 << s['width_bits']) - 1:
        return 'FRONTIER_EXHAUSTED'
    s.update(unresolved_valid=True, unresolved_attempt=t.attempt_id,
             next_attempt=t.attempt_id + 1, last_outcome='UNKNOWN')
    return 'NONE'


def baseline_receipt(s: dict, trust: dict, r) -> dict:
    checks = ((trust['valid'], 'TRUST_MISSING'),
              (r.device_id == trust['trusted_device_id'], 'DEVICE_ID'),
              (r.key_epoch == trust['trusted_key_epoch'], 'KEY_EPOCH'),
              (r.receipt_seq == trust['next_receipt_seq'], 'RECEIPT_SEQUENCE'),
              (r.auth_tag == r.expected_tag(trust['secret'], width_bits=trust['auth_width_bits']), 'AUTH_TAG'))
    for ok, reason in checks:
        if not ok:
            return dict(authenticated=False, applied=False, auth=reason, semantic='NONE')
    trust['next_receipt_seq'] += 1  # A7 accepts consume even on semantic reject.
    checks = ((s['lineage_value'] is not None, 'PERSISTENT_MISSING'),
              (tuple(s['lineage_value'] or []) == r.token().lineage(), 'PERSISTENT_LINEAGE'),
              (not (s['terminal_committed'] or s['terminal_conflict']), 'TERMINAL'),
              (s['unresolved_valid'], 'NO_UNRESOLVED_ATTEMPT'),
              (r.attempt_id == s['unresolved_attempt'], 'ATTEMPT_MISMATCH'),
              (r.outcome in (A6.Outcome.NOT_COMMITTED, A6.Outcome.COMMITTED, A6.Outcome.CONFLICT), 'INVALID_OUTCOME'))
    for ok, reason in checks:
        if not ok:
            return dict(authenticated=True, applied=False, auth='NONE', semantic=reason)
    s.update(unresolved_valid=False, last_outcome=r.outcome.value,
             last_resolved_attempt=r.attempt_id,
             terminal_committed=r.outcome is A6.Outcome.COMMITTED,
             terminal_conflict=r.outcome is A6.Outcome.CONFLICT)
    return dict(authenticated=True, applied=True, auth='NONE', semantic='NONE')


class Lab:
    def __init__(self, root: str | Path, engine: str = 'native'):
        if engine not in ('native', 'baseline'):
            raise ValueError('unknown engine')
        self.root, self.engine = Path(root), engine
        self.control, self.device = self.root / 'control.sqlite', self.root / 'device.sqlite'

    @staticmethod
    def connect(path: Path, *, create=False):
        db = sqlite3.connect(str(path) if create else path.resolve().as_uri() + '?mode=rw',
                             uri=not create, timeout=10, isolation_level=None)
        db.execute('PRAGMA synchronous=FULL')
        return db

    @contextmanager
    def transaction(self, path: Path) -> Iterator[sqlite3.Connection]:
        db = self.connect(path)
        try:
            db.execute('BEGIN IMMEDIATE')
            yield db
            db.commit()
        except BaseException:
            db.rollback()
            raise
        finally:
            db.close()

    def initialize(self):
        self.root.mkdir(parents=True, exist_ok=True)
        if self.control.exists() or self.device.exists():
            raise FileExistsError('Refusing to overwrite an existing experiment')
        store = A6.PersistentOutcomeStore()
        if not store.provision(token()):
            raise RuntimeError('provision failed')
        initial = dict(store=asdict(store), trust=asdict(A7.TrustedDeviceStore(60, 2, 0xBEEF)),
                       generation=1, state_version='state/1', engine=self.engine,
                       issuer_key=ISSUER_PUBLIC.hex())
        for path in (self.control, self.device):
            db = self.connect(path, create=True)
            try:
                db.execute('PRAGMA journal_mode=DELETE')
                if path == self.control:
                    db.execute('CREATE TABLE state(id INTEGER PRIMARY KEY CHECK(id=1), value TEXT NOT NULL)')
                    db.execute('CREATE TABLE audit(id INTEGER PRIMARY KEY, event TEXT NOT NULL, detail TEXT NOT NULL)')
                    db.execute('INSERT INTO state VALUES(1, ?)', (encoded(initial),))
                else:
                    # Deliberately NOT idempotent: duplicate calls make duplicate effects.
                    db.execute('CREATE TABLE effects(id INTEGER PRIMARY KEY, attempt INTEGER, detail TEXT NOT NULL)')
            finally:
                db.close()

    def _get(self, db):
        row = db.execute('SELECT value FROM state WHERE id=1').fetchone()
        if row is None:
            raise RuntimeError('missing state; do not provision automatically')
        data = json.loads(row[0])
        if data['engine'] != self.engine:
            raise ValueError('cannot switch engine for existing state')
        return data

    @staticmethod
    def _save(db, data, event, detail):
        db.execute('UPDATE state SET value=? WHERE id=1', (encoded(data),))
        db.execute('INSERT INTO audit(event,detail) VALUES(?,?)', (event, encoded(detail)))

    def state(self) -> dict:
        db = self.connect(self.control)
        try:
            return self._get(db)
        finally:
            db.close()

    def effects(self) -> int:
        db = self.connect(self.device)
        try:
            return db.execute('SELECT COUNT(*) FROM effects').fetchone()[0]
        finally:
            db.close()

    def context(self, *, generation=None, state_version=None):
        with self.transaction(self.control) as db:
            data = self._get(db)
            if generation is not None:
                if generation <= data['generation']:
                    raise ValueError('policy generation must increase')
                data['generation'] = generation
            if state_version is not None:
                data['state_version'] = state_version
            self._save(db, data, 'CONTEXT_CHANGED', {})

    @staticmethod
    def check_authority(bundle, t, data, now):
        grant, proof = AUTH.AuthorityGrant(**bundle['grant']), AUTH.AuthorityProof(**bundle['proof'])
        expected = action_for(t, data['state_version'])
        if bundle['action'] != expected:
            return ('CONTEXT_OR_ACTION_MISMATCH',)
        if proof.role != ROLE or proof.scope != SCOPE:
            return ('REQUIRED_ROLE_OR_SCOPE',)
        if proof.signed_at > now:
            return ('FUTURE_DATED_PROOF',)
        ok, reasons = AUTH.verify_authority_proof(
            grant, proof, action=expected,
            trusted_issuer_keys={'issuer-key': bytes.fromhex(data['issuer_key'])},
            current_policy_generation=data['generation'], now=now)
        return () if ok else reasons

    def dispatch(self, bundle: dict, *, now: int = 20, crash: str | None = None) -> dict:
        if crash not in (None, 'before_commit', 'after_commit', 'after_effect'):
            raise ValueError('invalid dispatch crash point')
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
            if crash == 'before_commit':
                os._exit(CRASH_CODES[crash])
        # Policy is linearized at the preceding durable admission, not at actuation.
        if not result['forwarded']:
            return result
        if crash == 'after_commit':
            os._exit(CRASH_CODES[crash])
        with self.transaction(self.device) as db:
            db.execute('INSERT INTO effects(attempt,detail) VALUES(?,?)',
                       (t.attempt_id, encoded(bundle['action'])))
        if crash == 'after_effect':
            os._exit(CRASH_CODES[crash])
        # No acknowledgement is invented here. Receipt reconciliation is separate.
        return result

    def reconcile(self, receipt: dict, *, crash: str | None = None) -> dict:
        if crash not in (None, 'during_reconcile', 'after_reconcile'):
            raise ValueError('invalid reconciliation crash point')
        with self.transaction(self.control) as db:
            data = self._get(db)
            try:
                fields = dict(receipt)
                fields['outcome'] = A6.Outcome(fields['outcome'])
                r = A7.DeviceReceipt(**fields)
                if self.engine == 'native':
                    store = decode_store(data['store'])
                    trust = A7.TrustedDeviceStore(**data['trust'])
                    decision = A7.A7Controller(A6.A6Controller(store), trust).process_receipt(r)
                    data.update(store=asdict(store), trust=asdict(trust))
                    result = dict(authenticated=decision.authenticated, applied=decision.reconcile_accept,
                                  auth=decision.auth_reject_code.name, semantic=decision.reconcile_reject_code.name)
                else:
                    result = baseline_receipt(data['store'], data['trust'], r)
            except (KeyError, TypeError, ValueError, AttributeError):
                # The pure upstream model may reject malformed inputs by raising;
                # don't persist any partial mutations from a malformed envelope.
                data = self._get(db)
                result = dict(authenticated=False, applied=False, auth='MALFORMED_RECEIPT', semantic='NONE')
            self._save(db, data, 'RECEIPT', {'result': result, 'receipt': receipt})
            if crash == 'during_reconcile':
                os._exit(CRASH_CODES[crash])
        if crash == 'after_reconcile':
            os._exit(CRASH_CODES[crash])
        return result

    def observation(self) -> dict:
        state = self.state()
        return dict(outcome=state['store']['last_outcome'],
                    next_attempt=state['store']['next_attempt'],
                    next_receipt_seq=state['trust']['next_receipt_seq'],
                    terminal=state['store']['terminal_committed'], effects=self.effects())


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('operation', choices=('dispatch', 'reconcile'))
    parser.add_argument('root', type=Path)
    parser.add_argument('input', type=Path)
    parser.add_argument('--engine', choices=('native', 'baseline'), required=True)
    parser.add_argument('--crash', choices=tuple(CRASH_CODES))
    args = parser.parse_args()
    lab = Lab(args.root, args.engine)
    result = getattr(lab, args.operation)(json.loads(args.input.read_text()), crash=args.crash)
    print(encoded(result))

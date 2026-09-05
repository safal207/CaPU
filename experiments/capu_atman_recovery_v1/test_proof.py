"""Real process exits, negative boundaries, native regressions and equal baselines."""
from __future__ import annotations
from concurrent.futures import ThreadPoolExecutor
import copy
import json
from pathlib import Path
import random
import subprocess
import sys
import tempfile
import unittest
from proof import A6, A7, Lab, CRASH_CODES, fixture_bundle, fixture_receipt, token

HERE = Path(__file__).resolve().parent


def crash(lab, point, value, operation='dispatch'):
    request = lab.root / f'{point}.json'
    request.write_text(json.dumps(value))
    run = subprocess.run([sys.executable, str(HERE / 'proof.py'), operation,
                          str(lab.root), str(request), '--engine', lab.engine,
                          '--crash', point], capture_output=True, text=True, timeout=15)
    if run.returncode != CRASH_CODES[point]:
        raise AssertionError(f'{point}: expected {CRASH_CODES[point]}, got {run.returncode}: {run.stderr}')
    return Lab(lab.root, lab.engine)


class Cases:
    def before_commit(self, lab):
        lab = crash(lab, 'before_commit', fixture_bundle())
        self.assertEqual(lab.observation(), dict(outcome='NONE', next_attempt=0,
                        next_receipt_seq=0, terminal=False, effects=0))
        self.assertTrue(lab.dispatch(fixture_bundle())['forwarded'])
        self.assertEqual(lab.effects(), 1)

    def after_commit(self, lab):
        lab = crash(lab, 'after_commit', fixture_bundle())
        self.assertEqual(lab.observation(), dict(outcome='UNKNOWN', next_attempt=1,
                        next_receipt_seq=0, terminal=False, effects=0))
        self.assertEqual(lab.dispatch(fixture_bundle(token(1)))['reason'], 'OUTCOME_UNKNOWN')
        self.assertEqual(lab.effects(), 0)  # No receipt inferred from absence.

    def lost_ack_restart_late_receipt(self, lab):
        lab = crash(lab, 'after_effect', fixture_bundle())
        self.assertEqual(lab.observation(), dict(outcome='UNKNOWN', next_attempt=1,
                        next_receipt_seq=0, terminal=False, effects=1))
        for attempt in (0, 1):
            self.assertEqual(lab.dispatch(fixture_bundle(token(attempt)))['reason'], 'OUTCOME_UNKNOWN')
        self.assertTrue(lab.reconcile(fixture_receipt())['applied'])
        self.assertEqual(lab.dispatch(fixture_bundle(token(1)))['reason'], 'TERMINAL_COMMITTED')
        self.assertEqual(lab.observation(), dict(outcome='COMMITTED', next_attempt=1,
                        next_receipt_seq=1, terminal=True, effects=1))

    def atomic_reconcile_rollback(self, lab):
        lab.dispatch(fixture_bundle())
        lab = crash(lab, 'during_reconcile', fixture_receipt(), 'reconcile')
        self.assertEqual(lab.observation()['outcome'], 'UNKNOWN')
        self.assertEqual(lab.observation()['next_receipt_seq'], 0)
        self.assertTrue(lab.reconcile(fixture_receipt())['applied'])
        self.assertEqual(lab.observation()['next_receipt_seq'], 1)

    def after_reconcile_commit(self, lab):
        lab.dispatch(fixture_bundle())
        lab = crash(lab, 'after_reconcile', fixture_receipt(), 'reconcile')
        self.assertEqual(lab.observation()['outcome'], 'COMMITTED')
        self.assertEqual(lab.reconcile(fixture_receipt())['auth'], 'RECEIPT_SEQUENCE')
        self.assertFalse(lab.dispatch(fixture_bundle(token(1)))['forwarded'])
        self.assertEqual(lab.effects(), 1)

    def stale_generation(self, lab):
        request = fixture_bundle()
        lab.context(generation=2)
        result = lab.dispatch(request)
        self.assertEqual(result['reason'], 'AUTHORITY')
        self.assertIn('stale_authority_policy_generation', result['details'])
        self.assertEqual(lab.effects(), 0)

    def stale_state_version(self, lab):
        request = fixture_bundle()
        lab.context(state_version='state/2')
        self.assertIn('CONTEXT_OR_ACTION_MISMATCH', lab.dispatch(request)['details'])
        self.assertEqual(lab.effects(), 0)

    def wrong_role(self, lab):
        self.assertIn('REQUIRED_ROLE_OR_SCOPE', lab.dispatch(fixture_bundle(role='effect.review'))['details'])
        self.assertEqual(lab.effects(), 0)

    def wrong_scope(self, lab):
        self.assertIn('REQUIRED_ROLE_OR_SCOPE', lab.dispatch(fixture_bundle(scope='mock/other'))['details'])
        self.assertEqual(lab.effects(), 0)

    def expired_grant(self, lab):
        self.assertIn('grant_expired', lab.dispatch(fixture_bundle(valid_until=15))['details'])
        self.assertEqual(lab.effects(), 0)

    def future_proof(self, lab):
        self.assertIn('FUTURE_DATED_PROOF', lab.dispatch(fixture_bundle(signed_at=30))['details'])
        self.assertEqual(lab.effects(), 0)

    def changed_action(self, lab):
        request = fixture_bundle()
        request['token']['command_id'] += 1
        request['action']['token']['command_id'] += 1
        self.assertIn('action_digest_mismatch', lab.dispatch(request)['details'])
        self.assertEqual(lab.effects(), 0)

    def missing_authority(self, lab):
        self.assertIn('MALFORMED_AUTHORITY', lab.dispatch({'token': {}})['details'])
        self.assertEqual(lab.effects(), 0)

    def uncommitted_request(self, lab):
        self.assertEqual(lab.dispatch(fixture_bundle(token(committed=False)))['reason'], 'UNCOMMITTED')
        self.assertEqual(lab.effects(), 0)

    def foreign_lineage(self, lab):
        self.assertEqual(lab.dispatch(fixture_bundle(token(effect_id=13)))['reason'], 'PERSISTENT_LINEAGE')
        self.assertEqual(lab.effects(), 0)

    def forged_receipt(self, lab):
        lab.dispatch(fixture_bundle())
        receipt = fixture_receipt(outcome='NOT_COMMITTED')
        receipt['auth_tag'] ^= 1
        self.assertEqual(lab.reconcile(receipt)['auth'], 'AUTH_TAG')
        self.assertEqual(lab.observation()['next_receipt_seq'], 0)
        self.assertEqual(lab.dispatch(fixture_bundle(token(1)))['reason'], 'OUTCOME_UNKNOWN')
        self.assertEqual(lab.effects(), 1)

    def foreign_device(self, lab):
        lab.dispatch(fixture_bundle())
        self.assertEqual(lab.reconcile(fixture_receipt(device_id=61))['auth'], 'DEVICE_ID')
        self.assertEqual(lab.observation()['outcome'], 'UNKNOWN')
        self.assertEqual(lab.observation()['next_receipt_seq'], 0)

    def wrong_key_epoch(self, lab):
        lab.dispatch(fixture_bundle())
        self.assertEqual(lab.reconcile(fixture_receipt(key_epoch=3))['auth'], 'KEY_EPOCH')
        self.assertEqual(lab.observation()['next_receipt_seq'], 0)

    def wrong_receipt_sequence(self, lab):
        lab.dispatch(fixture_bundle())
        self.assertEqual(lab.reconcile(fixture_receipt(seq=1))['auth'], 'RECEIPT_SEQUENCE')
        self.assertEqual(lab.observation()['next_receipt_seq'], 0)

    def wrong_attempt_consumes_sequence(self, lab):
        lab.dispatch(fixture_bundle())
        self.assertEqual(lab.reconcile(fixture_receipt(token(1)))['semantic'], 'ATTEMPT_MISMATCH')
        self.assertEqual(lab.observation()['outcome'], 'UNKNOWN')
        self.assertEqual(lab.observation()['next_receipt_seq'], 1)
        self.assertTrue(lab.reconcile(fixture_receipt(seq=1))['applied'])

    def malformed_receipt(self, lab):
        lab.dispatch(fixture_bundle())
        receipt = fixture_receipt()
        receipt['outcome'] = 'TIMEOUT_MEANS_FAILURE'
        self.assertEqual(lab.reconcile(receipt)['auth'], 'MALFORMED_RECEIPT')
        self.assertEqual(lab.observation()['next_receipt_seq'], 0)
        self.assertEqual(lab.observation()['outcome'], 'UNKNOWN')

    def historical_receipt_after_revocation(self, lab):
        lab.dispatch(fixture_bundle())
        lab.context(generation=2, state_version='state/2')
        fresh = fixture_bundle(token(1), generation=2, state_version='state/2')
        self.assertEqual(lab.dispatch(fresh)['reason'], 'OUTCOME_UNKNOWN')
        self.assertTrue(lab.reconcile(fixture_receipt())['applied'])
        self.assertEqual(lab.dispatch(fresh)['reason'], 'TERMINAL_COMMITTED')
        self.assertEqual(lab.effects(), 1)

    def explicit_negative_only_releases_successor(self, lab):
        lab = crash(lab, 'after_commit', fixture_bundle())  # No effect happened.
        self.assertTrue(lab.reconcile(fixture_receipt(outcome='NOT_COMMITTED'))['applied'])
        self.assertEqual(lab.dispatch(fixture_bundle())['reason'], 'PERSISTENT_FRONTIER')
        self.assertTrue(lab.dispatch(fixture_bundle(token(1)))['forwarded'])
        self.assertTrue(lab.reconcile(fixture_receipt(token(1), seq=1))['applied'])
        self.assertEqual(lab.effects(), 1)

    def conflict_holds(self, lab):
        lab.dispatch(fixture_bundle())
        self.assertTrue(lab.reconcile(fixture_receipt(outcome='CONFLICT'))['applied'])
        self.assertEqual(lab.dispatch(fixture_bundle(token(1)))['reason'], 'TERMINAL_CONFLICT')
        self.assertEqual(lab.effects(), 1)

    def concurrent_dispatch(self, lab):
        request = lab.root / 'race.json'
        request.write_text(json.dumps(fixture_bundle()))
        command = [sys.executable, str(HERE / 'proof.py'), 'dispatch', str(lab.root),
                   str(request), '--engine', lab.engine]
        def run():
            out = subprocess.run(command, capture_output=True, text=True, timeout=15)
            self.assertEqual(out.returncode, 0, out.stderr)
            return json.loads(out.stdout)
        with ThreadPoolExecutor(2) as pool:
            results = list(pool.map(lambda _: run(), range(2)))
        self.assertEqual(sum(r['forwarded'] for r in results), 1)
        self.assertEqual(lab.effects(), 1)

    def missing_storage_fails_closed(self, lab):
        lab.control.unlink()
        with self.assertRaises(Exception):
            lab.dispatch(fixture_bundle())
        self.assertFalse(lab.control.exists())
        self.assertEqual(lab.effects(), 0)


class RecoveryTests(unittest.TestCase, Cases):
    pass


def bind(case, engine):
    def run(self):
        with tempfile.TemporaryDirectory() as folder:
            lab = Lab(folder, engine)
            lab.initialize()
            case(self, lab)
    return run

for _name, _case in Cases.__dict__.items():
    if callable(_case) and not _name.startswith('_'):
        for _engine in ('native', 'baseline'):
            setattr(RecoveryTests, f'test_{_engine}_{_name}', bind(_case, _engine))


class SourceAndDifferentialTests(unittest.TestCase):
    def test_upstream_a6_regression(self):
        result = A6.scenario_result()
        self.assertTrue(result['terminal_committed'])
        self.assertTrue(result['restart_replay_blocked'])
        self.assertEqual(result['external_effect_count'], 1)

    def test_upstream_a7_exact_result_digest(self):
        self.assertEqual(A7.scenario_result()['result_digest_sha256'],
                         '6781dbfbd1b529866709980a3a85a38bd37f505daaddd53fd7c8e106ab863d2f')

    def test_seeded_transition_equivalence(self):
        random_source = random.Random(20260905)
        # 24 independent traces x 12 actions = 288 compared state-machine steps.
        # No claim of exhaustive checking. Shared authority and tag primitive;
        # separate lifecycle dispatch/reconciliation implementations.
        with tempfile.TemporaryDirectory() as root:
            for trace in range(24):
                native, baseline = [Lab(Path(root) / f'{trace}-{engine}', engine)
                                    for engine in ('native', 'baseline')]
                native.initialize()
                baseline.initialize()
                for step in range(12):
                    if random_source.randrange(2):
                        item = fixture_bundle(token(random_source.randrange(3)))
                        left, right = native.dispatch(item), baseline.dispatch(item)
                    else:
                        item = fixture_receipt(token(random_source.randrange(3)),
                                  seq=random_source.randrange(3),
                                  outcome=random_source.choice(['COMMITTED', 'CONFLICT', 'UNKNOWN']))
                        if random_source.randrange(4) == 0:
                            item['auth_tag'] ^= 1
                        left, right = native.reconcile(item), baseline.reconcile(item)
                    self.assertEqual(left, right, (trace, step))
                    self.assertEqual(native.observation(), baseline.observation(), (trace, step))
                    self.assertEqual(native.state()['store'], baseline.state()['store'])
                    self.assertEqual(native.state()['trust'], baseline.state()['trust'])


if __name__ == '__main__':
    unittest.main(verbosity=2)

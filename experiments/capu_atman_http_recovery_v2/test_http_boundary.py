"""Real loopback sockets, separate processes and a read-only external observer."""
from dataclasses import asdict
import json
from pathlib import Path
import subprocess
import sys
import tempfile
import time
import unittest

from http_boundary import ROOT, exchange
from proof import fixture_bundle, token

TRACE_LOG = []


class Harness:
    def __init__(self, root: Path, engine: str, fault='normal'):
        self.root, self.engine, self.serial = root, engine, 0
        self.children = []
        self.start_server(fault)
        self.command('init')

    def start_server(self, fault):
        self.server = subprocess.Popen(
            [sys.executable, str(ROOT / 'http_boundary.py'), 'serve',
             '--root', str(self.root / 'device'), '--fault', fault],
            stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
        self.children.append(self.server)
        ready = self.server.stdout.readline()
        if not ready:
            raise RuntimeError('device failed: ' + self.server.stderr.read())
        self.url = json.loads(ready)['url']

    def args(self, mode, value=None, timeout=2.0):
        args = [sys.executable, str(ROOT / 'http_boundary.py'), mode,
                '--root', str(self.root / 'controller'), '--engine', self.engine,
                '--url', self.url, '--timeout', str(timeout)]
        if value is not None:
            self.serial += 1
            path = self.root / f'input-{self.serial}.json'
            path.write_text(json.dumps(value))
            args += ['--input', str(path)]
        return args

    def spawn(self, mode, value=None, timeout=2.0):
        process = subprocess.Popen(self.args(mode, value, timeout),
                                   stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
        self.children.append(process)
        return process

    def command(self, mode, value=None, timeout=2.0):
        result = subprocess.run(self.args(mode, value, timeout),
                                capture_output=True, text=True, timeout=15)
        if result.returncode:
            raise AssertionError(result.stderr)
        return json.loads(result.stdout)

    def witness(self):
        result = subprocess.run([sys.executable, str(ROOT / 'observer.py'),
                                 str(self.root / 'device' / 'effects.sqlite')],
                                capture_output=True, text=True, check=True, timeout=10)
        return json.loads(result.stdout)

    def wait_effect(self):
        deadline = time.monotonic() + 8
        while time.monotonic() < deadline:
            observed = self.witness()
            if observed['effect_count'] == 1:
                return observed
            time.sleep(0.02)
        raise AssertionError('external effect not observed')

    def stop_server(self):
        self.server.kill()
        self.server.communicate(timeout=5)

    def close(self):
        for child in self.children:
            if child.poll() is None:
                child.kill()
            child.communicate(timeout=5)


class Cases:
    engine = None

    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.h = None
        self.trace = {'engine': self.engine, 'scenario': self._testMethodName, 'steps': []}

    def begin(self, fault='normal'):
        self.h = Harness(Path(self.temp.name), self.engine, fault)
        self.addCleanup(self.h.close)
        return self.h

    def tearDown(self):
        if self.h:
            self.h.close()
        self.temp.cleanup()
        TRACE_LOG.append(self.trace)

    def snapshot(self, label, effects, requests, outcome=None):
        witness = self.h.witness()
        control = self.h.command('observe')
        self.assertEqual(witness['integrity'], 'ok')
        self.assertEqual(witness['effect_count'], effects)
        self.assertEqual(witness['request_count'], requests)
        if outcome is not None:
            self.assertEqual(control['outcome'], outcome)
        self.trace['steps'].append({'event': label, 'controller': control, 'witness': witness})
        self.assertFalse((self.h.root / 'controller' / 'device.sqlite').exists())

    def blocked(self, bundle=None, reason='OUTCOME_UNKNOWN'):
        result = self.h.command('dispatch', bundle or fixture_bundle(token(1)))
        self.assertFalse(result['forwarded'])
        self.assertEqual(result['reason'], reason)
        self.assertNotIn('http', result)

    def finish(self):
        result = self.h.command('recover', asdict(token()))
        self.assertTrue(result['applied'])
        self.snapshot('LATE_POSITIVE_RECEIPT', 1, 1, 'COMMITTED')
        self.blocked(reason='TERMINAL_COMMITTED')
        self.snapshot('TERMINAL_RETRY_BLOCKED', 1, 1, 'COMMITTED')

    def lost(self, fault, transport):
        h = self.begin(fault)
        result = h.command('dispatch', fixture_bundle())
        self.assertTrue(result['forwarded'])
        self.assertEqual(result['http']['transport'], transport)
        self.snapshot('ACK_UNUSABLE', 1, 1, 'UNKNOWN')
        for _ in range(3):
            self.blocked()
        self.snapshot('THREE_RETRIES_BLOCKED_NO_HTTP', 1, 1, 'UNKNOWN')
        self.finish()

    def test_normal_ack_is_not_automatic_reconciliation(self):
        h = self.begin()
        result = h.command('dispatch', fixture_bundle())
        self.assertEqual(result['http']['transport'], 'RESPONSE_RECEIVED')
        self.snapshot('HTTP_ACK_RECEIVED_NOT_YET_RECONCILED', 1, 1, 'UNKNOWN')
        self.assertTrue(h.command('reconcile', result['http']['body']['receipt'])['applied'])
        self.snapshot('EXACT_ACK_APPLIED', 1, 1, 'COMMITTED')

    def test_connection_dropped_after_effect(self):
        self.lost('drop_after_effect', 'NO_USABLE_ACK')

    def test_http503_after_effect_is_not_negative(self):
        self.lost('http503_after_effect', 'HTTP_ERROR')

    def test_malformed_ack_after_effect_is_not_negative(self):
        self.lost('malformed_after_effect', 'NO_USABLE_ACK')

    def test_dropped_before_effect_stays_unknown(self):
        h = self.begin('drop_before_effect')
        self.assertEqual(h.command('dispatch', fixture_bundle())['http']['transport'], 'NO_USABLE_ACK')
        self.snapshot('REQUEST_RECEIVED_NO_EFFECT', 0, 1, 'UNKNOWN')
        result = h.command('recover', asdict(token()))
        self.assertFalse(result['applied'])
        self.assertEqual(result['reason'], 'NO_POSITIVE_RECEIPT')
        self.blocked()
        self.snapshot('MISSING_RECORD_NOT_NEGATIVE', 0, 1, 'UNKNOWN')

    def test_observer_triggers_actual_controller_kill(self):
        h = self.begin('hold_after_effect')
        worker = h.spawn('dispatch', fixture_bundle(), timeout=8)
        witness = h.wait_effect()
        self.assertEqual(witness['request_count'], 1)
        self.assertIsNone(worker.poll(), 'controller must still be awaiting ACK')
        worker.kill()
        worker.communicate(timeout=5)
        self.assertNotEqual(worker.returncode, 0)
        self.snapshot('OBSERVER_SAW_EFFECT_THEN_KILLED_CONTROLLER', 1, 1, 'UNKNOWN')
        exchange(h.url, '/release', {'release': True})
        self.blocked()
        h.command('context', {'generation': 2, 'state_version': 'state/2'})
        self.assertTrue(h.command('recover', asdict(token()))['applied'])
        self.blocked(fixture_bundle(token(1), generation=2, state_version='state/2'),
                     reason='TERMINAL_COMMITTED')
        self.snapshot('RESTART_POLICY_CHANGED_HISTORICAL_RECEIPT_APPLIED', 1, 1, 'COMMITTED')

    def test_http_timeout_after_effect(self):
        h = self.begin('hold_after_effect')
        result = h.command('dispatch', fixture_bundle(), timeout=0.15)
        self.assertEqual(result['http']['transport'], 'NO_USABLE_ACK')
        h.wait_effect()
        self.snapshot('TIMEOUT_AFTER_EFFECT', 1, 1, 'UNKNOWN')
        exchange(h.url, '/release', {'release': True})
        self.blocked()
        self.finish()

    def test_device_restart_preserves_positive_receipt(self):
        h = self.begin('drop_after_effect')
        h.command('dispatch', fixture_bundle())
        self.snapshot('BEFORE_DEVICE_KILL', 1, 1, 'UNKNOWN')
        h.stop_server()
        h.start_server('normal')
        self.snapshot('DEVICE_RESTARTED_SAME_LEDGER', 1, 1, 'UNKNOWN')
        self.finish()

    def test_tampered_receipt_does_not_release_unknown(self):
        h = self.begin('drop_after_effect')
        h.command('dispatch', fixture_bundle())
        receipt = exchange(h.url, '/receipt', {'token': asdict(token())})['body']['receipt']
        receipt['auth_tag'] ^= 1
        self.assertFalse(h.command('reconcile', receipt)['authenticated'])
        self.snapshot('TAMPERED_RECEIPT_REJECTED', 1, 1, 'UNKNOWN')
        self.blocked()
        self.finish()

    def test_receipt_query_binds_full_token(self):
        h = self.begin('drop_after_effect')
        h.command('dispatch', fixture_bundle())
        result = h.command('recover', asdict(token(command_id=10)))
        self.assertFalse(result['applied'])
        self.snapshot('FOREIGN_OPERATION_NOT_CONFUSED_WITH_OWN_EFFECT', 1, 1, 'UNKNOWN')
        self.finish()

    def test_two_dispatch_workers_create_one_effect(self):
        h = self.begin()
        workers = [h.spawn('dispatch', fixture_bundle()) for _ in range(2)]
        results = []
        for worker in workers:
            stdout, stderr = worker.communicate(timeout=15)
            self.assertEqual(worker.returncode, 0, stderr)
            results.append(json.loads(stdout))
        self.assertEqual(sum(r['forwarded'] for r in results), 1)
        self.snapshot('TWO_WORKERS_ONE_HTTP_REQUEST', 1, 1, 'UNKNOWN')
        self.finish()

    def test_stale_authorization_never_reaches_http(self):
        h = self.begin()
        h.command('context', {'generation': 2})
        self.blocked(fixture_bundle(), reason='AUTHORITY')
        self.snapshot('STALE_AUTHORITY_NO_REQUEST_NO_EFFECT', 0, 0)

    def test_receipt_replay_is_rejected(self):
        h = self.begin()
        reply = h.command('dispatch', fixture_bundle())['http']['body']['receipt']
        self.assertTrue(h.command('reconcile', reply)['applied'])
        self.assertFalse(h.command('reconcile', reply)['applied'])
        self.snapshot('EXACT_RECEIPT_REPLAY_REJECTED', 1, 1, 'COMMITTED')

    def test_unguarded_direct_http_really_duplicates(self):
        h = self.begin()
        for _ in range(2):
            self.assertEqual(exchange(h.url, '/effect', {'token': asdict(token())})['transport'],
                             'RESPONSE_RECEIVED')
        self.snapshot('BYPASS_CONTROL_TWO_REQUESTS_TWO_EFFECTS', 2, 2)
        receipt = exchange(h.url, '/receipt', {'token': asdict(token())})['body']
        self.assertEqual(receipt['status'], 'CONFLICT')
        self.assertNotIn('receipt', receipt)


class NativeTests(Cases, unittest.TestCase):
    engine = 'native'


class BaselineTests(Cases, unittest.TestCase):
    engine = 'baseline'


if __name__ == '__main__':
    unittest.main(verbosity=2)

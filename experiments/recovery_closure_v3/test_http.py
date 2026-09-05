"""Deterministic interleavings over real sockets and an external effect observer."""
from __future__ import annotations
from dataclasses import asdict
import json
from pathlib import Path
import selectors
import subprocess
import sys
import tempfile
import time
import unittest
from source_pins import prepare

HTTP = prepare()
from proof import fixture_bundle, token  # noqa: E402
ROOT = Path(__file__).resolve().parent
TRACES = []
POLICIES = ('hold', 'snapshot_negative', 'admission_fence', 'atomic_fence')
GATES = ('before_check', 'after_check', 'drop_before_effect', 'normal')


class Harness:
    def __init__(self, root, policy, gate, engine='native'):
        self.root, self.policy, self.gate, self.engine = root, policy, gate, engine
        self.server = None
        self.start()
        self.controller = None
        if engine:
            self.controller = HTTP.HTTPController(root / 'controller', engine, self.url)
            self.controller.initialize()

    def start(self):
        self.server = subprocess.Popen(
            [sys.executable, str(ROOT / 'receiver.py'), '--root', str(self.root / 'device'),
             '--policy', self.policy, '--gate', self.gate],
            stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
        selector = selectors.DefaultSelector()
        selector.register(self.server.stdout, selectors.EVENT_READ)
        try:
            if not selector.select(10):
                self.close()
                raise TimeoutError('receiver startup')
            line = self.server.stdout.readline()
            if not line:
                _, err = self.server.communicate(timeout=3)
                raise RuntimeError('receiver failed: ' + err)
            self.url = json.loads(line)['url']
        finally:
            selector.close()

    def restart(self):
        self.close()
        self.gate = 'normal'
        self.start()
        if self.engine:
            self.controller = HTTP.HTTPController(self.root / 'controller', self.engine, self.url)

    def close(self):
        if self.server:
            if self.server.poll() is None:
                self.server.kill()
            self.server.communicate(timeout=5)

    def request(self, path, value=None, timeout=2):
        result = HTTP.exchange(self.url, path, value or {'probe': True}, timeout)
        if result['transport'] != 'RESPONSE_RECEIVED':
            raise AssertionError(result)
        return result['body']

    def wait(self, key):
        deadline = time.monotonic() + 5
        while time.monotonic() < deadline:
            if self.request('/gate').get(key):
                return
            time.sleep(0.005)
        raise TimeoutError(key)

    def dispatch(self, attempt, **kwargs):
        if self.controller:
            return self.controller.dispatch(fixture_bundle(token(attempt), **kwargs), timeout=.12)
        return {'forwarded': True, 'http': HTTP.exchange(self.url, '/effect', {'token': asdict(token(attempt))}, .12)}

    def resolve(self, attempt):
        reply = self.request('/resolve', {'token': asdict(token(attempt))})
        # EXPLICIT NEW EXPERIMENTAL ADAPTER: v2's recover accepts only positives.
        # No state is forced and no native lifecycle implementation is modified.
        if self.controller and 'receipt' in reply:
            reply['application'] = self.controller.reconcile(reply['receipt'])
        return reply

    def witness(self):
        result = subprocess.run([sys.executable, str(ROOT / 'observer.py'),
                                 str(self.root / 'device/receiver.sqlite')],
                                capture_output=True, text=True, check=True, timeout=8)
        return json.loads(result.stdout)

    def snapshot(self, event):
        return {'event': event, 'witness': self.witness(),
                'controller': self.controller.observation() if self.controller else None}


def scenario(policy, gate, engine):
    with tempfile.TemporaryDirectory() as temp:
        h = Harness(Path(temp), policy, gate, engine)
        steps = []
        try:
            first = h.dispatch(0)
            if not (first['forwarded']):
                raise AssertionError(first)
            if gate != 'normal':
                h.wait('arrived')
            steps.append(h.snapshot('INITIAL_REQUEST'))
            closure = h.resolve(0)
            if engine and 'receipt' in closure:
                if not (closure['application']['applied']):
                    raise AssertionError(closure)
            retry = h.dispatch(1)
            steps.append(h.snapshot('AFTER_RECOVERY_BEFORE_RELEASE'))
            h.request('/release')
            if gate in ('before_check', 'after_check'):
                h.wait('finished')
            if engine:
                if retry['forwarded']:
                    positive = h.resolve(1)
                    if not (positive['status'] == 'COMMITTED' and positive['application']['applied']):
                        raise AssertionError(positive)
                elif gate != 'drop_before_effect' and closure['status'] != 'COMMITTED':
                    positive = h.resolve(0)
                    if not (positive['status'] == 'COMMITTED' and positive['application']['applied']):
                        raise AssertionError(positive)
            steps.append(h.snapshot('FINAL'))
            if policy == 'operation_idempotency':
                expected = 1
            elif gate == 'drop_before_effect':
                expected = 0 if policy == 'hold' else 1
            elif gate == 'normal':
                expected = 1
            elif policy == 'snapshot_negative' or (policy == 'admission_fence' and gate == 'after_check'):
                expected = 2
            else:
                expected = 1
            actual = steps[-1]['witness']['effect_count']
            if not (actual == expected):
                raise AssertionError((policy, gate, actual, expected))
            if not (all(s['witness']['integrity'] == 'ok' for s in steps)):
                raise AssertionError('test_http.py invariant at original line 140')
            if not (not (Path(temp) / 'controller/device.sqlite').exists()):
                raise AssertionError('test_http.py invariant at original line 141')
            return {'policy': policy, 'gate': gate, 'engine': engine or 'ordinary_operation_idempotency',
                    'closure_status': closure['status'], 'retry_forwarded': retry['forwarded'],
                    'effects_at_recovery': steps[1]['witness']['effect_count'],
                    'final_effects': actual, 'expected_effects': expected, 'steps': steps}
        finally:
            h.close()


class MatrixTests(unittest.TestCase):
    pass

for _policy in POLICIES:
    for _gate in GATES:
        for _engine in ('native', 'baseline'):
            def test(self, policy=_policy, gate=_gate, engine=_engine):
                TRACES.append(scenario(policy, gate, engine))
            setattr(MatrixTests, f'test_{_policy}_{_gate}_{_engine}', test)
for _gate in GATES:
    def test(self, gate=_gate):
        TRACES.append(scenario('operation_idempotency', gate, None))
    setattr(MatrixTests, f'test_operation_idempotency_{_gate}', test)


class BoundaryTests(unittest.TestCase):
    def test_atomic_tombstone_and_receipt_survive_receiver_restart(self):
        for engine in ('native', 'baseline'):
            with self.subTest(engine=engine), tempfile.TemporaryDirectory() as temp:
                h = Harness(Path(temp), 'atomic_fence', 'drop_before_effect', engine)
                try:
                    h.dispatch(0)
                    reply = h.resolve(0)
                    self.assertTrue(reply['application']['applied'])
                    before = h.witness()
                    h.restart()
                    replay = h.request('/effect', {'token': asdict(token(0))})
                    self.assertEqual(replay['status'], 'CLOSED_REJECTED')
                    self.assertTrue(h.dispatch(1)['forwarded'])
                    self.assertTrue(h.resolve(1)['application']['applied'])
                    after = h.witness()
                    self.assertEqual(after['effect_count'], 1)
                    self.assertEqual(before['closed_rows'], after['closed_rows'])
                    TRACES.append({'boundary': 'receiver_restart', 'engine': engine, 'before': before, 'after': after})
                finally:
                    h.close()

    def test_tampered_negative_receipt_does_not_open_retry(self):
        for engine in ('native', 'baseline'):
            with self.subTest(engine=engine), tempfile.TemporaryDirectory() as temp:
                h = Harness(Path(temp), 'atomic_fence', 'drop_before_effect', engine)
                try:
                    h.dispatch(0)
                    reply = h.request('/resolve', {'token': asdict(token(0))})
                    receipt = dict(reply['receipt'])
                    receipt['auth_tag'] ^= 1
                    self.assertFalse(h.controller.reconcile(receipt)['authenticated'])
                    self.assertFalse(h.dispatch(1)['forwarded'])
                    self.assertTrue(h.controller.reconcile(reply['receipt'])['applied'])
                    self.assertTrue(h.dispatch(1)['forwarded'])
                    self.assertEqual(h.witness()['effect_count'], 1)
                    TRACES.append({'boundary': 'tampered_negative', 'engine': engine, 'after': h.snapshot('VALID_CLOSURE_REQUIRED')})
                finally:
                    h.close()

    def test_closure_is_not_new_execution_authority(self):
        for engine in ('native', 'baseline'):
            with self.subTest(engine=engine), tempfile.TemporaryDirectory() as temp:
                h = Harness(Path(temp), 'atomic_fence', 'drop_before_effect', engine)
                try:
                    h.dispatch(0)
                    self.assertTrue(h.resolve(0)['application']['applied'])
                    h.controller.context(generation=2, state_version='state/2')
                    self.assertFalse(h.dispatch(1)['forwarded'])
                    self.assertTrue(h.dispatch(1, generation=2, state_version='state/2')['forwarded'])
                    self.assertEqual(h.witness()['effect_count'], 1)
                    TRACES.append({'boundary': 'authority_generation', 'engine': engine, 'after': h.snapshot('FRESH_AUTHORITY_REQUIRED')})
                finally:
                    h.close()

    def test_foreign_attempt_closure_does_not_close_own_attempt(self):
        with tempfile.TemporaryDirectory() as temp:
            h = Harness(Path(temp), 'atomic_fence', 'normal', None)
            try:
                foreign = token(0, command_id=10)
                reply = h.request('/resolve', {'token': asdict(foreign)})
                self.assertEqual(reply['status'], 'NOT_COMMITTED')
                own = h.request('/effect', {'token': asdict(token())})
                self.assertEqual(own['status'], 'EFFECT')
                self.assertEqual(h.witness()['effect_count'], 1)
                TRACES.append({'boundary': 'foreign_closure', 'after': h.witness()})
            finally:
                h.close()

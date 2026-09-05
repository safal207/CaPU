"""Run every test and emit a reproducible bounded evidence manifest."""
from __future__ import annotations
import argparse
import hashlib
import io
import json
from pathlib import Path
import platform
import sqlite3
import sys
import tempfile
import unittest
import cryptography
from bootstrap import PINS, ROOT, sources
from proof import Lab, fixture_bundle, fixture_receipt, token
from test_proof import crash
import test_proof


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def scenario(engine: str) -> dict:
    with tempfile.TemporaryDirectory() as root:
        lab = Lab(root, engine)
        lab.initialize()
        lab = crash(lab, 'after_effect', fixture_bundle())
        steps = [{'event': 'PROCESS_EXIT_AFTER_EFFECT_BEFORE_ACK', **lab.observation()}]
        result = lab.dispatch(fixture_bundle(token(1)))
        steps.append({'event': 'RETRY_WHILE_UNKNOWN', 'decision': result, **lab.observation()})
        forged = fixture_receipt(outcome='NOT_COMMITTED')
        forged['auth_tag'] ^= 1
        result = lab.reconcile(forged)
        steps.append({'event': 'FORGED_NEGATIVE', 'decision': result, **lab.observation()})
        # Current authority changes must not erase a historical external effect.
        lab.context(generation=2, state_version='state/2')
        result = lab.reconcile(fixture_receipt())
        steps.append({'event': 'LATE_EXACT_RECEIPT_AFTER_POLICY_CHANGE',
                      'decision': result, **lab.observation()})
        result = lab.dispatch(fixture_bundle(token(1), generation=2, state_version='state/2'))
        steps.append({'event': 'RETRY_AFTER_TERMINAL_COMMIT', 'decision': result, **lab.observation()})
        return {'engine': engine, 'steps': steps}


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument('--output', type=Path, default=ROOT / 'evidence')
    args = parser.parse_args()
    args.output.mkdir(parents=True, exist_ok=True)
    upstream = sources()
    log = io.StringIO()
    suite = unittest.defaultTestLoader.loadTestsFromModule(test_proof)
    result = unittest.TextTestRunner(stream=log, verbosity=2).run(suite)
    (args.output / 'tests.txt').write_text(log.getvalue())
    print(log.getvalue())
    if not result.wasSuccessful():
        return 1
    native, baseline = scenario('native'), scenario('baseline')
    if native['steps'] != baseline['steps']:
        raise AssertionError('end-to-end baseline/native disagreement')
    manifest = {
        'schema': 'capu.atman.process-recovery.lab.v1',
        'status': 'BOUNDED_SOFTWARE_COMPOSITION_PASS',
        'tests': {'run': result.testsRun, 'failures': len(result.failures),
                  'errors': len(result.errors), 'skipped': len(result.skipped)},
        'differential': {'seed': 20260905, 'traces': 24, 'steps_per_trace': 12,
                         'compared_steps': 288, 'all_equal': True},
        'process_crash_cut_points': ['before_commit', 'after_commit', 'after_effect',
                                     'during_reconcile', 'after_reconcile'],
        'baseline': 'independent ordinary FSM; shared I/O, ATMAN verifier and synthetic tag primitive',
        'native_scenario': native, 'baseline_scenario': baseline,
        'environment': {'python': platform.python_version(), 'sqlite': sqlite3.sqlite_version,
                        'cryptography': cryptography.__version__, 'platform': platform.system()},
        'upstream': [dict(repository=p[1], commit=p[2], path=p[3], git_blob_sha1=p[4],
                          sha256=sha256(path)) for p, path in zip(PINS, upstream)],
        'source_sha256': {name: sha256(ROOT / name)
                          for name in ('bootstrap.py', 'proof.py', 'test_proof.py', 'run.py')},
        'non_claims': [
            'No advantage over the equally capable conventional baseline established.',
            'No CPU/FPGA speed or energy measurement.',
            'No physical device, network, power-loss, adversarial-storage or Byzantine proof.',
            'No production cryptographic claim for A7 synthetic receipts or public fixture keys.',
            'No exactly-once or general liveness guarantee; UNKNOWN can remain blocked indefinitely.',
            'No full ATMAN runtime or Bardo/COSMIC integration.',
            'Native inputs are three pinned modules, not the entire repositories or test suites.',
            'Dispatch policy linearizes at durable admission, not at physical actuation.',
            'Evidence digest is not an independent timestamp, trust anchor or completeness proof.',
        ],
    }
    canonical = json.dumps(manifest, sort_keys=True, separators=(',', ':')).encode()
    manifest['result_digest_sha256'] = hashlib.sha256(canonical).hexdigest()
    (args.output / 'result.json').write_text(json.dumps(manifest, indent=2) + '\n')
    print('BOUNDED_SOFTWARE_COMPOSITION_PASS', manifest['result_digest_sha256'])
    return 0


if __name__ == '__main__':
    sys.exit(main())

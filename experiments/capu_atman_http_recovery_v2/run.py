"""Run the HTTP experiment; emit FAIL even if a test aborts, never stale PASS."""
import argparse
import hashlib
import io
import json
from pathlib import Path
import platform
import sqlite3
import sys
import unittest
import cryptography
import test_http_boundary as tests
from http_boundary import ROOT, PINS


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--output', type=Path, default=ROOT / 'evidence')
    args = parser.parse_args()
    args.output.mkdir(parents=True, exist_ok=True)
    tests.TRACE_LOG.clear()
    stream = io.StringIO()
    suite = unittest.defaultTestLoader.loadTestsFromModule(tests)
    result = unittest.TextTestRunner(stream=stream, verbosity=2).run(suite)
    log = stream.getvalue()
    (args.output / 'tests.txt').write_text(log)
    print(log, flush=True)
    native = {t['scenario']: t['steps'] for t in tests.TRACE_LOG if t['engine'] == 'native'}
    baseline = {t['scenario']: t['steps'] for t in tests.TRACE_LOG if t['engine'] == 'baseline'}
    equal = bool(native) and native == baseline
    passed = result.wasSuccessful() and not result.skipped and result.testsRun == 28 and equal
    manifest = {
        'schema': 'capu.atman.http-recovery.lab.v2',
        'status': 'BOUNDED_LOOPBACK_HTTP_RECOVERY_PASS' if passed else 'FAIL',
        'tests': {'run': result.testsRun, 'failures': len(result.failures),
                  'errors': len(result.errors), 'skipped': len(result.skipped)},
        'compared_scenarios': len(native), 'same_observations_as_baseline': equal,
        'observed_snapshots_per_arm': sum(len(steps) for steps in native.values()),
        'processes': ['controller subprocess', 'HTTP device subprocess', 'read-only observer subprocess'],
        'v1_head': '977864167c65f161e6db87b3d14257a11a67516f',
        'v1_source_sha256': PINS,
        'source_sha256': {p.name: hashlib.sha256(p.read_bytes()).hexdigest()
                          for p in sorted(ROOT.glob('*.py'))},
        'environment': {'python': platform.python_version(), 'sqlite': sqlite3.sqlite_version,
                        'cryptography': cryptography.__version__, 'platform': platform.system()},
        'traces': sorted(tests.TRACE_LOG, key=lambda t: (t['engine'], t['scenario'])),
        'non_claims': [
            'A real loopback HTTP/process boundary, not a third-party service, physical device or WAN test.',
            'The durable device-ledger insertion IS the external effect; no distributed atomicity is claimed.',
            'Separate observer path, not an independent organization, trust anchor or source-completeness proof.',
            'Same trusted host; process isolation is not OS permission isolation or bypass resistance.',
            'A direct unguarded HTTP caller creates duplicate effects, intentionally demonstrated.',
            'Public fixture keys and synthetic A7 receipt tags remain non-production.',
            'UNKNOWN may remain blocked indefinitely; no general liveness or exactly-once guarantee.',
            'No physical power-loss, NVRAM, Byzantine-device, storage-rollback or production transport proof.',
            'No speed/energy or superiority claim over an equally capable conventional FSM.',
            'No full ATMAN runtime, Bardo/COSMIC integration, deployment or merge.'
        ]}
    canonical = json.dumps(manifest, sort_keys=True, separators=(',', ':')).encode()
    manifest['result_digest_sha256'] = hashlib.sha256(canonical).hexdigest()
    (args.output / 'result.json').write_text(json.dumps(manifest, indent=2) + '\n')
    print(manifest['status'], manifest['result_digest_sha256'], flush=True)
    return 0 if passed else 1


if __name__ == '__main__':
    sys.exit(main())

"""Run bounded model exploration and live HTTP cases; retain raw evidence."""
from __future__ import annotations
import argparse
import hashlib
import importlib.metadata
import json
from pathlib import Path
import platform
import sys
import time
import unittest
import finite_model
import test_http
from provenance import DEPENDENCY_COMMIT, revision, source_hashes

ROOT = Path(__file__).resolve().parent


def dump(path, value):
    """Save a complete JSON artifact with stable formatting."""
    path.write_text(json.dumps(value, indent=2, sort_keys=True) + '\n')


def run(output):
    """Execute the unchanged scenario matrix and validate its generated evidence."""
    if sys.flags.optimize:
        raise RuntimeError("Run the HTTP harness without optimization; the validator supports -O separately")
    before = source_hashes()
    output.mkdir(parents=True, exist_ok=True)
    start = time.monotonic()
    model = finite_model.run()
    dump(output / 'model.json', model)
    test_http.TRACES.clear()
    with (output / 'http-tests.txt').open('w') as log:
        result = unittest.TextTestRunner(stream=log, verbosity=2).run(unittest.defaultTestLoader.loadTestsFromModule(test_http))
    dump(output / 'http-traces.json', test_http.TRACES)
    matrix = [r for r in test_http.TRACES if 'policy' in r]
    paired = []
    for policy in test_http.POLICIES:
        for gate in test_http.GATES:
            pair = [r for r in matrix if r['policy'] == policy and r['gate'] == gate]
            if len(pair) != 2:
                paired.append({'policy': policy, 'gate': gate, 'equal': False, 'reason': 'missing pair'})
                continue
            a, b = [{k: v for k, v in r.items() if k != 'engine'} for r in pair]
            paired.append({'policy': policy, 'gate': gate, 'equal': a == b})
    summary = {'schema': 'recovery-closure-experiment/2', **revision(), 'dependency_commit': DEPENDENCY_COMMIT,
               'environment': {'python': sys.version, 'platform': platform.platform(), 'cryptography': importlib.metadata.version('cryptography')},
               'model_trace_count': model['trace_count'], 'model_summary': model['summary'],
               'http_tests': {'run': result.testsRun, 'failures': len(result.failures), 'errors': len(result.errors), 'skipped': len(result.skipped)},
               'http_matrix': [{k: v for k, v in r.items() if k != 'steps'} for r in matrix],
               'boundary_trace_count': len(test_http.TRACES) - len(matrix), 'native_fsm_comparisons': paired,
               'elapsed_seconds_including_subprocess_startup_not_a_performance_benchmark': round(time.monotonic()-start, 3),
               'source_sha256': source_hashes()}
    summary['success'] = result.wasSuccessful() and all(r['equal'] for r in paired) and before == summary['source_sha256']
    dump(output / 'summary.json', summary)
    print(json.dumps({k: summary[k] for k in ('success', 'http_tests', 'model_trace_count', 'boundary_trace_count')}, indent=2))
    if summary['success']:
        from validate_results import validate
        validate(output)
    return 0 if summary['success'] else 1

if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--output', type=Path, default=ROOT / 'evidence/new')
    sys.exit(run(parser.parse_args().output))

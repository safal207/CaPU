"""Run bounded model exploration and live HTTP cases; retain raw evidence."""
from __future__ import annotations
import argparse
import hashlib
import json
from pathlib import Path
import platform
import sys
import time
import unittest
import finite_model
import test_http

ROOT = Path(__file__).resolve().parent


def dump(path, value):
    path.write_text(json.dumps(value, indent=2, sort_keys=True) + '\n')


def run(output):
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
    summary = {'schema': 'recovery-closure-experiment/1', 'source_commit': '8a2f2a37023a50aeac52cb8c8aed84b2eeceec88',
               'environment': {'python': sys.version, 'platform': platform.platform()},
               'model_trace_count': model['trace_count'], 'model_summary': model['summary'],
               'http_tests': {'run': result.testsRun, 'failures': len(result.failures), 'errors': len(result.errors), 'skipped': len(result.skipped)},
               'http_matrix': [{k: v for k, v in r.items() if k != 'steps'} for r in matrix],
               'boundary_trace_count': len(test_http.TRACES) - len(matrix), 'native_fsm_comparisons': paired,
               'elapsed_seconds_including_subprocess_startup_not_a_performance_benchmark': round(time.monotonic()-start, 3),
               'source_sha256': {p.name: hashlib.sha256(p.read_bytes()).hexdigest() for p in sorted(ROOT.glob('*.py'))}}
    summary['success'] = result.wasSuccessful() and all(r['equal'] for r in paired)
    dump(output / 'summary.json', summary)
    print(json.dumps({k: summary[k] for k in ('success', 'http_tests', 'model_trace_count', 'boundary_trace_count')}, indent=2))
    return 0 if summary['success'] else 1

if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--output', type=Path, default=ROOT / 'evidence/new')
    sys.exit(run(parser.parse_args().output))

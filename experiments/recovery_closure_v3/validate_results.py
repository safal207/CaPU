"""Independent aggregation of saved evidence; does not rerun the HTTP harness."""
import collections
import hashlib
import json
from pathlib import Path
import sys

root = Path(sys.argv[1])
s = json.loads((root / 'summary.json').read_text())
m = json.loads((root / 'model.json').read_text())
h = json.loads((root / 'http-traces.json').read_text())
assert s['success'] and s['http_tests'] == {'run': 40, 'failures': 0, 'errors': 0, 'skipped': 0}
assert len(m['traces']) == m['trace_count'] == s['model_trace_count'] == 560
assert len({(x['policy'], x['initial_request_dropped'], tuple(x['order'])) for x in m['traces']}) == 560
aggregate = collections.defaultdict(lambda: [0, 0, 0])
for t in m['traces']:
    a = aggregate[(t['policy'], t['initial_request_dropped'])]
    a[0] += 1
    a[1] += t['effect_count'] > 1
    a[2] += t['effect_count'] == 0
for row in m['summary']:
    assert aggregate[(row['policy'], row['initial_request_dropped'])] == [row['schedules'], row['duplicate_traces'], row['incomplete_traces']]
raw = json.dumps(m['traces'], sort_keys=True, separators=(',', ':')).encode()
assert hashlib.sha256(raw).hexdigest() == m['trace_sha256']
matrix = [r for r in h if 'policy' in r]
assert len(matrix) == 36 and len(h) - len(matrix) == 7
pairs = collections.defaultdict(list)
for r in matrix:
    assert r['final_effects'] == r['steps'][-1]['witness']['effect_count']
    assert r['final_effects'] == len(r['steps'][-1]['witness']['effect_rows'])
    if r['engine'] in ('native', 'baseline'):
        pairs[(r['policy'], r['gate'])].append({k: v for k, v in r.items() if k != 'engine'})
assert len(pairs) == 16
assert all(len(p) == 2 and p[0] == p[1] for p in pairs.values())
for path, expected in s['source_sha256'].items():
    # Source pins refer to the files as executed, not a later unrecorded version.
    actual = hashlib.sha256((Path(__file__).resolve().parent / path).read_bytes()).hexdigest()
    assert actual == expected, path
print('VALIDATED: 560 distinct bounded traces, 40 tests, 36 HTTP matrix rows, 7 boundary traces, 16 native/FSM pairs.')

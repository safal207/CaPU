"""Fail-closed checks for the fixed v3 contract; not an authenticity attestation.

Fresh runs must identify the complete current producer inputs. Historical mode
accepts only the exact original archive and explicitly corrects its dependency
commit label, without rewriting any historical file.
"""
from __future__ import annotations

import argparse
import collections
import hashlib
import json
from pathlib import Path
import sys

from provenance import DEPENDENCY_COMMIT, ROOT, SOURCE_FILES, revision, source_hashes

POLICIES = ('hold', 'snapshot_negative', 'admission_fence', 'atomic_fence')
GATES = ('before_check', 'after_check', 'drop_before_effect', 'normal')
ENGINES = ('native', 'baseline')
EXPECTED_TESTS = {'run': 40, 'failures': 0, 'errors': 0, 'skipped': 0}


class ValidationError(ValueError):
    """The supplied evidence does not satisfy the declared experiment contract."""


def require(condition: bool, message: str) -> None:
    """Enforce a check even with Python -O or PYTHONOPTIMIZE."""
    if not condition:
        raise ValidationError(message)


def load_json(path: Path):
    """Reject duplicate keys and non-standard non-finite JSON numbers."""
    def pairs(items):
        value = {}
        for key, item in items:
            require(key not in value, 'Duplicate JSON key: ' + key)
            value[key] = item
        return value
    def constant(value):
        raise ValidationError('Non-finite JSON constant: ' + value)
    return json.loads(path.read_text(encoding='utf-8'), object_pairs_hook=pairs,
                      parse_constant=constant)


def canonical(value) -> bytes:
    """Canonical JSON also distinguishes booleans from integer counts."""
    return json.dumps(value, sort_keys=True, separators=(',', ':'), allow_nan=False).encode()


def equal(actual, expected, label: str) -> None:
    """Compare complete JSON values, not Python's bool/int-coercing equality."""
    require(canonical(actual) == canonical(expected), label)


def expected_effects(policy: str, gate: str) -> int:
    """Outcome oracle independent of the result's declared expected_effects."""
    if policy == 'operation_idempotency':
        return 1
    if gate == 'drop_before_effect':
        return 0 if policy == 'hold' else 1
    if gate == 'normal':
        return 1
    if policy == 'snapshot_negative' or (policy == 'admission_fence' and gate == 'after_check'):
        return 2
    return 1


def validate(root: Path, historical: bool = False, source_root: Path = ROOT,
             observation: Path | None = None) -> dict:
    """Check outcomes, raw-to-summary consistency and complete source identity."""
    contract = load_json(source_root / 'evidence_contract.json')
    s, m, h = [load_json(root / name) for name in
               ('summary.json', 'model.json', 'http-traces.json')]
    require(s['success'] is True, 'Run did not succeed')
    equal(s['http_tests'], EXPECTED_TESTS, 'HTTP test counts/failures/skips')
    require(type(m['trace_count']) is int and m['trace_count'] == 560, 'Model trace count')
    require(len(m['traces']) == 560 and s['model_trace_count'] == 560, 'Incomplete model coverage')
    keys = {(t['policy'], t['initial_request_dropped'], tuple(t['order'])) for t in m['traces']}
    require(len(keys) == 560, 'Duplicate model scenario identity')
    aggregate = collections.defaultdict(lambda: [0, 0, 0])
    for t in m['traces']:
        n = t['effect_count']
        require(type(n) is int and 0 <= n <= 2, 'Invalid effect count')
        require(type(t['initial_request_dropped']) is bool, 'Delivery condition must be boolean')
        require(t['duplicate'] is (n > 1) and t['incomplete'] is (n == 0), 'Trace outcome flags')
        require(n == len(t['history'][-1]['effect_attempts']), 'Trace/history contradiction')
        a = aggregate[(t['policy'], t['initial_request_dropped'])]
        a[0] += 1
        a[1] += int(n > 1)
        a[2] += int(n == 0)
    expected_summary = []
    for policy in (*POLICIES, 'operation_idempotency'):
        for dropped in (False, True):
            duplicates = 0 if dropped else {'snapshot_negative': 50, 'admission_fence': 15}.get(policy, 0)
            incomplete = 56 if dropped and policy == 'hold' else 0
            equal(aggregate[(policy, dropped)], [56, duplicates, incomplete], 'Wrong bounded-model outcome')
            expected_summary.append({'policy': policy, 'initial_request_dropped': dropped,
                                     'schedules': 56, 'duplicate_traces': duplicates,
                                     'incomplete_traces': incomplete})
    equal(m['summary'], expected_summary, 'Model aggregate is not the contract aggregate')
    equal(s['model_summary'], expected_summary, 'Summary/model aggregate mismatch')
    digest = hashlib.sha256(canonical(m['traces'])).hexdigest()
    require(digest == m['trace_sha256'] == contract['model_trace_sha256'],
            'Model histories differ from the frozen v3 contract')

    matrix = [r for r in h if 'policy' in r]
    boundary = [r for r in h if 'policy' not in r]
    expected_ids = {(p, g, e) for p in POLICIES for g in GATES for e in ENGINES}
    expected_ids |= {('operation_idempotency', g, 'ordinary_operation_idempotency') for g in GATES}
    ids = [(r['policy'], r['gate'], r['engine']) for r in matrix]
    require(len(ids) == 36 and len(set(ids)) == 36 and set(ids) == expected_ids,
            'Missing, duplicate or unexpected HTTP scenario')
    pairs = collections.defaultdict(dict)
    for r in matrix:
        label = f"{r['policy']}/{r['gate']}/{r['engine']}"
        expected = expected_effects(r['policy'], r['gate'])
        equal(r['final_effects'], expected, 'Wrong actual effect count: ' + label)
        equal(r['expected_effects'], expected, 'Wrong declared oracle: ' + label)
        equal([step['event'] for step in r['steps']],
              ['INITIAL_REQUEST', 'AFTER_RECOVERY_BEFORE_RELEASE', 'FINAL'], 'Missing HTTP phases')
        for step in r['steps']:
            w = step['witness']
            require(w['integrity'] == 'ok', 'Observer integrity failure')
            equal(w['effect_count'], len(w['effect_rows']), 'Observer row/count mismatch')
        equal(r['final_effects'], r['steps'][-1]['witness']['effect_count'], 'Final/observer mismatch')
        equal(r['effects_at_recovery'], r['steps'][1]['witness']['effect_count'], 'Recovery/observer mismatch')
        if r['engine'] in ENGINES:
            pairs[(r['policy'], r['gate'])][r['engine']] = {k: v for k, v in r.items() if k != 'engine'}
    comparisons = []
    for p in POLICIES:
        for g in GATES:
            pair = pairs[(p, g)]
            equal(pair['native'], pair['baseline'], 'Native/baseline evidence differs')
            comparisons.append({'policy': p, 'gate': g, 'equal': True})
    equal(s['native_fsm_comparisons'], comparisons, 'Comparison summary mismatch')
    equal(s['http_matrix'], [{k: v for k, v in r.items() if k != 'steps'} for r in matrix],
          'HTTP summary does not match raw records')
    require(len(boundary) == s['boundary_trace_count'] == 7, 'Boundary trace coverage')
    boundary_ids = [(r['boundary'], r.get('engine')) for r in boundary]
    expected_boundary = {(b, e) for b in ('receiver_restart', 'tampered_negative', 'authority_generation') for e in ENGINES}
    expected_boundary.add(('foreign_closure', None))
    require(len(set(boundary_ids)) == 7 and set(boundary_ids) == expected_boundary, 'Boundary identities')
    # Fixed deterministic transcript pins protect less prominent fields, including
    # controller state, closure identity and negative-receipt boundary witnesses.
    require(hashlib.sha256(canonical(h)).hexdigest() == contract['http_canonical_sha256'],
            'HTTP transcript differs from the frozen v3 contract')

    observed = observation or source_root / 'evidence/observed-summary.json'
    require(hashlib.sha256(observed.read_bytes()).hexdigest() in {contract['observation_sha256'], contract['repository_observation_sha256']},
            'Historical observed-summary was edited')
    obs = load_json(observed)
    for field in ('http_tests', 'model_trace_count', 'model_summary'):
        equal(obs[field], s[field], 'Observed summary mismatch: ' + field)
    equal(obs['native_fsm_pairs'], len(comparisons), 'Observed pair count')
    require(obs['native_fsm_all_equal'] is True, 'Observed pair verdict')
    equal(obs['source_sha256'], contract['source_sha256'], 'Historical source inventory mismatch')
    equal(obs['source_commit'], contract['legacy_dependency_label'], 'Historical dependency label changed')

    if historical:
        require(s['schema'] == 'recovery-closure-experiment/1', 'Not the historical schema')
        for name, expected_hash in contract['artifact_sha256'].items():
            require(hashlib.sha256((root / name).read_bytes()).hexdigest() == expected_hash,
                    'Historical artifact changed: ' + name)
        equal(s['source_sha256'], contract['source_sha256'], 'Historical sources missing/changed')
        equal(s['source_commit'], contract['legacy_dependency_label'], 'Historical commit label changed')
        mode = 'exact historical archive; legacy source_commit labels the v2 dependency, not the v3 producer'
    else:
        require(s['schema'] == 'recovery-closure-experiment/2', 'Fresh evidence requires schema /2; use --historical for archive')
        require(set(s['source_sha256']) == set(SOURCE_FILES), 'Incomplete/unexpected source inventory')
        equal(s['source_sha256'], source_hashes(source_root), 'Producer files changed')
        for name, expected in revision(source_root).items():
            equal(s[name], expected, 'Producer revision mismatch: ' + name)
        equal(s['dependency_commit'], DEPENDENCY_COMMIT, 'Dependency revision mismatch')
        mode = 'fresh local producer identities and fixed outcome contract'
    return {'status': 'VALIDATED', 'mode': mode, 'tests': 40, 'model_traces': 560,
            'matrix_rows': 36, 'boundary_rows': 7, 'native_fsm_pairs': 16,
            'not_an_independent_or_cryptographic_attestation': True}


def main() -> int:
    """Return nonzero on malformed, partial or inconsistent evidence."""
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('evidence', type=Path)
    parser.add_argument('--historical', action='store_true')
    args = parser.parse_args()
    try:
        result = validate(args.evidence, args.historical)
    except (ValidationError, KeyError, TypeError, ValueError, IndexError, OSError) as exc:
        print('REJECTED: ' + str(exc), file=sys.stderr)
        return 1
    print(json.dumps(result, indent=2))
    return 0


if __name__ == '__main__':
    sys.exit(main())

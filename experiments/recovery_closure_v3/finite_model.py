"""Exhaustive finite interleavings, not a model of arbitrary distributed executions."""
from __future__ import annotations
import hashlib
import itertools
import json

POLICIES = ('hold', 'snapshot_negative', 'admission_fence', 'atomic_fence', 'operation_idempotency')
CHAINS = (('check0', 'effect0', 'replay0'), ('close', 'receipt', 'retry', 'check1', 'effect1'))


def schedules():
    # Recursive linear extensions avoid assuming a probability distribution.
    def extend(a, b, prefix):
        if a == len(CHAINS[0]) and b == len(CHAINS[1]):
            yield tuple(prefix)
        if a < len(CHAINS[0]):
            yield from extend(a + 1, b, prefix + [CHAINS[0][a]])
        if b < len(CHAINS[1]):
            yield from extend(a, b + 1, prefix + [CHAINS[1][b]])
    return list(extend(0, 0, []))


def simulate(policy, order, dropped=False):
    effects, closed, admitted = set(), set(), set()
    response, known, retry = 'UNKNOWN', 'UNKNOWN', False
    history = []

    def effect(attempt):
        if policy == 'atomic_fence' and attempt in closed:
            return
        if policy == 'operation_idempotency' and effects:
            return
        effects.add(attempt)  # Common per-attempt idempotency, NOT per-operation.

    for event in order:
        if event == 'check0' and not dropped and 0 not in closed:
            admitted.add(0)
        elif event == 'effect0' and 0 in admitted:
            effect(0)
        elif event == 'replay0' and not dropped and 0 not in closed:
            effect(0)  # A redelivered request performs a new admission check.
        elif event == 'close':
            if 0 in effects:
                response = 'COMMITTED'
            elif policy in ('hold', 'operation_idempotency'):
                response = 'UNKNOWN'
            else:
                response = 'NOT_COMMITTED'
                if policy in ('admission_fence', 'atomic_fence'):
                    closed.add(0)
        elif event == 'receipt':
            known = response
        elif event == 'retry':
            retry = known == 'NOT_COMMITTED' or policy == 'operation_idempotency'
        elif event == 'check1' and retry:
            admitted.add(1)
        elif event == 'effect1' and 1 in admitted:
            effect(1)
        history.append({'event': event, 'effect_attempts': sorted(effects),
                        'closed_attempts': sorted(closed), 'known': known, 'retry': retry})
    return {'policy': policy, 'initial_request_dropped': dropped,
            'order': list(order), 'effect_count': len(effects),
            'duplicate': len(effects) > 1, 'incomplete': not effects, 'history': history}


def run():
    orders = schedules()
    # Independent combinatorial check: all permutations filtered by both chains.
    brute = {p for p in itertools.permutations(sum(CHAINS, ()))
             if all(all(p.index(a) < p.index(b) for a, b in zip(c, c[1:])) for c in CHAINS)}
    if not (set(orders) == brute and len(orders) == 56):
        raise AssertionError('finite_model.py invariant at original line 71')
    traces, summary = [], []
    for policy in POLICIES:
        for dropped in (False, True):
            batch = [simulate(policy, o, dropped) for o in orders]
            traces += batch
            summary.append({'policy': policy, 'initial_request_dropped': dropped,
                            'schedules': len(batch), 'duplicate_traces': sum(r['duplicate'] for r in batch),
                            'incomplete_traces': sum(r['incomplete'] for r in batch)})
    for policy in ('hold', 'atomic_fence', 'operation_idempotency'):
        if not (not any(r['duplicate'] for r in traces if r['policy'] == policy)):
            raise AssertionError('finite_model.py invariant at original line 81')
    for policy in ('snapshot_negative', 'admission_fence'):
        if not (any(r['duplicate'] for r in traces if r['policy'] == policy)):
            raise AssertionError('finite_model.py invariant at original line 83')
    if not (all(r['effect_count'] == 1 for r in traces if r['policy'] in ('atomic_fence', 'operation_idempotency'))):
        raise AssertionError('finite_model.py invariant at original line 84')
    if not (all(r['incomplete'] for r in traces if r['policy'] == 'hold' and r['initial_request_dropped'])):
        raise AssertionError('finite_model.py invariant at original line 85')
    encoded = json.dumps(traces, sort_keys=True, separators=(',', ':')).encode()
    return {'summary': summary, 'trace_count': len(traces),
            'trace_sha256': hashlib.sha256(encoded).hexdigest(), 'traces': traces}

if __name__ == '__main__':
    print(json.dumps(run(), indent=2))

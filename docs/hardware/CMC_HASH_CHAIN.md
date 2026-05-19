# CMC Hash-Chain Trace Integrity

Status: integrity sketch / future implementation target.

CMC currently has machine-readable trace events. The next integrity step is to make those trace sequences tamper-evident.

## Core idea

```text
trace_hash[n] = H(trace_hash[n-1] || canonical_trace_event[n])
```

If any prior event is modified, removed, or reordered, later hashes no longer verify.

## Why this matters

CMC is about transition legitimacy. Legitimacy evidence is only useful if the evidence sequence itself cannot be silently rewritten.

Hash chaining moves CMC from:

```text
machine-readable causal trace
```

toward:

```text
tamper-evident causal replay
```

## Minimal fields

Stable fields for hashing:

```text
seq
kind
decision
address
effect_id
cause_id
message
prev_hash
```

## Verification sketch

```text
prev_hash = GENESIS_HASH
for event in trace:
    canonical = canonicalize(event without trace_hash)
    expected = H(prev_hash || canonical)
    assert event.trace_hash == expected
    prev_hash = event.trace_hash
```

## Future Rust target

```text
TraceEvent.prev_hash
TraceEvent.trace_hash
trace_jsonl_with_hashes()
verify_trace_hash_chain(jsonl)
```

Suggested tests:

- valid trace verifies
- modified decision fails verification
- removed event fails verification
- reordered events fail verification
- changed cause_id fails verification

## Relation to stack

```text
CMC TraceEvent -> causal decision fact
CMC Hash Chain -> tamper-evident local sequence
T-Trace        -> broader trace integrity surface
LTP            -> replay/admissibility layer
```

## Non-claims

This is not yet a cryptographic implementation. It does not claim traces are currently tamper-proof.

## Short pitch

```text
TraceOut makes decisions observable.
Replay makes them reconstructable.
Hash chaining makes the evidence sequence tamper-evident.
```

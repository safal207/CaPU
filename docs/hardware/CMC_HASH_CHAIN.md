# CMC Hash-Chain Trace Integrity

Status: executable reference evidence / not production security certification.

CMC has machine-readable trace events and two executable trace-integrity paths:

```text
legacy developer hash-chain demo
std-only SHA-256 reference hash-chain path
```

The legacy path is kept for continuity with earlier fixtures and demos.

The SHA-256 path is now the stronger reference integrity path.

For the full trace-integrity evidence map, see:

```text
docs/hardware/CMC_TRACE_INTEGRITY.md
```

---

## Core idea

```text
trace_hash[n] = H(trace_hash[n-1] || canonical_trace_event[n])
```

If any prior event is modified, removed, or reordered, later hashes no longer verify.

This moves CMC from:

```text
machine-readable causal trace
```

toward:

```text
tamper-evident causal replay evidence
```

---

## Why this matters

CMC is about transition legitimacy.

Legitimacy evidence is only useful if the evidence sequence itself cannot be silently rewritten.

Hash chaining gives reviewers an executable way to check that a trace was not modified after it was emitted.

---

## Current implementation split

| Path | Status | Purpose | Command |
| --- | --- | --- | --- |
| Legacy FNV-1a64 path | executable developer demo | continuity with earlier trace hash-chain demo | `cargo run --bin verify_trace --locked` |
| Legacy FNV tamper demo | executable developer demo | shows modified trace decisions are detected by the legacy path | `cargo run --bin verify_trace_tampered --locked` |
| SHA-256 reference path | executable std-only reference | stronger trace sealing and verification evidence | `cargo run --bin verify_trace_sha256 --locked` |
| SHA-256 tamper demo | executable std-only reference | shows modified trace decisions are detected by the SHA-256 path | `cargo run --bin verify_trace_sha256_tampered --locked` |

Primary SHA-256 files:

```text
rust/cmc-core/src/trace_crypto.rs
rust/cmc-core/src/bin/verify_trace_sha256.rs
rust/cmc-core/src/bin/verify_trace_sha256_tampered.rs
```

---

## SHA-256 reference chain

The SHA-256 reference path uses:

```text
GENESIS_SHA256 = 0000000000000000000000000000000000000000000000000000000000000000
trace_hash = SHA256(prev_hash || canonical_event_line)
```

The current reference module exposes:

```text
GENESIS_SHA256
SealedTraceEvent
sha256_hex(input)
trace_hash(prev_hash, event)
seal_trace(jsonl)
verify_trace(sealed)
```

Current tests cover:

```text
SHA-256 empty-string test vector
SHA-256 abc test vector
sealed trace verifies
modified trace fails verification
```

---

## Minimal fields for canonical event evidence

Current trace events include:

```text
seq
kind
decision
address
effect_id
cause_id
message
```

The current SHA-256 reference path seals the canonical JSONL event line emitted by `trace_jsonl()`.

Future work should make canonical trace-event encoding more explicit and preserve golden sealed trace fixtures.

---

## Verification sketch

```text
prev_hash = GENESIS_HASH
for event in trace:
    canonical = canonicalize(event without trace_hash)
    expected = H(prev_hash || canonical)
    assert event.trace_hash == expected
    prev_hash = event.trace_hash
```

For the current SHA-256 reference path, `seal_trace(jsonl)` produces sealed events and `verify_trace(sealed)` checks the chain.

---

## CI coverage

The CMC CI workflow now runs both legacy and SHA-256 integrity checks:

```text
cargo run --bin verify_trace --locked
cargo run --bin verify_trace_tampered --locked
cargo run --bin verify_trace_sha256 --locked
cargo run --bin verify_trace_sha256_tampered --locked
```

The one-command reviewer path also runs these checks through:

```bash
npm run review:cmc
```

---

## Relation to replay fixtures

Replay fixture fingerprints currently remain developer-stability fingerprints for drift detection.

That means:

```text
replay fixture fingerprint != production cryptographic seal
```

The SHA-256 path is the current reference implementation for trace-integrity evidence.

Future work should connect manifest entries to SHA-256 sealed trace fixtures or a companion integrity manifest.

---

## Relation to stack

```text
CMC TraceEvent          -> causal decision fact
CMC replay fixtures     -> manifest-linked legitimacy scenarios
CMC audit report        -> auditor-facing JSONL evidence
CMC legacy hash chain   -> developer continuity integrity demo
CMC SHA-256 path        -> stronger executable trace-integrity reference
T-Trace                 -> broader trace integrity surface
LTP                     -> replay/admissibility layer
```

---

## Current honest claim

The current repository can claim:

```text
CMC traces can be emitted, sealed with a std-only SHA-256 reference path, verified, and tamper-detected through executable checks and CI-compatible reviewer commands.
```

---

## Non-claims

The current implementation does not yet claim:

- production-grade trace storage
- hardware root of trust
- certified cryptographic protocol
- adversarial runtime isolation
- formal security proof
- replacement for sandboxing, access control, or policy enforcement

The implementation is executable research evidence, not production security certification.

---

## Next work

Useful next steps:

1. define canonical trace-event encoding rules explicitly
2. add golden SHA-256 sealed trace fixtures
3. add a verifier that reads sealed trace files
4. connect manifest entries to sealed trace evidence
5. add removed-event and reordered-event negative fixtures
6. measure SHA-256 trace sealing overhead

---

## Short pitch

```text
TraceOut makes decisions observable.
Replay makes them reconstructable.
Hash chaining makes the evidence sequence tamper-evident.
SHA-256 makes the integrity path stronger and reviewer-checkable.
```

# CMC Trace Integrity

Status: executable reference evidence.

This document explains the current CMC trace-integrity evidence path.

The goal is not to claim production-grade security or certified hardware integrity.

The current goal is narrower:

```text
CMC trace events can be canonically encoded, sealed, saved as golden fixtures, replayed, checked, drift-detected, tamper-detected, and exercised by CI.
```

Canonical byte-level encoding is documented in:

```text
docs/hardware/CMC_CANONICAL_TRACE_ENCODING.md
```

---

## What exists today

The repository currently has two trace-integrity paths.

| Path | Implementation | Purpose | Reviewer command |
| --- | --- | --- | --- |
| Legacy developer hash path | FNV-1a64 demo inside CLI examples | Stable developer integrity demo and continuity with older fixtures | `cargo run --bin verify_trace --locked` |
| Legacy tamper demo | FNV-1a64 demo with modified trace event | Shows that changed trace decisions invalidate the legacy hash chain | `cargo run --bin verify_trace_tampered --locked` |
| SHA-256 reference path | `src/trace_crypto.rs` + `CMC_CANONICAL_TRACE_ENCODING.md` | Std-only reference trace sealing and verification path | `cargo run --bin verify_trace_sha256 --locked` |
| SHA-256 tamper demo | `src/bin/verify_trace_sha256_tampered.rs` | Shows that changed trace decisions invalidate the SHA-256 chain | `cargo run --bin verify_trace_sha256_tampered --locked` |
| SHA-256 sealed fixtures | `fixtures/trace_integrity/*.jsonl` | Saved valid/tampered sealed trace artifacts | `cargo run --bin verify_trace_sha256_fixture --locked` |

---

## SHA-256 reference path

The SHA-256 path is implemented without external Rust dependencies so that the existing `--locked` reviewer workflow remains stable.

Primary files:

```text
rust/cmc-core/src/trace_crypto.rs
rust/cmc-core/src/bin/verify_trace_sha256.rs
rust/cmc-core/src/bin/verify_trace_sha256_tampered.rs
rust/cmc-core/src/bin/verify_trace_sha256_fixture.rs
docs/hardware/CMC_CANONICAL_TRACE_ENCODING.md
```

Golden sealed fixtures:

```text
rust/cmc-core/fixtures/trace_integrity/sha256_valid.jsonl
rust/cmc-core/fixtures/trace_integrity/sha256_tampered.jsonl
```

The module exposes:

```text
GENESIS_SHA256
SealedTraceEvent
sha256_hex(input)
trace_hash(prev_hash, event)
seal_trace(jsonl)
verify_trace(sealed)
```

The verifier uses the same basic chain rule:

```text
trace_hash_n = SHA256(previous_trace_hash || canonical_event_line_n)
```

The first event starts from:

```text
0000000000000000000000000000000000000000000000000000000000000000
```

The canonical event line is produced by:

```text
TraceEvent::to_json_line()
```

Current v0 field order:

```text
seq, kind, decision, address, effect_id, cause_id, message
```

---

## Golden sealed fixtures

The saved SHA-256 fixtures turn the integrity path from a runtime-only demo into an audit artifact.

| Fixture | Expected meaning | Verifier expectation |
| --- | --- | --- |
| `sha256_valid.jsonl` | two-event sealed CMC trace | verifies successfully |
| `sha256_tampered.jsonl` | same trace with first decision modified but old hash preserved | fails at event 1 |

The valid fixture currently covers:

```text
seq=1 WRITE  REJECT_MISSING_CAUSE
seq=2 EFFECT REJECT_EFFECT_BEFORE_COMMIT
```

The tampered fixture changes the first event decision to:

```text
ACCEPT_WRITE
```

while preserving the old `trace_hash`, so `verify_trace_sha256_fixture` must reject it.

---

## Evidence currently checked by tests

`trace_crypto.rs` includes SHA-256 test vectors for:

| Input | Expected evidence |
| --- | --- |
| empty bytes | canonical SHA-256 empty-string digest |
| `abc` | canonical SHA-256 `abc` digest |
| two-event sealed trace | verifier accepts unchanged trace |
| modified first event | verifier rejects at event 1 |

This gives the reference implementation basic correctness and tamper-detection coverage.

---

## Evidence currently checked by CI

The CMC workflow now runs:

```text
cargo fmt --check
cargo test --all --locked
cargo run --bin cmc_demo --locked
cargo run --bin verify_trace --locked
cargo run --bin verify_trace_tampered --locked
cargo run --bin verify_trace_sha256 --locked
cargo run --bin verify_trace_sha256_tampered --locked
cargo run --bin verify_trace_sha256_fixture --locked
cargo run --bin replay_fixture_verify --locked
cargo run --bin replay_fingerprint_verify --locked
cargo run --bin cmc_audit_report --locked
cargo run --bin audit_report_example_verify --locked
cargo run --bin trace_divergence --locked
npm run review:cmc
```

This means the SHA-256 path is not merely documented. It is part of the executable reviewer path and has saved valid/tampered fixtures.

---

## Relationship to replay fixtures

Replay fixtures currently use stable manifest fingerprints for drift detection.

Those fingerprints are still developer-stability fingerprints, not cryptographic claims.

The SHA-256 path strengthens the trace-integrity layer by adding a stronger reference chain for CMC-generated trace events and saved sealed trace artifacts.

Current split:

| Layer | Current status |
| --- | --- |
| Replay fixture fingerprints | stable developer drift detection |
| Saved audit examples | field-level JSONL verification |
| Canonical trace encoding | v0 byte-level event-line encoding note |
| Legacy trace hash chain | FNV developer demo |
| SHA-256 trace hash chain | std-only reference path |
| SHA-256 sealed trace fixtures | saved valid/tampered integrity artifacts |
| CI gate | runs replay, audit, divergence, legacy trace, SHA-256 trace, and sealed fixture checks |

---

## Honest claim boundary

The current implementation supports this claim:

```text
CMC can produce canonically encoded trace evidence that is sealed, saved as golden fixtures, verified, tamper-detected, replay-checked, audit-reported, example-verified, and regression-tested.
```

The current implementation does not yet claim:

- production-grade trace storage
- hardware root of trust
- formal security certification
- adversarially hardened runtime isolation
- complete cryptographic protocol design
- full JSON canonicalization standard compatibility
- replacement for sandboxing, access control, or policy design

---

## Next integrity work

Useful next steps:

1. add exact canonical event-line tests
2. connect manifest entries to SHA-256 sealed trace evidence
3. add multi-step branch-divergence SHA-256 fixtures
4. add removed-event and reordered-event negative fixtures
5. measure SHA-256 trace sealing overhead
6. document threat model and non-goals more formally

---

## Reviewer summary

A reviewer can currently check trace integrity through both the one-command reviewer path and explicit CI steps.

The important upgrade is this:

```text
The project no longer relies only on a developer FNV hash-chain demo.
It now includes a documented v0 canonical trace encoding, a std-only SHA-256 reference path, positive/tamper executables, saved valid/tampered sealed fixtures, and a fixture verifier in CI.
```

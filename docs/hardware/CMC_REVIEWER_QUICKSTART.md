# CMC Reviewer Quickstart

Status: 5-minute reviewer path / executable evidence guide.

This document gives reviewers a short path from thesis to executable evidence.

Goal:

```text
verify that causal legitimacy is represented, replayed, checked, reported, field-level example-verified, canonically encoded, SHA-256 sealed, fixture-verified, manifest-linked, and regression-tested by executable artifacts
```

---

## 0. Read the thesis first

Start here:

1. [WHY_CAUSAL_COMPUTATION.md](WHY_CAUSAL_COMPUTATION.md)
2. [CAUSAL_EXECUTION_ARCHITECTURE.md](CAUSAL_EXECUTION_ARCHITECTURE.md)
3. [CMC_INVARIANTS.md](CMC_INVARIANTS.md)
4. [CMC_CANONICAL_TRACE_ENCODING.md](CMC_CANONICAL_TRACE_ENCODING.md)
5. [CMC_TRACE_INTEGRITY.md](CMC_TRACE_INTEGRITY.md)
6. [CMC_EVIDENCE_MAP.md](CMC_EVIDENCE_MAP.md)
7. [CMC_BASELINE_STATUS.md](CMC_BASELINE_STATUS.md)
8. [CMC_PHASE_2_ROADMAP.md](CMC_PHASE_2_ROADMAP.md)

Core claim:

```text
Traditional computing verifies state transitions.
Causal computing verifies transition legitimacy.
```

Baseline claim:

```text
transition legitimacy can be represented, replayed, checked, reported, field-level example-verified, canonically encoded, SHA-256 sealed, fixture-verified, one-command verified, manifest-linked, and regression-tested
```

---

## 1. Run the one-command reviewer demo

From repository root:

```bash
npm run review:cmc
```

This command runs the full CMC baseline evidence path:

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
```

Expected final output:

```text
result=reviewer_baseline_passed
```

Evidence claim:

```text
transition legitimacy can be represented, replayed, checked, reported, field-level example-verified, canonically encoded, SHA-256 sealed, fixture-verified, and regression-tested
```

---

## 2. What the one-command demo proves

The reviewer demo checks that:

```text
missing cause -> reject
unknown cause -> reject
effect before commit -> reject
committed cause -> accept effect
read without cause -> reject
read with unknown cause/address -> reject
read after legitimate write -> accept
trace events -> emitted deterministically
canonical trace event bytes -> documented
legacy valid trace -> accepted
legacy tampered decision -> detected
SHA-256 generated sealed trace -> accepted
SHA-256 generated tampered decision -> detected
SHA-256 saved valid fixture -> accepted
SHA-256 saved tampered fixture -> rejected at event 1
fixture structure -> valid
fixture fingerprints -> stable
manifest-linked audit report -> emitted as JSONL
saved audit examples -> field-level verified
expected trace vs diverged trace -> mismatch detected
```

Evidence claim:

```text
CMC can model memory/read/effect decisions using explicit causal authorization and executable replay evidence.
```

---

## 3. Manual command breakdown

If you want to inspect each step manually, run the following from `rust/cmc-core`.

### Simulator tests

```bash
cargo test --all --locked
```

Checks basic causal memory/read/effect invariants:

```text
missing cause -> reject
unknown cause -> reject
effect before commit -> reject
committed cause -> accept effect
read authorization -> checked
trace events -> emitted deterministically
```

### Canonical trace encoding

Read:

```text
docs/hardware/CMC_CANONICAL_TRACE_ENCODING.md
```

Expected meaning:

```text
trace event field order -> documented
null/number/string encoding -> documented
hash input bytes -> documented
current v0 limitations -> explicit
```

Current v0 field order:

```text
seq, kind, decision, address, effect_id, cause_id, message
```

### Blocked-transition demo

```bash
cargo run --bin cmc_demo --locked
```

Expected meaning:

```text
write_without_cause -> rejected
effect_before_commit -> rejected
trace_events -> emitted
result -> blocked illegitimate transition
```

### Legacy trace integrity and tampering detection

```bash
cargo run --bin verify_trace --locked
cargo run --bin verify_trace_tampered --locked
```

Expected meaning:

```text
legacy valid trace -> accepted
legacy tampered decision -> detected
```

Note: this is a developer FNV-1a64 hash-chain demo kept for continuity. It is not production cryptography.

### SHA-256 generated trace integrity and tampering detection

```bash
cargo run --bin verify_trace_sha256 --locked
cargo run --bin verify_trace_sha256_tampered --locked
```

Expected meaning:

```text
SHA-256 generated sealed trace -> accepted
SHA-256 generated tampered decision -> detected
```

The SHA-256 reference path is documented in:

```text
docs/hardware/CMC_TRACE_INTEGRITY.md
docs/hardware/CMC_CANONICAL_TRACE_ENCODING.md
```

Primary implementation files:

```text
rust/cmc-core/src/trace_crypto.rs
rust/cmc-core/src/bin/verify_trace_sha256.rs
rust/cmc-core/src/bin/verify_trace_sha256_tampered.rs
```

Note: this is stronger executable reference evidence than the legacy developer hash demo, but it is still not a production security certification.

### SHA-256 sealed fixture verification

```bash
cargo run --bin verify_trace_sha256_fixture --locked
```

Expected meaning:

```text
saved SHA-256 valid fixture -> accepted
saved SHA-256 tampered fixture -> rejected at event 1
```

Saved sealed fixtures:

```text
rust/cmc-core/fixtures/trace_integrity/sha256_valid.jsonl
rust/cmc-core/fixtures/trace_integrity/sha256_tampered.jsonl
```

Verifier:

```text
rust/cmc-core/src/bin/verify_trace_sha256_fixture.rs
```

This is important because it turns SHA-256 trace integrity from a runtime-only demo into stable saved evidence artifacts.

### Replay fixtures and fingerprint stability

```bash
cargo run --bin replay_fixture_verify --locked
cargo run --bin replay_fingerprint_verify --locked
```

Expected meaning:

```text
fixture structure -> valid
expected decisions -> present
fixture fingerprints -> stable
scenario/invariant/category/severity/verdict metadata -> parsed
```

Current replay corpus:

```text
I1 write_missing_cause
I2 write_unknown_cause
I3 effect_before_commit
I4 valid_committed_effect
I5 read_missing_cause
I6 read_unknown_cause_or_address
I7 effect_missing_parent
I8 valid_read_after_write
```

### Audit report JSONL

```bash
cargo run --bin cmc_audit_report --locked
```

Expected meaning:

```text
manifest-linked replay evidence -> emitted as JSONL
scenario_id -> included
invariant_id -> included
category/severity/expected_verdict -> included
fingerprint drift -> would fail the report
```

Saved examples:

```text
examples/audit_reports/cmc_audit_report_valid.jsonl
examples/audit_reports/cmc_audit_report_drift.jsonl
```

### Field-level saved audit example verification

```bash
cargo run --bin audit_report_example_verify --locked
```

Expected meaning:

```text
saved valid report -> 8 cases, 8 passed, 0 failed
saved drift report -> 8 cases, 7 passed, 1 failed
required JSONL fields -> checked explicitly
```

This is still an early developer report format, but the saved examples are executable-verified at field level.

### Divergence detection

```bash
cargo run --bin trace_divergence --locked
```

Expected meaning:

```text
expected trace vs diverged trace -> mismatch detected
```

---

## 4. Optional root-level commands

From repository root:

```bash
npm run demo:cmc
npm run verify:cmc-golden
npm run bench:cmc
```

These provide npm-facing entrypoints for demo, golden snapshot verification, and developer benchmark.

---

## 5. CI interpretation

The CMC GitHub Actions workflow runs the reviewer baseline and explicit CMC checks on changes to:

```text
rust/cmc-core/**
scripts/run-cmc-reviewer-demo.mjs
package.json
.github/workflows/cmc-rust.yml
```

The workflow includes explicit steps for:

```text
legacy trace verification
legacy tamper detection
SHA-256 generated trace verification
SHA-256 generated tamper detection
SHA-256 sealed fixture verification
audit report emission
saved audit example verification
replay divergence detection
one-command reviewer demo
```

Doc-only changes outside those paths do not necessarily trigger the workflow.

---

## What this quickstart proves

This quickstart demonstrates that CMC currently has executable evidence for:

- causal write rejection
- unknown cause rejection
- commit-before-effect enforcement
- accepted committed effect path
- causal read rejection without explicit cause
- causal read rejection with unknown cause or unavailable address
- accepted read after legitimate write
- deterministic trace emission
- documented v0 canonical trace encoding
- replay fixture checking
- fixture fingerprint stability
- manifest-linked audit report output
- saved valid/drift audit report examples
- field-level verification of saved audit examples
- legacy tampering detection
- SHA-256 generated trace sealing and verification
- SHA-256 generated tampering detection
- saved SHA-256 valid/tampered sealed fixtures
- executable verification of saved SHA-256 sealed fixtures
- divergence detection
- one-command reviewer verification
- CI-enforced replay/integrity/audit checks

---

## What this quickstart does not prove

It does not claim:

- production cryptography
- certified trace storage
- hardware root of trust
- hardware implementation
- formal verification
- complete AI safety coverage
- production workload performance
- full JSON canonicalization standard compatibility
- replacement for sandboxing, access control, or policy design

The current repository is an executable research scaffold.

---

## Reviewer interpretation

The key thing to evaluate is not whether CMC is finished.

The key thing to evaluate is whether the project has made this claim testable:

```text
transition legitimacy can be represented, replayed, checked, reported, field-level example-verified, canonically encoded, SHA-256 sealed, fixture-verified, manifest-linked, and regression-tested
```

That is the current proof point.

---

## One-line summary

```text
Run npm run review:cmc; it turns the CMC causal legitimacy claim into one executable reviewer check covering replay, audit examples, canonical trace encoding, trace integrity, saved SHA-256 fixtures, tamper detection, divergence detection, and CI-compatible validation.
```

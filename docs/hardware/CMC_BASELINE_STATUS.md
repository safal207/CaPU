# CMC Baseline Status

Status: reviewer-ready baseline snapshot.

This document summarizes the current CMC baseline after thesis, architecture, manifest-linked persona boundary corpus, 8 replay invariants, replay fixtures, manifest-linked evidence, audit report output, field-level verified audit examples, canonical trace encoding v0, legacy integrity demos, SHA-256 trace-integrity reference checks, saved SHA-256 sealed trace fixtures, one-command reviewer demo, and CI-gate work.

---

## Baseline claim

```text
transition legitimacy can be represented, replayed, checked, reported, persona-boundary-verified, field-level example-verified, canonically encoded, SHA-256 sealed, fixture-verified, one-command verified, manifest-linked, and regression-tested
```

The current repository does not claim a finished product. It claims an executable research scaffold for legitimacy-preserving computation.

Related persona-boundary framing:

```text
Future AI personas require causal legitimacy, not only conversational coherence.
```

---

## Current evidence chain

```text
thesis
 -> architecture
 -> persona boundary framing
 -> manifest-linked persona boundary corpus
 -> 8 replay invariants
 -> simulator
 -> deterministic trace events
 -> canonical trace encoding v0
 -> JSONL replay fixtures
 -> machine-readable replay manifest
 -> manifest-linked fixture structure checks
 -> manifest-linked fixture fingerprint checks
 -> JSONL audit report output
 -> saved valid/drift audit examples
 -> field-level audit report example verifier
 -> legacy hash-chain integrity demo
 -> legacy tampering detection demo
 -> SHA-256 generated trace sealing demo
 -> SHA-256 generated tampering detection demo
 -> saved SHA-256 sealed trace fixtures
 -> SHA-256 sealed fixture verifier
 -> divergence detection demo
 -> one-command reviewer demo
 -> CI workflow gate
 -> evidence map
 -> trace integrity doc
 -> reviewer quickstart
```

Short form:

```text
invariant -> scenario -> fixture -> manifest -> verifier -> audit report -> saved examples -> field-level example verifier -> persona boundary -> canonical trace encoding -> trace integrity -> sealed trace fixtures -> reviewer command -> CI
```

---

## Core documents

- [WHY_CAUSAL_COMPUTATION.md](WHY_CAUSAL_COMPUTATION.md)
- [CAUSAL_EXECUTION_ARCHITECTURE.md](CAUSAL_EXECUTION_ARCHITECTURE.md)
- [CAUSAL_MEMORY_CONTROLLER.md](CAUSAL_MEMORY_CONTROLLER.md)
- [CMC_PERSONA_BOUNDARY.md](CMC_PERSONA_BOUNDARY.md)
- [CMC_REPLAY.md](CMC_REPLAY.md)
- [CMC_HASH_CHAIN.md](CMC_HASH_CHAIN.md)
- [CMC_CANONICAL_TRACE_ENCODING.md](CMC_CANONICAL_TRACE_ENCODING.md)
- [CMC_TRACE_INTEGRITY.md](CMC_TRACE_INTEGRITY.md)
- [CMC_INVARIANTS.md](CMC_INVARIANTS.md)
- [CMC_AUDITOR_REPORT.md](CMC_AUDITOR_REPORT.md)
- [CMC_EVIDENCE_MAP.md](CMC_EVIDENCE_MAP.md)
- [CMC_REVIEWER_QUICKSTART.md](CMC_REVIEWER_QUICKSTART.md)
- [CMC_BASELINE_STATUS.md](CMC_BASELINE_STATUS.md)
- [CMC_PHASE_2_ROADMAP.md](CMC_PHASE_2_ROADMAP.md)

---

## Persona boundary

The persona boundary is documented in:

```text
docs/hardware/CMC_PERSONA_BOUNDARY.md
```

It frames CMC as a safety substrate for future companion/persona-like AI systems.

Core persona boundary rule:

```text
A persona may express continuity only when the continuity is causally grounded.
```

Current executable persona corpus:

```text
rust/cmc-core/fixtures/persona/MANIFEST.tsv
rust/cmc-core/fixtures/persona/inferred_preference_rejected.jsonl
rust/cmc-core/fixtures/persona/confirmed_preference_accepted.jsonl
rust/cmc-core/src/bin/persona_boundary_verify.rs
```

Current checked persona scenarios:

| Scenario | Invariant | Decision | Cause | Verdict |
| --- | --- | --- | --- | --- |
| `inferred_preference_rejected` | `P1` | `REJECT_INFERRED_MEMORY` | `null` | `blocked_unconfirmed_persona_memory` |
| `confirmed_preference_accepted` | `P1` | `ACCEPT_CONFIRMED_MEMORY` | `42` | `accepted_confirmed_persona_memory` |

Reviewer command:

```bash
cd rust/cmc-core
cargo run --bin persona_boundary_verify --locked
```

This is not a claim of AI consciousness, personhood, therapeutic capability, or autonomous moral agency.

---

## Replay corpus source of truth

Machine-readable replay manifest:

```text
rust/cmc-core/fixtures/replay/MANIFEST.tsv
```

Human-readable manifest explanation:

```text
rust/cmc-core/fixtures/replay/MANIFEST.md
```

Current manifest shape:

```tsv
scenario_id	invariant_id	path	decision	events	fingerprint	category	severity	expected_verdict
```

Current checked scenarios:

| Scenario | Invariant | Fixture | Decision | Events | Fingerprint | Category | Severity | Verdict |
| --- | --- | --- | --- | ---: | --- | --- | --- | --- |
| `write_missing_cause` | `I1` | `fixtures/replay/missing_cause.jsonl` | `REJECT_MISSING_CAUSE` | 1 | `88fd99689760140e` | `write_authorization` | high | `blocked_illegitimate_transition` |
| `write_unknown_cause` | `I2` | `fixtures/replay/unknown_cause.jsonl` | `REJECT_UNKNOWN_CAUSE` | 1 | `d8c4983b8a5a0ab0` | `write_authorization` | high | `blocked_illegitimate_transition` |
| `effect_before_commit` | `I3` | `fixtures/replay/forbidden_effect_before_commit_fixture.jsonl` | `REJECT_EFFECT_BEFORE_COMMIT` | 1 | `28bf87f68e4ec6cb` | `effect_commit_boundary` | critical | `blocked_illegitimate_transition` |
| `valid_committed_effect` | `I4` | `fixtures/replay/valid_committed_effect.jsonl` | `ACCEPT_EFFECT` | 1 | `e3e96ba017e2c235` | `effect_commit_boundary` | info | `accepted_legitimate_transition` |
| `read_missing_cause` | `I5` | `fixtures/replay/read_missing_cause.jsonl` | `REJECT_MISSING_CAUSE` | 1 | `9f49c650fcd31fff` | `read_authorization` | high | `blocked_illegitimate_transition` |
| `read_unknown_cause_or_address` | `I6` | `fixtures/replay/read_unknown_cause_or_address.jsonl` | `REJECT_UNKNOWN_CAUSE` | 1 | `91768923fb87d345` | `read_authorization` | high | `blocked_illegitimate_transition` |
| `effect_missing_parent` | `I7` | `fixtures/replay/effect_missing_parent.jsonl` | `REJECT_MISSING_CAUSE` | 1 | `da78371555a0b983` | `effect_commit_boundary` | critical | `blocked_illegitimate_transition` |
| `valid_read_after_write` | `I8` | `fixtures/replay/valid_read_after_write.jsonl` | `ACCEPT_READ` | 2 | `d6b83bfe3651c60d` | `read_authorization` | info | `accepted_legitimate_transition` |

These manifest fingerprints are developer-stability fingerprints for replay fixture drift detection. They are not production cryptographic evidence.

---

## Canonical trace encoding

Canonical trace encoding is documented in:

```text
docs/hardware/CMC_CANONICAL_TRACE_ENCODING.md
```

Current v0 trace event field order:

```text
seq, kind, decision, address, effect_id, cause_id, message
```

Current v0 hash input rule:

```text
trace_hash_n = SHA256(previous_trace_hash || canonical_event_line_n)
```

This document makes the SHA-256 trace-integrity path reviewer-checkable at the byte-level evidence boundary.

---

## Trace integrity

Trace integrity is documented in:

```text
docs/hardware/CMC_TRACE_INTEGRITY.md
```

Current trace-integrity checks:

```bash
cd rust/cmc-core
cargo run --bin verify_trace --locked
cargo run --bin verify_trace_tampered --locked
cargo run --bin verify_trace_sha256 --locked
cargo run --bin verify_trace_sha256_tampered --locked
cargo run --bin verify_trace_sha256_fixture --locked
```

Saved SHA-256 sealed trace fixtures:

```text
rust/cmc-core/fixtures/trace_integrity/sha256_valid.jsonl
rust/cmc-core/fixtures/trace_integrity/sha256_tampered.jsonl
```

Current split:

| Layer | Current status |
| --- | --- |
| Canonical trace encoding | v0 event-line byte rules documented |
| Legacy hash-chain demo | FNV-1a64 developer integrity path |
| Legacy tamper demo | detects modified trace decisions in the legacy path |
| SHA-256 generated trace path | std-only trace sealing and verification via `trace_crypto.rs` |
| SHA-256 generated tamper demo | detects modified trace decisions in the generated SHA-256 path |
| SHA-256 sealed fixture verifier | verifies saved valid fixture and rejects saved tampered fixture at event 1 |

This is stronger than the original developer hash-chain demo, but it is still not a production security certification.

---

## Audit report output

Current auditor-facing command:

```bash
cd rust/cmc-core
cargo run --bin cmc_audit_report --locked
```

It emits JSONL records derived from `MANIFEST.tsv` and fails if a fixture is missing, drifted, has the wrong event count, or no longer contains the expected decision.

Saved audit examples:

```text
examples/audit_reports/cmc_audit_report_valid.jsonl
examples/audit_reports/cmc_audit_report_drift.jsonl
```

The valid example now covers 8 audit cases:

```text
cases=8
passed=8
failed=0
```

The drift example demonstrates one failed case in an 8-case corpus:

```text
cases=8
passed=7
failed=1
```

Field-level executable example verifier:

```bash
cd rust/cmc-core
cargo run --bin audit_report_example_verify --locked
```

The verifier parses each saved JSONL line as a flat object and checks typed fields such as `type`, `scenario_id`, `invariant_id`, `ok`, `status`, `cases`, `passed`, and `failed`.

---

## One-command reviewer check

From repository root:

```bash
npm run review:cmc
```

Expected final result:

```text
result=reviewer_baseline_passed
```

This command runs:

```text
cargo fmt --check
cargo test --all --locked
cargo run --bin cmc_demo --locked
cargo run --bin verify_trace --locked
cargo run --bin verify_trace_tampered --locked
cargo run --bin verify_trace_sha256 --locked
cargo run --bin verify_trace_sha256_tampered --locked
cargo run --bin verify_trace_sha256_fixture --locked
cargo run --bin persona_boundary_verify --locked
cargo run --bin replay_fixture_verify --locked
cargo run --bin replay_fingerprint_verify --locked
cargo run --bin cmc_audit_report --locked
cargo run --bin audit_report_example_verify --locked
cargo run --bin trace_divergence --locked
```

---

## CI coverage

The CMC GitHub Actions workflow is configured to run on changes to:

```text
rust/cmc-core/**
scripts/run-cmc-reviewer-demo.mjs
package.json
.github/workflows/cmc-rust.yml
```

The workflow currently covers:

- formatting check
- Rust tests
- executable CMC demo
- legacy trace hash-chain verifier
- legacy tampering detection demo
- SHA-256 generated trace sealing verifier
- SHA-256 generated tampering detection demo
- SHA-256 sealed trace fixture verifier
- manifest-linked persona boundary verifier
- manifest-linked replay fixture structure verifier
- manifest-linked replay fixture fingerprint verifier
- manifest-linked audit report JSONL output
- field-level executable verification of saved valid/drift audit report examples
- replay divergence detector
- one-command reviewer demo via `npm run review:cmc`

Doc-only changes outside those paths do not necessarily trigger this workflow.

---

## What is strong today

The baseline is strong because it turns a conceptual claim into executable artifacts:

- manifest-linked persona-boundary corpus for future AI companion/persona systems
- rejected inferred persona memory without confirmation/cause
- accepted confirmed persona memory with confirmation/cause
- rejected illegal memory writes without cause
- rejected writes with unknown cause
- rejected effects before causal commit
- accepted legitimate committed effect transition
- rejected reads without explicit cause
- rejected reads with unknown cause or unavailable address
- rejected effects without parent cause
- accepted read after legitimate write under known cause
- invariant-to-scenario replay mapping for I1-I8
- deterministic trace events
- documented v0 canonical trace-event encoding
- machine-readable replay manifest
- manifest-linked replay fixture structure checks
- manifest-linked fixture fingerprint drift checks
- manifest-linked audit report output
- saved valid/drift audit report examples for 8 cases
- field-level executable verification of audit report examples
- legacy tampering detection demo
- SHA-256 generated trace sealing and verification reference path
- SHA-256 generated tampering detection demo
- saved SHA-256 valid/tampered sealed trace fixtures
- executable verification of saved SHA-256 sealed trace fixtures
- divergence detection demo
- one-command reviewer verification
- CI enforcement path

---

## Known limits

The baseline does not yet provide:

- production cryptographic sealing
- certified trace storage
- hardware implementation
- hardware root of trust
- formal verification
- full JSON canonicalization standard compatibility
- AI consciousness or personhood claims
- therapeutic diagnosis or treatment
- real workload performance evaluation
- full multi-agent benchmark coverage
- certification-grade assurance

The current repository should be read as an executable research scaffold for legitimacy-preserving computation.

---

## Next phase

The next phase should focus on:

1. adding exact canonical event-line tests,
2. adding persona-boundary fixtures for action proposals and persona state changes,
3. connecting manifest entries to SHA-256 sealed trace evidence,
4. adding richer manifest validation rules,
5. adding removed-event and reordered-event negative trace-integrity fixtures,
6. measuring overhead and stability across repeated runs,
7. optionally replacing lightweight flat JSON parsing with dependency-backed JSON parsing if dependency policy changes,
8. expanding beyond current memory/read/effect/persona-boundary cases into broader workloads.

---

## One-line status

```text
CMC baseline is reviewer-ready as an 8-scenario, one-command, manifest-linked persona-boundary-aware, JSONL-reporting, field-level example-verified, canonical-trace-encoded, SHA-256 sealed-fixture-verified, CI-enforced executable research scaffold, not yet production-ready infrastructure.
```

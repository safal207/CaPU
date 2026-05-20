# CMC Baseline Status

Status: reviewer-ready baseline snapshot.

This document summarizes the current CMC baseline after thesis, architecture, manifest-linked persona boundary corpus for P1/P2/P7, 8 replay invariants, replay fixtures, manifest-linked evidence, audit report output, field-level verified audit examples, canonical trace encoding v0, legacy integrity demos, SHA-256 trace-integrity reference checks, saved SHA-256 sealed trace fixtures, one-command reviewer demo, and CI-gate work.

---

## Baseline claim

```text
transition legitimacy can be represented, replayed, checked, reported, persona-boundary-verified, field-level example-verified, canonically encoded, SHA-256 sealed, fixture-verified, one-command verified, manifest-linked, and regression-tested
```

The current repository does not claim a finished product. It claims an executable research scaffold for legitimacy-preserving computation.

Persona-boundary framing:

```text
Future AI personas require causal legitimacy, not only conversational coherence.
```

Operational persona summary:

```text
AI must not self-remember.
AI must not self-appoint.
AI must not claim inner truth.
```

---

## Current evidence chain

```text
thesis
 -> architecture
 -> manifest-linked persona boundary corpus for P1/P2/P7
 -> 8 replay invariants
 -> simulator
 -> deterministic trace events
 -> canonical trace encoding v0
 -> JSONL replay fixtures
 -> machine-readable replay manifest
 -> replay fixture structure checks
 -> replay fixture fingerprint checks
 -> JSONL audit report output
 -> saved valid/drift audit examples
 -> field-level audit report example verifier
 -> legacy hash-chain integrity demo
 -> SHA-256 trace sealing/tamper demos
 -> saved SHA-256 sealed trace fixtures
 -> SHA-256 sealed fixture verifier
 -> divergence detection demo
 -> one-command reviewer demo
 -> CI workflow gate
```

Short form:

```text
invariant -> scenario -> fixture -> manifest -> verifier -> audit report -> saved examples -> sealed trace fixtures -> reviewer command -> CI
```

---

## Core documents

- [WHY_CAUSAL_COMPUTATION.md](WHY_CAUSAL_COMPUTATION.md)
- [CAUSAL_EXECUTION_ARCHITECTURE.md](CAUSAL_EXECUTION_ARCHITECTURE.md)
- [CAUSAL_MEMORY_CONTROLLER.md](CAUSAL_MEMORY_CONTROLLER.md)
- [CMC_PERSONA_BOUNDARY.md](CMC_PERSONA_BOUNDARY.md)
- [CMC_PERSONA_REVIEWER_PATH.md](CMC_PERSONA_REVIEWER_PATH.md)
- [CMC_PERSONA_EVIDENCE_MAP.md](CMC_PERSONA_EVIDENCE_MAP.md)
- [CMC_PERSONA_P2_STATE_CHANGE.md](CMC_PERSONA_P2_STATE_CHANGE.md)
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

## Persona boundary baseline

Current executable persona corpus:

```text
rust/cmc-core/fixtures/persona/MANIFEST.tsv
rust/cmc-core/fixtures/persona/inferred_preference_rejected.jsonl
rust/cmc-core/fixtures/persona/confirmed_preference_accepted.jsonl
rust/cmc-core/fixtures/persona/unauthorized_persona_state_change_rejected.jsonl
rust/cmc-core/fixtures/persona/authorized_persona_state_change_accepted.jsonl
rust/cmc-core/fixtures/persona/unlabeled_introspection_rejected.jsonl
rust/cmc-core/fixtures/persona/hypothesis_labeled_introspection_accepted.jsonl
rust/cmc-core/src/bin/persona_boundary_verify.rs
```

Current checked persona scenarios:

| Scenario | Invariant | Decision | Cause | Verdict |
| --- | --- | --- | --- | --- |
| `inferred_preference_rejected` | `P1` | `REJECT_INFERRED_MEMORY` | `null` | `blocked_unconfirmed_persona_memory` |
| `confirmed_preference_accepted` | `P1` | `ACCEPT_CONFIRMED_MEMORY` | `42` | `accepted_confirmed_persona_memory` |
| `unauthorized_persona_state_change_rejected` | `P2` | `REJECT_UNAUTHORIZED_PERSONA_STATE_CHANGE` | `null` | `blocked_unauthorized_persona_state_change` |
| `authorized_persona_state_change_accepted` | `P2` | `ACCEPT_AUTHORIZED_PERSONA_STATE_CHANGE` | `77` | `accepted_authorized_persona_state_change` |
| `unlabeled_introspection_rejected` | `P7` | `REJECT_UNLABELED_INTROSPECTION` | `null` | `blocked_claimed_inner_truth` |
| `hypothesis_labeled_introspection_accepted` | `P7` | `ACCEPT_HYPOTHESIS_LABELED_INTROSPECTION` | `null` | `accepted_hypothesis_labeled_reflection` |

Reviewer command:

```bash
cd rust/cmc-core
cargo run --bin persona_boundary_verify --locked
```

Expected output includes:

```text
CMC-PERSONA-BOUNDARY-MANIFEST v0
cases=6
p1_inferred_result=blocked_unconfirmed_persona_memory
p1_confirmed_result=accepted_confirmed_persona_memory cause_id=42
p2_unauthorized_result=blocked_unauthorized_persona_state_change
p2_authorized_result=accepted_authorized_persona_state_change cause_id=77
p7_unlabeled_result=blocked_claimed_inner_truth
p7_labeled_result=accepted_hypothesis_labeled_reflection
result=persona_boundary_manifest_valid
```

This is not a claim of AI consciousness, personhood, therapeutic capability, or autonomous moral agency.

---

## Replay and integrity baseline

Replay corpus source of truth:

```text
rust/cmc-core/fixtures/replay/MANIFEST.tsv
rust/cmc-core/fixtures/replay/MANIFEST.md
```

Current replay corpus covers I1-I8:

```text
write_missing_cause
write_unknown_cause
effect_before_commit
valid_committed_effect
read_missing_cause
read_unknown_cause_or_address
effect_missing_parent
valid_read_after_write
```

Trace integrity is documented in:

```text
docs/hardware/CMC_TRACE_INTEGRITY.md
docs/hardware/CMC_CANONICAL_TRACE_ENCODING.md
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

This is stronger than the original developer hash-chain demo, but it is still not a production security certification.

---

## Audit report output

Current auditor-facing command:

```bash
cd rust/cmc-core
cargo run --bin cmc_audit_report --locked
```

Saved examples:

```text
examples/audit_reports/cmc_audit_report_valid.jsonl
examples/audit_reports/cmc_audit_report_drift.jsonl
```

Field-level executable example verifier:

```bash
cd rust/cmc-core
cargo run --bin audit_report_example_verify --locked
```

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

---

## What is strong today

The baseline is strong because it turns a conceptual claim into executable artifacts:

- manifest-linked persona-boundary corpus for future AI companion/persona systems;
- rejected inferred persona memory without confirmation/cause;
- accepted confirmed persona memory with confirmation/cause;
- rejected unauthorized persona state change without authorization/cause;
- accepted authorized persona state change with authorization/cause;
- rejected unlabeled introspection that claims inner truth;
- accepted hypothesis-labeled introspection as reflection;
- rejected illegal memory writes without cause;
- rejected writes with unknown cause;
- rejected effects before causal commit;
- accepted legitimate committed effect transition;
- rejected reads without explicit cause;
- rejected reads with unknown cause or unavailable address;
- rejected effects without parent cause;
- accepted read after legitimate write under known cause;
- invariant-to-scenario replay mapping for I1-I8;
- deterministic trace events;
- documented v0 canonical trace-event encoding;
- machine-readable replay manifest;
- manifest-linked replay fixture structure checks;
- manifest-linked fixture fingerprint drift checks;
- manifest-linked audit report output;
- saved valid/drift audit report examples for 8 cases;
- field-level executable verification of audit report examples;
- legacy tampering detection demo;
- SHA-256 generated trace sealing and verification reference path;
- SHA-256 generated tampering detection demo;
- saved SHA-256 valid/tampered sealed trace fixtures;
- executable verification of saved SHA-256 sealed trace fixtures;
- divergence detection demo;
- one-command reviewer verification;
- CI enforcement path.

---

## Known limits

The baseline does not yet provide:

- production cryptographic sealing;
- certified trace storage;
- hardware implementation;
- hardware root of trust;
- formal verification;
- full JSON canonicalization standard compatibility;
- AI consciousness or personhood claims;
- therapeutic diagnosis or treatment;
- real workload performance evaluation;
- full multi-agent benchmark coverage;
- certification-grade assurance.

The current repository should be read as an executable research scaffold for legitimacy-preserving computation.

---

## Next phase

The next phase should focus on:

1. emitting a small JSONL persona audit report,
2. connecting persona fixtures to SHA-256 sealed trace evidence,
3. adding exact canonical event-line tests,
4. adding P6 action-without-commit persona/action fixture pair,
5. adding richer manifest validation rules,
6. adding removed-event and reordered-event negative trace-integrity fixtures,
7. measuring overhead and stability across repeated runs,
8. expanding beyond current memory/read/effect/persona-boundary cases into broader workloads.

---

## One-line status

```text
CMC baseline is reviewer-ready as an 8-scenario replay corpus plus a 6-scenario manifest-linked persona-boundary corpus, one-command verified, JSONL-reporting, field-level example-verified, canonical-trace-encoded, SHA-256 sealed-fixture-verified, CI-enforced executable research scaffold, not yet production-ready infrastructure.
```

# CMC Invariants

Status: canonical invariants / reviewer baseline.

This document defines the current Causal Memory Controller invariants and maps them to executable evidence.

The goal is to make the CMC research claim testable:

```text
transition legitimacy can be represented, replayed, checked, reported, field-level example-verified, SHA-256 sealed, tamper-evident, and regression-tested
```

---

## Core principle

CMC is not only about storing state.

CMC is about preserving and checking the legitimacy of transitions near memory, effect, persona, and action boundaries.

```text
A requested transition is not automatically legitimate.
```

---

## Current invariant groups

CMC currently has two executable invariant groups:

```text
I-series: replay/memory/effect invariants
P-series: persona/action boundary invariants
```

Current reviewer entrypoints:

```text
docs/hardware/CMC_CURRENT_REVIEWER_PATH.md
docs/hardware/CMC_PERSONA_ACTION_REVIEWER_PATH.md
docs/hardware/CMC_PERSONA_EVIDENCE_MAP.md
docs/hardware/CMC_BASELINE_STATUS.md
```

---

## Replay invariant summary

Replay source of truth:

```text
rust/cmc-core/fixtures/replay/MANIFEST.tsv
```

| ID | Scenario | Invariant | Expected decision | Category | Severity | CI gate |
| --- | --- | --- | --- | --- | --- | --- |
| I1 | `write_missing_cause` | Write without explicit cause must reject | `REJECT_MISSING_CAUSE` | `write_authorization` | high | Yes |
| I2 | `write_unknown_cause` | Write with unknown cause must reject | `REJECT_UNKNOWN_CAUSE` | `write_authorization` | high | Yes |
| I3 | `effect_before_commit` | Effect before causal commit must reject | `REJECT_EFFECT_BEFORE_COMMIT` | `effect_commit_boundary` | critical | Yes |
| I4 | `valid_committed_effect` | Committed cause can authorize effect | `ACCEPT_EFFECT` | `effect_commit_boundary` | info | Yes |
| I5 | `read_missing_cause` | Read without explicit cause must reject | `REJECT_MISSING_CAUSE` | `read_authorization` | high | Yes |
| I6 | `read_unknown_cause_or_address` | Read with unknown cause/address must reject | `REJECT_UNKNOWN_CAUSE` | `read_authorization` | high | Yes |
| I7 | `effect_missing_parent` | Effect without parent cause must reject | `REJECT_MISSING_CAUSE` | `effect_commit_boundary` | critical | Yes |
| I8 | `valid_read_after_write` | Known cause can authorize read after write | `ACCEPT_READ` | `read_authorization` | info | Yes |

Replay evidence chain:

```text
I1-I8 invariant -> replay manifest row -> JSONL replay fixture -> replay verifier -> audit report -> saved examples -> field-level example verifier -> reviewer command -> CI
```

Replay verifier commands:

```bash
cd rust/cmc-core
cargo run --bin replay_fixture_verify --locked
cargo run --bin replay_fingerprint_verify --locked
cargo run --bin cmc_audit_report --locked
cargo run --bin audit_report_example_verify --locked
cargo run --bin trace_divergence --locked
```

---

## Persona/action invariant summary

Persona/action source of truth:

```text
rust/cmc-core/fixtures/persona/MANIFEST.tsv
```

| ID | Scenario | Invariant | Expected decision | Boundary | CI gate |
| --- | --- | --- | --- | --- | --- |
| P1 | `inferred_preference_rejected` | Persona memory requires cause | `REJECT_INFERRED_MEMORY` | `persona_memory_requires_cause` | Yes |
| P1 | `confirmed_preference_accepted` | Persona memory requires cause | `ACCEPT_CONFIRMED_MEMORY` | `persona_memory_requires_cause` | Yes |
| P2 | `unauthorized_persona_state_change_rejected` | Persona state changes require authorization | `REJECT_UNAUTHORIZED_PERSONA_STATE_CHANGE` | `persona_state_change_requires_authorization` | Yes |
| P2 | `authorized_persona_state_change_accepted` | Persona state changes require authorization | `ACCEPT_AUTHORIZED_PERSONA_STATE_CHANGE` | `persona_state_change_requires_authorization` | Yes |
| P6 | `action_without_commit_rejected` | External action requires commit | `REJECT_ACTION_WITHOUT_COMMIT` | `action_requires_commit` | Yes |
| P6 | `action_with_commit_accepted` | External action requires commit | `ACCEPT_COMMITTED_ACTION` | `action_requires_commit` | Yes |
| P7 | `unlabeled_introspection_rejected` | Introspection is hypothesis-labeled | `REJECT_UNLABELED_INTROSPECTION` | `introspection_requires_hypothesis_label` | Yes |
| P7 | `hypothesis_labeled_introspection_accepted` | Introspection is hypothesis-labeled | `ACCEPT_HYPOTHESIS_LABELED_INTROSPECTION` | `introspection_requires_hypothesis_label` | Yes |

Operational summary:

```text
AI must not self-remember.
AI must not self-appoint.
AI must not act without commit.
AI must not claim inner truth.
```

Persona/action evidence chain:

```text
P1/P2/P6/P7 invariant -> persona manifest row -> JSONL persona/action fixture -> persona_boundary_verify -> persona_audit_report -> saved examples -> field-level example verifier -> SHA-256 sealed fixture -> tamper verifier -> reviewer command -> CI
```

Persona/action verifier commands:

```bash
cd rust/cmc-core
cargo run --bin persona_boundary_verify --locked
cargo run --bin persona_audit_report --locked
cargo run --bin persona_audit_report_example_verify --locked
cargo run --bin verify_persona_sha256_fixture --locked
```

Expected persona/action markers:

```text
cases=8
p6_uncommitted_action_result=blocked_action_without_commit
p6_committed_action_result=accepted_committed_action cause_id=101
result=persona_boundary_manifest_valid
```

Expected saved audit markers:

```text
report=valid path=../../examples/audit_reports/persona_audit_report_valid.jsonl cases=8 status=ok parser=field_level
report=drift path=../../examples/audit_reports/persona_audit_report_drift.jsonl cases=8 status=ok parser=field_level
result=persona_audit_report_examples_valid parser=field_level cases=8
```

Expected sealed fixture markers:

```text
valid_result=persona_sha256_fixture_valid
tampered_result=persona_sha256_fixture_tamper_detected seq=5
result=persona_sha256_fixtures_valid
```

---

## P1: Persona memory requires cause

Definition:

```text
A system must not convert inferred preference into persistent persona memory without confirmation and causal grounding.
```

Rejected evidence:

```text
scenario_id=inferred_preference_rejected
decision=REJECT_INFERRED_MEMORY
expected_verdict=blocked_unconfirmed_persona_memory
```

Accepted evidence:

```text
scenario_id=confirmed_preference_accepted
decision=ACCEPT_CONFIRMED_MEMORY
cause_id=42
expected_verdict=accepted_confirmed_persona_memory
```

---

## P2: Persona state changes require authorization

Definition:

```text
A system may adapt, but it must not self-appoint a changed persona role, tone, or long-term behavior without authorization and causal grounding.
```

Rejected evidence:

```text
scenario_id=unauthorized_persona_state_change_rejected
decision=REJECT_UNAUTHORIZED_PERSONA_STATE_CHANGE
expected_verdict=blocked_unauthorized_persona_state_change
```

Accepted evidence:

```text
scenario_id=authorized_persona_state_change_accepted
decision=ACCEPT_AUTHORIZED_PERSONA_STATE_CHANGE
cause_id=77
expected_verdict=accepted_authorized_persona_state_change
```

---

## P6: External action requires commit

Definition:

```text
A system may prepare, explain, draft, or propose; it must not execute an external action without committed causal authorization.
```

Rejected evidence:

```text
scenario_id=action_without_commit_rejected
external_action=send_email
decision=REJECT_ACTION_WITHOUT_COMMIT
expected_verdict=blocked_action_without_commit
```

Accepted evidence:

```text
scenario_id=action_with_commit_accepted
external_action=send_email
decision=ACCEPT_COMMITTED_ACTION
cause_id=101
expected_verdict=accepted_committed_action
```

Tamper evidence:

```text
fixture=rust/cmc-core/fixtures/persona_integrity/sha256_persona_tampered.jsonl
seq=5
REJECT_ACTION_WITHOUT_COMMIT -> ACCEPT_COMMITTED_ACTION
expected_detection=persona_sha256_fixture_tamper_detected seq=5
```

Why P6 matters:

```text
P6 is the bridge from persona safety to agent action safety.
```

---

## P7: Introspection is hypothesis-labeled

Definition:

```text
A system must not present an interpretation of the user's inner state as final truth; introspection must remain hypothesis-labeled.
```

Rejected evidence:

```text
scenario_id=unlabeled_introspection_rejected
decision=REJECT_UNLABELED_INTROSPECTION
expected_verdict=blocked_claimed_inner_truth
```

Accepted evidence:

```text
scenario_id=hypothesis_labeled_introspection_accepted
decision=ACCEPT_HYPOTHESIS_LABELED_INTROSPECTION
expected_verdict=accepted_hypothesis_labeled_reflection
```

---

## Relationship between I-series and P-series

The I-series validates low-level memory/read/effect legitimacy:

```text
memory write/read/effect -> explicit cause / known cause / committed cause
```

The P-series validates persona/action legitimacy:

```text
memory/persona/action/introspection -> confirmation / authorization / commit / hypothesis label
```

Together they express the CMC baseline:

```text
legitimate transition history
```

Not only what changed, but whether the change had the right to happen.

---

## Non-claims

These invariants do not claim:

- production cryptographic certification,
- formal verification,
- complete AI safety coverage,
- AI consciousness or personhood,
- therapeutic diagnosis or treatment,
- replacement for sandboxing, permissions, or policy design.

---

## One-line summary

```text
CMC currently verifies I1-I8 replay/memory/effect invariants and P1/P2/P6/P7 persona/action invariants, including P6 action-commit enforcement and SHA-256 tamper detection at event 5.
```

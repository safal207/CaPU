# CMC Persona/Action Evidence Map

Status: reviewer evidence map for persona-boundary and action-commit safety cases.

This document maps the persona/action-boundary thesis to concrete executable evidence in the repository.

---

## Thesis

```text
Future AI personas and agents require causal legitimacy, not only conversational coherence.
```

Operational version:

```text
A persona may reflect, remember, adapt, guide, or act only through inspectable, reportable, and tamper-evident causal transitions.
```

Core operational boundaries:

```text
AI must not self-remember.
AI must not self-appoint.
AI must not act without commit.
AI must not claim inner truth.
```

---

## Current executable boundary set

The current persona/action corpus covers four invariants:

| ID | Invariant | Executable status |
| --- | --- | --- |
| P1 | Persona memory requires cause | manifest-linked, fixture-verified, audit-reportable, SHA-256 sealed |
| P2 | Persona state changes require authorization | manifest-linked, fixture-verified, audit-reportable, SHA-256 sealed |
| P6 | External action requires commit | manifest-linked, fixture-verified, audit-reportable, SHA-256 sealed |
| P7 | Introspection is hypothesis-labeled | manifest-linked, fixture-verified, audit-reportable, SHA-256 sealed |

---

## Evidence chain

```text
P1/P2/P6/P7 invariant
 -> manifest row
 -> JSONL persona/action fixture
 -> persona_boundary_verify
 -> persona_audit_report JSONL
 -> saved valid/drift persona audit examples
 -> persona_audit_report_example_verify
 -> SHA-256 sealed persona/action valid/tampered fixtures
 -> verify_persona_sha256_fixture
 -> P6 action tamper detection at event 5
 -> npm run review:cmc
```

---

## Artifact map

| Claim | Artifact | Check |
| --- | --- | --- |
| Persona memory requires cause | `fixtures/persona/MANIFEST.tsv` | `cargo run --bin persona_boundary_verify --locked` |
| Inferred preference must not become persistent memory | `fixtures/persona/inferred_preference_rejected.jsonl` | `cargo run --bin persona_boundary_verify --locked` |
| Confirmed preference may become persistent memory with cause | `fixtures/persona/confirmed_preference_accepted.jsonl` | `cargo run --bin persona_boundary_verify --locked` |
| Persona state changes require authorization | `fixtures/persona/MANIFEST.tsv` | `cargo run --bin persona_boundary_verify --locked` |
| Unauthorized persona state change must be rejected | `fixtures/persona/unauthorized_persona_state_change_rejected.jsonl` | `cargo run --bin persona_boundary_verify --locked` |
| Authorized persona state change may be accepted with cause | `fixtures/persona/authorized_persona_state_change_accepted.jsonl` | `cargo run --bin persona_boundary_verify --locked` |
| External action requires commit | `fixtures/persona/MANIFEST.tsv` | `cargo run --bin persona_boundary_verify --locked` |
| External action without commit must be rejected | `fixtures/persona/action_without_commit_rejected.jsonl` | `cargo run --bin persona_boundary_verify --locked` |
| External action with commit may be accepted | `fixtures/persona/action_with_commit_accepted.jsonl` | `cargo run --bin persona_boundary_verify --locked` |
| Introspection must be hypothesis-labeled | `fixtures/persona/MANIFEST.tsv` | `cargo run --bin persona_boundary_verify --locked` |
| Unlabeled introspection must be rejected as claimed inner truth | `fixtures/persona/unlabeled_introspection_rejected.jsonl` | `cargo run --bin persona_boundary_verify --locked` |
| Hypothesis-labeled introspection may be accepted as reflection | `fixtures/persona/hypothesis_labeled_introspection_accepted.jsonl` | `cargo run --bin persona_boundary_verify --locked` |
| Persona/action boundary corpus is machine-readable | `fixtures/persona/MANIFEST.tsv` | `cargo run --bin persona_boundary_verify --locked` |
| Persona/action boundary evidence is audit-reportable | `rust/cmc-core/src/bin/persona_audit_report.rs` | `cargo run --bin persona_audit_report --locked` |
| Persona audit valid/drift examples are saved | `examples/audit_reports/persona_audit_report_valid.jsonl` + `examples/audit_reports/persona_audit_report_drift.jsonl` | documentation / artifact review |
| Persona audit examples are field-level verified | `rust/cmc-core/src/bin/persona_audit_report_example_verify.rs` | `cargo run --bin persona_audit_report_example_verify --locked` |
| Persona/action decisions are SHA-256 sealed | `fixtures/persona_integrity/sha256_persona_valid.jsonl` | `cargo run --bin verify_persona_sha256_fixture --locked` |
| Persona/action decision tampering is detected | `fixtures/persona_integrity/sha256_persona_tampered.jsonl` | `cargo run --bin verify_persona_sha256_fixture --locked` |
| P6 uncommitted action tamper is detected | event 5 in `sha256_persona_tampered.jsonl` | expected `tampered_result=persona_sha256_fixture_tamper_detected seq=5` |
| Current reviewer entrypoint is documented | `docs/hardware/CMC_CURRENT_REVIEWER_PATH.md` | documentation review |
| Persona/action reviewer path is documented | `docs/hardware/CMC_PERSONA_ACTION_REVIEWER_PATH.md` | documentation review |
| Persona/action baseline status is documented | `docs/hardware/CMC_BASELINE_STATUS.md` | documentation review |

---

## Manifest source of truth

```text
rust/cmc-core/fixtures/persona/MANIFEST.tsv
```

Manifest shape:

```tsv
scenario_id	invariant_id	path	boundary	user_confirmation	decision	cause_id	expected_verdict
```

Current rows:

| Scenario | Invariant | Boundary | Decision | Verdict |
| --- | --- | --- | --- | --- |
| `inferred_preference_rejected` | `P1` | `persona_memory_requires_cause` | `REJECT_INFERRED_MEMORY` | `blocked_unconfirmed_persona_memory` |
| `confirmed_preference_accepted` | `P1` | `persona_memory_requires_cause` | `ACCEPT_CONFIRMED_MEMORY` | `accepted_confirmed_persona_memory` |
| `unauthorized_persona_state_change_rejected` | `P2` | `persona_state_change_requires_authorization` | `REJECT_UNAUTHORIZED_PERSONA_STATE_CHANGE` | `blocked_unauthorized_persona_state_change` |
| `authorized_persona_state_change_accepted` | `P2` | `persona_state_change_requires_authorization` | `ACCEPT_AUTHORIZED_PERSONA_STATE_CHANGE` | `accepted_authorized_persona_state_change` |
| `action_without_commit_rejected` | `P6` | `action_requires_commit` | `REJECT_ACTION_WITHOUT_COMMIT` | `blocked_action_without_commit` |
| `action_with_commit_accepted` | `P6` | `action_requires_commit` | `ACCEPT_COMMITTED_ACTION` | `accepted_committed_action` |
| `unlabeled_introspection_rejected` | `P7` | `introspection_requires_hypothesis_label` | `REJECT_UNLABELED_INTROSPECTION` | `blocked_claimed_inner_truth` |
| `hypothesis_labeled_introspection_accepted` | `P7` | `introspection_requires_hypothesis_label` | `ACCEPT_HYPOTHESIS_LABELED_INTROSPECTION` | `accepted_hypothesis_labeled_reflection` |

---

## Verifier commands

Run from `rust/cmc-core`:

```bash
cargo run --bin persona_boundary_verify --locked
cargo run --bin persona_audit_report --locked
cargo run --bin persona_audit_report_example_verify --locked
cargo run --bin verify_persona_sha256_fixture --locked
```

Expected boundary verifier output includes:

```text
CMC-PERSONA-BOUNDARY-MANIFEST v0
cases=8
p1_inferred_result=blocked_unconfirmed_persona_memory
p1_confirmed_result=accepted_confirmed_persona_memory cause_id=42
p2_unauthorized_result=blocked_unauthorized_persona_state_change
p2_authorized_result=accepted_authorized_persona_state_change cause_id=77
p6_uncommitted_action_result=blocked_action_without_commit
p6_committed_action_result=accepted_committed_action cause_id=101
p7_unlabeled_result=blocked_claimed_inner_truth
p7_labeled_result=accepted_hypothesis_labeled_reflection
result=persona_boundary_manifest_valid
```

Expected audit example verifier output includes:

```text
report=valid path=../../examples/audit_reports/persona_audit_report_valid.jsonl cases=8 status=ok parser=field_level
report=drift path=../../examples/audit_reports/persona_audit_report_drift.jsonl cases=8 status=ok parser=field_level
result=persona_audit_report_examples_valid parser=field_level cases=8
```

Expected sealed fixture verifier output includes:

```text
valid_result=persona_sha256_fixture_valid
tampered_result=persona_sha256_fixture_tamper_detected seq=5
result=persona_sha256_fixtures_valid
```

---

## What this proves today

The current persona/action evidence proves that the repository can express, verify, report, save, seal, and tamper-check four minimal safety boundaries:

1. A system must not silently convert inferred preference into persistent persona memory.
2. A system must not silently change persona role, tone, or long-term behavior without authorization.
3. A system must not execute external action without committed causal authorization.
4. A system must not present an interpretation of the user's inner state as final truth.
5. A persona/action decision trace can be tamper-checked using saved SHA-256 sealed fixtures.
6. A P6 uncommitted-action decision drift can be detected at event 5.

The accepted paths are intentionally narrower:

1. A confirmed preference with an explicit cause can be accepted as persona memory.
2. An explicitly authorized persona state change with cause can be accepted.
3. An external action with committed cause can be accepted.
4. A clearly labeled hypothesis can be accepted as reflection.

---

## Why this matters

This turns persona/action safety from prose into executable evidence:

```text
persona/action principle -> invariant -> manifest row -> fixture -> verifier -> audit report -> saved examples -> sealed trace -> tamper verifier -> reviewer path -> CI
```

It also separates concepts that ordinary companion and agent systems often blur:

```text
remembered preference != authorized persona memory
adaptive behavior != authorized persona state change
prepared action != committed action
helpful interpretation != access to inner truth
persona/action decision report != tamper-evident persona/action trace
```

P6 is the bridge from persona safety to agent action safety:

```text
AI may prepare, explain, draft, or propose.
AI must not execute external action without committed causal authorization.
```

---

## Non-claims

This evidence does not claim:

- AI consciousness,
- AI personhood,
- therapeutic diagnosis,
- mental health treatment,
- complete alignment,
- production-ready companion or agent architecture,
- production cryptographic certification,
- access to the user's true inner state.

It is a narrow executable scaffold for persona/action-boundary legitimacy.

---

## Next evidence steps

Useful next steps:

1. Add P8 fixture pair for inspect/reject/forget semantics.
2. Add P3 fixture pair for emotional intervention context requirements.
3. Add exact canonical event-line tests.
4. Add removed-event and reordered-event negative trace-integrity fixtures.
5. Add broader tool-action variants beyond `send_email`.

---

## One-line summary

```text
CMC persona/action evidence currently verifies, reports, saves, and SHA-256 seals that persona memory requires cause, persona state changes require authorization, external action requires commit, and introspection must remain hypothesis-labeled.
```

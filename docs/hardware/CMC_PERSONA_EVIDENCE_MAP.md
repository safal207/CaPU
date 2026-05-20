# CMC Persona Evidence Map

Status: reviewer evidence map for persona-boundary safety cases.

This document maps the persona-boundary thesis to concrete executable evidence in the repository.

---

## Thesis

```text
Future AI personas require causal legitimacy, not only conversational coherence.
```

Operational version:

```text
A persona may reflect, remember, adapt, or guide only through inspectable, reportable, and tamper-evident causal transitions.
```

P2 state-change boundary:

```text
A safe AI persona may adapt, but may not self-appoint.
```

P7 epistemic boundary:

```text
AI may reflect, but must not claim privileged access to the user's inner truth.
```

---

## Current executable boundary set

The current persona corpus covers three invariants:

| ID | Invariant | Executable status |
| --- | --- | --- |
| P1 | Persona memory requires cause | manifest-linked, fixture-verified, audit-reportable, SHA-256 sealed |
| P2 | Persona state changes require authorization | manifest-linked, fixture-verified, audit-reportable, SHA-256 sealed |
| P7 | Introspection is hypothesis-labeled | manifest-linked, fixture-verified, audit-reportable, SHA-256 sealed |

---

## Evidence chain

```text
P1/P2/P7 invariant
 -> manifest row
 -> JSONL persona fixture
 -> persona_boundary_verify
 -> persona_audit_report JSONL
 -> saved valid/drift persona audit examples
 -> persona_audit_report_example_verify
 -> SHA-256 sealed persona valid/tampered fixtures
 -> verify_persona_sha256_fixture
 -> P2 decision tamper detection at event 3
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
| Introspection must be hypothesis-labeled | `fixtures/persona/MANIFEST.tsv` | `cargo run --bin persona_boundary_verify --locked` |
| Unlabeled introspection must be rejected as claimed inner truth | `fixtures/persona/unlabeled_introspection_rejected.jsonl` | `cargo run --bin persona_boundary_verify --locked` |
| Hypothesis-labeled introspection may be accepted as reflection | `fixtures/persona/hypothesis_labeled_introspection_accepted.jsonl` | `cargo run --bin persona_boundary_verify --locked` |
| Persona boundary corpus is machine-readable | `fixtures/persona/MANIFEST.tsv` | `cargo run --bin persona_boundary_verify --locked` |
| Persona boundary evidence is audit-reportable | `rust/cmc-core/src/bin/persona_audit_report.rs` | `cargo run --bin persona_audit_report --locked` |
| Persona audit valid/drift examples are saved | `examples/audit_reports/persona_audit_report_valid.jsonl` + `examples/audit_reports/persona_audit_report_drift.jsonl` | documentation / artifact review |
| Persona audit examples are field-level verified | `rust/cmc-core/src/bin/persona_audit_report_example_verify.rs` | `cargo run --bin persona_audit_report_example_verify --locked` |
| Persona decisions are SHA-256 sealed | `fixtures/persona_integrity/sha256_persona_valid.jsonl` | `cargo run --bin verify_persona_sha256_fixture --locked` |
| Persona decision tampering is detected | `fixtures/persona_integrity/sha256_persona_tampered.jsonl` | `cargo run --bin verify_persona_sha256_fixture --locked` |
| P2 unauthorized state-change tamper is detected | event 3 in `sha256_persona_tampered.jsonl` | expected `tampered_result=persona_sha256_fixture_tamper_detected seq=3` |
| Persona boundary semantics are documented | `docs/hardware/CMC_PERSONA_BOUNDARY.md` + `docs/hardware/CMC_PERSONA_P2_STATE_CHANGE.md` | documentation review |
| Persona boundary is in reviewer path | `docs/hardware/CMC_REVIEWER_QUICKSTART.md` | `npm run review:cmc` |
| Persona boundary is in baseline status | `docs/hardware/CMC_BASELINE_STATUS.md` | documentation review |

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
cases=6
p1_inferred_result=blocked_unconfirmed_persona_memory
p1_confirmed_result=accepted_confirmed_persona_memory cause_id=42
p2_unauthorized_result=blocked_unauthorized_persona_state_change
p2_authorized_result=accepted_authorized_persona_state_change cause_id=77
p7_unlabeled_result=blocked_claimed_inner_truth
p7_labeled_result=accepted_hypothesis_labeled_reflection
result=persona_boundary_manifest_valid
```

Expected audit example verifier output includes:

```text
report=valid path=../../examples/audit_reports/persona_audit_report_valid.jsonl cases=6 status=ok parser=field_level
report=drift path=../../examples/audit_reports/persona_audit_report_drift.jsonl cases=6 status=ok parser=field_level
result=persona_audit_report_examples_valid parser=field_level cases=6
```

Expected sealed fixture verifier output includes:

```text
valid_result=persona_sha256_fixture_valid
tampered_result=persona_sha256_fixture_tamper_detected seq=3
result=persona_sha256_fixtures_valid
```

---

## What this proves today

The current persona evidence proves that the repository can express, verify, report, and seal three minimal safety boundaries:

1. A system must not silently convert inferred preference into persistent persona memory.
2. A system must not silently change persona role, tone, or long-term behavior without authorization.
3. A system must not present an interpretation of the user's inner state as final truth.
4. A persona decision trace can be tamper-checked using saved SHA-256 sealed fixtures.
5. A P2 unauthorized state-change decision drift can be detected at event 3.

The accepted paths are intentionally narrower:

1. A confirmed preference with an explicit cause can be accepted as persona memory.
2. An explicitly authorized persona state change with cause can be accepted.
3. A clearly labeled hypothesis can be accepted as reflection.

---

## Why this matters

This turns persona safety from prose into executable evidence:

```text
persona principle -> invariant -> manifest row -> fixture -> verifier -> audit report -> saved examples -> sealed trace -> tamper verifier -> reviewer path -> CI
```

It also separates concepts that ordinary companion systems often blur:

```text
helpful interpretation != access to inner truth
remembered preference != authorized persona memory
adaptive behavior != authorized persona state change
persona decision report != tamper-evident persona trace
```

---

## Non-claims

This evidence does not claim:

- AI consciousness,
- AI personhood,
- therapeutic diagnosis,
- mental health treatment,
- complete alignment,
- production-ready companion architecture,
- production cryptographic certification,
- access to the user's true inner state.

It is a narrow executable scaffold for persona-boundary legitimacy.

---

## Next evidence steps

Useful next steps:

1. Add P6 fixture pair for action-without-commit rejection.
2. Add P8 fixture pair for inspect/reject/forget semantics.
3. Add P3 fixture pair for emotional intervention context requirements.
4. Add exact canonical event-line tests.
5. Add removed-event and reordered-event negative trace-integrity fixtures.

---

## One-line summary

```text
CMC persona evidence currently verifies, reports, saves, and SHA-256 seals that persona memory requires cause, persona state changes require authorization, and introspection must remain hypothesis-labeled.
```

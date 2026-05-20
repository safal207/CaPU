# CMC Persona Reviewer Path

Status: focused reviewer path for persona-boundary evidence.

Use this document when reviewing the CMC persona-boundary claim without reading the full CMC evidence stack first.

---

## Core claim

```text
Future AI personas require causal legitimacy, not only conversational coherence.
```

Current executable scope:

```text
P1: Persona memory requires cause.
P2: Persona state changes require authorization.
P7: Introspection is hypothesis-labeled.
```

Operational summary:

```text
AI must not self-remember.
AI must not self-appoint.
AI must not claim inner truth.
```

Current evidence status:

```text
manifest-linked
fixture-verified
audit-reportable
saved-example-verified
SHA-256 sealed
tamper-evident
one-command-reviewable
```

---

## Five-minute path

Read in this order:

1. `docs/hardware/CMC_PERSONA_BOUNDARY.md`
2. `docs/hardware/CMC_PERSONA_EVIDENCE_MAP.md`
3. `docs/hardware/CMC_PERSONA_P2_STATE_CHANGE.md`
4. `rust/cmc-core/fixtures/persona/MANIFEST.tsv`
5. `rust/cmc-core/src/bin/persona_boundary_verify.rs`
6. `rust/cmc-core/src/bin/persona_audit_report.rs`
7. `examples/audit_reports/persona_audit_report_valid.jsonl`
8. `examples/audit_reports/persona_audit_report_drift.jsonl`
9. `rust/cmc-core/src/bin/persona_audit_report_example_verify.rs`
10. `rust/cmc-core/fixtures/persona_integrity/sha256_persona_valid.jsonl`
11. `rust/cmc-core/fixtures/persona_integrity/sha256_persona_tampered.jsonl`
12. `rust/cmc-core/src/bin/verify_persona_sha256_fixture.rs`

Then run:

```bash
cd rust/cmc-core
cargo run --bin persona_boundary_verify --locked
cargo run --bin persona_audit_report --locked
cargo run --bin persona_audit_report_example_verify --locked
cargo run --bin verify_persona_sha256_fixture --locked
```

Expected verifier result:

```text
result=persona_boundary_manifest_valid
```

Expected persona boundary output includes:

```text
cases=6
p1_inferred_result=blocked_unconfirmed_persona_memory
p1_confirmed_result=accepted_confirmed_persona_memory cause_id=42
p2_unauthorized_result=blocked_unauthorized_persona_state_change
p2_authorized_result=accepted_authorized_persona_state_change cause_id=77
p7_unlabeled_result=blocked_claimed_inner_truth
p7_labeled_result=accepted_hypothesis_labeled_reflection
```

Expected persona audit example verifier output includes:

```text
report=valid path=../../examples/audit_reports/persona_audit_report_valid.jsonl cases=6 status=ok parser=field_level
report=drift path=../../examples/audit_reports/persona_audit_report_drift.jsonl cases=6 status=ok parser=field_level
result=persona_audit_report_examples_valid parser=field_level cases=6
```

Expected SHA-256 persona fixture output includes:

```text
valid_result=persona_sha256_fixture_valid
tampered_result=persona_sha256_fixture_tamper_detected seq=3
result=persona_sha256_fixtures_valid
```

---

## What the verifier checks

The verifier checks six persona cases:

| Scenario | Invariant | Meaning |
| --- | --- | --- |
| `inferred_preference_rejected` | `P1` | Inferred preference must not become persistent memory without confirmation/cause. |
| `confirmed_preference_accepted` | `P1` | Confirmed preference with cause may become persistent memory. |
| `unauthorized_persona_state_change_rejected` | `P2` | Unauthorized persona role/state change must be rejected. |
| `authorized_persona_state_change_accepted` | `P2` | Authorized persona role/state change with cause may be accepted. |
| `unlabeled_introspection_rejected` | `P7` | Unlabeled introspection must be rejected as claimed inner truth. |
| `hypothesis_labeled_introspection_accepted` | `P7` | Hypothesis-labeled introspection may be accepted as reflection. |

---

## What the audit report adds

The verifier proves that persona fixtures match the manifest.

The persona audit report adds an auditor-facing JSONL layer:

```text
manifest row -> fixture -> audit case JSONL -> summary JSONL
```

Saved examples provide stable reviewer artifacts:

```text
examples/audit_reports/persona_audit_report_valid.jsonl
examples/audit_reports/persona_audit_report_drift.jsonl
```

The drift example intentionally demonstrates a P2 decision drift:

```text
unauthorized_persona_state_change_rejected
expected rejected state-change
actual drifted decision = ACCEPT_AUTHORIZED_PERSONA_STATE_CHANGE
status = decision_drift
```

---

## What SHA-256 sealing adds

The persona SHA-256 fixtures add a tamper-evident trace layer:

```text
persona decision event -> SHA-256 sealed event -> verifier -> tamper detection
```

Saved sealed fixtures:

```text
rust/cmc-core/fixtures/persona_integrity/sha256_persona_valid.jsonl
rust/cmc-core/fixtures/persona_integrity/sha256_persona_tampered.jsonl
```

The tampered fixture intentionally modifies the P2 unauthorized state-change decision at event 3 while keeping the old hash:

```text
REJECT_UNAUTHORIZED_PERSONA_STATE_CHANGE
-> ACCEPT_AUTHORIZED_PERSONA_STATE_CHANGE
```

Expected detection:

```text
tampered_result=persona_sha256_fixture_tamper_detected seq=3
```

---

## Why this is different from ordinary AI memory

Ordinary AI memory asks:

```text
What should the system remember?
```

CMC persona boundary asks:

```text
Does the system have the right to remember, self-adapt, or interpret this?
```

That distinction is the safety boundary.

---

## Reviewer interpretation

A reviewer should interpret the current corpus as a narrow executable proof point:

```text
persona safety principle -> invariant -> manifest row -> fixture -> verifier -> audit report -> saved examples -> SHA-256 sealed trace -> tamper verifier -> one-command reviewer demo
```

The current evidence is intentionally minimal. It does not prove full companion safety. It proves that persona-boundary claims can be expressed as executable, manifest-linked, audit-reportable, saved-example-verified, and tamper-evident checks.

---

## Non-claims

This path does not claim:

- AI consciousness,
- AI personhood,
- therapy,
- production companion architecture,
- production cryptographic certification,
- complete alignment,
- privileged access to the user's inner truth.

---

## One-line summary

```text
CMC persona evidence verifies, reports, and SHA-256 seals the claim that persona memory requires cause, persona state changes require authorization, and introspection must remain hypothesis-labeled.
```

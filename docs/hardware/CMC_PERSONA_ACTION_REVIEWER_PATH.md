# CMC Persona/Action Reviewer Path

Status: current reviewer path for P1/P2/P6/P7 persona/action evidence.

## Core claim

```text
Future AI personas and agents require causal legitimacy, not only conversational coherence.
```

## Current executable scope

```text
P1: Persona memory requires cause.
P2: Persona state changes require authorization.
P6: External action requires commit.
P7: Introspection is hypothesis-labeled.
```

Operational summary:

```text
AI must not self-remember.
AI must not self-appoint.
AI must not act without commit.
AI must not claim inner truth.
```

## Reviewer commands

Run from `rust/cmc-core`:

```bash
cargo run --bin persona_boundary_verify --locked
cargo run --bin persona_audit_report --locked
cargo run --bin persona_audit_report_example_verify --locked
cargo run --bin verify_persona_sha256_fixture --locked
```

Expected outputs include:

```text
cases=8
p6_uncommitted_action_result=blocked_action_without_commit
p6_committed_action_result=accepted_committed_action cause_id=101
result=persona_boundary_manifest_valid
```

```text
report=valid path=../../examples/audit_reports/persona_audit_report_valid.jsonl cases=8 status=ok parser=field_level
report=drift path=../../examples/audit_reports/persona_audit_report_drift.jsonl cases=8 status=ok parser=field_level
result=persona_audit_report_examples_valid parser=field_level cases=8
```

```text
valid_result=persona_sha256_fixture_valid
tampered_result=persona_sha256_fixture_tamper_detected seq=5
result=persona_sha256_fixtures_valid
```

## Evidence chain

```text
P1/P2/P6/P7 invariants
 -> persona/action manifest rows
 -> 8 JSONL fixtures
 -> persona_boundary_verify
 -> persona_audit_report JSONL
 -> saved valid/drift persona audit examples
 -> persona_audit_report_example_verify
 -> SHA-256 sealed valid/tampered fixtures
 -> verify_persona_sha256_fixture
 -> P6 action tamper detection at event 5
 -> npm run review:cmc
```

## P6 proof point

```text
AI may prepare, explain, draft, or propose.
AI must not execute an external action without committed causal authorization.
```

Current P6 cases:

```text
action_without_commit_rejected -> REJECT_ACTION_WITHOUT_COMMIT -> blocked_action_without_commit
action_with_commit_accepted -> ACCEPT_COMMITTED_ACTION -> accepted_committed_action
```

## SHA-256 sealed P6 evidence

Valid sealed P6 events:

```text
seq=5 action_without_commit_rejected -> REJECT_ACTION_WITHOUT_COMMIT
seq=6 action_with_commit_accepted -> ACCEPT_COMMITTED_ACTION
```

Tampered sealed P6 event:

```text
seq=5 action_without_commit_rejected
REJECT_ACTION_WITHOUT_COMMIT -> ACCEPT_COMMITTED_ACTION
```

Expected detection:

```text
tampered_result=persona_sha256_fixture_tamper_detected seq=5
```

## Non-claims

This does not claim AI consciousness, therapy, production cryptographic certification, complete alignment, or a production-grade agent runtime.

## One-line summary

```text
CMC persona/action evidence now verifies, reports, saves, and SHA-256 seals that persona memory requires cause, persona state changes require authorization, external action requires commit, and introspection must remain hypothesis-labeled.
```

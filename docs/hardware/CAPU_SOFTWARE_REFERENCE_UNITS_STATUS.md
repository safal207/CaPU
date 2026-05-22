# CaPU Software Reference Units Status

Status: current implementation snapshot for CaPU software reference units.

Progress estimate:

```text
Software reference processor: ~50%
Runtime sidecar/API:        ~15%
Hardware/device path:       ~5%
```

This document is the current short status source for the Rust-side CaPU reference pipeline.

---

## Current implemented units

```text
rust/cmc-core/src/capu/mod.rs
rust/cmc-core/src/capu/transition.rs
rust/cmc-core/src/capu/decoder.rs
rust/cmc-core/src/capu/boundary_router.rs
rust/cmc-core/src/capu/cause_unit.rs
rust/cmc-core/src/capu/commit_unit.rs
rust/cmc-core/src/capu/decision_unit.rs
rust/cmc-core/src/capu/audit_bus.rs
rust/cmc-core/src/capu/seal_unit.rs
rust/cmc-core/src/capu/replay_unit.rs
rust/cmc-core/src/bin/capu_p6_pipeline_demo.rs
rust/cmc-core/src/bin/capu_p6_replay_verify.rs
rust/cmc-core/src/bin/capu_p6_fixture_verify.rs
rust/cmc-core/src/bin/capu_p6_action_variants_verify.rs
rust/cmc-core/src/bin/capu_manifest_verify.rs
rust/cmc-core/fixtures/capu/MANIFEST.tsv
rust/cmc-core/fixtures/capu/p6_audit_valid.jsonl
rust/cmc-core/fixtures/capu/p6_audit_tampered.jsonl
```

Current module tree:

```rust
pub mod audit_bus;
pub mod boundary_router;
pub mod cause_unit;
pub mod commit_unit;
pub mod decision_unit;
pub mod decoder;
pub mod replay_unit;
pub mod seal_unit;
pub mod transition;
```

---

## Current executable P6 pipeline

The current software reference pipeline implements P6 external-action legitimacy as an executable evidence path:

```text
ExternalActionRequest
 -> decode_external_action
 -> route_boundary(TransitionType::ExternalAction)
 -> Boundary::ActionRequiresCommit
 -> decide_transition
 -> check_external_action_commit
 -> check_cause_present
 -> emit_audit_record
 -> seal_audit_records
 -> replay_p6_audit_chain
 -> saved fixture verification
 -> manifest verification
 -> reviewer-visible result marker
```

Current outcomes:

```text
commit=false
 -> REJECT_ACTION_WITHOUT_COMMIT
 -> blocked_action_without_commit

commit=true + cause_id=101
 -> ACCEPT_COMMITTED_ACTION
 -> accepted_committed_action

commit=true + missing cause
 -> REJECT_ACTION_WITHOUT_CAUSE
 -> blocked_action_without_cause
```

Current broader P6 action variants:

```text
delete_file without commit -> REJECT_ACTION_WITHOUT_COMMIT
delete_file with commit    -> ACCEPT_COMMITTED_ACTION
deploy_code without commit -> REJECT_ACTION_WITHOUT_COMMIT
deploy_code with commit    -> ACCEPT_COMMITTED_ACTION
```

---

## Reviewer commands

Run from `rust/cmc-core`:

```bash
cargo run --bin capu_p6_pipeline_demo --locked
```

Expected output includes:

```text
CAPU-P6-PIPELINE-DEMO v0
uncommitted_result=blocked_action_without_commit code=REJECT_ACTION_WITHOUT_COMMIT boundary=action_requires_commit accepted=false
committed_result=accepted_committed_action code=ACCEPT_COMMITTED_ACTION boundary=action_requires_commit cause_id=101 accepted=true
sealed_events=2
seal_result=capu_p6_audit_seal_valid
replay_summary events=2 p6_boundary_events=2 rejected_without_commit=1 accepted_committed_action=1
replay_result=capu_p6_audit_replay_valid
result=capu_p6_pipeline_valid
```

Independent replay verifier:

```bash
cargo run --bin capu_p6_replay_verify --locked
```

Expected output includes:

```text
CAPU-P6-REPLAY-VERIFY v0
sealed_events=2
replay_summary events=2 p6_boundary_events=2 rejected_without_commit=1 accepted_committed_action=1
result=capu_p6_replay_verified
```

Saved fixture verifier:

```bash
cargo run --bin capu_p6_fixture_verify --locked
```

Expected output includes:

```text
CAPU-P6-FIXTURE-VERIFY v0
valid_fixture=fixtures/capu/p6_audit_valid.jsonl
valid_events=2
valid_result=capu_p6_fixture_replay_valid
tampered_fixture=fixtures/capu/p6_audit_tampered.jsonl
tampered_events=2
tampered_result=capu_p6_fixture_tamper_detected event=1
result=capu_p6_fixtures_verified
```

Action variants verifier:

```bash
cargo run --bin capu_p6_action_variants_verify --locked
```

Expected output includes:

```text
CAPU-P6-ACTION-VARIANTS-VERIFY v0
variant_cases=4
variant_rejected=2
variant_accepted=2
sealed_events=4
seal_result=capu_p6_action_variants_seal_valid
result=capu_p6_action_variants_verified
```

Manifest verifier:

```bash
cargo run --bin capu_manifest_verify --locked
```

Expected output includes:

```text
CAPU-MANIFEST-VERIFY v0
case=p6_audit_valid role=valid events=2 result=capu_p6_fixture_replay_valid
case=p6_audit_tampered role=tampered events=2 result=capu_p6_fixture_tamper_detected
manifest=fixtures/capu/MANIFEST.tsv
manifest_cases=2
manifest_valid=1
manifest_tampered=1
result=capu_manifest_verified
```

All commands are included in:

```bash
npm run review:cmc
```

---

## What is implemented now

Implemented:

```text
Transition shared types
Boundary enum
DecisionClass enum
UnitDecision struct
ExternalActionRequest
P6 external action decoder
Boundary router
Cause unit
P6 commit unit
Decision unit with route-mismatch rejection
Audit bus with JSONL-shaped records
Seal unit using existing SHA-256 trace-chain primitives
Replay unit for sealed P6 audit evidence
P6 CLI pipeline demo
Independent P6 replay verifier binary
Saved valid P6 sealed audit fixture
Saved tampered P6 sealed audit fixture
Saved fixture verifier binary
P6 action variants verifier binary
CaPU fixture manifest
CaPU manifest verifier binary
Reviewer script integration
```

Boundaries not yet implemented by dedicated units intentionally return:

```text
HOLD_UNIMPLEMENTED_BOUNDARY
```

This keeps the reference processor honest while more units are extracted.

---

## Evidence semantics

The current P6 path now demonstrates six separate evidence layers:

```text
Decision evidence
 -> UnitDecision: ACCEPT / REJECT / HOLD

Audit evidence
 -> AuditRecord JSONL

Integrity evidence
 -> SHA-256 sealed trace chain

Replay evidence
 -> semantic replay summary over sealed audit events

Saved fixture evidence
 -> valid fixture + tampered fixture + fixture verifier

Manifest-linked evidence
 -> MANIFEST.tsv + manifest verifier
```

Replay currently checks the canonical two-event P6 pair:

```text
REJECT_ACTION_WITHOUT_COMMIT
ACCEPT_COMMITTED_ACTION
```

The tampered fixture intentionally modifies the first saved event while preserving the old hash, so the verifier must fail before semantic replay:

```text
ReplayError::SealInvalid { event_index: 1 }
```

The action variants verifier demonstrates that P6 is not tied to `send_email` only; the same action-commit boundary applies to `delete_file` and `deploy_code` cases.

This is intentionally narrow and deterministic. Future replay units can generalize to arbitrary trace classes.

---

## Relationship to architecture docs

This status file connects the architecture docs to code:

```text
CAPU_PROCESSOR_MODEL
 -> CAPU_PROCESSOR_ISA_V0
 -> CAPU_MICROARCHITECTURE_V0
 -> CAPU_SOFTWARE_REFERENCE_UNITS_ROADMAP
 -> CAPU_SOFTWARE_REFERENCE_UNITS_STATUS
 -> rust/cmc-core/src/capu
 -> reviewer binaries
 -> saved fixtures
 -> fixture manifest
 -> npm run review:cmc
```

---

## Current reviewer claim

The current implemented claim is:

```text
A P6 external action can be decoded, boundary-routed, decided, cause-checked, audit-emitted, SHA-256 sealed, semantically replay-verified, saved as fixture evidence, tamper-detected, tested across multiple action kinds, and manifest-verified through reviewer-visible command paths.
```

The current implementation does not claim a complete CaPU runtime.

---

## Next implementation steps

Recommended next step:

```text
Get a fresh green CI / reviewer baseline on current main.
```

Then:

```text
If CI fails, fix only the failing layer:
- compile error
- fixture hash mismatch
- manifest parsing mismatch
- reviewer script mismatch
```

Then:

```text
Start P1 cause/persona-memory unit extraction using the same pipeline pattern:
decode -> boundary route -> cause check -> decision -> audit -> seal -> replay -> fixture -> manifest
```

---

## Non-claims

This status does not claim:

```text
production runtime
hardware implementation
complete policy language
complete AI safety system
production cryptographic certification
full arbitrary replay engine
```

It is a software reference scaffold.

---

## One-line summary

```text
CaPU currently has a manifest-linked executable software reference evidence path for P6 external actions: decode -> boundary route -> decision -> cause check -> audit -> seal -> replay -> saved fixture verification -> action variants -> manifest verification -> reviewer script.
```

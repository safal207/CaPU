# CaPU Software Reference Units Status

Status: current implementation snapshot for CaPU software reference units.

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

Both commands are included in:

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
Reviewer script integration
```

Boundaries not yet implemented by dedicated units intentionally return:

```text
HOLD_UNIMPLEMENTED_BOUNDARY
```

This keeps the reference processor honest while more units are extracted.

---

## Evidence semantics

The current P6 path now demonstrates four separate evidence layers:

```text
Decision evidence
 -> UnitDecision: ACCEPT / REJECT / HOLD

Audit evidence
 -> AuditRecord JSONL

Integrity evidence
 -> SHA-256 sealed trace chain

Replay evidence
 -> semantic replay summary over sealed audit events
```

Replay currently checks the canonical two-event P6 pair:

```text
REJECT_ACTION_WITHOUT_COMMIT
ACCEPT_COMMITTED_ACTION
```

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
 -> npm run review:cmc
```

---

## Current reviewer claim

The current implemented claim is:

```text
A P6 external action can be decoded, boundary-routed, decided, cause-checked, audit-emitted, SHA-256 sealed, and semantically replay-verified through a reviewer-visible command path.
```

The current implementation does not claim a complete CaPU runtime.

---

## Next implementation steps

Recommended next step:

```text
Create a small fixture file for the P6 sealed audit pair
Create a capu_p6_fixture_verify.rs verifier
Keep capu_p6_pipeline_demo and capu_p6_replay_verify markers unchanged
```

Then:

```text
Extract broader P6 action variants:
- delete_file_without_commit_rejected
- delete_file_with_commit_accepted
- deploy_code_without_commit_rejected
- deploy_code_with_commit_accepted
```

Then:

```text
Start P1 cause/persona-memory unit extraction using the same pipeline pattern.
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
CaPU currently has a first executable software reference evidence path for P6 external actions: decode -> boundary route -> decision -> cause check -> audit -> seal -> replay -> independent verifier.
```

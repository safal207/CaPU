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
rust/cmc-core/src/capu/decision_unit.rs
rust/cmc-core/src/capu/commit_unit.rs
rust/cmc-core/src/bin/capu_p6_pipeline_demo.rs
```

Current module tree:

```rust
pub mod boundary_router;
pub mod commit_unit;
pub mod decision_unit;
pub mod decoder;
pub mod transition;
```

---

## Current executable pipeline

The current software reference pipeline implements P6 external-action legitimacy:

```text
ExternalActionRequest
 -> decode_external_action
 -> route_boundary(TransitionType::ExternalAction)
 -> Boundary::ActionRequiresCommit
 -> decide_transition
 -> check_external_action_commit
 -> REJECT_ACTION_WITHOUT_COMMIT / ACCEPT_COMMITTED_ACTION
```

---

## Reviewer command

Run from `rust/cmc-core`:

```bash
cargo run --bin capu_p6_pipeline_demo --locked
```

Expected output includes:

```text
CAPU-P6-PIPELINE-DEMO v0
uncommitted_result=blocked_action_without_commit code=REJECT_ACTION_WITHOUT_COMMIT boundary=action_requires_commit accepted=false
committed_result=accepted_committed_action code=ACCEPT_COMMITTED_ACTION boundary=action_requires_commit cause_id=101 accepted=true
result=capu_p6_pipeline_valid
```

This command is also included in:

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
Decision unit with route-mismatch rejection
P6 commit unit
P6 CLI pipeline demo
```

P6 verified outcomes:

```text
commit=false -> REJECT_ACTION_WITHOUT_COMMIT -> blocked_action_without_commit
commit=true + cause_id=101 -> ACCEPT_COMMITTED_ACTION -> accepted_committed_action
commit=true + missing cause -> REJECT_ACTION_WITHOUT_CAUSE -> blocked_action_without_cause
```

Boundaries not yet implemented by dedicated units intentionally return:

```text
HOLD_UNIMPLEMENTED_BOUNDARY
```

This keeps the reference processor honest while more units are extracted.

---

## Relationship to docs

This status file connects the architecture docs to code:

```text
CAPU_PROCESSOR_MODEL
 -> CAPU_PROCESSOR_ISA_V0
 -> CAPU_MICROARCHITECTURE_V0
 -> CAPU_SOFTWARE_REFERENCE_UNITS_ROADMAP
 -> CAPU_SOFTWARE_REFERENCE_UNITS_STATUS
 -> rust/cmc-core/src/capu
```

---

## Next implementation steps

Recommended next step:

```text
Create cause_unit.rs
Move cause presence validation out of commit_unit.rs
Use cause_unit from check_external_action_commit
Keep P6 demo output unchanged
```

Then:

```text
Create audit_bus.rs
Emit audit-shaped records from the P6 pipeline demo
Create seal_unit.rs
Wrap current SHA-256 sealing as a reusable unit
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
```

It is a software reference scaffold.

---

## One-line summary

```text
CaPU currently has a first executable software reference pipeline for P6 external actions: decode -> boundary route -> decision -> commit check -> reviewer CLI demo.
```

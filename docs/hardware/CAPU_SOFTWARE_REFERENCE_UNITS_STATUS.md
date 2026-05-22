# CaPU Software Reference Units Status

Status: current implementation snapshot for CaPU software reference units.

Progress estimate:

```text
Software reference processor: ~66%
Runtime sidecar/API:        ~90%
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
rust/cmc-core/src/capu/persona_memory_unit.rs
rust/cmc-core/src/capu/decision_unit.rs
rust/cmc-core/src/capu/audit_bus.rs
rust/cmc-core/src/capu/seal_unit.rs
rust/cmc-core/src/capu/replay_unit.rs
rust/cmc-core/src/bin/capu_p6_pipeline_demo.rs
rust/cmc-core/src/bin/capu_p6_replay_verify.rs
rust/cmc-core/src/bin/capu_p6_fixture_verify.rs
rust/cmc-core/src/bin/capu_p6_action_variants_verify.rs
rust/cmc-core/src/bin/capu_manifest_verify.rs
rust/cmc-core/src/bin/capu_p1_persona_memory_verify.rs
rust/cmc-core/src/bin/capu_runtime_http_sidecar.rs
rust/cmc-core/fixtures/capu/MANIFEST.tsv
rust/cmc-core/fixtures/capu/p6_audit_valid.jsonl
rust/cmc-core/fixtures/capu/p6_audit_tampered.jsonl
rust/cmc-core/fixtures/capu_runtime_http/requests/replay_submitted_p1_pair.json
rust/cmc-core/fixtures/capu_runtime_http/requests/replay_submitted_p6_pair.json
```

Current module tree:

```rust
pub mod audit_bus;
pub mod boundary_router;
pub mod cause_unit;
pub mod commit_unit;
pub mod decision_unit;
pub mod decoder;
pub mod persona_memory_unit;
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

Current P6 outcomes:

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

## Current executable P1 pipeline

The current software reference pipeline now also implements P1 persona-memory causal legitimacy:

```text
PersonaMemoryRequest
 -> decode_persona_memory
 -> route_boundary(TransitionType::PersonaMemory)
 -> Boundary::PersonaMemoryRequiresCause
 -> decide_transition
 -> check_persona_memory_cause
 -> emit_audit_record
 -> seal_audit_records
 -> reviewer-visible result marker
```

Current P1 outcomes:

```text
cause_id=None
 -> REJECT_PERSONA_MEMORY_WITHOUT_CAUSE
 -> blocked_persona_memory_without_cause

cause_id=42
 -> ACCEPT_PERSONA_MEMORY_WITH_CAUSE
 -> accepted_persona_memory_with_cause
```

---

## Current replay submission decoder semantics

The core decoder now has typed replay submission semantics for the runtime replay path:

```text
ReplaySubmissionRequest
 -> decode_replay_submission
 -> DecodedReplaySubmission
```

Supported v0 selectors:

```text
invariant_id = P1 | P6
replay       = canonical_pair | submitted_pair
```

Canonical replay decoding:

```text
ReplaySubmissionRequest::canonical_pair("P6")
 -> invariant_id=P6
 -> mode=canonical_pair
 -> events=canonical_pair
```

Submitted replay decoding:

```text
ReplaySubmissionRequest::submitted_pair("P1", "http-p1-submitted-replay", "canonical_pair")
 -> invariant_id=P1
 -> mode=submitted_pair
 -> submission_id=http-p1-submitted-replay
 -> events=canonical_pair
```

Current negative decode cases:

```text
missing submission_id       -> MissingSubmissionId
unsupported events          -> UnsupportedEvents
unsupported invariant_id    -> UnsupportedInvariantId
unsupported replay mode     -> UnsupportedReplayMode
```

This keeps submitted replay honest: v0 supports an explicit submitted request envelope, but does not yet claim arbitrary inline replay event decoding.

---

## Reviewer commands

Run from `rust/cmc-core`.

P6 pipeline demo:

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

P6 independent replay verifier:

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

P6 saved fixture verifier:

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

P6 action variants verifier:

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

CaPU manifest verifier:

```bash
cargo run --bin capu_manifest_verify --locked
```

Expected output includes:

```text
CAPU-MANIFEST-VERIFY v0
case=p6_audit_valid role=valid events=2 result=capu_p6_fixture_replay_valid
case=p6_audit_tampered role=tampered events=2 result=capu_p6_fixture_tamper_detected
case=p1_persona_memory_valid role=valid events=2 result=capu_p1_fixture_replay_valid
case=p1_persona_memory_missing_cause role=missing_cause events=1 result=capu_p1_fixture_missing_cause
manifest=fixtures/capu/MANIFEST.tsv
manifest_cases=4
manifest_valid=2
manifest_tampered=1
manifest_missing_cause=1
result=capu_manifest_verified
```

P1 persona-memory verifier:

```bash
cargo run --bin capu_p1_persona_memory_verify --locked
```

Expected output includes:

```text
CAPU-P1-PERSONA-MEMORY-VERIFY v0
unconfirmed_result=blocked_persona_memory_without_cause code=REJECT_PERSONA_MEMORY_WITHOUT_CAUSE boundary=persona_memory_requires_cause accepted=false
confirmed_result=accepted_persona_memory_with_cause code=ACCEPT_PERSONA_MEMORY_WITH_CAUSE boundary=persona_memory_requires_cause cause_id=42 accepted=true
sealed_events=2
seal_result=capu_p1_persona_memory_seal_valid
result=capu_p1_persona_memory_verified
```

All commands are included in:

```bash
npm run review:cmc
```

The CI workflow also runs the P1 verifier and runtime HTTP examples directly.

---

## What is implemented now

Implemented:

```text
Transition shared types
Boundary enum
DecisionClass enum
UnitDecision struct
ExternalActionRequest
PersonaMemoryRequest
ReplaySubmissionRequest
DecodedReplaySubmission
ReplaySubmissionDecodeError
P6 external action decoder
P1 persona-memory decoder
Replay submission decoder
Boundary router
Cause unit
P6 commit unit
P1 persona memory unit
Decision unit with route-mismatch rejection
Audit bus with JSONL-shaped records
Seal unit using existing SHA-256 trace-chain primitives
Replay unit for sealed P6 audit evidence
Replay unit for sealed P1 audit evidence
P6 CLI pipeline demo
Independent P6 replay verifier binary
Saved valid P6 sealed audit fixture
Saved tampered P6 sealed audit fixture
Saved fixture verifier binary
P6 action variants verifier binary
CaPU fixture manifest
CaPU manifest verifier binary
P1 persona-memory verifier binary
Runtime HTTP sidecar reference path
Reviewer script integration
CI integration for CaPU verifiers and runtime HTTP examples
```

Boundaries not yet implemented by dedicated units intentionally return:

```text
HOLD_UNIMPLEMENTED_BOUNDARY
```

This keeps the reference processor honest while more units are extracted.

---

## Evidence semantics

The current CaPU path now demonstrates eight separate evidence layers:

```text
Decision evidence
 -> UnitDecision: ACCEPT / REJECT / HOLD

Audit evidence
 -> AuditRecord JSONL

Integrity evidence
 -> SHA-256 sealed trace chain

Replay evidence
 -> semantic replay summary over sealed P6/P1 audit events

Replay submission evidence
 -> typed canonical/submitted replay request decoding with explicit failure modes

Saved fixture evidence
 -> valid P6/P1 fixtures + tampered/missing-cause fixture checks

Manifest-linked evidence
 -> MANIFEST.tsv + manifest verifier

Cross-invariant evidence
 -> P6 external actions + P1 persona-memory writes
```

P6 currently checks the canonical two-event pair:

```text
REJECT_ACTION_WITHOUT_COMMIT
ACCEPT_COMMITTED_ACTION
```

P1 currently checks the canonical two-event pair:

```text
REJECT_PERSONA_MEMORY_WITHOUT_CAUSE
ACCEPT_PERSONA_MEMORY_WITH_CAUSE
```

The tampered P6 fixture intentionally modifies the first saved event while preserving the old hash, so the verifier must fail before semantic replay:

```text
ReplayError::SealInvalid { event_index: 1 }
```

This is intentionally narrow and deterministic. Future replay units can generalize to arbitrary trace classes and multiple invariants.

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
 -> runtime HTTP evidence
 -> npm run review:cmc
 -> GitHub Actions verifier steps
```

---

## Current reviewer claim

The current implemented claim is:

```text
CaPU can execute reviewer-visible legitimacy checks for P6 external actions, P1 persona-memory writes, and replay submission request envelopes: decoded requests are boundary-routed or replay-decoded, decided, cause/commit-checked, audit-emitted, SHA-256 sealed, and verified through direct CLI commands, reviewer script integration, and CI steps.
```

The current implementation does not claim a complete CaPU runtime.

---

## Next implementation steps

Recommended next step:

```text
Add a dedicated replay_submission_unit.rs that turns DecodedReplaySubmission into replay execution decisions.
```

Then:

```text
Add explicit unsupported replay submission HTTP error fixtures:
- unsupported invariant_id
- missing submission_id
- unsupported events
```

Then:

```text
Get a fresh green CI / reviewer baseline on current main.
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
CaPU currently has an executable software reference evidence path for P6 external actions, P1 persona-memory writes, and typed replay submission envelopes: decode -> boundary/replay route -> decision -> cause/commit check -> audit -> seal -> replay/fixture/manifest verification -> reviewer script -> CI step.
```

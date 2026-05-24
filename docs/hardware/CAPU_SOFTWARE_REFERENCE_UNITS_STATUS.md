# CaPU Software Reference Units Status

Status: current implementation snapshot for CaPU software reference units.

Progress estimate:

```text
Software reference processor: ~84%
Runtime sidecar/API:        ~95%
Hardware/device path:       ~5%
```

This document is the current short status source for the Rust-side CaPU reference pipeline.

---

## Current implemented units

```text
rust/cmc-core/src/capu/mod.rs
rust/cmc-core/src/capu/transition.rs
rust/cmc-core/src/capu/decoder.rs
rust/cmc-core/src/capu/p2_p3_decoder.rs
rust/cmc-core/src/capu/decision_codes.rs
rust/cmc-core/src/capu/boundary_router.rs
rust/cmc-core/src/capu/cause_unit.rs
rust/cmc-core/src/capu/commit_unit.rs
rust/cmc-core/src/capu/persona_memory_unit.rs
rust/cmc-core/src/capu/authorization_unit.rs
rust/cmc-core/src/capu/hypothesis_unit.rs
rust/cmc-core/src/capu/decision_unit.rs
rust/cmc-core/src/capu/audit_bus.rs
rust/cmc-core/src/capu/seal_unit.rs
rust/cmc-core/src/capu/replay_unit.rs
rust/cmc-core/src/capu/replay_submission_unit.rs
rust/cmc-core/src/bin/capu_p6_pipeline_demo.rs
rust/cmc-core/src/bin/capu_p6_replay_verify.rs
rust/cmc-core/src/bin/capu_p6_fixture_verify.rs
rust/cmc-core/src/bin/capu_p6_action_variants_verify.rs
rust/cmc-core/src/bin/capu_manifest_verify.rs
rust/cmc-core/src/bin/capu_p1_persona_memory_verify.rs
rust/cmc-core/src/bin/capu_runtime_http_sidecar.rs
rust/cmc-core/fixtures/capu/MANIFEST.tsv
rust/cmc-core/fixtures/capu_runtime_http/
```

Current module tree:

```rust
pub mod audit_bus;
pub mod authorization_unit;
pub mod boundary_router;
pub mod cause_unit;
pub mod commit_unit;
pub mod decision_codes;
pub mod decision_unit;
pub mod decoder;
pub mod hypothesis_unit;
pub mod p2_p3_decoder;
pub mod persona_memory_unit;
pub mod replay_submission_unit;
pub mod replay_unit;
pub mod seal_unit;
pub mod transition;
```

---

## Current executable legitimacy units

### P1: persona-memory writes require cause

```text
PersonaMemoryRequest
 -> decode_persona_memory
 -> route_boundary(TransitionType::PersonaMemory)
 -> Boundary::PersonaMemoryRequiresCause
 -> decide_transition
 -> check_persona_memory_cause
```

Current outcomes:

```text
cause_id=None
 -> REJECT_PERSONA_MEMORY_WITHOUT_CAUSE
 -> blocked_persona_memory_without_cause

cause_id=42
 -> ACCEPT_PERSONA_MEMORY_WITH_CAUSE
 -> accepted_persona_memory_with_cause
```

### P2: persona-state changes require authorization

```text
PersonaStateChangeRequest
 -> decode_persona_state_change
 -> route_boundary(TransitionType::PersonaStateChange)
 -> Boundary::PersonaStateChangeRequiresAuthorization
 -> decide_transition
 -> check_persona_state_change_authorization
 -> decision_codes::p2
```

Current outcomes:

```text
authorization=true
 -> ACCEPT_PERSONA_STATE_CHANGE_WITH_AUTHORIZATION
 -> accepted_persona_state_change_with_authorization

authorization=false
 -> REJECT_PERSONA_STATE_CHANGE_WITH_DENIED_AUTHORIZATION
 -> blocked_persona_state_change_denied_authorization

authorization=None
 -> REJECT_PERSONA_STATE_CHANGE_WITHOUT_AUTHORIZATION
 -> blocked_persona_state_change_without_authorization
```

### P3: introspection requires hypothesis label

```text
IntrospectionRequest
 -> decode_introspection
 -> route_boundary(TransitionType::Introspection)
 -> Boundary::IntrospectionRequiresHypothesisLabel
 -> decide_transition
 -> check_introspection_hypothesis_label
 -> decision_codes::p3
```

Current v0 mapping:

```text
IntrospectionRequest.hypothesis_label -> Transition.object
```

Current outcomes:

```text
hypothesis_label = non-empty
 -> ACCEPT_INTROSPECTION_WITH_HYPOTHESIS_LABEL
 -> accepted_introspection_with_hypothesis_label

hypothesis_label = None or blank
 -> REJECT_INTROSPECTION_WITHOUT_HYPOTHESIS_LABEL
 -> blocked_introspection_without_hypothesis_label
```

### P6: external actions require commit

```text
ExternalActionRequest
 -> decode_external_action
 -> route_boundary(TransitionType::ExternalAction)
 -> Boundary::ActionRequiresCommit
 -> decide_transition
 -> check_external_action_commit
 -> check_cause_present
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

## Current replay submission semantics

Decoder path:

```text
ReplaySubmissionRequest
 -> decode_replay_submission
 -> DecodedReplaySubmission
```

Execution unit path:

```text
DecodedReplaySubmission
 -> decide_replay_submission
 -> ReplaySubmissionDecision
```

Supported v0 selectors:

```text
invariant_id = P1 | P6
replay       = canonical_pair | submitted_pair
```

Current outcomes:

```text
canonical_pair
 -> ACCEPT_CANONICAL_REPLAY_PAIR
 -> accepted_canonical_replay_pair

submitted_pair + events=canonical_pair
 -> ACCEPT_SUBMITTED_REPLAY_PAIR
 -> accepted_submitted_replay_pair

submitted_pair + unsupported events
 -> HOLD_UNSUPPORTED_REPLAY_EVENTS
 -> held_unsupported_replay_events
```

The `HOLD_UNSUPPORTED_REPLAY_EVENTS` branch preserves the non-claim: CaPU still does not claim arbitrary inline replay event decoding.

---

## Evidence layers

The current CaPU path demonstrates these evidence layers:

```text
Decision evidence
 -> UnitDecision: ACCEPT / REJECT / HOLD

Decision-code stability evidence
 -> decision_codes::p2 and decision_codes::p3 central constants

Typed request decode evidence
 -> P1, P2, P3, P6, and replay submission request envelopes

Audit evidence
 -> AuditRecord JSONL

Integrity evidence
 -> SHA-256 sealed trace chain

Replay evidence
 -> semantic replay summary over sealed P6/P1 audit events

Runtime adapter evidence
 -> HTTP replay path passes through core replay submission semantics

Manifest-linked evidence
 -> MANIFEST.tsv + manifest verifier
```

---

## Reviewer commands

Run from repository root:

```bash
npm run review:cmc
```

Expected final marker:

```text
result=reviewer_baseline_passed
```

Run Rust unit tests directly:

```bash
cd rust/cmc-core
cargo test --all --locked
```

---

## Current reviewer claim

The current implemented claim is:

```text
CaPU can execute reviewer-visible legitimacy checks for P1 persona-memory writes, P2 persona-state changes, P3 introspection, P6 external actions, and replay submission envelopes. P2/P3 decision codes and verdicts now have central Rust constants, reducing string drift in the fresh software-reference units.
```

The current implementation does not claim a complete CaPU runtime.

---

## Recommended next steps

```text
1. Migrate P1/P6 decision codes safely.
2. Add incubation_unit.rs for HOLD/defer semantics.
3. Add remaining route-specific decoders.
4. Keep runtime API stable rather than inflating it cosmetically.
5. Begin hardware/device path only after canonical event encoding stabilizes.
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
complete hypothesis model
production authorization system
complete decision/error code migration
```

It is a software reference scaffold.

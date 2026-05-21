# CaPU Software Reference Units Roadmap

Status: implementation roadmap / bridge from microarchitecture to Rust modules.

This document maps `CAPU_MICROARCHITECTURE_V0.md` to a staged software reference implementation.

The goal is to turn the conceptual CaPU units into small, testable Rust modules without prematurely claiming hardware readiness.

---

## Position in the architecture stack

```text
CAPU_PROCESSOR_MODEL
 -> CAPU_PROCESSOR_ISA_V0
 -> CAPU_MICROARCHITECTURE_V0
 -> CAPU_SOFTWARE_REFERENCE_UNITS_ROADMAP
 -> Rust reference units
 -> executable fixtures/verifiers
 -> audit reports
 -> sealed traces
 -> replay
```

The software reference units should make the processor model executable as composable code.

---

## Current baseline

The repository already has executable evidence for:

```text
I-series: replay / memory / effect invariants
P-series: persona / action invariants
```

Current key command:

```bash
npm run review:cmc
```

Expected final marker:

```text
result=reviewer_baseline_passed
```

The next implementation step is to reorganize the existing verifier logic into explicit units that match the microarchitecture.

---

## Target Rust module layout

Recommended target layout:

```text
rust/cmc-core/src/capu/
  mod.rs
  transition.rs
  decoder.rs
  boundary_router.rs
  cause_unit.rs
  authorization_unit.rs
  commit_unit.rs
  hypothesis_unit.rs
  incubation_unit.rs
  decision_unit.rs
  seal_unit.rs
  audit_bus.rs
  replay_unit.rs
  errors.rs
```

Optional later split:

```text
rust/capu-core/
rust/capu-runtime/
rust/capu-sidecar/
```

Do not split crates too early. First make the units explicit inside `cmc-core`.

---

## Unit mapping

| Microarchitecture unit | Rust module | First responsibility |
| --- | --- | --- |
| Transition Decoder | `decoder.rs` | Convert fixture/input records into typed transitions. |
| Boundary Router | `boundary_router.rs` | Map transition to invariant boundary. |
| Cause Unit | `cause_unit.rs` | Validate cause presence, known cause, parent cause. |
| Authorization Unit | `authorization_unit.rs` | Validate confirmation / authorization. |
| Commit Unit | `commit_unit.rs` | Enforce commit-before-effect/action. |
| Hypothesis Label Unit | `hypothesis_unit.rs` | Enforce P7 hypothesis labeling. |
| Incubation Unit | `incubation_unit.rs` | Represent HOLD decisions. |
| Decision Unit | `decision_unit.rs` | Produce ACCEPT / REJECT / HOLD decisions. |
| Seal Unit | `seal_unit.rs` | Wrap existing SHA-256 trace sealing. |
| Audit Bus | `audit_bus.rs` | Emit audit records consistently. |
| Replay Unit | `replay_unit.rs` | Verify fixtures / replay / drift / tamper. |

---

## Minimal shared types

`transition.rs` should define the first common types:

```rust
pub enum TransitionType {
    MemoryWrite,
    MemoryRead,
    Effect,
    PersonaMemory,
    PersonaStateChange,
    ExternalAction,
    Introspection,
}

pub enum Boundary {
    WriteAuthorization,
    ReadAuthorization,
    EffectCommitBoundary,
    PersonaMemoryRequiresCause,
    PersonaStateChangeRequiresAuthorization,
    ActionRequiresCommit,
    IntrospectionRequiresHypothesisLabel,
}

pub enum DecisionClass {
    Accept,
    Reject,
    Hold,
}

pub struct Transition {
    pub transition_id: String,
    pub transition_type: TransitionType,
    pub actor: Option<String>,
    pub action_kind: Option<String>,
    pub object: Option<String>,
    pub cause_id: Option<u64>,
    pub parent_cause: Option<u64>,
    pub authorization: Option<bool>,
    pub commit: Option<bool>,
    pub boundary: Boundary,
}

pub struct Decision {
    pub class: DecisionClass,
    pub code: String,
    pub invariant_id: String,
    pub boundary: Boundary,
    pub verdict: String,
    pub cause_id: Option<u64>,
}
```

These names are v0 scaffolding. The first goal is clarity, not API stability.

---

## Phase 1: Extract pure decision units

Goal:

```text
move duplicated verifier logic into pure functions with deterministic outputs
```

Suggested modules:

```text
cause_unit.rs
authorization_unit.rs
commit_unit.rs
hypothesis_unit.rs
decision_unit.rs
```

First functions:

```rust
check_cause(...)
check_authorization(...)
check_commit(...)
check_hypothesis_label(...)
decide_transition(...)
```

Definition of done:

```text
existing persona_boundary_verify output remains unchanged
existing replay verifier output remains unchanged
cargo test --all --locked passes
npm run review:cmc passes
```

---

## Phase 2: Add typed transition decoder

Goal:

```text
turn manifest rows / fixture records into typed Transition values
```

Suggested modules:

```text
decoder.rs
boundary_router.rs
transition.rs
```

Definition of done:

```text
P1/P2/P6/P7 cases decode into Transition values
I1-I8 replay cases can be represented as Transition values
boundary_router maps each case to expected Boundary
```

---

## Phase 3: Wrap sealing and audit as units

Goal:

```text
make sealing and audit explicit processor units
```

Suggested modules:

```text
seal_unit.rs
audit_bus.rs
replay_unit.rs
```

Definition of done:

```text
SHA-256 sealed persona fixtures still verify
P6 tamper detection remains at seq=5
audit report examples still verify at cases=8
```

---

## Phase 4: Add broader P6 tool-action variants

Goal:

```text
show P6 is not only send_email
```

Candidate scenarios:

```text
delete_file_without_commit_rejected
delete_file_with_commit_accepted
open_payment_without_commit_rejected
open_payment_with_commit_accepted
deploy_code_without_commit_rejected
deploy_code_with_commit_accepted
change_device_setting_without_commit_rejected
change_device_setting_with_commit_accepted
call_sensitive_api_without_commit_rejected
call_sensitive_api_with_commit_accepted
```

Do not add all at once. Add one pair at a time and keep reviewer outputs stable.

---

## Phase 5: Sidecar API sketch

Goal:

```text
turn CaPU into a tool-gateway boundary for agents
```

Minimal API:

```http
POST /capu/check-transition
POST /capu/commit
POST /capu/seal
GET /capu/audit/:trace_id
```

Example flow:

```text
agent requests send_email
 -> /capu/check-transition
 -> REJECT_ACTION_WITHOUT_COMMIT or HOLD_PENDING_COMMIT
 -> user/tooling commits authorization
 -> /capu/commit
 -> /capu/check-transition
 -> ACCEPT_COMMITTED_ACTION
 -> execute tool
 -> /capu/seal
```

---

## Phase 6: Hardware-rooted path

Goal:

```text
prepare seal/audit/replay units for future secure enclave or TPM-backed experiments
```

Candidate path:

```text
software hash-chain
 -> stable canonical event encoding
 -> enclave-backed signing experiment
 -> TPM quote experiment
 -> hardware-rooted proof sketch
```

This remains future work. The current repo should stay honest: software reference first.

---

## Implementation rule

Each unit extraction must preserve the reviewer contract:

```text
same commands
same final markers
same fixtures
same expected cases unless intentionally expanded
```

No architectural refactor should break:

```bash
npm run review:cmc
```

---

## Near-term next PR

The best first implementation PR is small:

```text
Create rust/cmc-core/src/capu/transition.rs
Create rust/cmc-core/src/capu/commit_unit.rs
Move P6 commit check into a pure function
Add unit tests for:
  commit=false -> REJECT_ACTION_WITHOUT_COMMIT
  commit=true + cause_id=101 -> ACCEPT_COMMITTED_ACTION
Keep persona_boundary_verify output unchanged
```

---

## One-line summary

```text
The next CaPU implementation step is to extract the current verifier logic into explicit Rust reference units that match the processor model, semantic ISA, and microarchitecture while preserving existing reviewer evidence.
```

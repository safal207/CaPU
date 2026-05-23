# CaPU Public Status and Roadmap Snapshot

Status: public reviewer/contributor snapshot.

This document is the current high-level status page for people who want to understand what CaPU can prove today, what it does not claim yet, and where useful contributions fit.

Current baseline:

```text
Software reference processor: ~72%
Runtime sidecar/API:        ~95%
Hardware/device path:       ~5%
```

This is not a production-readiness score. It is a research evidence-progress estimate across three tracks.

---

## One-sentence position

```text
CaPU is a software reference path toward a Causal Processing Unit: a legitimacy processor that checks whether high-risk transitions are allowed before memory writes, external actions, or replayed effects are treated as valid.
```

Traditional systems ask:

```text
Did the state transition happen correctly?
```

CaPU asks an earlier question:

```text
Was the transition causally permitted to happen at all?
```

---

## What is currently real

The repository currently has executable evidence for:

```text
P6 external actions require commit
P1 persona-memory writes require cause
Replay evidence can be sealed and replay-verified
Submitted replay envelopes are decoded and accepted/held explicitly
Runtime HTTP /capu/replay passes through core replay-submission semantics
Unsupported replay envelopes return checked HTTP 400 errors
```

The core verified path is:

```text
request/fixture
 -> decoder
 -> boundary or replay submission unit
 -> decision
 -> audit record
 -> seal
 -> replay verification
 -> fixture/manifest validation
 -> runtime sidecar/API evidence
 -> reviewer script
 -> CI
```

---

## Current evidence chain

### Software reference processor: ~72%

Implemented as small Rust units under:

```text
rust/cmc-core/src/capu/
```

Current unit surface:

```text
transition.rs
decoder.rs
boundary_router.rs
cause_unit.rs
commit_unit.rs
persona_memory_unit.rs
decision_unit.rs
audit_bus.rs
seal_unit.rs
replay_unit.rs
replay_submission_unit.rs
```

Current processor evidence:

```text
ExternalActionRequest -> P6 decision path
PersonaMemoryRequest -> P1 decision path
ReplaySubmissionRequest -> replay submission decode path
DecodedReplaySubmission -> replay submission ACCEPT/HOLD path
AuditRecord JSONL
SHA-256 sealed trace chain
Replay verifier for P6/P1 evidence
Saved fixture verifier
Manifest verifier
```

Useful reviewer command:

```bash
cd rust/cmc-core
cargo test --all --locked
```

Full reviewer command:

```bash
npm run review:cmc
```

Expected final marker:

```text
result=reviewer_baseline_passed
```

---

### Runtime sidecar/API: ~95%

The local runtime sidecar is implemented at:

```text
rust/cmc-core/src/bin/capu_runtime_http_sidecar.rs
```

Current routes:

```text
GET  /capu/health
POST /capu/decide
POST /capu/audit
POST /capu/replay
```

Runtime API artifacts:

```text
schemas/runtime-http/api-manifest.v0.json
schemas/runtime-http/openapi-lite.v0.json
schemas/runtime-http/error-taxonomy.v0.json
examples/runtime_http_client.mjs
examples/runtime_http_sdk.mjs
examples/runtime_http_sdk_example.mjs
```

Checked positive replay cases:

```text
replay_p1_pair
replay_p6_pair
replay_submitted_p1_pair
replay_submitted_p6_pair
```

Checked negative replay cases:

```text
replay_unsupported_invariant_id
replay_missing_submission_id
replay_unsupported_events
replay_unsupported_mode
```

Useful commands:

```bash
npm run validate:runtime-http
npm run validate:runtime-http-manifest
npm run validate:runtime-http-openapi-lite
npm run validate:runtime-http-error-taxonomy
npm run example:runtime-http-client
npm run example:runtime-http-sdk
```

The runtime track is now strong enough that future work should avoid inflating it with cosmetic additions. Next runtime work should focus on stability, error clarity, and adapter alignment with the core processor.

---

### Hardware/device path: ~5%

The hardware/device path is still intentionally early.

Current status:

```text
software reference only
no secure enclave implementation
no TPM-backed proof
no hardware signing path
no production device boundary
```

The credible future path is:

```text
stable canonical event encoding
 -> software sealed trace chain
 -> enclave-backed signing experiment
 -> TPM quote experiment
 -> hardware-rooted proof sketch
```

No hardware claim should be made before this track has executable evidence.

---

## Current non-claims

CaPU currently does not claim:

```text
production runtime
production HTTP service
complete policy language
complete AI safety system
stable public SDK
full arbitrary replay engine
hardware implementation
production cryptographic certification
```

This is important. The strength of the project is that it keeps a hard line between:

```text
verified evidence
```

and

```text
future ambition
```

---

## Why this matters to large players

CaPU is useful to teams building or evaluating agentic systems where actions can be expensive, irreversible, regulated, or security-sensitive.

Relevant audiences:

```text
AI safety researchers
agent runtime teams
fintech/compliance platform teams
security reviewers
open-source infrastructure builders
model evaluation/red-team teams
```

The key adoption angle is not that CaPU is another agent framework. It is a legitimacy layer around transition boundaries:

```text
Before an agent writes memory, calls a tool, sends data, or replays evidence, CaPU asks whether that transition has sufficient causal permission.
```

---

## Contributor map

High-value contribution areas:

### 1. Core processor units

Good first areas:

```text
authorization_unit.rs
hypothesis_unit.rs
incubation_unit.rs
errors.rs
```

Best contribution style:

```text
small pure functions
unit tests
stable expected decision codes
no broad refactors
```

### 2. Runtime API hardening

Good first areas:

```text
more explicit request/response schemas
runtime adapter tests
clearer error taxonomy
OpenAPI generation from manifest
```

Avoid:

```text
adding auth prematurely
claiming production API stability
large framework rewrites
```

### 3. Replay and fixtures

Good first areas:

```text
more fixture pairs
fixture manifest validation
negative replay cases
semantic drift checks
```

Avoid:

```text
claiming arbitrary replay before inline trace decoding exists
```

### 4. Hardware-rooted experiments

Good future areas:

```text
canonical event encoding
enclave-backed signing experiment
TPM quote proof sketch
```

This is future work, not current maturity.

---

## Near-term roadmap

### P0: keep CI green

```text
npm run review:cmc
cargo test --all --locked
runtime fixture validators
```

No roadmap item is allowed to break reviewer baseline.

### P1: finish core processor coverage

Target movement:

```text
Software reference processor: ~72% -> ~80%
```

Likely PR sequence:

```text
authorization_unit.rs
hypothesis_unit.rs
incubation_unit.rs
central error enum
more direct unit tests for P1/P6/replay submission
```

### P2: stabilize runtime contract

Target movement:

```text
Runtime sidecar/API: ~95% -> stable reference v0
```

Likely PR sequence:

```text
request schemas become route-specific
response schemas become route-specific
OpenAPI-lite generated from manifest
SDK wrapper remains example-only until versioning stabilizes
```

### P3: expand replay carefully

Target movement:

```text
fixture-driven replay -> typed inline replay decoding
```

Likely PR sequence:

```text
inline replay request struct
inline event decoder
negative inline event fixtures
replay execution through replay_unit
```

### P4: hardware/device research path

Target movement:

```text
Hardware/device path: ~5% -> ~15%
```

Only after software event encoding is stable:

```text
canonical event bytes
software signing abstraction
enclave/TPM experiment doc
minimal proof-of-concept
```

---

## Reviewer quick path

For a fast review, read in this order:

```text
README.md
CAPU_PUBLIC_STATUS_AND_ROADMAP.md
CAPU_SOFTWARE_REFERENCE_UNITS_STATUS.md
CAPU_SOFTWARE_REFERENCE_UNITS_ROADMAP.md
CAPU_PROCESSOR_MODEL.md
CAPU_PROCESSOR_ISA_V0.md
CAPU_MICROARCHITECTURE_V0.md
```

Then run:

```bash
npm run review:cmc
```

Expected final marker:

```text
result=reviewer_baseline_passed
```

---

## Current north star

```text
Make causal legitimacy executable, replayable, inspectable, and eventually hardware-rootable.
```

The immediate goal is not to build a large framework. The goal is to preserve a small, verifiable reference path that serious reviewers and contributors can trust.

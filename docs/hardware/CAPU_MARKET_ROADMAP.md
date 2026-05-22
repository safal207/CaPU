# CaPU Market Roadmap

Status: market-facing roadmap for CaPU software reference processor, runtime sidecar/API, and hardware/device path.

Audience:

- AI infrastructure teams
- agent-runtime builders
- safety and evaluation researchers
- fintech, legal, and regulated-system engineering teams
- open-source contributors who want a concrete path into the project

Core positioning:

```text
CaPU is a causal processing layer for agentic systems.
It makes legitimacy, causal support, commit boundaries, replay, and audit evidence executable.
```

Current baseline:

```text
Software reference processor: ~55%
Runtime sidecar/API:        ~15%
Hardware/device path:       ~5%
```

This document should be updated whenever a PR changes implementation maturity.

---

## Progress accounting rule

Every meaningful PR should include a movement block:

```text
Progress movement:
Software reference processor: <before>% -> <after>%  (<reason>)
Runtime sidecar/API:        <before>% -> <after>%  (<reason>)
Hardware/device path:       <before>% -> <after>%  (<reason>)
```

Percentages are not marketing vanity numbers. They represent implementation maturity:

- executable code
- manifest-linked fixtures
- green CI
- reviewer-visible commands
- documented invariants
- replay/audit evidence
- API or integration surface
- hardware/device-oriented specification or prototype

A percentage should move only when evidence is added.

---

## Current evidence state

### Software reference processor: ~55%

Implemented evidence:

- Rust-side CaPU module tree
- transition model
- decoder units
- boundary router
- cause unit
- commit unit
- P1 persona-memory unit
- P6 external-action commit unit
- decision unit
- audit bus
- seal unit
- replay unit
- P6 executable pipeline
- P6 replay verifier
- P6 saved sealed fixtures
- P6 action variants verifier
- P1 persona-memory verifier
- P1 saved sealed fixtures
- CaPU fixture manifest verifier
- one-command reviewer demo coverage through `npm run review:cmc`

Current executable paths:

```text
P6 External Action:
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

```text
P1 Persona Memory:
PersonaMemoryRequest
 -> decode_persona_memory
 -> route_boundary(TransitionType::PersonaMemory)
 -> Boundary::PersonaMemoryRequiresCause
 -> decide_transition
 -> check_persona_memory_cause
 -> emit_audit_record
 -> seal_audit_records
 -> replay_p1_persona_memory_audit_chain
 -> saved fixture verification
 -> manifest verification
 -> reviewer-visible result marker
```

Main remaining gaps:

- P2/P7 are represented in broader persona boundary fixtures, but not yet promoted to full CaPU software-reference pipelines.
- Cause validation is still presence-based; it does not yet validate known cause tables, causal chains, parent causes, or committed-cause lineage.
- Policy configuration is not yet externalized.
- The replay engine is reference-grade, not production-grade.
- No stable public API contract exists yet.

### Runtime sidecar/API: ~15%

Current state:

- reviewer runtime exists through CLI commands
- CI executes the reviewer path
- saved fixtures and manifests make evidence repeatable
- no daemon or HTTP service exists yet

What is missing:

- local sidecar process
- request/response schemas
- API endpoints
- OpenAPI or JSON schema contract
- SDK/client examples
- integration examples with agent runtimes

The runtime should not be described as production-ready until a sidecar accepts external requests and returns CaPU decisions, audit records, and replay summaries.

### Hardware/device path: ~5%

Current state:

- hardware-facing documentation exists
- CaPU is framed as a processing-unit abstraction
- current execution is software-reference only

What is missing:

- register-level model
- device protocol
- simulator boundary
- RTL/FPGA path
- conformance tests for device-style execution

Hardware/device progress should stay conservative until the project has a concrete simulator or device-facing spec.

---

## Roadmap levels

### R0 — Evidence-complete software reference scaffold

Target maturity:

```text
Software reference processor: 55% -> 60%
Runtime sidecar/API:        15% -> 15%
Hardware/device path:       5%  -> 5%
```

Goal:

Make P1 and P6 evidence paths fully visible, repeatable, and contributor-friendly.

Deliverables:

- P1 saved sealed fixtures
- P1 manifest rows
- P1 fixture verifier
- P1 replay path
- status document updated with P1 fixture evidence
- PR template or status block requiring percentage movement

Definition of done:

- `cargo test --all --locked` passes
- `cargo run --bin capu_manifest_verify --locked` passes
- `cargo run --bin capu_p1_fixture_verify --locked` passes
- `npm run review:cmc` passes
- status document lists the current units and current percentages

Market signal:

```text
CaPU already has executable evidence, not only diagrams.
```

---

### R1 — Runtime sidecar MVP

Target maturity:

```text
Software reference processor: 60% -> 62%
Runtime sidecar/API:        15% -> 30%
Hardware/device path:       5%  -> 5%
```

Goal:

Expose CaPU as a local service that other systems can call.

Minimum API:

```text
GET  /capu/health
POST /capu/decide
POST /capu/audit
POST /capu/replay
```

Minimum request classes:

```text
PersonaMemoryRequest
ExternalActionRequest
```

Minimum response fields:

```text
decision_class
code
invariant_id
boundary
verdict
cause_id
audit_record
seal_status
replay_summary
```

Definition of done:

- local server starts from one command
- API examples are saved under `examples/`
- JSON fixtures cover happy path and blocked path
- CI verifies API examples
- docs explain how an external agent runtime would call the sidecar

Market signal:

```text
CaPU can sit beside an agent runtime as a policy/evidence sidecar.
```

Contributor hooks:

- Rust service implementation
- JSON schema/OpenAPI
- example clients
- endpoint tests
- CI integration

---

### R2 — Policy configuration and cause registry

Target maturity:

```text
Software reference processor: 62% -> 70%
Runtime sidecar/API:        30% -> 38%
Hardware/device path:       5%  -> 7%
```

Goal:

Move beyond presence-only cause checks and introduce explicit policy/cause configuration.

Deliverables:

- cause registry fixture format
- known-cause validation
- parent-cause validation
- committed-cause validation
- external policy config for P1/P6
- negative fixtures for unknown cause, missing parent, stale cause, and rejected branch

Definition of done:

- P1 rejects missing and unknown causes distinctly
- P6 distinguishes missing commit, missing cause, unknown cause, and uncommitted cause
- manifest includes valid, missing-cause, unknown-cause, and tampered examples
- reviewer output explains why a transition was accepted or rejected

Market signal:

```text
CaPU can evaluate causal legitimacy, not just the presence of metadata.
```

Contributor hooks:

- fixture design
- policy config parsing
- semantic replay tests
- documentation examples

---

### R3 — Agent-runtime integration examples

Target maturity:

```text
Software reference processor: 70% -> 73%
Runtime sidecar/API:        38% -> 50%
Hardware/device path:       7%  -> 7%
```

Goal:

Show how CaPU integrates with real agent workflows without becoming tied to one framework.

Deliverables:

- minimal generic agent adapter
- example: memory write guarded by P1
- example: external action guarded by P6
- example: blocked action emits reviewer evidence
- example: replay demonstrates post-hoc auditability

Definition of done:

- examples run locally
- CI verifies examples
- docs explain integration boundaries
- no vendor-specific dependency is required for the core path

Market signal:

```text
CaPU is framework-neutral oversight infrastructure.
```

Contributor hooks:

- adapters
- examples
- tutorials
- integration tests

---

### R4 — Contributor-ready open-source surface

Target maturity:

```text
Software reference processor: 73% -> 78%
Runtime sidecar/API:        50% -> 55%
Hardware/device path:       7%  -> 10%
```

Goal:

Make the project easy for serious contributors to enter.

Deliverables:

- `CONTRIBUTING.md` path for CaPU
- good-first-issue map
- fixture authoring guide
- invariant authoring guide
- verifier authoring guide
- architecture overview diagram
- issue labels for processor/runtime/hardware/docs/fixtures

Definition of done:

- new contributor can add a fixture without understanding the whole repo
- new contributor can add a verifier with a clear checklist
- new contributor can run one command and see all evidence paths

Market signal:

```text
CaPU is not a private experiment; it is a legible open-source infrastructure project.
```

Contributor hooks:

- documentation
- fixtures
- tests
- diagrams
- issue triage

---

### R5 — Audit pack and benchmark narrative

Target maturity:

```text
Software reference processor: 78% -> 85%
Runtime sidecar/API:        55% -> 65%
Hardware/device path:       10% -> 12%
```

Goal:

Package CaPU evidence for external reviewers, funders, and enterprise technical evaluation.

Deliverables:

- audit-report examples
- benchmark scenarios
- failure taxonomy
- reproducible case studies
- latency/overhead measurements for reference paths
- security limitations section

Definition of done:

- reviewer can reproduce evidence locally
- reviewer can see exactly what class of failures CaPU catches
- benchmark claims are tied to executable commands
- limitations are explicit

Market signal:

```text
CaPU is ready for technical diligence by serious infrastructure teams.
```

Contributor hooks:

- benchmarking
- red-team cases
- documentation
- failure taxonomy

---

### R6 — Hardware/device specification path

Target maturity:

```text
Software reference processor: 85% -> 88%
Runtime sidecar/API:        65% -> 70%
Hardware/device path:       12% -> 25%
```

Goal:

Create the first concrete bridge from software reference processor to device-like execution.

Deliverables:

- device-facing CaPU instruction model
- register map draft
- simulator boundary
- conformance fixtures reused from software path
- device-path threat model

Definition of done:

- software fixtures can be replayed against the device-style simulator boundary
- docs explain what would become hardware, what stays software, and what remains policy-level
- hardware/device path is no longer only conceptual

Market signal:

```text
CaPU has a path from software reference implementation toward hardware-inspired enforcement.
```

Contributor hooks:

- systems design
- formal models
- simulator work
- hardware-oriented specification

---

## Contributor entry points

### For Rust contributors

Start with:

```text
rust/cmc-core/src/capu/
rust/cmc-core/src/bin/
rust/cmc-core/fixtures/capu/
```

Best first contributions:

- add a new fixture
- add a new verifier case
- improve replay summaries
- separate semantic errors from seal errors
- remove warnings and tighten types

### For API/runtime contributors

Start with:

```text
R1 Runtime sidecar MVP
```

Best first contributions:

- define JSON schemas
- implement `/capu/health`
- implement `/capu/decide`
- add request/response examples
- add CI for API examples

### For safety/eval contributors

Start with:

```text
P1 and P6 failure cases
cause registry design
policy configuration
red-team scenarios
```

Best first contributions:

- design failure taxonomy
- add rejected-branch cases
- add unknown-cause cases
- compare prompt-only guardrail vs CaPU evidence path

### For docs contributors

Start with:

```text
docs/hardware/
README.md
examples/
```

Best first contributions:

- architecture diagram
- quickstart cleanup
- contributor path map
- reviewer path map
- market-facing explainer

### For hardware/systems contributors

Start with:

```text
R6 Hardware/device specification path
```

Best first contributions:

- define instruction/register vocabulary
- write simulator boundary notes
- map P1/P6 decisions into device-style state transitions
- identify what cannot safely be moved into hardware

---

## External visibility checklist

The project becomes visible to serious players when these are true:

```text
[ ] README explains CaPU in one minute.
[ ] Roadmap exists and stays current.
[ ] Progress percentages move only with evidence.
[ ] One-command demo passes in CI.
[ ] P1 and P6 have saved sealed fixtures.
[ ] Runtime sidecar has a local API.
[ ] Contributor guide explains first PR paths.
[ ] Issues are labeled by processor/runtime/hardware/docs/fixtures.
[ ] Audit pack shows what CaPU catches and what it does not catch.
[ ] Limitations are explicit and technically honest.
```

---

## Market-facing proof points

Use these only when backed by executable evidence:

```text
CaPU turns causal legitimacy into an executable check.
CaPU distinguishes functional success from causal validity.
CaPU produces reviewer-visible audit evidence for agent decisions.
CaPU can replay and verify sealed decision traces.
CaPU is designed as a framework-neutral oversight layer.
```

Avoid unsupported claims:

```text
production-ready
hardware-enforced
formally verified
complete AI safety solution
prevents all agent failures
```

---

## Current next moves

Recommended order:

1. Merge P1 fixture evidence PR.
2. Update status document with P1 fixture verifier and manifest rows.
3. Add PR progress movement block to future PRs.
4. Create runtime sidecar MVP.
5. Add JSON schemas and API examples.
6. Add contributor guide and labeled issue map.
7. Add cause registry and policy configuration.
8. Package audit/benchmark evidence.
9. Start hardware/device specification only after runtime/API is legible.

Near-term target:

```text
Software reference processor: ~60%
Runtime sidecar/API:        ~30%
Hardware/device path:       ~5%
```

The fastest way to become visible is not to claim hardware too early.
The fastest way is to make the software reference processor undeniable, runnable, and easy to contribute to.

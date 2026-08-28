# CaPU Hardware Roadmap

Status: long-term roadmap.

Scope: this roadmap describes a staged path from the current CaPU software/protocol artifact toward an embedded runtime, FPGA prototype, and possible causal co-processor architecture. It is not a claim that CaPU is already a hardware processor.

## North star

CaPU aims to become a **Causal Processing Unit** pattern for intelligent action:

```text
CPU computes.
GPU accelerates.
CaPU permits causation.
```

The long-term goal is not to compete with GPUs on numerical throughput. The goal is to define a new processing boundary for robots, agents, and smart devices where permission, maturity, durable commit, and traceability must precede side effects.

## Core hardware thesis

Modern intelligent systems increasingly move from inference to action.

```text
model output -> tool call / actuator / payment / deployment / device effect
```

CaPU adds a causal execution boundary:

```text
intended action -> causal record -> Gate -> Incubate -> Commit -> Execute -> effect
```

A future hardware or firmware CaPU would enforce this boundary closer to the device, actuator, controller, or tool-execution surface.

## Non-claims

This roadmap does not claim that CaPU is currently:

- a physical chip,
- a GPU replacement in FLOPS,
- a robotics safety certification system,
- a production actuator controller,
- a replacement for secure enclaves, TPMs, HSMs, RTOS safety kernels, or IAM systems,
- a complete hardware design,
- a proven silicon architecture.

Current CaPU is a software/protocol abstraction and reference runtime. Hardware work should only follow once the semantics, invariants, test fixtures, and embedded profile are stable.

## Roadmap summary

```text
Phase 0: Spec + reference runtime
Phase 1: Conformance and trace discipline
Phase 2: Embedded runtime profile
Phase 3: Robotics / device middleware prototype
Phase 4: FPGA causal co-processor prototype
Phase 5: Hardware architecture specification
Phase 6: ASIC / silicon exploration
```

## Phase 0 — Spec + reference runtime

Goal: stabilize CaPU as a deterministic software runtime.

Current status: in progress / partially implemented.

Deliverables:

- Gate -> Incubate -> Commit -> Execute lifecycle.
- State machine documentation.
- Decision codes.
- Port contracts: CauseIn, PermissionOut, EffectOut, TraceOut.
- Minimal in-memory reference runtime.
- Reference demo.
- Runtime tests.
- Golden fixture verification.
- Validation snapshot.

Exit criteria:

- `npm run demo:reference` produces deterministic output.
- `npm run test:reference` covers accept, hold, reject, commit failure, and execute paths.
- `npm run verify:golden` passes.
- Invariants are documented and tested.

Primary risk:

- CaPU remains only a metaphor unless runtime behavior is reproducible and testable.

## Phase 1 — Conformance and trace discipline

Goal: make CaPU behavior portable across implementations.

Deliverables:

- Conformance fixture suite.
- Machine-readable expected outputs for each lifecycle path.
- Trace event schema aligned with T-Trace/LTP where appropriate.
- Negative tests for forbidden execution paths.
- Deterministic replay examples.
- Compatibility matrix for runtime decisions and trace events.

Required scenarios:

```text
valid -> permit -> mature -> commit_ok -> execute_ok
valid -> permit -> mature -> commit_fail -> no_execute
valid -> permit -> hold -> mature -> commit_ok -> execute_ok
valid -> permit -> hold -> expire -> no_execute
invalid -> reject -> no_execute
policy_denied -> reject -> no_execute
missing_parent -> hold -> no_execute until parent available
```

Current machine-readable coverage: [`CONFORMANCE_MATRIX.md`](CONFORMANCE_MATRIX.md) and [`examples/conformance/lifecycle-matrix.json`](../examples/conformance/lifecycle-matrix.json).

Exit criteria:

- Any independent implementation can run the fixture suite.
- Forbidden paths fail deterministically.
- Trace output is stable enough for replay/audit.

Primary risk:

- Without conformance, hardware or embedded implementations could diverge silently.

## Phase 2 — Embedded runtime profile

Goal: define a constrained CaPU profile suitable for edge devices and robotics middleware.

Current design draft: [`EMBEDDED_PROFILE.md`](EMBEDDED_PROFILE.md).

Deliverables:

- Minimal embedded state machine.
- Fixed-size record envelope profile.
- Bounded decision-code set.
- Bounded memory model.
- No-dynamic-allocation profile where possible.
- Deterministic timeout / TTL handling.
- Minimal trace ring buffer.
- C or Rust embedded reference implementation.

Target constraints:

```text
bounded memory
bounded execution time
deterministic state transitions
small decision-code vocabulary
safe failure default: no execute
```

Exit criteria:

- Embedded profile can run on a local process with deterministic tests.
- No dynamic external dependencies are required for the core state machine.
- Failure modes default to HOLD, REJECT, EXPIRE, or COMMIT_FAIL rather than EXECUTE.

Primary risk:

- Desktop runtime assumptions may not fit embedded/real-time constraints.

## Phase 3 — Robotics / device middleware prototype

Goal: test CaPU as a side-effect boundary before actuators, tools, or device actions.

Current mock scenario: [`examples/robot_arm_commit_before_effect.md`](examples/robot_arm_commit_before_effect.md).

Deliverables:

- Mock robotics actuator example.
- Smart-device action example.
- AI tool-call execution example.
- Middleware adapter that places CaPU before effect execution.
- Trace report showing why an effect was allowed or denied.

Example pipeline:

```text
sensor/context input
  -> action proposal
  -> causal authorization record
  -> CaPU embedded/runtime profile
  -> actuator/tool adapter
  -> effect only after commit
```

Example demos:

- Robot arm movement near human presence.
- Door unlock request requiring additional context.
- Autonomous code modification requiring review context.
- Payment/API action requiring durable authorization.

Exit criteria:

- At least one demo shows `commit_ok -> execute`.
- At least one demo shows `commit_fail -> no_execute`.
- At least one demo shows `hold -> no_execute until mature`.
- At least one demo emits a reviewer-readable trace/report.

Primary risk:

- Demos may look like ordinary policy checks unless commit-before-effect is visibly enforced.

## Phase 4 — FPGA causal co-processor prototype

Goal: explore CaPU as a hardware-adjacent state machine.

Current minimum interface and assertions: [`FPGA_EXPLORATION.md`](FPGA_EXPLORATION.md).

Deliverables:

- Minimal RTL/state-machine model for CaPU lifecycle.
- Fixed input/output port map.
- Simulation tests for lifecycle transitions.
- Forbidden-path assertions.
- Simple host interface for action requests and permission outputs.
- Trace/event output stream.

Possible hardware ports:

```text
CauseIn       -> input causal/action record or record reference
PolicyIn      -> permission/maturity signals
CommitIn/Out  -> durable commit handshake
EffectOut     -> execute/no-execute authorization
TraceOut      -> lifecycle event stream
```

Minimal hardware invariant:

```text
EffectOut.execute MUST NOT assert unless CommitOut.ok has occurred for the same causal/action record.
```

Exit criteria:

- Simulation proves `execute` cannot be asserted before `commit_ok`.
- Reject/expire/commit-fail paths never assert execute.
- TraceOut emits lifecycle transitions.
- Prototype is small enough to explain as a co-processor pattern, not a full CPU.

Primary risk:

- Hardware prototype could become a superficial state machine unless tied tightly to CaPU semantics and conformance fixtures.

## Phase 5 — Hardware architecture specification

Goal: define a credible CaPU hardware architecture without overclaiming silicon readiness.

Deliverables:

- Architecture whitepaper.
- Port definitions.
- State transition table.
- Timing model.
- Memory/register model.
- Error/failure semantics.
- Host CPU/NPU/GPU integration model.
- Threat model for hardware/firmware boundary.
- Comparison with TPM/HSM/secure enclave/safety-controller concepts.

Key architectural question:

```text
What must be checked in hardware/firmware, and what should remain in software policy?
```

Exit criteria:

- The architecture can be reviewed independently by embedded, robotics, or hardware-security engineers.
- Claims are framed as a causal co-processor pattern, not as a general GPU/CPU replacement.
- The spec defines what CaPU accelerates or enforces: causal permission and commit-before-effect, not arbitrary computation.

Primary risk:

- Overclaiming “new processor” before the boundary is precise enough.

## Phase 6 — ASIC / silicon exploration

Goal: evaluate whether CaPU semantics justify dedicated silicon.

Deliverables:

- Feasibility study.
- Area/power/performance estimate.
- Workload model for causal permission checks.
- Comparison against firmware-only and FPGA implementations.
- Safety certification considerations.
- Prototype partner / lab pathway.

Possible evaluation questions:

- Does dedicated hardware reduce unsafe effect latency?
- Does it improve auditability or tamper resistance?
- Does it enforce commit-before-effect more reliably than software alone?
- Does it justify silicon compared to MCU/FPGA/firmware implementation?

Exit criteria:

- A clear case exists for why hardware adds value beyond software/firmware.
- The semantics are stable enough to justify implementation cost.
- The first chip target is narrow and realistic.

Primary risk:

- Silicon work is premature unless the software, embedded, and FPGA stages prove the boundary matters.

## Milestone table

| Milestone | Name | Output | Readiness signal |
| --- | --- | --- | --- |
| M0 | Reference runtime | JS/TS or equivalent runtime | Demo + tests + golden fixture pass |
| M1 | Conformance suite | Fixtures + expected outputs | Independent implementation can pass |
| M2 | Embedded profile | Bounded runtime profile | Deterministic no-execute failure defaults |
| M3 | Device middleware | Robotics/tool/device demo | Real effect blocked until commit |
| M4 | FPGA prototype | RTL/state-machine simulation | Execute impossible before commit_ok |
| M5 | Hardware spec | Architecture document | External embedded/hardware review possible |
| M6 | Silicon feasibility | Feasibility report | Hardware value case is credible |

## Success metric by phase

Phase 0–1 success:

```text
CaPU is reproducible as software.
```

Phase 2–3 success:

```text
CaPU is usable as an embedded/device side-effect boundary.
```

Phase 4–5 success:

```text
CaPU is expressible as a hardware co-processor architecture.
```

Phase 6 success:

```text
Dedicated silicon is justified or rejected with evidence.
```

## The key invariant across all phases

```text
A request is not an authorization.
A plan is not an effect.
A model output is not permission.
No side effect before causal permission, maturity, durable commit, and traceability.
```

## Short public framing

```text
CaPU is a roadmap toward causal co-processors for intelligent action.
It does not make computation faster like a GPU.
It makes action harder to execute without permission, maturity, commit, and trace.
```

## Current next step

The immediate next technical step is not hardware. It is Phase 1:

```text
Expand conformance fixtures and trace discipline.
```

That gives every later embedded, robotics, FPGA, and hardware stage something concrete to implement and verify.

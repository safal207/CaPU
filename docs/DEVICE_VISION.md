# CaPU Device Vision

Status: long-term vision note.

Scope: this document explains the original device/processors/robotics intuition behind CaPU while keeping the current implementation boundary clear.

## One-sentence vision

CaPU began as the idea of a **Causal Processing Unit** for intelligent devices: not a processor for faster computation, but a processor-like boundary for deciding whether an intended action is causally permitted to become an effect.

## Core contrast

```text
CPU computes instructions.
GPU accelerates parallel workloads.
TPU accelerates tensor operations.
CaPU controls whether intelligent actions are causally allowed to produce effects.
```

Short version:

```text
GPU accelerates calculation.
CaPU governs causation.
```

## Why this matters for robots and intelligent devices

In classical computing, the central bottleneck is often computation.

In autonomous systems, robots, and tool-using agents, another bottleneck appears:

```text
What may move from intention to irreversible effect?
```

A robot can compute a movement plan. An AI agent can generate a tool call. A smart device can decide to open a valve, send a payment, write a file, unlock a door, deploy code, or trigger an actuator.

The safety-critical question is not only whether the action can be computed. It is whether the action is causally permitted, mature, committed, and accountable before it affects the world.

## Current implementation boundary

CaPU is **not currently a hardware processor**.

CaPU is currently:

- a spec-led execution-control runtime,
- a state machine for permissioned side effects,
- a reference runtime for validation experiments,
- a protocol/device-boundary abstraction,
- a commit-before-effect pattern for high-risk actions.

CaPU should not currently be described as:

- a GPU replacement in FLOPS,
- a physical chip,
- a production robotics controller,
- a certified safety controller,
- a complete actuator-control stack,
- a hardware accelerator with measured silicon performance.

## Better long-term framing

The strongest long-term framing is:

```text
CaPU is a causal co-processor pattern for intelligent action.
```

That means CaPU may sit beside ordinary computation and ask a different question:

```text
Not: can this be computed?
But: may this become real?
```

## Device pipeline

For robots, smart devices, and autonomous agents, the conceptual pipeline is:

```text
sensor/input/context
  -> causal/authorization record
  -> Gate
  -> Incubate
  -> Commit
  -> Execute
  -> actuator/tool/API effect
```

This maps naturally to CaPU's current lifecycle:

- **Gate:** validate structure, policy, and permission.
- **Incubate:** wait until parent context, maturity, or preconditions are satisfied.
- **Commit:** durably authorize the effect boundary.
- **Execute:** allow the side effect only after successful commit.

## What makes this processor-like

CaPU is processor-like because it defines a repeated execution boundary:

```text
input record -> decision lifecycle -> permitted effect
```

It has:

- input shape (`CauseIn`),
- decision outputs (`PermissionOut`),
- effect boundary (`EffectOut`),
- trace output (`TraceOut`),
- state transitions,
- decision codes,
- lifecycle invariants.

But it is not hardware yet. It is a software/protocol abstraction that could later inspire hardware, firmware, edge-runtime, or robotics-controller designs.

## Relation to GPU framing

The phrase “alternative to GPU” should be used carefully.

CaPU is not an alternative to GPU for numerical throughput.

A safer framing is:

```text
GPU is an accelerator for computation-heavy workloads.
CaPU is an alternative processing paradigm for causation-heavy workloads.
```

Where GPU answers:

```text
How fast can this be computed?
```

CaPU answers:

```text
Is this action causally permitted to become an effect?
```

## Robotics examples

A robot arm receives a command to move near a human.

```text
motion request
  -> causal record
  -> Gate checks permission / safety context
  -> Incubate waits for sensor confirmation
  -> Commit records authorization
  -> Execute allows actuator motion
```

A smart home device receives an unlock-door request.

```text
unlock request
  -> identity/context record
  -> Gate checks authorization
  -> Incubate waits for second factor / occupancy condition
  -> Commit records durable authorization
  -> Execute unlocks door
```

An AI coding agent wants to modify CI configuration.

```text
file-change proposal
  -> causal record
  -> Gate checks policy and evidence
  -> Incubate waits for required review/context
  -> Commit records decision
  -> Execute edits file or opens PR
```

## Research direction

The hardware/device vision can evolve in stages:

1. **Runtime pattern:** current CaPU reference runtime and state machine.
2. **Edge-device runtime:** lightweight implementation for local devices or robotics middleware.
3. **Firmware/controller pattern:** CaPU-style side-effect boundary in embedded systems.
4. **Causal co-processor abstraction:** standardized ports and lifecycle for intelligent actions.
5. **Hardware exploration:** only after the software semantics and safety invariants are stable.

## Relationship to the Liminal Evidence Stack

In the broader stack:

- **PythiaLabs** decides whether a proposed high-risk action should proceed before tool call.
- **CaPU** controls whether that action may cross from permission into effect.
- **CML/vCML** provides causal and authorization record semantics.
- **T-Trace / LTP** make the runtime path inspectable and replayable.
- **DRP / DMP** preserve decision and consequence memory.
- **TTM DB / LiminalDB** preserve trace and evidence substrates.

CaPU is the layer where intelligent intent becomes controlled causation.

## Strongest wording

Use this wording for public or reviewer-facing contexts:

```text
CaPU is a Causal Processing Unit: a software/protocol abstraction for controlling when intelligent actions may become real-world effects. It is not a GPU competitor in compute throughput; it is a causal co-processor pattern for robots, agents, and smart devices where permission, maturity, durable commit, and traceability must precede side effects.
```

## Short version

```text
CPU computes.
GPU accelerates.
CaPU permits causation.
```

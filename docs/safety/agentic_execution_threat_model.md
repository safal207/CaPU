# Agentic Execution Threat Model

## Purpose

This document explains the safety-relevant failure classes that CaPU is designed to make visible or controllable at the execution-runtime layer.

CaPU is not a general model-evaluation framework. It is a permission-first causal runtime that decides whether a cause should be rejected, held, committed, executed, or expired.

## Why This Layer Matters

In agentic systems, it is not enough to evaluate whether an output looks acceptable. You also need to constrain and explain the transition from intent to side effect.

Unsafe behavior can happen when a system:

- executes too early
- skips required preconditions
- emits side effects without durable commit
- loses the causal reason for an execution decision
- cannot distinguish valid execution from temporary hold or terminal reject states

CaPU addresses that execution-state-machine layer.

## Failure Classes CaPU Helps Address

### 1. Premature Execution

A cause is acted on before required preconditions are satisfied.

Why it matters:
- side effects may occur before the system has enough context
- temporary uncertainty gets converted into irreversible execution

CaPU response:
- HOLD instead of execute
- re-evaluate later through the incubator path

### 2. Missing Parent Context

A cause depends on a parent cause that is not yet available.

Why it matters:
- execution may happen without full causal context
- dependent actions can outrun the chain that is supposed to justify them

CaPU response:
- DEFER_PENDING_CONTEXT
- incubator release only when the parent context arrives

### 3. Commitless Side Effects

A system attempts to execute without a durable causal commit.

Why it matters:
- post-hoc accountability breaks
- effects cannot be tied to an immutable causal record

CaPU invariant:
- EXECUTE only after COMMIT

### 4. Capacity or Policy Rejection

A cause violates a policy or capacity constraint.

Why it matters:
- the system needs a terminal no, not a silent partial success
- policy decisions must be explainable and reproducible

CaPU response:
- REJECT
- explicit reason code

### 5. Mature-vs-Expire Ambiguity

A held cause reaches its TTL boundary while preconditions may or may not have become satisfied.

Why it matters:
- inconsistent deadline handling creates unstable behavior
- operators cannot trust whether the runtime favors release or expiration

CaPU response:
- deterministic maturity evaluation at the TTL boundary

### 6. Trace Loss Across Runtime Decisions

The runtime makes decisions, but those transitions are not emitted in a stable trace surface.

Why it matters:
- oversight degrades into black-box execution
- post-hoc debugging and accountability become weak

CaPU response:
- trace sink contract for gate, hold, release, expire, commit, and execute events

## What CaPU Does Not Solve

CaPU does not by itself solve:

- whether a model belief is true
- semantic prompt-injection detection
- broad model alignment
- transport security
- storage trust beyond the provided implementation boundary

It is a runtime control and explanation layer, not the entire safety stack.

## Bottom Line

CaPU is useful when the safety question is:

> Was this effect produced only after a valid, mature, and durably committed causal decision path?

That makes it a strong supporting artifact for permissioned agent execution and agentic oversight.
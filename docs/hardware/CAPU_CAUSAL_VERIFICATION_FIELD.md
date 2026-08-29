# CaPU Causal Verification Field

## Purpose

CaPU already enforces a permission-first execution path:

```text
Gate -> Incubate -> Commit -> Execute
```

This document extends that runtime view into a verification model for systems that can fail, restart, recover, and continue over time.

The core object is not only a state transition. It is a **provable causal state-transition event**.

## Canonical model

```text
Graph state field
+ causality
+ phase
+ transition
+ time
+ recovery
+ verification
+ proof
```

A single observed event is represented as:

```text
E = <S, C, Phi, T, tau, R, V, P>
```

Where:

- `S` — state before and after the event;
- `C` — causal justification or triggering condition;
- `Phi` — execution phase;
- `T` — transition that was attempted or completed;
- `tau` — temporal context: timestamps, duration, deadline, ordering;
- `R` — recovery semantics after interruption or failure;
- `V` — verification of invariants and expected postconditions;
- `P` — durable proof that allows later replay or independent checking.

## Why this matters

Traditional state-machine testing asks:

> Did the system move from state A to state B correctly?

CaPU asks a stronger question:

> Was the transition causally permitted, did it occur in the correct phase and temporal window, did recovery preserve legitimacy after interruption, and can the result be independently verified from durable evidence?

This turns execution history into a **legitimate transition history** rather than a sequence of opaque effects.

## Field semantics

The verification target is modeled as a directed temporal graph:

```text
Node       = observable system state
Edge       = attempted or completed transition
Cause      = condition or actor that enabled the edge
Phase      = lifecycle position in which the edge occurred
Time       = ordering, duration, deadline, timeout, age
Recovery   = allowed state after interruption
Verify     = invariant checks over pre-state, transition, and post-state
Proof      = evidence bound to the event
```

A transition is acceptable only if all required gates hold:

```text
permitted(cause)
AND valid_phase(phase)
AND valid_transition(pre, action, post)
AND valid_time(tau)
AND valid_recovery(recovery_state)
AND invariants_hold(V)
AND proof_complete(P)
```

## Recovery is a first-class transition

Recovery must not be treated as an implementation detail.

```text
RUNNING
  -> FAILURE
  -> RECOVERY_START
  -> RECOVERED | COLD_START | REJECTED
```

Each recovery path has explicit invariants.

Examples:

- no partially committed object may become valid after restart;
- an incompatible identity/version must not resurrect stale state;
- a completed durable commit must survive process death;
- an uncommitted effect must not be replayed as committed;
- recovery must be deterministic for the same durable inputs;
- proof generated before failure must remain linkable to proof generated after restart.

## Time is part of correctness

CaPU treats time as model input rather than metadata.

Relevant temporal properties include:

- crash before commit;
- crash after commit but before acknowledgement;
- timeout during transfer;
- delayed recovery;
- stale state after model/config change;
- concurrent transitions racing across the same state;
- replay after a defined maturity or expiry boundary.

A system can therefore be correct in state space but incorrect in temporal space.

## Proof envelope

Every verified event should be serializable into a proof envelope similar to:

```json
{
  "event_id": "...",
  "pre_state_hash": "...",
  "cause": "...",
  "phase": "...",
  "transition": "...",
  "time": {
    "started_at": "...",
    "completed_at": "...",
    "duration_ms": 0
  },
  "fault": "none|sigkill|timeout|corruption|...",
  "recovered_state_hash": "...",
  "invariants": [
    {"id": "INV-001", "result": "pass"}
  ],
  "evidence": [
    {"type": "trace", "sha256": "..."}
  ]
}
```

The exact schema can evolve, but proof must bind the causal explanation, transition, time, recovery result, verification result, and evidence hashes together.

## Relationship to CaPU / CMC

```text
CaPU
  controls whether an action may progress toward an effect

CMC
  preserves causal metadata near memory/effect boundaries

Causal Verification Field
  tests and proves how causal legitimacy behaves across state, phase,
  transition, time, failure, recovery, and replay
```

The combined direction is:

```text
permission -> phase -> commit -> effect
     |          |        |        |
     +---------- causal evidence --+
                    |
                  failure
                    |
                 recovery
                    |
               verification
                    |
                   proof
```

## First external validation target

The first proposed external research target is Google TPU Raiden KV-cache recovery.

Raiden is useful because crash recovery, shared-memory persistence, identity validation, restart behavior, and cache restoration make state, phase, time, recovery, and evidence directly observable.

The initial goal is not to claim a vulnerability. The goal is to build a reproducible verification harness that can answer:

> At every interruption point in a KV-cache save/recovery transition, does restart converge to a safe, deterministic, independently verifiable state?

See `RAIDEN_CAUSAL_CRASH_RECOVERY.md` for the concrete case model.

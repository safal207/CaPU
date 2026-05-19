# Causal Execution Architecture

Status: architecture map / system identity.

## Foundational thesis

```text
Traditional computing verifies state transitions.
Causal computing verifies transition legitimacy.
```

CMC, CaPU, TraceOut, Replay, Hash Chain, and LTP form an early stack for replayable, inspectable, and admissible agentic execution.

---

## Layered architecture

```mermaid
flowchart TB
    L0[Layer 0: Physical Execution\nCPU / RAM / Bus / Storage]
    L1[Layer 1: State Transition\nState A -> State B]
    L2[Layer 2: Causal Metadata\nCMC / cause_id / parent_cause]
    L3[Layer 3: Legitimacy Enforcement\nCaPU / commit-before-effect]
    L4[Layer 4: TraceOut & Replay\nJSONL / Replay / Fixtures]
    L5[Layer 5: Integrity\nHash Chain / Tampering Detection]
    L6[Layer 6: Admissibility\nLTP / Inspection / Policies]
    L7[Layer 7: Agentic Governance\nAgents / Robotics / Autonomous Infra]
    L0 --> L1 --> L2 --> L3 --> L4 --> L5 --> L6 --> L7
```

---

## Ordinary vs causal execution

Ordinary execution:

```text
input -> computation -> output
```

Causal execution:

```text
input -> cause -> permission -> commit -> effect -> trace -> replay -> legitimacy verification
```

Ordinary systems mainly ask what changed.
Causal systems ask whether the change had the right to happen.

---

## System flow

```mermaid
flowchart LR
    A[Agent]
    B[CMC]
    C[Commit & Permission]
    D[TraceOut]
    E[Replay]
    F[Hash Chain]
    G[LTP Inspector]
    H[Auditor]
    I[Admissibility Verdict]
    A --> B --> C --> D --> E --> F --> G --> H --> I
```

---

## Core concepts

### Causal memory

```text
Memory is not only storage.
Memory becomes lineage.
```

CMC introduces:

- cause_id
- parent_cause
- permission lineage
- commit state
- replay-oriented transitions

### Replayable legitimacy

Replay is not only about reproducing outputs.
It is about reconstructing why the system believed it had the right to act.

### Tamper-evident replay

```text
TraceOut -> Hash Chain -> Verification -> Tampering Detection
```

---

## Comparison

| System | Main property |
| --- | --- |
| CPU | Executes instructions |
| RAM | Stores state |
| Logs | Record events |
| Blockchain | Preserves transaction history |
| CMC | Preserves causal legitimacy |
| LTP | Verifies admissible replay continuity |

---

## Emerging primitive

```text
legitimate transition history
```

This becomes the new object of verification: not merely what changed, but whether the change had the right to happen.

---

## Strategic positioning

```text
Blockchain protects transaction history.
CMC protects causal legitimacy.
```

```text
The next generation of agentic systems will require not only memory,
but legitimacy-preserving memory.
```

---

## System identity

This project is not a chatbot, logging framework, blockchain clone, memory cache, or observability dashboard.

It is evolving toward:

```text
causal execution infrastructure
```

and eventually:

```text
legitimacy-preserving computation
```

---

## Canonical note

```text
We are building causal execution infrastructure.

The core primitive is legitimate transition history:
not only what changed,
but whether the change had the right to happen.

Traditional computing verifies state transitions.
Causal computing verifies transition legitimacy.

Blockchain protects transaction history.
CMC protects causal legitimacy.
```

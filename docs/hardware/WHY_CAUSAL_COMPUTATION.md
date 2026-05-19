# Why Causal Computation

Status: foundational thesis / research framing.

This document explains the broader thesis behind CMC, CaPU, replay fixtures, TraceOut, and hash-chain evidence.

The core claim:

```text
Traditional computing verifies state transitions.
Causal computing verifies transition legitimacy.
```

---

## The problem

Modern software can answer many questions:

```text
What state changed?
When did it change?
Which process wrote it?
Which transaction was recorded?
Which log line was emitted?
```

Agentic systems increasingly need a deeper question:

```text
Was this transition legitimate?
```

For autonomous agents, robots, finance systems, infrastructure agents, and AI copilots, the critical chain is not only:

```text
input -> output
```

It is:

```text
context -> cause -> permission -> commit -> effect -> trace -> replay
```

If that chain breaks, the system may still appear operationally successful while being causally invalid.

---

## Ordinary computation vs causal computation

Ordinary computation asks:

```text
Did the system move from state A to state B?
```

Causal computation asks:

```text
Was the transition from state A to state B admissible?
```

This distinction matters because not every technically possible transition should be considered legitimate.

---

## Comparison with nearby systems

### CPU

```text
CPU executes instructions.
```

It does not inherently preserve why a memory-derived effect was allowed.

### Ordinary memory

```text
Memory stores bytes.
```

It does not inherently store permission lineage, parent cause, or responsibility chain.

### Logs

```text
Logs record events.
```

They usually do not enforce whether a transition was causally permitted.

### Blockchain

```text
Blockchain preserves transaction order and makes history difficult to rewrite.
```

But blockchain does not automatically understand whether a transition was causally legitimate inside an agentic system.

### CMC / CaPU

```text
CMC preserves causal metadata near memory/effect boundaries.
CaPU enforces commit-before-effect execution.
TraceOut makes decisions observable.
Replay makes legitimacy reconstructable.
Hash chaining makes evidence tamper-evident.
```

---

## The central distinction

```text
Blockchain protects transaction history.
CMC protects causal legitimacy.
```

A transaction can be immutable and still be causally wrong.

A log can be complete and still fail to prove why an effect was allowed.

A memory write can be valid at the byte level and invalid at the legitimacy level.

---

## Causal legitimacy

A transition is causally legitimate when it can show:

```text
who initiated it
what cause authorized it
which permission or policy allowed it
whether commit occurred before effect
which memory/effect boundary was crossed
whether the evidence can be replayed
whether the trace was modified
```

This creates a new object of verification:

```text
legitimate transition history
```

---

## Why this matters for agents

Agentic systems are not just programs that return outputs.

They act across time:

```text
observe -> remember -> decide -> write -> call tool -> affect world
```

Their failure modes include:

- context drift
- missing parent cause
- unauthorized memory-derived action
- effect before commit
- silent trace mutation
- replay divergence
- responsibility-chain loss

Causal computation treats these as first-class infrastructure problems.

---

## Current CaPU / CMC proof ladder

```text
thesis
 -> simulator
 -> TraceOut
 -> JSONL replay
 -> golden fixtures
 -> hash-chain integrity sketch
 -> tampering detection demo
 -> divergence detection demo
 -> CI verification
```

The system is still early. But it already demonstrates the path from prose to executable evidence.

---

## Research direction

The long-term direction is not only better logs.

It is:

```text
replayable legitimacy
```

Possible future layers:

```text
Causal Memory Controller
 -> TraceOut
 -> Replay verifier
 -> Hash-chain sealing
 -> LTP admissibility inspection
 -> Auditor agents
 -> hardware-adjacent enforcement
```

---

## Non-claims

This document does not claim:

- causal computation is a finished field
- CMC currently replaces ordinary memory
- CaPU replaces security engineering
- hash-chain sketches are production cryptography
- current demos are enough for regulated deployment

This is a research thesis and implementation path.

---

## Short pitch

```text
The next generation of agentic systems will not only need more memory.
They will need memory, execution, and replay layers that preserve legitimacy.

Ordinary systems ask what changed.
Causal systems ask whether the change had the right to happen.
```

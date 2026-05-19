# CMC Replay Surface

Status: early replay and admissibility sketch.

This document defines the first replay-oriented surface for the Causal Memory Controller (CMC).

The goal is not full deterministic replay yet.
The goal is to establish a machine-readable causal trace boundary.

---

## Core idea

CMC does not only emit logs.

It emits:

```text
causal transition evidence
```

The replay surface allows a reviewer or future runtime to reconstruct:

```text
what transition was attempted
why it was accepted or rejected
which cause authorized it
whether the effect was committed
```

---

## Replay pipeline

```text
operation
 -> decision
 -> TraceEvent
 -> JSONL export
 -> replay parser
 -> deterministic reconstruction
```

---

## Current replay format

CMC currently exports replay-oriented traces as JSONL.

Example:

```json
{"seq":1,"kind":"WRITE","decision":"REJECT_MISSING_CAUSE","address":4096,"effect_id":null,"cause_id":null,"message":"memory write requires an explicit cause"}
```

Each line represents a single causal decision boundary.

---

## Why JSONL

JSONL is intentionally simple:

- append-friendly
- stream-friendly
- replay-friendly
- diff-friendly
- deterministic ordering
- easy to feed into external tooling

Future layers may add:

- hash chains
- signatures
- compressed binary formats
- T-Trace compatibility
- LTP admissibility metadata

---

## Minimal replay guarantees

Current replay guarantees:

```text
same operation sequence
 -> same decisions
 -> same trace ordering
```

This is enough for:

- CI verification
- fixture comparison
- blocked-transition proofs
- causal audit demos
- reproducible research artifacts

---

## Relation to LTP and T-Trace

```text
CMC TraceEvent
 -> local causal decision

T-Trace
 -> integrity + verification layer

LTP
 -> replay/admissibility transport layer
```

CMC replay is intentionally minimal.
It focuses on causal decision boundaries near memory/effect operations.

---

## Admissibility direction

Future replay layers may support:

```text
proof that an effect
was causally legitimate
at execution time
```

Potential future checks:

- missing cause detection
- effect-before-commit detection
- replay divergence detection
- forbidden transition verification
- trace completeness verification

---

## Example replay questions

A future reviewer should be able to ask:

```text
Which transition failed?
Which cause authorized it?
Was the cause committed?
Did the effect execute anyway?
Did replay diverge from the original trace?
```

---

## Non-claims

CMC replay currently does NOT provide:

- cryptographic integrity
- Byzantine guarantees
- distributed consensus
- complete deterministic execution replay
- production audit admissibility
- hardware trace persistence

It only establishes the first machine-readable causal replay surface.

---

## Long-term direction

```text
software trace
 -> replay surface
 -> admissibility checks
 -> embedded trace stream
 -> FPGA TraceOut
 -> hardware causal replay
```

The long-term thesis is:

```text
agentic systems may eventually require
not only replayable execution,
but replayable legitimacy.
```

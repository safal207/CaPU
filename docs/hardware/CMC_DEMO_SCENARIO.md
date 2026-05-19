# CMC Demo Scenario: Illegitimate Transition Blocked

Status: first demo scenario / investor-readable proof moment.

This scenario shows the core CMC idea:

```text
CMC does not ask only what changed.
It asks whether the transition was legitimate.
```

---

## Scenario summary

An agent tries to create a memory-derived effect without a legitimate causal transition.

The system should reject the effect and emit trace evidence explaining why.

```text
invalid or missing cause
  -> memory transition is not legitimate
  -> effect is blocked
  -> TraceOut records the decision
```

---

## Why this matters

Agentic systems often fail not because they lack storage, but because they lose the chain of legitimacy:

```text
context -> permission -> action -> memory write -> later effect
```

A system may still produce an output, call a tool, or modify state. But if the transition cannot prove its cause, permission, and commit, it is causally invalid.

CMC makes that failure visible and testable.

---

## Demo story

### Step 1 — Agent attempts an unsupported memory write

```text
agent writes memory
but does not provide a valid cause
```

Expected result:

```text
write rejected: REJECT_MISSING_CAUSE
```

### Step 2 — Agent attempts an external effect before causal commit

```text
agent tries to execute effect using an uncommitted cause
```

Expected result:

```text
effect blocked: REJECT_EFFECT_BEFORE_COMMIT
```

### Step 3 — CMC emits trace evidence

Expected trace:

```text
TraceEventKind::Write  -> REJECT_MISSING_CAUSE
TraceEventKind::Effect -> REJECT_EFFECT_BEFORE_COMMIT
```

### Step 4 — Reviewer can inspect the failure

A reviewer should be able to answer:

```text
What was attempted?
Why was it blocked?
Which cause was missing or uncommitted?
Was the rejected transition observable?
```

---

## Expected demo output

A minimal runner should print something like:

```text
CMC-DEMO illegitimate-transition v0
1. write_without_cause: REJECT_MISSING_CAUSE accepted=false
2. effect_before_commit: REJECT_EFFECT_BEFORE_COMMIT accepted=false
3. trace_events=2
4. result=blocked_illegitimate_transition
```

---

## Core claim demonstrated

```text
A requested transition is not automatically legitimate.
A memory-derived effect must be grounded in a committed causal chain.
```

---

## What this demo does not claim

This demo does not claim:

- production hardware enforcement
- full AI safety coverage
- real memory-controller integration
- cryptographic trace sealing
- complete replay protocol

It only demonstrates a minimal proof moment:

```text
invalid transition -> blocked effect -> trace evidence
```

---

## Next implementation target

Add:

```text
rust/cmc-core/src/bin/cmc_demo.rs
```

The runner should:

1. Create a controller.
2. Attempt write without cause.
3. Add an uncommitted cause.
4. Attempt effect before commit.
5. Print decisions and trace event count.
6. Exit successfully only if both operations are rejected as expected.

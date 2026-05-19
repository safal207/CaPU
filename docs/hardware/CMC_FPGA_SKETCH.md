# CMC FPGA Sketch

Status: early architecture sketch / not an RTL implementation.

This document describes a minimal FPGA-oriented state-machine sketch for the Causal Memory Controller (CMC) research path.

It is not a claim that CMC currently has a hardware implementation. The purpose is to define a small, reviewable proof target for a future FPGA simulation.

---

## Goal

Translate the CMC software thesis into a tiny hardware-adjacent state machine:

```text
memory/effect request
  -> causal reference check
  -> commit check
  -> allow/block decision
  -> TraceOut event
```

The FPGA proof should demonstrate one central invariant:

```text
WriteOut.enable or EffectOut.execute MUST NOT assert
unless a valid committed cause exists for the same operation.
```

---

## Minimal ports

```text
Clock / reset
  clk
  rst_n

Request input
  Req.valid
  Req.kind          // WRITE | READ | EFFECT
  Req.address       // for WRITE/READ
  Req.effect_id     // for EFFECT
  Req.cause_id

Cause table input / lookup result
  CauseLookup.valid
  CauseLookup.found
  CauseLookup.committed
  CauseLookup.parent_cause

Decision outputs
  WriteOut.enable
  ReadOut.enable
  EffectOut.execute
  RejectOut.valid
  RejectOut.code

Trace output
  TraceOut.valid
  TraceOut.seq
  TraceOut.kind
  TraceOut.decision
  TraceOut.target
  TraceOut.cause_id
  TraceOut.ready
```

This is intentionally small. The first FPGA proof should validate the control boundary, not implement a real memory hierarchy.

---

## Request kinds

```text
WRITE  -> request to make a memory write authoritative
READ   -> request to read memory under a causal reference
EFFECT -> request to allow an external effect derived from memory/action state
```

---

## Decision codes

Minimal decision vocabulary:

```text
ACCEPT_WRITE
ACCEPT_READ
ACCEPT_EFFECT
REJECT_MISSING_CAUSE
REJECT_UNKNOWN_CAUSE
REJECT_EFFECT_BEFORE_COMMIT
```

These correspond to the current CMC-0 Rust simulator decision codes.

---

## State machine

```text
IDLE
  -> ACCEPT_REQ
  -> CHECK_CAUSE
  -> DECIDE
  -> EMIT_TRACE
  -> COMPLETE
```

### IDLE

Waits for `Req.valid`.

### ACCEPT_REQ

Latches request fields.

### CHECK_CAUSE

Checks whether `cause_id` is present and whether cause lookup returned a known cause.

### DECIDE

Computes one of:

```text
ACCEPT_WRITE
ACCEPT_READ
ACCEPT_EFFECT
REJECT_MISSING_CAUSE
REJECT_UNKNOWN_CAUSE
REJECT_EFFECT_BEFORE_COMMIT
```

### EMIT_TRACE

Emits a TraceOut event for the decision.

### COMPLETE

Asserts allowed output or reject output, then returns to IDLE.

---

## ASCII state diagram

```text
          +------+
          | IDLE |
          +--+---+
             |
             v
      +------+-------+
      |  ACCEPT_REQ  |
      +------+-------+
             |
             v
      +------+-------+
      | CHECK_CAUSE  |
      +------+-------+
             |
             v
      +------+-------+
      |    DECIDE    |
      +------+-------+
             |
             v
      +------+-------+
      |  EMIT_TRACE  |
      +------+-------+
             |
             v
      +------+-------+
      |   COMPLETE   |
      +------+-------+
             |
             v
          +--+---+
          | IDLE |
          +------+
```

---

## Core assertions

### A1 — No write without cause

```systemverilog
assert property (
  WriteOut.enable |-> CauseLookup.found
);
```

### A2 — No effect before commit

```systemverilog
assert property (
  EffectOut.execute |-> (CauseLookup.found && CauseLookup.committed)
);
```

### A3 — Missing cause rejects

```systemverilog
assert property (
  Req.valid && Req.cause_id == 0 |-> eventually RejectOut.valid
);
```

### A4 — Every decision emits trace

```systemverilog
assert property (
  decision_made |-> eventually TraceOut.valid
);
```

### A5 — Trace decision matches output

```systemverilog
assert property (
  TraceOut.valid |-> TraceOut.decision == latched_decision
);
```

These are sketches, not final SystemVerilog.

---

## TraceOut interaction

TraceOut should emit for both accepted and rejected decisions:

```text
accepted write  -> TraceOut.valid with ACCEPT_WRITE
rejected write  -> TraceOut.valid with reject code
accepted effect -> TraceOut.valid with ACCEPT_EFFECT
rejected effect -> TraceOut.valid with reject code
```

Open design question:

```text
If TraceOut.ready is low, should the controller stall or buffer?
```

Conservative safety profile:

```text
For sensitive operations, no untraced effect should silently execute.
```

---

## Minimal simulation scenarios

The first FPGA testbench should cover:

### S1 — Valid write

```text
Req.kind=WRITE
Req.cause_id=1
CauseLookup.found=1
CauseLookup.committed=1
Expected: WriteOut.enable=1, TraceOut.decision=ACCEPT_WRITE
```

### S2 — Missing cause

```text
Req.kind=WRITE
Req.cause_id=0
Expected: WriteOut.enable=0, RejectOut.valid=1, TraceOut.decision=REJECT_MISSING_CAUSE
```

### S3 — Unknown cause

```text
Req.kind=WRITE
Req.cause_id=999
CauseLookup.found=0
Expected: WriteOut.enable=0, RejectOut.valid=1, TraceOut.decision=REJECT_UNKNOWN_CAUSE
```

### S4 — Effect before commit

```text
Req.kind=EFFECT
Req.cause_id=2
CauseLookup.found=1
CauseLookup.committed=0
Expected: EffectOut.execute=0, RejectOut.valid=1, TraceOut.decision=REJECT_EFFECT_BEFORE_COMMIT
```

### S5 — Committed effect

```text
Req.kind=EFFECT
Req.cause_id=2
CauseLookup.found=1
CauseLookup.committed=1
Expected: EffectOut.execute=1, TraceOut.decision=ACCEPT_EFFECT
```

---

## Relation to Rust simulator

The FPGA sketch should stay aligned with CMC-0 Rust semantics:

```text
Rust DecisionCode     -> FPGA decision code
Rust trace_events()   -> FPGA TraceOut
Rust golden fixture   -> FPGA expected-output fixture
Rust benchmark        -> software baseline only
```

The first hardware proof should not invent new semantics. It should implement the same minimal accept/reject behavior in a constrained state machine.

---

## Relation to CML / CaPU / T-Trace / LTP

```text
CML / vCML -> causal record semantics
CaPU       -> commit-before-effect boundary
CMC        -> causal metadata near memory/effect operations
TraceOut   -> observable event stream
T-Trace    -> trace verification surface
LTP        -> replay/admissibility layer
```

The FPGA sketch is only one possible implementation target for the CMC boundary.

---

## Non-claims

This document does not claim:

- CMC has a working FPGA implementation
- CMC is a memory chip
- this is a complete RTL spec
- this replaces RAM, CXL, TPM, HSM, CHERI, or secure enclaves
- this is ready for ASIC design

This is a proof-target sketch for a future state-machine simulation.

---

## First implementation path

Recommended next steps:

1. Keep Rust simulator as source-of-truth semantics.
2. Add a small machine-readable fixture for CMC decisions.
3. Create a minimal Verilog/SystemVerilog module stub.
4. Add testbench scenarios S1–S5.
5. Add assertions A1–A5.
6. Compare FPGA simulation output against the same expected decision vocabulary.

---

## Short pitch

```text
CMC software proves the semantics.
TraceOut proves the decisions are observable.
The FPGA sketch asks whether the same boundary can be enforced as a tiny state machine.
```

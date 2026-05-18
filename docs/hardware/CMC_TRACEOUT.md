# CMC TraceOut

Status: draft hardware-adjacent interface spec.

`TraceOut` is the observable event stream for the Causal Memory Controller (CMC) research path.

It defines how accepted and rejected memory/effect decisions become replayable evidence.

---

## Purpose

CMC is not only a memory metadata model. It needs an inspection surface.

`TraceOut` exists so every relevant memory/effect boundary can be observed, replayed, and checked by external tooling.

The core idea:

```text
No causal memory decision should be invisible.
```

For CMC-0, this is implemented in software as:

```rust
trace_events()
```

For later embedded, FPGA, or controller profiles, this can become a bounded output stream or hardware-adjacent port.

---

## Current software model

The Rust simulator emits one trace event for every accepted or rejected decision:

```text
write accepted/rejected  -> TraceEventKind::Write
read accepted/rejected   -> TraceEventKind::Read
effect accepted/rejected -> TraceEventKind::Effect
```

Current Rust fields:

```text
TraceEvent {
  seq,
  kind,
  decision,
  address,
  effect_id,
  cause_id,
  message,
}
```

This is intentionally small. CMC-0 prioritizes deterministic replay and testability over rich event payloads.

---

## Canonical event fields

A future stable TraceOut event should preserve at least:

| Field | Meaning |
| --- | --- |
| `seq` | Monotonic event sequence number. |
| `kind` | Decision boundary type: write, read, effect. |
| `decision` | Accepted/rejected decision code. |
| `address` | Memory address or region, when applicable. |
| `effect_id` | External effect identifier, when applicable. |
| `cause_id` | Cause or parent cause used for the decision. |
| `message` | Human-readable decision explanation. |

Future fields may include:

| Field | Meaning |
| --- | --- |
| `value_hash` | Hash of written/read value metadata. |
| `parent_cause` | Explicit parent cause, if distinct from cause. |
| `actor_id` | Actor or requester responsible for the operation. |
| `region_id` | Memory region identifier for constrained devices. |
| `policy_ref` | Policy or permission reference used by the decision. |
| `trace_hash` | Hash-chain link for tamper-evident trace streams. |

---

## Minimal event grammar

```text
TraceOutEvent :=
  seq ":" kind ":" decision ":" target ":" cause

kind := WRITE | READ | EFFECT

decision :=
  ACCEPT_WRITE
  ACCEPT_READ
  ACCEPT_EFFECT
  REJECT_MISSING_CAUSE
  REJECT_UNKNOWN_CAUSE
  REJECT_EFFECT_BEFORE_COMMIT

target := address | effect_id | none
cause := cause_id | none
```

This grammar is not a serialization format yet. It is a compact semantic sketch for conformance tests and future fixtures.

---

## Core invariants

### T1 — Every decision emits a trace event

```text
For every write/read/effect decision, TraceOut MUST emit exactly one event.
```

This includes rejects. Rejected operations are often the most important audit evidence.

### T2 — Trace sequence is monotonic

```text
TraceOut.seq MUST increase monotonically within a controller instance.
```

A replay engine should be able to reconstruct order without wall-clock time.

### T3 — Decision code must match operation result

```text
TraceOut.decision MUST equal the Decision returned by the controller operation.
```

TraceOut must not describe a different outcome than the runtime decision.

### T4 — Effect events must carry causal reference

```text
Accepted effects MUST include a committed parent cause.
Rejected effects SHOULD include the failed or missing cause when known.
```

This preserves the commit-before-effect guarantee at the trace boundary.

### T5 — TraceOut is observable, not authoritative

```text
TraceOut records decisions. It does not grant permission by itself.
```

Permission remains a CMC/CaPU decision. TraceOut is the evidence surface.

---

## Relation to CaPU ports

CaPU already uses the idea of explicit device-style ports:

```text
CauseIn
PermissionOut
EffectOut
TraceOut
```

CMC TraceOut specializes this for causal memory/effect operations:

```text
MemOpIn / CauseIn -> CMC decision -> WriteOut / EffectOut -> TraceOut
```

The future hardware-adjacent invariant is:

```text
If WriteOut.enable or EffectOut.execute is decided,
TraceOut must emit a corresponding decision event.
```

---

## Relation to T-Trace and LTP

TraceOut is intentionally compatible with the broader stack direction:

```text
CMC TraceOut -> T-Trace event stream -> LTP replay/admissibility surface
```

CMC does not need to own the full replay protocol. It only needs to emit stable event facts that another layer can replay and verify.

Possible mapping:

| CMC TraceOut | T-Trace / LTP role |
| --- | --- |
| `seq` | event order |
| `kind` | operation type |
| `decision` | decision/status code |
| `cause_id` | causal anchor |
| `address/effect_id` | target object |
| `message` | human-readable audit reason |

---

## FPGA / controller sketch

A later FPGA or controller proof may expose TraceOut as a bounded stream:

```text
TraceOut.valid
TraceOut.seq
TraceOut.kind
TraceOut.decision
TraceOut.target
TraceOut.cause
TraceOut.ready
```

Minimal handshake:

```text
valid=1 means a trace event is available.
ready=1 means downstream accepted the event.
```

Open design question:

```text
Should CMC block WriteOut/EffectOut when TraceOut is backpressured,
or should it buffer trace events in a bounded ring?
```

For safety-oriented profiles, the conservative default is:

```text
If a sensitive effect cannot be traced, it should not silently execute.
```

---

## CMC-0 acceptance criteria

CMC-0 should satisfy:

- every write emits a trace event
- every read emits a trace event
- every effect emits a trace event
- accepted and rejected paths are both traced
- golden fixture includes trace event count
- tests verify event kind and decision code
- documentation links TraceOut to T-Trace/LTP and future hardware ports

Current implementation status:

```text
software trace_events(): present
write trace tests: present
read trace tests: present
effect trace tests: present
golden trace count: present
hardware port: not implemented
serialization format: not finalized
hash-chain trace sealing: future work
```

---

## Non-claims

TraceOut is not currently:

- a hardware bus
- a finalized serialization format
- a cryptographic trace seal
- a full T-Trace implementation
- a full LTP replay protocol
- a replacement for observability, SIEM, or compliance tooling

At this stage, TraceOut is the minimal evidence surface that makes CMC decisions externally inspectable.

---

## Short pitch

```text
CMC decides whether memory/effect operations are causally valid.
TraceOut makes those decisions replayable.

No causal memory decision should be invisible.
```

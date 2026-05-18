# Causal Memory Controller (CMC)

Status: research thesis / hardware-adjacent roadmap.

This document defines the first research path for a **Causal Memory Controller (CMC)**: a memory/controller-adjacent primitive that preserves causal metadata next to ordinary memory and effect operations.

It is not a claim that CaPU or CML already provide a physical memory chip. It is a disciplined proof path from existing causal semantics toward simulator, embedded runtime, FPGA model, and possible hardware architecture.

---

## Core thesis

```text
CPU computes.
GPU accelerates.
Ordinary memory stores bytes.
Causal Memory stores why a byte, transition, or effect was allowed to exist.
```

Agentic systems do not only need more memory. They need memory with causal continuity.

For an agent, the critical chain is not just:

```text
prompt -> context -> output
```

The critical chain is:

```text
context -> permission -> action -> memory write -> later effect
```

When this chain breaks, a system can still look operationally successful while losing responsibility, authorization lineage, or causal grounding.

CMC exists to explore whether causal metadata can be kept close to memory/effect boundaries so later reads, writes, actions, and device effects remain auditable.

---

## Problem statement

Ordinary memory answers:

```text
address -> bytes
```

It does not answer:

```text
who wrote this?
why was this write allowed?
what parent cause authorized it?
which later action used this memory?
can the resulting effect be traced back to a valid cause?
```

For agentic systems, robots, controllers, autonomous tools, and high-risk automation, this is a structural blind spot.

A model or agent may carry a large context window, external vector memory, or logs, but still lose the causal chain that explains why a state transition or side effect was permitted.

CMC treats causal continuity as a memory/control-plane problem, not only as an application logging problem.

---

## Relation to the existing ecosystem

```text
CML / vCML -> causal record semantics
CaPU       -> commit-before-effect execution boundary
T-Trace    -> trace/event verification surface
LTP        -> replay / admissibility / continuity protocol
CMC        -> hardware-adjacent causal metadata plane near memory/effects
```

### CML / vCML

CML defines the semantic unit of causal memory:

- actor
- action
- object
- permitted_by
- parent_cause
- timestamp
- integrity hooks

CMC should reuse those semantics in a constrained, controller-friendly form.

### CaPU

CaPU defines the execution boundary:

```text
Gate -> Incubate -> Commit -> Execute
```

CMC extends the same principle toward memory and controller operations:

```text
No write/effect should become authoritative without causal permission, durable commit, and traceability.
```

### T-Trace / LTP

CMC should emit trace events that can be replayed and verified by external tooling. Hardware-adjacent causal memory is only valuable if its behavior is externally inspectable.

---

## Minimal CMC model

A minimal causal memory entry can be represented as:

```text
CausalMemoryEntry {
  address:        u64,
  value_hash:     bytes32,
  writer:         ActorId,
  permitted_by:   CauseId | PolicyRef,
  parent_cause:   CauseId | null,
  timestamp:      u64,
  flags:          EntryFlags,
}
```

The controller does not need to store full application data. It can store compact metadata next to, or parallel to, ordinary memory writes.

Possible storage strategies:

1. **Sidecar table**: address/page/region -> causal metadata.
2. **Ring buffer**: append-only causal event stream for constrained devices.
3. **Tagged region map**: region-level causal labels, cheaper than per-byte metadata.
4. **Hybrid**: region tags for normal operation, event records for sensitive transitions.

---

## Boundary operations

CMC-0 should model four operations:

```text
cmc_write(address, value_hash, cause)
cmc_read(address, requester, cause)
cmc_effect(effect_id, parent_cause)
cmc_audit()
```

### `cmc_write`

Records that a value or state was written to memory.

Questions:

- Was there a valid cause?
- Was the writer permitted?
- Does this write derive from an existing chain?

### `cmc_read`

Records that an actor accessed memory.

Questions:

- Is the requester allowed to read this causal region?
- Does reading this memory create a causal dependency for later effects?

### `cmc_effect`

Records a boundary where memory-derived state influences an external effect.

Examples:

- network send
- actuator move
- payment/API call
- code deployment
- device command

Questions:

- Does the effect have a committed parent cause?
- Does it derive from valid causal memory?
- Is the causal chain reconstructible?

### `cmc_audit`

Runs deterministic checks over causal memory state and emitted event records.

---

## Core invariants

### I1 — No authoritative write without cause

```text
A memory write that affects later decisions must carry a valid cause or be explicitly marked as an observed causal gap.
```

### I2 — No external effect without committed cause

```text
An effect must not be authorized unless it can reference a committed causal record.
```

### I3 — Missing parent is invalid or auditable

```text
If parent_cause references a missing record, the chain is causally invalid.
```

### I4 — Secret-to-effect lineage must be explicit

```text
If sensitive memory is read and later used for network/device output, the effect must reconstruct a causal path back to the sensitive access.
```

### I5 — Failure defaults must be safe

```text
Missing cause, malformed cause, expired cause, or failed commit must lead to HOLD, REJECT, EXPIRE, or AUDIT — not silent execute.
```

---

## CMC-0: Rust simulator

The first implementation should be a Rust reference simulator, not hardware.

Suggested layout:

```text
rust/
  cmc-core/
    Cargo.toml
    src/
      lib.rs
      record.rs
      controller.rs
      audit.rs
      trace.rs
    tests/
      causal_write.rs
      missing_cause.rs
      effect_before_commit.rs
      secret_to_effect.rs
```

Initial API sketch:

```rust
pub struct CausalMemoryController { /* bounded or simulated state */ }

impl CausalMemoryController {
    pub fn write(&mut self, address: u64, value_hash: [u8; 32], cause: CauseRef) -> Decision;
    pub fn read(&mut self, address: u64, requester: ActorId, cause: CauseRef) -> Decision;
    pub fn effect(&mut self, effect_id: EffectId, parent_cause: CauseRef) -> Decision;
    pub fn audit(&self) -> AuditReport;
}
```

Expected tests:

- accepted write with valid cause
- rejected or warned write with missing cause
- rejected effect before causal commit
- reconstructed chain for memory-derived effect
- detected secret-read-to-effect without causal lineage

The simulator should produce deterministic outputs and golden fixtures before any embedded or FPGA work begins.

---

## CMC-1: Embedded profile

After the simulator, define a constrained embedded profile.

Target properties:

```text
bounded memory
bounded execution time
fixed-size records
no dynamic allocation in the core path
small decision vocabulary
safe failure defaults
```

Possible implementation targets:

- Rust `no_std`
- C99 embedded profile
- MCU-friendly ring buffer
- RTOS middleware adapter

Minimal embedded record:

```c
typedef struct {
    uint64_t address;
    uint8_t  value_hash[32];
    uint32_t writer_id;
    uint32_t cause_id;
    uint32_t parent_cause_id;
    uint64_t timestamp;
    uint16_t flags;
} cmc_record_t;
```

The embedded profile should prove that causal metadata can be tracked without requiring a full desktop runtime or database.

---

## CMC-2: Device/controller demo

Build a small middleware demo before FPGA.

Example demo:

```text
sensor input
  -> agent proposes action
  -> memory state updated
  -> CMC records causal write
  -> CaPU commit check
  -> device effect allowed or blocked
```

Possible scenarios:

- robot arm movement blocked without causal commit
- door unlock denied when parent cause is missing
- payment/tool call blocked when memory-derived authorization is stale
- network send denied after secret memory read without explicit chain

The demo must visibly show:

```text
operational request exists
but effect is blocked because causal memory is invalid
```

This is the investor-friendly proof moment.

---

## CMC-3: FPGA proof-of-behavior

Only after CMC-0 and CMC-1 should we explore FPGA.

Minimal port sketch:

```text
CauseIn
MemOpIn
CommitIn
ReadOut
WriteOut
EffectOut
TraceOut
ViolationOut
```

Minimal hardware invariant:

```text
WriteOut.enable or EffectOut.execute MUST NOT assert
unless a valid committed cause exists for the same operation.
```

Required simulation tests:

- valid cause -> write enable allowed
- missing cause -> write enable blocked
- commit fail -> no effect
- expired cause -> no effect
- trace event emitted for every decision

The FPGA prototype should be described as a causal controller/state-machine proof, not a full CPU or memory chip.

---

## Investor evidence path

The evidence path should be staged and falsifiable.

### Stage 1 — Concept proof

Deliverables:

- this thesis document
- simulator design
- invariant list
- non-claims

Investor question answered:

```text
Is this a coherent new primitive, or just logging?
```

### Stage 2 — Software proof

Deliverables:

- Rust simulator
- deterministic tests
- golden fixtures
- small benchmark

Investor question answered:

```text
Can causal memory behavior be reproduced deterministically?
```

### Stage 3 — Device proof

Deliverables:

- embedded profile
- fixed-size ring buffer
- device/actuator demo
- blocked-effect example

Investor question answered:

```text
Can this protect or explain real device/tool effects?
```

### Stage 4 — Hardware-adjacent proof

Deliverables:

- FPGA state machine
- simulation assertions
- forbidden-path proof
- host interface sketch

Investor question answered:

```text
Is there a credible path from software semantics to controller hardware?
```

### Stage 5 — Architecture / feasibility

Deliverables:

- architecture whitepaper
- area/power/latency estimate
- comparison against firmware-only path
- partner/lab pathway

Investor question answered:

```text
Does dedicated hardware add value beyond software?
```

---

## What makes this different from ordinary memory or logs

| System | Stores | Does not store |
| --- | --- | --- |
| RAM | bytes | why the bytes were authorized |
| database | records | causal permission lineage by default |
| logs | events | enforceable memory/effect continuity |
| vector memory | semantic similarity | responsibility chain |
| tracing | execution flow | whether a memory-derived effect was causally permitted |
| CMC | causal metadata for memory/effects | full application state or model reasoning |

CMC is not about making memory larger. It is about making memory causally accountable.

---

## Non-claims

CMC is not currently:

- a physical memory chip
- a replacement for RAM
- a replacement for CXL
- a replacement for TPM, HSM, CHERI, secure enclaves, or RTOS safety kernels
- a proven silicon architecture
- a full AI memory system
- a general-purpose processor

At this stage, CMC is a research direction and proof path for causal metadata near memory/controller boundaries.

---

## Scope boundaries

### In scope

- causal metadata associated with memory writes, reads, and effects
- deterministic audit of memory/effect lineage
- commit-before-effect compatibility with CaPU
- simulator, embedded profile, and FPGA proof path
- investor-facing evidence artifacts

### Out of scope for now

- real silicon design
- production memory controller replacement
- general AI long-term memory product
- full OS virtual memory implementation
- formal hardware certification

---

## Short pitch

```text
Agentic AI does not only need more memory.
It needs memory with causal continuity.

Ordinary memory stores what changed.
Causal Memory stores why the change was allowed.

CMC is a staged path toward memory/controller systems that preserve
actor, permission, parent cause, and responsibility lineage close to
where memory-derived effects happen.
```

---

## Immediate next steps

1. Implement CMC-0 as a Rust simulator.
2. Add deterministic tests for missing cause, valid cause, and effect-before-commit.
3. Emit a simple trace format compatible with CML/T-Trace concepts.
4. Add one benchmark: overhead of causal metadata tracking per write/effect.
5. Create a small investor demo: memory-derived effect blocked because causal lineage is missing.

The goal is not to sound like hardware too early. The goal is to build an evidence ladder that makes hardware feel inevitable only after the software and embedded proofs are real.

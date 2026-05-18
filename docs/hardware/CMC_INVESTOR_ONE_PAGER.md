# Causal Memory Controller (CMC) — Investor One-Pager

Status: early research branch / proof path.

## One-line thesis

**Agentic AI does not only need more memory. It needs memory with causal continuity.**

Ordinary memory stores what changed. Causal Memory stores why the change was allowed.

---

## The problem

Modern agentic systems increasingly operate across long chains:

```text
context -> permission -> action -> memory write -> later effect
```

Current memory systems can store more tokens, vectors, files, logs, and state, but they usually do not preserve the causal chain behind state changes.

That creates a gap:

```text
The system may remember data,
but forget why that data was authorized,
who caused it,
and whether a later effect is still grounded in a valid chain.
```

For high-risk agentic systems, this matters because an action can be operationally successful while being causally invalid.

Examples:

- an agent writes state without a valid parent permission
- a later action uses stale or unauthorized memory
- a device effect happens before durable commit
- a sensitive read influences an external output without explicit lineage
- a chain appears coherent in logs but cannot prove responsibility continuity

---

## Why ordinary memory is not enough

Ordinary memory answers:

```text
address -> bytes
```

Agentic systems increasingly need to answer:

```text
who wrote this?
why was it allowed?
what parent cause authorized it?
which later action used it?
can we prove the effect was causally permitted?
```

This is not only a storage-capacity problem. It is a continuity, responsibility, and auditability problem.

---

## What CMC proposes

The **Causal Memory Controller (CMC)** is a staged research path toward a memory/controller-adjacent primitive that stores causal metadata near memory and effect operations.

CMC does not replace RAM. It adds a causal metadata plane around memory-derived actions.

Minimal causal memory entry:

```text
CausalMemoryEntry {
  address,
  value_hash,
  writer,
  permitted_by,
  parent_cause,
  timestamp,
  flags
}
```

The goal is to make memory-derived effects auditable and eventually enforceable:

```text
No authoritative write or external effect without causal permission, commit, and traceability.
```

---

## Why this can become hardware-relevant

Today, causal tracking is usually implemented in application code, logs, databases, or observability systems. That is useful, but it is often late, slow, optional, or incomplete.

CMC explores whether some causal metadata and invariants can move closer to the controller/device boundary:

```text
software simulator -> embedded profile -> device demo -> FPGA state machine -> hardware architecture study
```

The hypothesis:

```text
If causal metadata is closer to memory/effect operations,
then causal continuity checks can become faster, more deterministic,
and harder to bypass than application-level logging alone.
```

---

## Current artifacts

CMC is currently an early proof path inside the CaPU repository.

Available artifacts:

- CMC thesis: `docs/hardware/CAUSAL_MEMORY_CONTROLLER.md`
- Rust simulator: `rust/cmc-core`
- CI workflow: `.github/workflows/cmc-rust.yml`
- Simulator command:

```bash
cd rust/cmc-core
cargo test
```

Current simulator proof cases:

- valid write with known cause is accepted
- write with missing cause is rejected
- write with unknown cause is rejected
- effect before causal commit is rejected
- committed effect is accepted
- memory-derived effect chain can be reconstructed

---

## Evidence ladder

### Stage 1 — Concept proof

Output:

- thesis document
- minimal causal memory model
- invariants
- non-claims

Investor question:

```text
Is this a coherent primitive, or just logging?
```

### Stage 2 — Software proof

Output:

- Rust simulator
- deterministic tests
- CI badge
- golden fixtures
- first overhead benchmark

Investor question:

```text
Can causal memory behavior be reproduced and tested?
```

### Stage 3 — Device proof

Output:

- embedded fixed-size ring buffer
- device/actuator middleware demo
- blocked-effect example
- traceable report

Investor question:

```text
Can this protect or explain real memory-derived effects?
```

### Stage 4 — Hardware-adjacent proof

Output:

- FPGA state-machine model
- forbidden-path assertions
- host interface sketch
- trace output stream

Investor question:

```text
Can this become a credible controller/co-processor pattern?
```

### Stage 5 — Feasibility study

Output:

- architecture whitepaper
- latency/area/power estimate
- comparison against software-only and firmware-only approaches
- partner/lab pathway

Investor question:

```text
Does dedicated hardware add enough value to justify the cost?
```

---

## Relation to the broader stack

```text
CML / vCML -> causal record semantics
CaPU       -> commit-before-effect execution boundary
CMC        -> causal metadata near memory/controller operations
T-Trace    -> trace and verification surface
LTP        -> replay and admissibility layer
```

CMC is not a separate fantasy project. It is the hardware-adjacent continuation of the same causal-validity thesis.

---

## Differentiation

| Layer | Main question | CMC difference |
| --- | --- | --- |
| RAM | What bytes are stored? | CMC asks why memory-derived state was allowed. |
| Logs | What happened? | CMC keeps causal metadata near memory/effect operations. |
| Vector memory | What is semantically similar? | CMC tracks permission and responsibility lineage. |
| Tracing | What executed and when? | CMC checks whether memory-derived effects are causally permitted. |
| Policy engine | Is this allowed now? | CMC preserves the cause chain across later reads/writes/effects. |
| CaPU | Can this effect execute? | CMC helps prove the memory lineage behind the effect. |

---

## Near-term roadmap

Next 30–45 days:

1. Expand `rust/cmc-core` with trace events.
2. Add golden fixtures for accepted/rejected memory/effect flows.
3. Add a first benchmark for causal metadata overhead.
4. Add a small demo: memory-derived effect blocked before commit.
5. Add an embedded-profile design note with fixed-size record/ring-buffer constraints.

Next 90 days:

1. Build a minimal C or Rust `no_std` profile.
2. Add a device/controller middleware demo.
3. Add an FPGA state-machine sketch.
4. Publish a short technical report.
5. Prepare investor/demo packet.

---

## Non-claims

CMC is not currently:

- a physical memory chip
- a replacement for RAM
- a replacement for CXL, TPM, HSM, CHERI, secure enclaves, or RTOS safety kernels
- a proven silicon architecture
- a production memory controller
- a general AI long-term memory product

At this stage, CMC is a disciplined proof path toward causal memory/controller infrastructure.

---

## Investor framing

```text
The AI infrastructure market is racing to give agents more memory.
CMC asks a different question:

What if agent memory needs not only capacity,
but causal continuity?

Ordinary memory remembers what changed.
Causal Memory remembers why the change was allowed.
```

The first investable milestone is not a chip. It is a reproducible proof that causal memory semantics can be simulated, tested, benchmarked, and moved toward embedded/controller boundaries.

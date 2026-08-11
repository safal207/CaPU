# CaPU Core v0.1 — Causal STORE Retirement

## Purpose

v0.1 extends the v0 register commit experiment to the first externally visible side effect: a memory STORE.

Primary invariant:

> **A memory-visible write may occur only as the consequence of a valid causal commit.**

In implication form:

```text
MEMORY_VISIBLE_WRITE => VALID_CAUSAL_COMMIT
```

This is stronger than merely checking that the STORE instruction executed correctly. The design separates speculative computation from architectural visibility.

## Minimal data path

```text
STORE candidate
      |
      v
    GATE
      |
      v
  EXECUTE OK
      |
      v
+---------------------+
| speculative buffer  |
| valid | addr | data |
+----------+----------+
           |
           v
   CAUSAL VALIDATION
           |
           v
        COMMIT
           |
           v
  MEMORY WRITE PULSE
```

The one-entry buffer is deliberately minimal. It gives the architecture a concrete speculative state that is distinct from memory-visible state.

## Issue contract

A STORE may enter the speculative buffer only when:

```text
issue_allowed = issue_valid && gate_allow && execute_ok
```

Issue is not commitment. Buffering an address and data value produces no memory write.

## Commit contract

The buffered STORE may retire only when:

```text
commit_allowed = buffer_valid
              && causal_valid
              && commit_request
              && !flush
```

At the commit edge, the design emits exactly one registered `memory_write_enable` pulse carrying the buffered address and data, then clears the speculative entry.

## Recovery / flush

`flush` models a squash, interruption, or recovery event that occurs before retirement.

Priority is explicit:

```text
flush > commit > issue
```

Therefore a simultaneous `flush=1` and otherwise valid commit cannot create a memory-visible write. The speculative entry is discarded instead.

This gives a minimal precise-state property:

```text
pre-commit interruption -> discard speculative STORE
post-commit observation  -> one explicit memory write pulse
```

v0.1 does not yet model persistent memory, cache coherence, power-loss durability, or replay after reset. It proves only the local retirement boundary.

## Invariants

### INV-CAPU-STORE-001 — Causal commit dominates visibility

```text
memory_write_enable
=> previous(buffer_valid && causal_valid && commit_request && !flush)
```

### INV-CAPU-STORE-002 — Flush blocks visibility

```text
flush => next(memory_write_enable == 0)
```

### INV-CAPU-STORE-003 — Issue is speculative

```text
issue_allowed && !commit_allowed
=> no memory-visible write
```

### INV-CAPU-STORE-004 — Causal validation is necessary

```text
buffer_valid && commit_request && !causal_valid
=> no memory-visible write
```

### INV-CAPU-STORE-005 — One commit, one write

A successful commit retires the buffered entry. Repeating `commit_request` without a new buffered STORE cannot create another write.

## Deterministic smoke trajectories

The executable testbench covers:

1. Gate rejection — STORE never enters speculation.
2. Valid issue — address/data are buffered, memory remains unchanged.
3. Commit request without causal validation — buffer remains speculative, no write.
4. Flush concurrent with would-be commit — flush wins, no write.
5. Valid causal commit — exactly one memory write pulse with exact address/data.
6. Repeated commit after retirement — no second write.
7. Execute failure — STORE never enters speculation.

The test emits a deterministic trace:

```text
S0 reset
S1 gate_rejected
S2 speculative
S3 causal_invalid
S4 flushed
S5 committed
S6 retired
S7 execute_failed
```

The trace is uploaded by CI as evidence.

## Relationship to a conventional processor

A conventional out-of-order CPU may compute a STORE early but holds it in a store queue until retirement/order constraints permit visibility. CaPU adds an explicit causal legitimacy predicate to that retirement boundary.

The architectural question is therefore:

> **What must be true before a computed side effect is allowed to become reality?**

In v0.1, the answer is encoded directly in RTL.

## Next step

The next useful experiment is not a larger ISA. It is stronger verification:

1. formally prove the no-write-before-causal-commit invariant over arbitrary input sequences;
2. add a small memory model and count visible writes;
3. attach transition metadata (`transition_id`, logical time, pre/post hashes) to the buffered entry;
4. seal the deterministic trace into a CaPU proof record;
5. only then extend toward multiple in-flight entries or a retirement queue.

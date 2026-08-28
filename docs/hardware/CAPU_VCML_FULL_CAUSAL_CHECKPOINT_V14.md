# CaPU v0.14 — Full Causal Checkpoint State Binding

## Status

Experimental bounded hardware/software checkpoint composition layered above the frozen v0.13 checkpoint-content boundary.

v0.14 extends the checkpointed recovery content from the finite replay spent-set to the explicit **committed causal state** currently needed to describe the local CaPU continuation boundary:

- `causal_head_valid`;
- `causal_head_transition_id`;
- committed 4-bit `GEN`;
- `sealed_chain`;
- the existing finite spent root-authorization reference set;
- checkpoint identity (`checkpoint_ref`, `checkpoint_epoch`).

Speculative or buffered execution state is deliberately not part of this checkpoint schema.

## Architectural rule

v0.13 established that checkpoint authority and checkpoint bytes are not equivalent unless the same content commitment survives prepare, persistence, authority commit and recovery.

v0.14 strengthens the state being bound:

```text
finite replay spent-set
        +
committed causal head
        +
committed GEN
        +
committed SEAL
        ↓
canonical causal checkpoint snapshot
        ↓
off-path SHA-256 commitment
        ↓
PREPARE
        ↓
PERSIST exact commitment + causal state
        ↓
ANCHOR COMMIT exact commitment + causal state
        ↓
RESET / RECOVERY
        ↓
verify exact anchor commitment + exact causal state
        ↓
recovered causal checkpoint record
```

Central invariant:

> **CHECKPOINT AUTHORITY IS NOT A FULL CAUSAL CHECKPOINT UNLESS THE SAME COMMITTED CAUSAL STATE IS BOUND ACROSS PREPARE → PERSIST → AUTHORITY COMMIT → RECOVERY.**

## Canonical software commitment

`tools/vcml_causal_checkpoint_v14.py` is the reference canonical encoder. SHA-256 remains outside the RTL critical path.

The canonical snapshot includes only authoritative fields:

```text
checkpoint_ref
checkpoint_epoch
spent root-authorization refs (semantic set; canonical sorted order)
causal_head_valid
causal_head_transition_id
causal_head_gen
sealed_chain
```

Unknown fields are rejected rather than silently ignored. This intentionally rejects keys such as `buffered_*` or `speculative_*`, preventing a caller from treating transient execution state as part of the committed checkpoint contract.

When `causal_head_valid == false`, the only canonical empty causal state is:

```text
transition_id = 0
GEN           = 0
SEAL          = 0
```

The reference tests require:

- the same replay spent-set in a different input order produces the same digest;
- changing the causal head changes the digest;
- changing committed GEN changes the digest;
- changing SEAL changes the digest;
- changing the replay spent-set changes the digest;
- speculative/buffered fields are rejected;
- malformed empty causal state is rejected.

## RTL composition

`rtl/capu_checkpoint_full_state_binding_v14.sv` wraps the existing v0.13 commitment lifecycle. It does not calculate SHA-256.

### Prepare

Checkpoint prepare is admitted only when the supplied candidate causal state exactly equals the explicit current committed causal state:

```text
PREPARE_ACCEPT
=> CANDIDATE_CAUSAL_STATE == COMMITTED_CAUSAL_STATE
```

The v0.14 module receives only committed causal-state inputs for this comparison. No speculative-state input exists on this ABI.

### Persistence

Persistence acknowledgement must preserve the exact causal state latched by accepted prepare:

```text
PERSIST_ACCEPT
=> PERSISTED_CAUSAL_STATE == REQUEST_CAUSAL_STATE
```

A matching checkpoint ref/epoch/commitment cannot compensate for a changed head, GEN or SEAL.

### Authority commit

The durable-anchor acknowledgement must preserve both:

- the pending candidate causal state; and
- the causal state associated with the base anchor used by the v0.12 CAS-style transition.

```text
CHECKPOINT_COMMIT_EVENT
=> ACK_CAUSAL_STATE == REQUEST_CAUSAL_STATE
```

Any causal-state mismatch prevents the checkpoint from becoming new authority in this composition.

### Recovery

For anchored recovery, the explicit snapshot causal state must equal the causal state associated with the authoritative anchor, in addition to satisfying the existing v0.13 commitment and v0.11 ref/epoch checks:

```text
ANCHORED_RESTORE_ACCEPT
=> SNAPSHOT_COMMITMENT == ANCHOR_COMMITMENT
&& SNAPSHOT_CAUSAL_STATE == ANCHOR_CAUSAL_STATE
```

An accepted restore produces an explicit recovered record:

```text
recovered_causal_state_ready
recovered_causal_head_valid
recovered_causal_head_transition_id
recovered_causal_head_gen
recovered_sealed_chain
```

The existing v0.10 replay restore simultaneously recovers the finite spent-authorization set.

## Deterministic failure trajectory

The v0.14 RTL testbench exercises independent mismatch locations:

- wrong causal head at PREPARE → rejected;
- changed GEN at persistence → rejected;
- changed SEAL in anchor acknowledgement → rejected;
- exact checkpoint commit → accepted;
- changed causal state during anchored restore → rejected;
- exact anchored restore → recovers head, GEN, SEAL and replay spent-set.

## Bounded formal envelope

The dedicated v0.14 formal harness uses a reduced finite instance and proves the explicit state-binding rules for a bounded horizon. It also contains non-vacuity covers for mismatch rejection, successful checkpoint commit, successful anchored restore and exact recovered-state observation.

Primary properties:

```text
PREPARE_ACCEPT
=> CANDIDATE_CAUSAL_STATE == COMMITTED_CAUSAL_STATE

PERSIST_ACCEPT
=> PERSISTED_CAUSAL_STATE == REQUEST_CAUSAL_STATE

CHECKPOINT_COMMIT_EVENT
=> ACK_CAUSAL_STATE == REQUEST_CAUSAL_STATE

ANCHORED_RESTORE_ACCEPT
=> SNAPSHOT_CAUSAL_STATE == ANCHOR_CAUSAL_STATE

CAUSAL_STATE_MISMATCH
=> NO_RESTORE_ACCEPT

RECOVERED_STATE_READY_AFTER_ACCEPT
=> RECOVERED_CAUSAL_STATE == ACCEPTED_SNAPSHOT_CAUSAL_STATE
```

Formal verification is intentionally reduced-width and bounded; it is not a parametric or unbounded proof.

## What v0.14 does not claim

v0.14 does **not** claim:

- complete CPU architectural-state checkpointing;
- cache, predictor, register-file, ISA or coherence recovery;
- cryptographic SHA-256 computation or verification inside RTL;
- correctness or trustworthiness of the off-path commitment engine;
- durable-media correctness;
- correctness of the external monotonic/CAS anchor implementation;
- source-history omission resistance;
- distributed checkpoint consensus;
- unbounded or parametric verification.

Most importantly, the recovered causal record is **not yet wired back into the live v0.9 parent/GEN/SEAL continuation controller after reset**. v0.14 proves checkpoint construction/binding/recovery of the causal record; live causal execution resumption is a separate future boundary.

## Narrow claim

Within the explicitly finite v0.14 composition and bounded formal envelope, checkpoint prepare, persistence, authority acknowledgement and anchored recovery fail closed on mismatched committed causal-head / GEN / SEAL state, while an exact accepted recovery reproduces the checkpoint-bound causal record alongside the existing replay spent-set.

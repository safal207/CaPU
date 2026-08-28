# CaPU v0.12 — Checkpoint Commit Protocol

## Purpose

CaPU v0.11 verifies that recovery uses the exact externally authoritative checkpoint. v0.12 adds the complementary creation-side boundary: a checkpoint does not become recovery authority merely because candidate bytes exist or because a snapshot write was attempted.

The prototype models a three-stage protocol:

```text
PREPARE candidate against current anchor
        ↓
PERSIST exact checkpoint snapshot
        ↓
REQUEST external anchor compare-and-swap
        ↓
ACK exact base + candidate
        ↓
CHECKPOINT COMMIT EVENT
```

The central rule is:

```text
CHECKPOINT_COMMIT_EVENT
  => SNAPSHOT_DURABLE
  && BASE_ANCHOR_STILL_CURRENT
  && EXACT_EXTERNAL_ANCHOR_ACK
```

This is deliberately analogous to the existing CaPU distinction between speculative/internal work and architecturally visible commit.

## Candidate preparation

A checkpoint candidate is admitted only when no other candidate is pending and the candidate metadata is structurally usable:

- checkpoint reference is non-zero;
- checkpoint state tag is non-zero;
- the current anchor is structurally well formed when present;
- the candidate epoch is exactly the next epoch;
- epoch wrap is not allowed.

The initial checkpoint begins at epoch `1` when no anchor exists.

For an existing anchor:

```text
candidate_epoch = current_anchor_epoch + 1
```

A skipped epoch is rejected. When the anchor epoch is all ones, automatic checkpoint progression fails closed rather than wrapping to zero.

## Latched base anchor

Preparation latches the current authoritative anchor as the candidate's base. The commit protocol therefore remembers not only *what checkpoint is being created* but also *which authoritative state it is replacing*.

If the externally authoritative anchor changes while the candidate is pending:

```text
latched base != current anchor
        ↓
STALE_BASE
        ↓
NO ANCHOR COMMIT REQUEST
        ↓
pending candidate discarded
```

This is a local fencing rule for concurrent checkpoint writers. It does not by itself implement distributed consensus or the external compare-and-swap store.

## Snapshot persistence boundary

A persistence acknowledgement is accepted only when it exactly matches the prepared candidate and the latched base anchor is still current.

The checkpoint state tag is opaque binding metadata in v0.12. CaPU compares it exactly but does not compute a cryptographic hash inside this RTL block.

A wrong checkpoint reference, epoch, or state tag cannot set `snapshot_durable`.

Therefore:

```text
NO SNAPSHOT PERSISTENCE
        =>
NO ANCHOR COMMIT REQUEST
```

## External anchor commit boundary

Only a durable candidate may request an external anchor update.

The request projects both:

```text
expected base anchor
        +
new checkpoint candidate
```

The external durable store is expected to perform an atomic compare-and-swap or equivalent operation. Its acknowledgement must echo the exact base and exact candidate.

A wrong or early acknowledgement is rejected and cannot emit `checkpoint_commit_event`.

The external durable store, acknowledgement authentication and media durability are outside this RTL block.

## Abort semantics

`checkpoint_abort` clears the local pending candidate and suppresses anchor commit.

If the snapshot had already been persisted, abort may leave an orphaned snapshot artifact, but that artifact is **not authoritative** because the durable anchor was never advanced.

This preserves the ordering:

```text
snapshot bytes exist
        !=
checkpoint authoritative
```

## Recovery composition

`capu_vcml_store_buffer_v12.sv` composes:

```text
checkpoint commit controller          v0.12
        ↓
external durable anchor
        ↓
exact-anchor recovery freshness       v0.11
        ↓
replay-state restore across reset     v0.10
        ↓
one-shot authorization replay guard  v0.9
        ↓
causal STORE retirement
```

v0.12 also removes the free-standing `checkpoint_trusted` input from the outer wrapper. For anchored recovery, trust is derived from exact checkpoint reference/epoch matching in v0.11 plus exact equality of the presented snapshot state tag to the external anchor state tag.

This state-tag equality is a binding check, not cryptographic verification.

## Deterministic trajectory

The v0.12 RTL test covers:

- initial epoch-1 candidate preparation;
- anchor acknowledgement before persistence rejected;
- wrong persistence state tag rejected;
- exact persistence acknowledgement accepted;
- wrong anchor CAS acknowledgement rejected;
- exact initial checkpoint commit;
- recovery from the newly committed checkpoint;
- restored spent authorization remains replay-rejected;
- fresh root authorization remains usable;
- same ref/epoch with wrong snapshot state tag rejected;
- concurrent anchor advance invalidates a prepared candidate;
- skipped checkpoint epoch rejected;
- persisted candidate followed by abort does not advance authority;
- exact non-empty-base CAS commit;
- epoch wrap rejected fail-closed.

Marker:

`CAPU_VCML_BRIDGE_V12_CHECKPOINT_COMMIT_PASS`

## Bounded formal envelope

The formal harness uses a reduced finite instance:

- checkpoint reference width: 3 bits;
- checkpoint epoch width: 3 bits;
- checkpoint state-tag width: 3 bits.

Bounded safety checks the commit-controller state machine. Separate cover verifies that successful and rejected trajectories are reachable.

Primary invariants:

```text
ANCHOR_COMMIT_REQUEST
  => CANDIDATE_PENDING
  && SNAPSHOT_DURABLE
  && BASE_STILL_CURRENT

STALE_BASE
  => NO_ANCHOR_COMMIT_REQUEST

CHECKPOINT_COMMIT_EVENT
  => EXACT_EXTERNAL_ACK
  && ANCHOR_COMMIT_REQUEST

NO_SNAPSHOT_PERSISTENCE
  => NO_ANCHOR_COMMIT_REQUEST

INVALID_OR_SKIPPED_EPOCH
  => NO_PREPARE_ACCEPT

EPOCH_EXHAUSTED
  => NO_PREPARE_ACCEPT

ABORT
  => NO_ANCHOR_COMMIT_REQUEST
  && NO_COMMIT_EVENT
```

## Scope / non-claims

CaPU v0.12 does **not** implement or prove:

- durable storage media;
- cryptographic checkpoint authentication;
- signature, MAC, TPM, TEE, certificate or attestation verification;
- checkpoint payload hashing inside hardware;
- correctness or persistence of the external anchor store;
- atomic compare-and-swap implementation inside the external store;
- crash consistency of filesystem, database or NVRAM internals;
- distributed consensus or multi-controller global serialization;
- globally unique checkpoint references;
- unbounded or parametric formal correctness;
- a complete CPU, ISA, cache or coherence proof.

The current anchor, snapshot-persistence acknowledgement and external anchor-CAS acknowledgement remain trusted interface boundaries.

The narrow v0.12 result is: **within the finite prototype, a checkpoint authority event can occur only after an exact prepared candidate has been acknowledged as persisted, its latched base anchor still matches the authoritative anchor, and the external anchor boundary acknowledges the exact base-to-candidate update; stale, skipped, early, mismatched and aborted paths fail closed.**

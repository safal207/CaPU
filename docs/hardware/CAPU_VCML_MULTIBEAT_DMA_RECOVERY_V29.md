# CaPU v0.29 — Partial / Multi-Beat DMA Recovery Authority

## Scope

v0.29 extends verified v0.28 from one DMA effect to one bounded four-beat DMA transaction.

Each beat carries an independent recovery state:

```text
UNISSUED | UNKNOWN | COMMITTED | NOT_COMMITTED
```

The transaction is ordered: beat `N` may issue only after every earlier beat is `COMMITTED`.

The target failure window is:

```text
beat0 -> COMMITTED
beat1 -> COMMITTED
beat2 -> UNKNOWN
beat3 -> UNISSUED
        ↓
      crash
        ↓
recovery must preserve:
  beat0/1: never replay
  beat2: require discriminating evidence
  beat3: no authority until beat2 resolves committed
```

## Per-beat authority

```text
COMMITTED
=> NO_REPLAY

UNKNOWN
=> EVIDENCE_REQUIRED
&& NO_REPLAY

NOT_COMMITTED
=> REPLAY_MAY_REOPEN_FOR_THIS_BEAT
&& ONLY_IF_PREFIX_COMMITTED

UNISSUED
=> ISSUE_MAY_OPEN_FOR_THIS_BEAT
&& ONLY_IF_PREFIX_COMMITTED
```

A committed prefix therefore behaves as an immutable externally visible prefix. Recovery never rolls the transaction back to its beginning.

## Durable evidence

v0.29 models three four-bit durable evidence maps bound to one exact command / execution epoch / effect identity:

- `issue_receipt_bitmap` — beat entered the unresolved in-flight window;
- `negative_receipt_bitmap` — exact evidence proved that beat did not commit;
- `completion_receipt_bitmap` — exact evidence proved that beat committed.

For each beat during restore, exact receipt precedence is:

```text
completion receipt
  > current issue receipt
  > durable negative receipt
  > checkpoint beat state
```

This preserves v0.28 convergence while applying it at beat granularity.

## Core invariants

```text
BEAT_COMMITTED(i)
=> !REPLAY_AUTHORITY(i)

BEAT_UNKNOWN(i)
=> EVIDENCE_REQUIRED(i)
&& !REPLAY_AUTHORITY(i)

REPLAY_AUTHORITY(i)
=> ALL_BEATS_BEFORE(i) == COMMITTED
&& STATE(i) IN {UNISSUED, NOT_COMMITTED}

EXACT_NEGATIVE_EVIDENCE(i)
=> STATE(i) := NOT_COMMITTED
&& NEGATIVE_RECEIPT(i)
&& ISSUE_RECEIPT(i) := 0

RETRY_ISSUE(i)
=> STATE(i) := UNKNOWN
&& NEGATIVE_RECEIPT(i) := 0
&& ISSUE_RECEIPT(i) := 1

EXACT_COMMITTED_EVIDENCE(i)
=> STATE(i) := COMMITTED
&& COMPLETION_RECEIPT(i)
&& ISSUE_RECEIPT(i) := 0

RETIRE
=> ALL_4_BEATS == COMMITTED
&& COMPLETION_RECEIPT_BITMAP == 1111
```

## Canonical binding

The v0.29 canonical payload domain-separates and binds:

- verified v0.28 canonical digest;
- live transaction identity;
- live four-beat state vector;
- checkpoint transaction identity;
- checkpoint four-beat state vector;
- issue / negative / completion receipt bitmaps;
- exact receipt transaction identity.

Mutation tests reject:

- reopening a committed prefix beat;
- foreign receipt identity;
- retaining old negative evidence while presenting a fresh unresolved retry;
- substituting a committed beat into a stale partial checkpoint under the unchanged commitment.

## Formal method

v0.29 deliberately uses bounded model checking.

- transaction beats: 4;
- command / execution epoch / effect identity width in formal instance: 2 bits each;
- safety depth: 22;
- cover depth: 36;
- solver: Z3 through pinned SymbiYosys;
- v0.28 bounded safety is regressed in the same workflow.

## Claim boundary

This is a bounded reduced-width one-command, one ordered four-beat DMA-transaction recovery-authority model.

It verifies per-beat replay containment, prefix ordering, durable per-beat issue/negative/committed evidence, stale partial-checkpoint reconciliation and all-beat retirement gating.

It does **not** prove real PCIe/CXL/NoC beat semantics, byte enables, cache-line tearing, burst splitting, device-memory ordering, IOMMU/cache/coherence, atomicity across persistence domains, arbitrary burst length, out-of-order beat completion, multiple outstanding DMA transactions, queue ordering, completion interrupts, evidence authenticity/durability implementation, production widths, liveness/fairness, or unbounded correctness.

A natural next boundary is out-of-order / overlapping DMA fragments, where the visible committed set is no longer a simple prefix.

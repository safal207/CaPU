# CaPU v0.30 — Out-of-Order / Overlapping DMA Fragment Recovery Authority

## Scope

v0.30 extends verified v0.29 beyond a simple committed prefix. It models one bounded transaction split into four independently resolving fragments whose byte-lane masks overlap:

```text
fragment0 -> lanes 0,1
fragment1 -> lanes 1,2
fragment2 -> lanes 2,3
fragment3 -> lanes 3,0
```

Fragments may issue and resolve out of order. The committed set therefore need not be a prefix.

Target failure state:

```text
fragment0 = COMMITTED
fragment1 = UNKNOWN
fragment2 = COMMITTED
fragment3 = UNKNOWN

committed set = {0,2}
```

Recovery must preserve the exact per-fragment authority state without inferring completion from neighboring fragments or from the currently visible byte values.

## Why completion evidence is not enough

With overlapping fragments, two facts are distinct:

```text
Did fragment F commit?
Which committed fragment currently determines byte lane L?
```

v0.30 therefore models both:

- per-fragment issue / negative / completion receipts;
- a durable per-byte `visible_owner` map.

A completion bitmap answers fragment completion. The owner map answers last-visible causal provenance for each modeled byte lane.

## Fragment states

Each fragment uses:

```text
UNISSUED | UNKNOWN | COMMITTED | NOT_COMMITTED
```

Unlike v0.29, no committed-prefix rule gates a different fragment. A fragment in `UNISSUED` or `NOT_COMMITTED` may issue independently. `UNKNOWN` remains evidence-gated and `COMMITTED` remains non-replayable.

## Durable ownership

When exact committed evidence is accepted for fragment `F`, every lane in `mask(F)` records `F` as its durable owner.

```text
COMMIT(F)
=> COMPLETION_RECEIPT(F)
&& for lane in mask(F): DURABLE_OWNER(lane) := F
```

Later overlapping commits may replace the owner of those lanes without erasing the earlier fragment's completion receipt.

On restore:

```text
fragment completion state:
completion receipt
> current issue receipt
> durable negative receipt
> checkpoint fragment state

byte ownership:
durable owner
> checkpoint owner
```

This prevents a stale checkpoint from rolling back the visible provenance of an overlapping committed write.

## Core invariants

```text
FRAGMENT_COMMITTED(F)
=> !REPLAY_AUTHORITY(F)

FRAGMENT_UNKNOWN(F)
=> EVIDENCE_REQUIRED(F)
&& !REPLAY_AUTHORITY(F)

REPLAY_AUTHORITY(F)
=> STATE(F) IN {UNISSUED, NOT_COMMITTED}

DURABLE_OWNER(L)=F
=> COMPLETION_RECEIPT(F)
&& L IN MASK(F)

EXACT_NEGATIVE_EVIDENCE(F)
=> STATE(F) := NOT_COMMITTED
&& NEGATIVE_RECEIPT(F)
&& ISSUE_RECEIPT(F) := 0

EXACT_COMMITTED_EVIDENCE(F)
=> STATE(F) := COMMITTED
&& COMPLETION_RECEIPT(F)
&& OWNER(mask(F)) := F

RESTORE
=> DURABLE_FRAGMENT_EVIDENCE_DOMINATES_STALE_FRAGMENT_STATE
&& DURABLE_OWNER_DOMINATES_STALE_CHECKPOINT_OWNER

RETIRE
=> ALL_4_FRAGMENTS == COMMITTED
&& COMPLETION_RECEIPT_BITMAP == 1111
```

## Canonical binding

The canonical v0.30 payload binds:

- verified v0.29 canonical digest;
- the fixed bounded fragment masks;
- live transaction identity;
- live fragment state set;
- checkpoint fragment state set;
- checkpoint owner map;
- issue / negative / completion receipt bitmaps;
- exact receipt transaction identity;
- durable owner-valid bitmap and owner map.

Semantic consistency additionally requires every durable owner to reference a fragment with completion evidence and a fragment mask that actually covers that lane.

## Formal method

v0.30 deliberately uses bounded model checking.

- fragments: 4;
- byte lanes: 4;
- formal transaction identity width: 2 bits;
- safety depth: 14;
- cover depth: 26;
- solver: Z3 through pinned SymbiYosys;
- verified v0.29 bounded safety is regressed in the same workflow.

## Claim boundary

This is a bounded reduced-width one-command, four-fragment, four-byte-lane recovery-authority model with fixed overlapping masks.

It verifies modeled out-of-order fragment completion, non-prefix committed sets, per-fragment replay/evidence authority, overlapping visible-owner provenance, stale checkpoint reconciliation and all-fragment retirement gating.

It does **not** prove production PCIe/CXL/NoC transactions, arbitrary addresses or fragment masks, byte values/data correctness, cache-line tearing, memory-model ordering, atomicity across persistence domains, multiple outstanding commands, arbitrary fragment counts, IOMMU/cache/coherence, DMA descriptor queues, completion interrupts, evidence authenticity/durability implementation, production widths, liveness/fairness or unbounded correctness.

A natural next boundary is multiple concurrent transactions whose overlapping fragments compete for the same visible lanes, requiring transaction-level ordering/provenance rather than one transaction-local owner map.

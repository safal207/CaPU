# CaPU v0.31 — Multiple Concurrent DMA Transactions / Queue Ordering Recovery Authority

## Scope

v0.31 extends verified v0.30 from one overlapping-fragment DMA transaction to two bounded concurrent DMA transactions in one queue epoch.

The modeled queue order is:

```text
TX0 (older) -> TX1 (younger)
```

Each transaction has two fragments. The fixed lane map is:

```text
TX0.F0 -> lanes 0,1
TX0.F1 -> lane 2
TX1.F0 -> lane 3
TX1.F1 -> lanes 1,2
```

This intentionally creates both kinds of concurrency:

- `TX1.F0` does not overlap the older transaction and may complete while TX0 is unresolved;
- `TX1.F1` overlaps both TX0 fragments and is fail-closed until the older overlapping effects are committed or TX0 is retired.

## Core distinction

v0.30 proved visible-owner provenance for one transaction. v0.31 separates **visibility authority** from **queue authority**:

```text
visible owner of lane
!=
permission for younger transaction to overtake older overlapping effects
```

The model therefore binds:

- exact TX0/TX1 slot identities;
- one queue epoch;
- transaction pending/retired state;
- per-fragment state;
- per-fragment issue/negative/completion evidence;
- durable visible-owner provenance;
- stale checkpoint state.

## Queue-order invariants

```text
YOUNGER_NONOVERLAP_FRAGMENT
=> MAY_EXECUTE_WHILE_OLDER_UNRESOLVED

YOUNGER_OVERLAP_FRAGMENT
&& OLDER_OVERLAP_NOT_COMMITTED
=> NO_ISSUE_AUTHORITY

YOUNGER_OVERLAP_ISSUE_ACCEPT
=> OLDER_OVERLAP_COMMITTED
   || OLDER_TX_RETIRED

TX1_RETIRE_ACCEPT
=> TX0_RETIRED
&& TX1_ALL_FRAGMENTS_COMMITTED

DURABLE_OWNER(LANE)=FRAGMENT
=> COMPLETION_RECEIPT(FRAGMENT)
&& LANE IN MASK(FRAGMENT)
```

Recovery/restore preserves queue semantics:

```text
RECOVERY
=> volatile transaction state cleared
&& durable fragment evidence preserved
&& durable owner provenance preserved
&& retired-order state preserved

RESTORE
=> durable completion/issue/negative evidence dominates stale fragment state
&& durable owner provenance dominates stale owner state
&& retired transactions cannot be reopened from a stale checkpoint
```

## Deterministic target path

```text
submit TX0
submit TX1
TX0.F0 -> UNKNOWN
TX1.F0 -> COMMITTED       # non-overlap concurrency allowed
TX1.F1 issue -> REJECT    # overlap with unresolved older effects
TX0.F0 -> COMMITTED
TX0.F1 -> COMMITTED
TX1.F1 issue -> UNKNOWN
checkpoint
recovery / restore
TX1.F1 -> NOT_COMMITTED
retry TX1.F1 -> COMMITTED
stale restore -> completion evidence + owner provenance win
retire TX1 before TX0 -> REJECT
retire TX0
retire TX1
```

## Formal method

v0.31 deliberately uses bounded model checking.

- transactions: 2;
- fragments: 2 per transaction;
- byte lanes: 4;
- transaction identity width in formal instance: 2 bits;
- safety depth: 12;
- cover depth: 24;
- solver: Z3 through pinned SymbiYosys;
- v0.30 deterministic/canonical and bounded-safety regressions run in the same workflow.

## Claim boundary

This is a bounded reduced-width two-transaction queue model with fixed fragment/lane overlap and one queue epoch.

It verifies modeled non-overlap concurrency, fail-closed younger overlap, exact queue-epoch/transaction identity binding, durable per-fragment completion evidence, visible-owner provenance, stale-checkpoint reconciliation, and ordered transaction retirement.

It does **not** prove arbitrary queue depth, arbitrary overlap graphs, real PCIe/CXL/NoC transport, payload values, cache/coherence/IOMMU behavior, arbitration fairness, dynamic priorities, cancellation, transaction dependencies beyond the modeled two-slot order, multiple queue epochs in flight, production persistence, evidence authenticity, production widths, liveness/fairness or unbounded correctness.

A natural next boundary is queue cancellation / priority reordering, where the authority relation itself changes while transactions remain in flight.

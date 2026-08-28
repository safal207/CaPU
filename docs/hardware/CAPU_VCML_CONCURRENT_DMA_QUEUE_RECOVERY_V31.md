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

Formal exploration exposed one additional distinction that must also be durable:

```text
fragment evidence
!=
transaction-slot existence / identity
```

A checkpoint may predate a younger transaction. If that younger transaction later produces durable fragment completion/owner evidence, recovery must not restore the old checkpoint as if the younger queue slot never existed. Otherwise the slot can be re-submitted and its old fragment evidence can become detached from the transaction identity that created it.

v0.31 therefore carries **durable transaction-slot authority**:

- two durable slot-valid bits;
- one durable queue epoch;
- exact per-slot command ID;
- exact per-slot execution epoch;
- exact per-slot effect ID.

A durable slot is not reusable within this modeled queue epoch. Restore reconstructs the live slot identity from the durable record before interpreting fragment receipts.

## Bound authority state

The model binds:

- exact TX0/TX1 live slot identities;
- durable TX0/TX1 slot identities;
- one durable queue epoch;
- transaction pending/retired state;
- per-fragment state;
- per-fragment issue/negative/completion evidence;
- durable visible-owner provenance;
- stale checkpoint transaction state and owner state.

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
&& DURABLE_TX_SLOT(OWNER_TX)
&& LANE IN MASK(FRAGMENT)
```

## Durable slot invariants

```text
TX_PENDING(tx)
|| TX_RETIRED(tx)
|| ANY_FRAGMENT_RECEIPT(tx)
=> DURABLE_TX_SLOT(tx)

DURABLE_TX_SLOT(tx)
=> LIVE_IDENTITY(tx) == DURABLE_IDENTITY(tx)

DURABLE_TX1
=> DURABLE_TX0

STALE_CHECKPOINT_PREDATES_TX1
&& DURABLE_TX1
=> RESTORE_TX1_FROM_DURABLE_SLOT
&& NO_TX1_SLOT_RESUBMIT

RECOVERY
=> DURABLE_TX_SLOTS_PRESERVED
&& DURABLE_FRAGMENT_EVIDENCE_PRESERVED
&& DURABLE_OWNER_PROVENANCE_PRESERVED
```

## Recovery / restore precedence

```text
transaction identity:
  durable transaction-slot record
  > stale checkpoint slot identity

fragment state:
  durable completion receipt
  > current issue receipt
  > durable negative receipt
  > checkpoint fragment state

visible lane owner:
  durable owner provenance
  > checkpoint owner state
```

A retired durable transaction cannot be reopened by a stale checkpoint.

## Deterministic target path

```text
submit TX0
checkpoint                         # checkpoint predates TX1
submit TX1
TX0.F0 -> UNKNOWN
TX1.F0 -> COMMITTED                # non-overlap concurrency allowed
recovery
restore pre-TX1 checkpoint
  -> durable TX1 slot wins
  -> TX1 identity/pending reconstructed
  -> TX1 completion/owner evidence preserved
re-submit TX1 -> REJECT
TX1.F1 issue -> REJECT             # overlap with unresolved older effects
TX0.F0 -> COMMITTED
TX0.F1 -> COMMITTED
TX1.F1 issue -> UNKNOWN
checkpoint
recovery / restore
TX1.F1 -> NOT_COMMITTED
retry TX1.F1 -> COMMITTED
stale restore -> completion evidence + owner provenance + durable slots win
retire TX1 before TX0 -> REJECT
retire TX0
retire TX1
```

## Verification history

Two pre-verification failures materially improved this milestone:

1. An initial formal run stopped during Yosys elaboration because a conditional nested-loop variable in the fixed overlap gate inferred a latch. The fixed two-transaction overlap relation was rewritten explicitly. No solver counterexample existed in that run.
2. The next formal run reached bounded solving and found a genuine step-9 counterexample: a checkpoint captured before TX1 could later erase the TX1 slot on restore while TX1 fragment completion/owner evidence survived. The apparently free slot could then be re-submitted, clearing completion receipts while old owner provenance remained. v0.31 now closes this identity-resurrection / evidence-split path with durable transaction-slot authority.

Only a later fully green exact-head run is authoritative for the verified milestone.

## Formal method

v0.31 deliberately uses bounded model checking.

- transactions: 2;
- fragments: 2 per transaction;
- byte lanes: 4;
- queue epochs in flight: 1;
- transaction identity width in formal instance: 2 bits;
- safety depth: 12;
- cover depth: 24;
- solver: Z3 through pinned SymbiYosys;
- v0.30 deterministic/canonical and bounded-safety regressions run in the same workflow.

## Claim boundary

This is a bounded reduced-width two-transaction queue model with fixed fragment/lane overlap, one queue epoch and non-reusable durable transaction slots within that epoch.

It verifies modeled non-overlap concurrency, fail-closed younger overlap, exact queue-epoch/transaction-slot identity binding, durable transaction-slot recovery, durable per-fragment completion evidence, visible-owner provenance, stale-checkpoint reconciliation, rejection of slot identity resurrection, and ordered transaction retirement.

It does **not** prove arbitrary queue depth, slot reuse, arbitrary overlap graphs, real PCIe/CXL/NoC transport, payload values, cache/coherence/IOMMU behavior, arbitration fairness, dynamic priorities, cancellation, transaction dependencies beyond the modeled two-slot order, multiple queue epochs in flight, production persistence, evidence authenticity, production widths, liveness/fairness or unbounded correctness.

A natural next boundary is queue cancellation / priority reordering, where the authority relation itself changes while transactions remain in flight.

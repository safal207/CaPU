# CaPU v0.28 — Durable Negative Completion Evidence / UNKNOWN Convergence

## Purpose

v0.27 proved a fail-closed rule for accelerator DMA completion uncertainty: an issued-but-unresolved effect is `UNKNOWN`, and `UNKNOWN` grants neither replay nor retirement authority until exact evidence resolves the outcome.

v0.28 closes the next bounded liveness gap. Exact `NOT_COMMITTED` evidence is now represented by a durable negative receipt so that a later crash cannot erase the resolved-negative fact and strand recovery behind a stale `UNKNOWN` checkpoint.

## State extension

The v0.28 model adds one durable negative completion receipt:

```text
negative_receipt_valid
negative_receipt_command_id
negative_receipt_execution_epoch
negative_receipt_effect_id
```

The receipt is bound to the same exact command / execution-epoch / effect identity as the issue and positive-completion receipts.

## Recovery precedence

For a restored checkpoint, evidence authority is ordered:

```text
matching COMMITTED receipt
    → COMMITTED

else matching NEGATIVE receipt
    → NOT_COMMITTED
    → replay may reopen

else matching ISSUE witness or checkpoint UNKNOWN
    → UNKNOWN
    → no replay / no retire

else
    → exact checkpoint state
```

This means a stale checkpoint that says `UNKNOWN` cannot override later durable evidence proving `NOT_COMMITTED`.

## Retry consumption rule

A negative receipt authorizes only the transition back to a new issue attempt. When `DMA_ISSUE_ACCEPT` occurs, the matching negative receipt is consumed while a fresh issue witness is created atomically.

```text
negative receipt for resolved attempt
        ↓
DMA retry issue
        ↓
negative receipt cleared
fresh issue witness created
completion = UNKNOWN
```

This prevents old negative evidence from leaking across the next in-flight attempt.

## Core bounded invariants

```text
UNKNOWN
=> NO_DMA_REPLAY_AUTHORITY
&& NO_RETIRE_AUTHORITY

EXACT_EVIDENCE(NOT_COMMITTED)
=> DURABLE_NEGATIVE_RECEIPT
&& COMPLETION == NOT_COMMITTED
&& ISSUE_WITNESS_CONSUMED

RECOVERY
=> NEGATIVE_RECEIPT_PRESERVED

RESTORE(stale UNKNOWN + matching negative receipt)
=> NOT_COMMITTED
&& !EVIDENCE_REQUIRED
&& REPLAY_MAY_REOPEN_IF_NO_NEW_BARRIER

DMA_RETRY_ACCEPT
=> NEGATIVE_RECEIPT_CONSUMED
&& FRESH_ISSUE_WITNESS
&& COMPLETION == UNKNOWN

FRESH_UNKNOWN_ATTEMPT
=> OLD_NEGATIVE_EVIDENCE_CANNOT_AUTHORIZE_REPLAY

MATCHING_COMPLETION_RECEIPT
=> COMMITTED_PRECEDENCE
```

## Canonical binding

The canonical v0.28 checkpoint payload extends the verified v0.27 digest with live/checkpoint completion state plus issue, negative and committed completion receipts. Mutation tests reject:

- deleting a durable negative receipt while rewriting state back to `UNKNOWN`;
- substituting a foreign negative receipt;
- combining an old negative receipt with a fresh issue witness under the unchanged commitment.

## Verification boundary

The formal instance is deliberately reduced-width and bounded. It models one command, one DMA effect, one active issue witness, one durable negative receipt and one durable committed-completion receipt.

It does **not** prove:

- how negative completion evidence is obtained from a real device;
- physical durability or authenticity of receipts;
- multiple outstanding accelerator commands;
- attempt IDs across non-atomic persistence domains;
- PCIe/CXL/NoC transport;
- partial/multi-beat DMA visibility;
- IOMMU/cache/coherence;
- queue ordering or interrupts;
- liveness under permanently unavailable evidence;
- production widths or unbounded correctness.

The model assumes the transition that consumes a negative receipt and creates the next issue witness is atomic inside the modeled persistence authority. A later milestone should split those persistence actions if the target platform cannot provide that atomicity.

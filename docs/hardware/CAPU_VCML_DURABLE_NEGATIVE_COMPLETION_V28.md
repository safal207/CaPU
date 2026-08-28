# CaPU v0.28 — Durable Negative Completion Evidence / UNKNOWN Convergence

## Scope

v0.28 extends verified v0.27 with a durable negative-completion receipt for the case where exact discriminating evidence establishes that an issued DMA effect did **not** commit.

The purpose is convergence across a second crash. v0.27 safely preserved `UNKNOWN`, but a later stale `UNKNOWN` checkpoint could remain fail-closed if the negative resolution itself was not durable. v0.28 binds that negative outcome to durable authority.

```text
DMA issue
→ UNKNOWN
→ exact NOT_COMMITTED evidence
→ durable negative receipt
→ crash
→ stale UNKNOWN checkpoint restore
→ negative receipt wins
→ NOT_COMMITTED
→ replay may reopen
```

## Authority precedence on restore

For the exact checkpoint command / execution epoch / effect identity:

```text
matching completion receipt
  > matching current issue receipt
  > matching durable negative receipt
  > checkpoint UNKNOWN
  > checkpoint recorded state
```

This ordering prevents an old negative receipt from overriding a newer unresolved retry. A successful retry issue consumes the old negative receipt and creates a new issue witness, returning the effect to `UNKNOWN`.

## Core invariants

```text
UNKNOWN
=> NO_DMA_REPLAY_AUTHORITY
&& NO_RETIRE_AUTHORITY
&& EVIDENCE_REQUIRED

EXACT_EVIDENCE(NOT_COMMITTED)
=> DURABLE_NEGATIVE_RECEIPT
&& NOT_COMMITTED
&& OLD_ISSUE_WITNESS_CONSUMED

RECOVERY
=> NEGATIVE_RECEIPT_PRESERVED

RESTORE(STALE_UNKNOWN + MATCHING_NEGATIVE_RECEIPT)
=> NOT_COMMITTED
&& !EVIDENCE_REQUIRED
&& REPLAY_MAY_REOPEN_IF_NO_NEW_BARRIER

RETRY_ISSUE
=> OLD_NEGATIVE_RECEIPT_CONSUMED
&& UNKNOWN
&& NEW_ISSUE_WITNESS

MATCHING_COMPLETION_RECEIPT
=> COMMITTED
&& STALE_UNKNOWN_CANNOT_RECREATE_REPLAY_AUTHORITY
```

## Canonical binding

The v0.28 canonical payload domain-separates and binds:

- verified v0.27 digest;
- live command identity and completion state;
- checkpoint identity and completion state;
- durable issue witness;
- durable negative completion receipt;
- durable committed completion receipt.

Mutation tests specifically reject:

- removal of the negative receipt while retaining a replayable state;
- a foreign negative receipt identity;
- retaining old negative evidence across a new unresolved retry under the same commitment.

## Formal method

v0.28 uses reduced-width bounded model checking, not an inductive or unbounded correctness claim.

- command / execution epoch / effect identity width: 2 bits each;
- safety depth: 18;
- cover depth: 28;
- solver: Z3 through pinned SymbiYosys;
- v0.27 bounded safety is regressed in the same workflow.

## Claim boundary

This is a bounded one-command / one-DMA-effect model of durable negative completion authority and recovery convergence.

The negative receipt, issue witness and committed completion receipt are modeled as authoritative durable evidence. This milestone does **not** prove how real hardware or software obtains, authenticates, persists or orders those receipts; PCIe/CXL/NoC semantics; device-memory visibility; IOMMU/cache/coherence; partial or multi-beat DMA writes; multiple outstanding commands; queue ordering; completion interrupts; liveness/fairness beyond the modeled convergence path; production widths; or unbounded correctness.

The next natural boundary is partial / multi-beat DMA recovery, where some externally visible beats may have committed while later beats remain unresolved.

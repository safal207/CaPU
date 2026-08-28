# CaPU v0.27 — In-Flight DMA Completion Uncertainty

CaPU v0.27 extends the verified v0.26 accelerator command / DMA recovery model into the failure window where a DMA command was issued but completion is not yet known when recovery begins.

## Core problem

```text
command pending
→ pre-issue checkpoint says NOT_COMMITTED
→ DMA issue accepted
→ device may or may not commit the external effect
→ recovery before completion evidence exists
→ stale checkpoint restore
```

Treating the stale checkpoint as authoritative would be unsafe: replay can duplicate an effect that actually committed, while blindly marking the effect spent can lose an effect that did not commit.

v0.27 therefore models three completion states:

```text
NOT_COMMITTED
UNKNOWN
COMMITTED
```

An accepted DMA issue moves the command to `UNKNOWN` and creates a modeled durable issue witness. Recovery clears volatile execution state but preserves the checkpoint and durable evidence. Restoring a pre-issue checkpoint while the matching issue witness exists reconstructs `UNKNOWN`, not `NOT_COMMITTED`.

## Authority rule

```text
UNKNOWN
=> NO_DMA_REPLAY_AUTHORITY
&& NO_RETIRE_AUTHORITY
&& REQUIRE_DISCRIMINATING_EVIDENCE
```

Exact discriminating evidence resolves the uncertainty:

- `NOT_COMMITTED` evidence clears the outstanding issue witness and may reopen replay authority;
- `COMMITTED` evidence creates a modeled durable completion receipt, marks the effect spent, permanently closes replay authority for that effect, and permits exact retirement.

A later stale checkpoint cannot override a matching completion receipt: `COMMITTED` wins for external-effect authority.

## Modeled identity

```text
command_id + execution_epoch + effect_id
```

Issue and completion evidence are accepted only for the exact live identity.

## Checkpoint commitment

The v0.27 canonical SHA-256 commitment domain-separates and binds the verified v0.26 digest plus:

- live command identity;
- DMA-issued state;
- tri-state completion state;
- evidence-required state;
- checkpoint identity and completion state;
- outstanding issue witness identity;
- committed completion receipt identity.

This prevents a mixed `UNKNOWN → NOT_COMMITTED` reconstruction from acquiring replay authority under an unchanged commitment.

## Safety invariants

```text
DMA_ISSUE_ACCEPT
=> EXACT_COMMAND_EPOCH_EFFECT
&& PRIOR_STATE == NOT_COMMITTED
&& DMA_REPLAY_AUTHORITY

DMA_ISSUE_ACCEPT
=> NEXT_STATE == UNKNOWN
&& EVIDENCE_REQUIRED
&& ISSUE_WITNESS_EXISTS

UNKNOWN
=> !DMA_REPLAY_AUTHORITY
&& !RETIRE_AUTHORITY

RECOVERY
=> VOLATILE_COMMAND_STATE_CLEARED
&& CHECKPOINT_PRESERVED
&& ISSUE_WITNESS_PRESERVED
&& COMPLETION_RECEIPT_PRESERVED

RESTORE(pre-issue checkpoint + matching issue witness)
=> UNKNOWN
&& EVIDENCE_REQUIRED
&& !DMA_REPLAY_AUTHORITY

EXACT_EVIDENCE(NOT_COMMITTED)
=> NOT_COMMITTED
&& REPLAY_MAY_REOPEN

EXACT_EVIDENCE(COMMITTED)
=> COMMITTED
&& COMPLETION_RECEIPT_EXISTS
&& EFFECT_SPENT
&& !DMA_REPLAY_AUTHORITY

MATCHING_COMPLETION_RECEIPT
=> STALE_CHECKPOINT_CANNOT_RECREATE_REPLAY_AUTHORITY
```

## Claim boundary

This is a **bounded reduced-width one-command / one-DMA-effect uncertainty model** layered on verified v0.26. The issue witness and discriminating completion evidence are modeled as authoritative durable evidence.

It does not prove how hardware obtains trustworthy completion evidence, device-memory visibility, PCIe/CXL/NoC transaction semantics, IOMMU/cache/coherence, partial DMA writes, scatter/gather descriptors, multiple outstanding commands/effects, command queue ordering, completion interrupts, receipt authenticity/durability, liveness/fairness, production widths, or unbounded correctness.

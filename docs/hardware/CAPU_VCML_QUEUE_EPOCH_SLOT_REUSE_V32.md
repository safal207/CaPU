# CaPU vCML Queue-Epoch Slot Reuse v0.32

v0.32 extends verified v0.31 by allowing a modeled accelerator transaction slot to be reclaimed and reused across exact successor queue epochs without allowing stale prior-epoch evidence to recreate authority.

## Threat

v0.31 deliberately made transaction slots non-reusable inside one queue epoch. Once slot reuse is introduced, the same numeric slot can identify a different transaction later:

```text
epoch E   : slot 0 -> transaction A -> retire
epoch E+1 : slot 0 -> transaction B

late evidence from E
+ same numeric slot
+ optionally the same command/execution/effect IDs
=> MUST NOT mutate transaction B
```

The queue epoch is therefore part of the exact authority identity, not ambient scheduling metadata.

## Bounded model

- one reclaimable transaction slot;
- reduced formal identity width of two bits;
- one modeled effect with states `UNISSUED / UNKNOWN / COMMITTED / NOT_COMMITTED`;
- durable issue, negative and completion receipts for the current active slot;
- one stale checkpoint that may predate the reused slot;
- durable last-retired queue epoch;
- exact-successor epoch reuse only;
- epoch-namespace exhaustion fails closed rather than wrapping.

## Authority identity

```text
queue_epoch
+ slot
+ command_id
+ execution_epoch
+ effect_id
= exact transaction authority identity
```

The numeric slot is fixed in this bounded model. Reuse is authorized only by exact queue-epoch succession.

## Core invariants

```text
SLOT_REUSE_ACCEPT
&& LAST_RETIRED_VALID
=> NEW_QUEUE_EPOCH == LAST_RETIRED_QUEUE_EPOCH + 1
&& NO_EPOCH_WRAP

CURRENT_SLOT_VALID
=> LIVE_IDENTITY == DURABLE_CURRENT_IDENTITY

OLD_EPOCH_EVIDENCE
&& CURRENT_SLOT_VALID
=> REJECT
&& NO_CURRENT_EFFECT_AUTHORITY_MUTATION

STALE_CHECKPOINT_PREDATING_CURRENT_EPOCH
&& DURABLE_CURRENT_SLOT_VALID
=> DURABLE_CURRENT_SLOT_WINS

RETIRED_SLOT
=> STALE_CHECKPOINT_CANNOT_RESURRECT_PENDING_SLOT

QUEUE_EPOCH_EXHAUSTED
=> NO_NEW_SLOT_AUTHORITY
```

## Deterministic trajectory

The executable trajectory deliberately reuses the same command, execution and effect IDs across epochs. Only `queue_epoch` changes:

```text
epoch 2 submit
→ capture stale epoch-2 checkpoint
→ issue / commit / retire
→ same-epoch reuse rejected
→ epoch 3 exact-successor reuse accepted
→ issue epoch-3 effect -> UNKNOWN
→ late epoch-2 completion evidence arrives
→ rejected + quarantined
→ recovery
→ stale epoch-2 checkpoint restore
→ durable epoch-3 slot + issue witness win
→ exact epoch-3 negative evidence -> replayable
→ retry / commit / retire
→ exact-successor reuse continues to epoch 15
→ attempted 15 -> 0 epoch wrap rejected fail-closed
```

## Verification target

- deterministic Icarus trajectory;
- canonical SHA-256 mutation and consistency tests;
- v0.31 deterministic + canonical regression;
- bounded safety BMC depth 14;
- reachability cover depth 28;
- v0.31 bounded-safety regression;
- Core RTL Smoke and Validate Examples on the same exact head.

## Claim boundary

This is a bounded reduced-width one-slot lifecycle model. It verifies one modeled slot's exact-successor reuse across queue epochs, rejection/quarantine of stale prior-epoch evidence, stale-checkpoint dominance by the current durable slot identity, retirement history preservation and fail-closed queue-epoch exhaustion.

It does **not** prove arbitrary queue depth, multiple reusable slots, asynchronous free lists, epoch wrap safety, persistent monotonic epochs across real power loss, cancellation, arbitrary transaction reordering, arbitrary overlap graphs, production PCIe/CXL/NoC transport, payload-value semantics, byte tearing, IOMMU/cache/coherence, evidence authenticity, production widths, liveness/fairness or unbounded correctness.

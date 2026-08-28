# CaPU vCML Accelerator Command / DMA Recovery Authority v0.26

## Goal

v0.26 starts the AI-accelerator execution/recovery layer above the verified CaPU hardware trust stack.

The bounded model asks one narrow question:

> If an accelerator command has already produced one externally committed DMA effect, can recovery of an older checkpoint authorize that same effect again?

The answer in this model is **no**.

## Causal model

```text
command submit
  ↓
pre-effect checkpoint
  ↓
authorized DMA issue
  ↓
external DMA effect commit
  ↓
durable effect receipt
  ↓
recovery
  ↓
restore older checkpoint (effect_spent = 0)
  ↓
receipt/checkpoint conflict
  ↓
RECONCILE_REQUIRED
  ↓
no DMA replay authority
  ↓
exact reconcile marks effect_spent = 1
  ↓
command may retire, effect may not re-execute
```

## Modeled authoritative identity

A modeled accelerator effect is identified by:

```text
command_id + execution_epoch + effect_id
```

The v0.26 canonical commitment additionally binds the verified v0.25 digest, live command state, DMA-issued/spent state, stored checkpoint state, durable receipt state and reconciliation state.

## Safety invariants

```text
DMA_ISSUE_ACCEPT
=> EXACT_COMMAND_EPOCH_EFFECT
&& DMA_REPLAY_AUTHORITY
&& !EFFECT_SPENT
&& !MATCHING_DURABLE_RECEIPT

DMA_COMMIT_ACCEPT
=> PRIOR_AUTHORIZED_ISSUE
&& EXACT_COMMAND_EPOCH_EFFECT
&& !PRIOR_RECEIPT

RECOVERY
=> VOLATILE_ACCELERATOR_STATE_CLEARED
&& CHECKPOINT_PRESERVED
&& DURABLE_RECEIPT_PRESERVED

RESTORE_OLD_CHECKPOINT
&& MATCHING_DURABLE_RECEIPT
&& CHECKPOINT_EFFECT_SPENT == 0
=> RECONCILE_REQUIRED
&& !DMA_REPLAY_AUTHORITY

RECONCILE_ACCEPT
=> EXACT_DURABLE_RECEIPT
&& EFFECT_SPENT
&& !DMA_REPLAY_AUTHORITY

EFFECT_SPENT
=> SAME_EFFECT_CANNOT_BE_AUTHORIZED_AGAIN
```

## Threat model

The primary adversarial trajectory is the classic external-side-effect recovery window:

```text
checkpoint: effect not spent
→ DMA effect commits
→ durable receipt exists
→ crash/recovery before a newer checkpoint
→ stale checkpoint restored
→ naive replay would execute DMA twice
```

v0.26 fails closed by requiring reconciliation against the durable receipt before the restored command can retire, while DMA replay authority remains closed throughout.

## Verification plan

The exact-head workflow requires:

- SystemVerilog compile;
- deterministic stale-checkpoint / durable-receipt recovery trajectory;
- canonical SHA-256 mutation and mixed-state tests;
- v0.25 deterministic and canonical regressions;
- bounded v0.26 safety proof;
- bounded v0.26 reachability proof with VCD witnesses;
- v0.25 bounded-safety regression;
- Core RTL Smoke;
- Validate Examples.

## Claim boundary

This is a **bounded reduced-width one-command / one-DMA-effect recovery-authority model** layered above the verified v0.25 trust stack.

It models an authoritative durable effect receipt as an input to recovery semantics. It does **not** prove the durability or authenticity of the receipt itself, asynchronous in-flight DMA ambiguity before receipt creation, arbitrary command queues, multiple concurrent effects, production DMA engines, accelerator firmware, IOMMU behavior, cache/coherence ordering, device-memory contents, completion interrupts, cryptographic receipt authenticity, durable-media correctness, production widths, liveness/fairness, or unbounded correctness.

# ASTRA–CaPU v1 Execution Contract

Status: draft executable contract.

This document turns the ASTRA–CaPU reference architecture into the smallest implementation surface that can be tested in software and mirrored in RTL.

## 1. Objects

### IntentEnvelope

```json
{
  "schema": "capu.astra.intent.v1",
  "intent_id": "intent-001",
  "actor_id": "agent-1",
  "cause_id": "cause-001",
  "parent_state_digest": "sha256:...",
  "memory_context_digest": "sha256:...",
  "policy_digest": "sha256:...",
  "requested_effect": {
    "kind": "accelerator_command",
    "target": "device-0",
    "operation": "dma_write"
  },
  "constraints": {
    "max_attempts": 1,
    "expiry_epoch": 42
  }
}
```

### AuthorityTicket

```json
{
  "schema": "capu.astra.authority-ticket.v1",
  "authority_id": "authority-001",
  "intent_id": "intent-001",
  "authority_incarnation": 7,
  "queue_epoch": 12,
  "slot_id": 0,
  "command_id": "command-001",
  "execution_epoch": 3,
  "effect_id": "effect-001",
  "checkpoint_digest": "sha256:...",
  "policy_digest": "sha256:...",
  "decision": "COMMITTED"
}
```

### OutcomeEvidence

```json
{
  "schema": "capu.astra.outcome-evidence.v1",
  "authority_id": "authority-001",
  "authority_incarnation": 7,
  "queue_epoch": 12,
  "command_id": "command-001",
  "effect_id": "effect-001",
  "outcome_state": "COMMITTED",
  "evidence_digest": "sha256:..."
}
```

Allowed `outcome_state` values:

```text
NOT_DISPATCHED
DISPATCHED_UNKNOWN
NOT_COMMITTED
COMMITTED
CONFLICT
```

### ProofReceipt

```json
{
  "schema": "capu.astra.proof-receipt.v1",
  "receipt_id": "receipt-001",
  "intent_id": "intent-001",
  "authority_id": "authority-001",
  "authority_incarnation": 7,
  "queue_epoch": 12,
  "command_id": "command-001",
  "effect_id": "effect-001",
  "pre_state_digest": "sha256:...",
  "outcome_state": "COMMITTED",
  "outcome_evidence_digest": "sha256:...",
  "post_state_digest": "sha256:...",
  "parent_receipt_digest": "sha256:...",
  "receipt_digest": "sha256:..."
}
```

## 2. State machine

```text
PROPOSED
  -> GROUNDED
  -> AUTHORIZED
  -> COMMITTED
  -> DISPATCHED
  -> OBSERVED
  -> RECONCILED
  -> SEALED
```

Failure branches:

```text
PROPOSED / GROUNDED / AUTHORIZED -> REJECTED or HELD
DISPATCHED -> DISPATCHED_UNKNOWN
OBSERVED -> CONFLICT
UNKNOWN / CONFLICT -> RECONCILIATION_REQUIRED
```

## 3. Dispatch rule

```text
DISPATCH_ACCEPT
<=> authority_ticket.decision == COMMITTED
&& exact identity matches
&& checkpoint is accepted
&& policy is current
&& authority namespace is live
```

## 4. Recovery rule

```text
DURABLE_EXACT_RECEIPT
> stale checkpoint state

DURABLE_CURRENT_AUTHORITY_IDENTITY
> stale slot identity

UNKNOWN
> guessed success
UNKNOWN
> blind replay
```

The `>` symbol means “dominates during reconciliation,” not numeric comparison.

## 5. Memory update rule

```text
MEMORY_UPDATE_ACCEPT
<=> outcome_state == COMMITTED
&& proof receipt is exact
&& post-state parent equals accepted pre-state
```

A memory record derived only from dispatch, timeout, or an agent’s own claim must not become trusted outcome memory.

## 6. Negative controls

A complete fixture set must include:

- missing committed authority;
- stale authority incarnation;
- stale queue epoch;
- same numeric IDs under a foreign incarnation;
- stale checkpoint predating the current slot;
- duplicate dispatch;
- committed effect with lost receipt;
- negative receipt consumed by a fresh retry;
- conflicting completion evidence;
- false-success agent report without external outcome evidence;
- memory update before reconciliation.

## 7. Reference adapter target

The first adapter should bridge:

```text
existing CaPU action boundary
-> IntentEnvelope
-> AuthorityTicket
-> synthetic accelerator executor
-> OutcomeEvidence
-> ProofReceipt
-> memory update gate
```

The adapter must emit one deterministic evidence bundle containing inputs, decisions, transitions, receipts, hashes, and negative-control results.

## 8. RTL mirror

The first synthesizable mirror should implement only:

```text
exact authority identity compare
commit-before-dispatch gate
outcome uncertainty latch
receipt-based replay closure
stale-incarnation rejection
checkpoint/recovery barrier
```

It should not claim tensor execution, production DMA, cryptographic receipt verification, or arbitrary queue depth.

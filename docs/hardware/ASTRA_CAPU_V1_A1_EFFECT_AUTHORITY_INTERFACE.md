# ASTRA–CaPU v1.0-A1 — Accelerator Effect Authority Interface

Status: executable implementation-neutral reference contract.

## Purpose

A1 is the first executable slice of the ASTRA–CaPU v1 reference architecture. It does not accelerate tensors. It controls whether an accelerator command or DMA-like effect has authority to dispatch, retry, retire, and update trusted memory after a crash or ambiguous completion.

The boundary is:

```text
intent/state/policy commitments
+ queue incarnation / epoch / slot
+ command / attempt / effect identity
+ checkpoint commitment
+ durable outcome evidence
=
exact effect authority
```

## Core rule

```text
UNKNOWN
=> NO BLIND REPLAY
&& NO RETIRE
&& NO SUCCESS CLAIM
&& NO TRUSTED MEMORY UPDATE
```

Absence of completion evidence is not evidence of non-completion.

## Contract objects

### `AuthorityIdentity`

```text
queue_incarnation
queue_epoch
slot_id
command_id
attempt_id
effect_id
```

Every field participates in authority identity. Reusing the same numeric command or effect ID does not transfer authority across incarnation, epoch, slot, or attempt boundaries.

### `AuthorityTicket`

Binds:

```text
authority_id
actor_id
intent_commitment
state_commitment
policy_commitment
checkpoint_commitment
AuthorityIdentity
stage
receipts
```

### `OutcomeEvidence`

Carries an exact identity and one bounded outcome:

```text
NOT_COMMITTED
COMMITTED
CONFLICT
```

No evidence is accepted for a different authority ID or any mismatching identity dimension.

### `ProofReceipt`

A canonical SHA-256 receipt seals the exact completed authority record after committed outcome evidence and retirement.

## Lifecycle

```text
PROPOSED
  -> GROUNDED
  -> AUTHORIZED
  -> COMMITTED
  -> DISPATCHED / UNKNOWN
      -> exact NOT_COMMITTED -> RECONCILED_NOT_COMMITTED -> next attempt
      -> exact COMMITTED     -> RECONCILED_COMMITTED     -> SEALED
      -> exact CONFLICT      -> CONFLICT / fail closed
```

## Recovery rule

A potentially stale checkpoint cannot erase a newer durable issue witness or durable completion receipt for the same authority. The reference `recover(checkpoint, durable)` operation returns the exact durable record when its identity is equal or newer; it rejects cross-authority mixing and older durable identity.

```text
stale pre-dispatch checkpoint
+ durable issue witness
=> UNKNOWN, not replayable

stale pre-dispatch checkpoint
+ durable completion receipt
=> COMMITTED outcome, not replayable
```

## Executable artifacts

```text
tools/astra_capu_effect_authority_a1.py
tests/test_astra_capu_effect_authority_a1.py
schemas/hardware/astra-capu-effect-authority-v1.0-a1.schema.json
examples/hardware/astra-capu-v1-a1-valid.json
examples/hardware/astra-capu-v1-a1-adversarial.json
```

Run:

```bash
python3 -m unittest -v tests/test_astra_capu_effect_authority_a1.py
```

## Verified test classes

The deterministic suite covers:

- committed dispatch -> exact committed evidence -> retirement -> proof receipt;
- UNKNOWN blocks replay, retirement and sealing;
- dispatch before commitment rejects;
- foreign authority ID rejects;
- stale/foreign incarnation, epoch, slot, command, attempt or effect identity rejects;
- exact negative evidence authorizes only the next attempt;
- old negative evidence cannot authorize or resolve the next attempt;
- conflicting evidence is fail closed;
- stale checkpoints cannot override durable UNKNOWN or COMMITTED evidence;
- canonical commitments change when any authority dimension changes.

## Relation to verified v0.26–v0.33

A1 consolidates already explored bounded mechanisms into an implementation-neutral interface:

```text
v0.26-v0.29  effect uncertainty and per-attempt evidence
v0.30-v0.31  overlapping/concurrent transaction authority
v0.32-v0.33  epoch reuse, wrap and authority incarnation
A1           one stable accelerator-facing authority contract
```

A1 does not replace the individual formal proofs. It provides the composition target that a later synthesizable controller, runtime adapter, and FPGA demonstrator can implement.

## Claim boundary

This is a deterministic software reference contract and schema. It does not claim production transport, cryptographic evidence authenticity, a real GPU/TPU/NPU command queue, FPGA implementation, silicon performance, PPA, arbitrary concurrency, liveness/fairness, or unbounded correctness.

The next milestone is **A2 — command-queue adapter and crash-injection demonstrator**, where this exact interface is attached to a synthetic accelerator queue and compared against an unsafe retry baseline.

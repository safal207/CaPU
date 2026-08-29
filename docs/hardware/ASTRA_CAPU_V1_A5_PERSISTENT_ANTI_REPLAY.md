# ASTRA–CaPU v1.0-A5 — Restart-Safe Persistent Anti-Replay Frontier

## Purpose

A4 physically gates a synthetic accelerator command with an exact committed authority token, but its `attempt_spent` bit is volatile. Resetting the shim and reloading the same token is therefore outside the A4 claim.

A5 adds a small **persistent attempt frontier interface**. The frontier is advanced before a command reaches the effect device:

```text
exact committed authority
+ exact persistent lineage
+ attempt == persistent_next_attempt
        ↓
persistent frontier advances to attempt + 1
        ↓
command_forward
        ↓
external effect may occur
```

After a logic restart, the volatile shim state is cleared while the frontier and synthetic external effect count remain. Reloading the old attempt then fails closed because its attempt ID no longer equals the durable frontier.

## Exact authority identity

The persistent lineage binds:

```text
authority_tag
+ queue_incarnation
+ queue_epoch
+ slot_id
+ command_id
+ effect_id
```

The anti-replay frontier adds `persistent_next_attempt`. A command can advance the frontier only when its full lineage matches and its attempt ID is exactly the current frontier.

## Restart discriminator

```text
persistent_next_attempt = 0
attempt 0 committed authority
        ↓
frontier advance 0 → 1
        ↓
command 0 reaches device
        ↓
logic reset
        ↓
volatile attempt_spent = 0
persistent_next_attempt = 1
external effect count = 1
        ↓
reload attempt 0
        ↓
REJECT_PERSISTENT_FRONTIER
        ↓
no second effect
```

A successor token with attempt ID 1 is accepted, advances the frontier to 2, and may reach the device.

## Modules

- `astra_capu_persistent_frontier_store_a5.sv` — synthesizable single-lineage retention-domain model with explicit cold reset, provision-once lineage, and monotonic no-wrap attempt advance.
- `astra_capu_persistent_authority_shim_a5.sv` — volatile exact-token authority state plus commit-before-effect frontier gate.
- `astra_capu_persistent_authorized_effect_device_a5.sv` — composes the A5 shim and frontier store with the A3 synthetic effect counter.

## Core invariants

```text
COMMAND_FORWARD
=> ACTIVE
&& COMMITTED
&& EXACT_VOLATILE_IDENTITY
&& EXACT_PERSISTENT_LINEAGE
&& ATTEMPT == PERSISTENT_NEXT_ATTEMPT_PRE
&& PERSIST_ADVANCE_ACCEPT
```

```text
PERSISTENT_FRONTIER_ADVANCE
happens before / atomically with
EXTERNAL_COMMAND_ACCEPT
```

```text
SAME_ATTEMPT_AFTER_LOGIC_RESTART
=> REJECT
&& NO_EXTERNAL_EFFECT_INCREMENT
```

```text
SUCCESSOR_ATTEMPT
=> MAY_FORWARD
only when it equals the persistent frontier
```

## Failure semantics

If the persistent frontier advances but the external device effect does not commit, A5 may conservatively lose replay authority for that attempt. This is a safety-first tradeoff: it prevents duplicate effects but does not prove liveness or automatic recovery of a lost effect. Outcome reconciliation remains the A1–R0 responsibility.

## Claim boundary

A5 is a bounded, reduced-width, single-lineage model. The frontier store is a synthesizable **retention-domain abstraction with explicit cold reset**, not a claim of actual NVRAM, power-loss persistence, device attestation, or production storage durability.

A5 does not prove survival of complete power removal, atomicity of a real NVRAM/flash/TPM write, cryptographic verification of `authority_tag`, arbitrary concurrent lineages, attempt-counter wrap handling, real accelerator transport, CDC safety, timing closure, PPA, liveness/fairness, or unbounded correctness.

## Next useful milestone

A6 should replace the single-lineage retention abstraction with a bounded multi-entry persistent authority ledger and explicit recovery of the `frontier-advanced / effect-unknown` window.

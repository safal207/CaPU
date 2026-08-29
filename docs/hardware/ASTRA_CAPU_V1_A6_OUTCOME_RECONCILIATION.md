# ASTRA–CaPU v1.0-A6 — Durable Attempt Outcome Reconciliation

## Purpose

A5 prevents the same accelerator-like attempt from forwarding again after a logic restart by advancing a persistent attempt frontier before the effect command is exposed.

That safety-first ordering creates a real recovery window:

```text
persistent frontier advanced
        ↓
command forwarded
        ↓
external effect outcome unknown
        ↓
logic restart
```

Blind replay may duplicate an effect. Permanent suppression may lose useful work. A6 therefore binds the persistent frontier to a durable per-attempt outcome state.

## Persistent state machine

```text
NONE
  ↓ reserve exact frontier attempt
UNKNOWN
  ├─ exact NOT_COMMITTED evidence → NOT_COMMITTED
  │                                  ↓
  │                            successor attempt may reserve
  ├─ exact COMMITTED evidence → COMMITTED (terminal)
  └─ exact CONFLICT evidence  → CONFLICT  (terminal fail-closed)
```

The persistent lineage remains:

```text
authority_tag
+ queue_incarnation
+ queue_epoch
+ slot_id
+ command_id
+ effect_id
```

The store additionally retains:

```text
persistent_next_attempt
unresolved_valid
unresolved_attempt
last_outcome
last_resolved_attempt
terminal_committed
terminal_conflict
```

## Dispatch rule

A command can reach the effect device only when:

```text
ACTIVE
&& COMMITTED_AUTHORITY
&& EXACT_VOLATILE_IDENTITY
&& EXACT_PERSISTENT_LINEAGE
&& !UNRESOLVED
&& !TERMINAL_COMMITTED
&& !TERMINAL_CONFLICT
&& ATTEMPT == PERSISTENT_NEXT_ATTEMPT
&& RESERVATION_ACCEPTED
```

Reservation is commit-before-effect:

```text
persistent outcome := UNKNOWN
persistent next attempt := attempt + 1
        ↓
command_forward
        ↓
external effect may occur
```

## Recovery discriminator

### Negative path

```text
attempt 0 reserved
→ outcome UNKNOWN
→ logic restart
→ attempt 0 replay blocked
→ exact NOT_COMMITTED evidence
→ UNKNOWN cleared
→ attempt 1 may reserve
```

The same attempt ID is never reused. Exact negative evidence releases only the successor attempt.

### Committed path

```text
attempt 1 reserved
→ external effect commits
→ outcome UNKNOWN
→ logic restart
→ successor blocked
→ exact COMMITTED evidence
→ lineage terminally committed
→ all later attempts blocked
```

### Conflict path

Exact `CONFLICT` evidence closes the lineage fail-closed. No replay or retirement authority is created.

## Evidence acceptance

Outcome evidence is accepted only when all fields match the current unresolved attempt:

```text
persistent lineage
+ unresolved attempt ID
+ valid outcome discriminator
```

Foreign lineage, stale attempt, missing unresolved state, invalid outcome, and already-terminal records are rejected without mutating the persistent state.

## Core invariants

```text
COMMAND_FORWARD
=> RESERVATION_ACCEPTED
&& OUTCOME_PRE == NONE/RESOLVED
&& OUTCOME_POST == UNKNOWN
```

```text
OUTCOME_UNKNOWN
=> NO_COMMAND_FORWARD
&& NO_BLIND_REPLAY
```

```text
NOT_COMMITTED_RECONCILIATION
=> UNRESOLVED_CLEARED
&& FRONTIER_NOT_DECREMENTED
&& ONLY_SUCCESSOR_ATTEMPT_MAY_FORWARD
```

```text
COMMITTED_RECONCILIATION
=> TERMINAL_COMMITTED
&& NO_LATER_ATTEMPT_MAY_FORWARD
```

```text
REJECTED_EVIDENCE
=> NO_PERSISTENT_STATE_MUTATION
```

## Relation to A1 and A5

- A1 defines the semantic `UNKNOWN / NOT_COMMITTED / COMMITTED / CONFLICT` authority contract.
- A5 supplies a restart-preserved anti-replay frontier at the physical command gate.
- A6 joins them in a bounded synthesizable control-plane model.

## Claim boundary

A6 is a bounded, reduced-width, single-lineage model with one unresolved attempt at a time. The persistent outcome store is a retention-domain abstraction with explicit cold reset, not proof of actual NVRAM, flash, TPM, secure element, battery-backed SRAM or complete power-loss durability.

A6 trusts the supplied outcome discriminator after exact identity matching. It does not prove that an external evidence source is truthful, cryptographically authenticated, Byzantine resistant or available.

A6 does not prove real persistent-media atomicity, multiple concurrent lineages, arbitrary queue depth, attempt wrap handling, real GPU/TPU/NPU transport, CDC correctness, memory ordering, FPGA timing/PPA, liveness/fairness, production widths or unbounded correctness.

## Next useful milestone

A7 should bind outcome evidence to an authenticated device receipt or query path and model evidence-source disagreement without trusting a single unverified discriminator.

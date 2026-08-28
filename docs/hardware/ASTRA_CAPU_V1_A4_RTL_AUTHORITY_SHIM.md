# ASTRA–CaPU v1.0-A4 — Synthesizable RTL Authority Shim

Status: deterministic and bounded-formal verification candidate.

## Purpose

A4 moves the critical command-issue decision from the Python A1 reference into a small synthesizable RTL gate in front of the A3 device model.

```text
command request
+ loaded authority token
+ committed bit
+ exact identity match
+ unspent identity
+ no recovery barrier
=
downstream command valid
```

The device receives no command pulse when any required condition is absent.

## Exact bounded identity

```text
queue_incarnation
queue_epoch
slot_id
command_id
attempt_id
effect_id
```

The RTL compares every identity field before permitting issue.

## Interface

The shim accepts two independent input classes.

### Authority load

```text
authority_load_valid
authority_committed
authority identity
```

A token whose identity appears in the bounded spent history is rejected during load.

### Command request

```text
command_valid
command identity
```

The command is permitted only when it exactly matches the currently loaded, committed, unspent token and recovery is not active.

## Outputs

```text
authority_load_accept / rejected
command_permit / rejected
downstream_command_valid
observable token state
observable two-entry spent history
```

## One-shot authority

On an exact permit:

```text
command identity
-> downstream command pulse
-> token_spent = 1
-> identity inserted at spent[0]
-> prior spent[0] shifts to spent[1]
```

A repeated command cannot produce a second downstream pulse from the same token.

## Recovery barrier

```text
recovery_begin = 1
=> no authority load
&& no command permit
```

Token and spent-history state are preserved across the modeled recovery barrier.

## Deterministic trajectory

The testbench composes the A4 gate with the A3 effect-counter RTL and verifies:

```text
missing authority               -> blocked, effect_count 0
uncommitted authority           -> blocked, effect_count 0
attempt mismatch                -> blocked, effect_count 0
exact committed identity        -> permit,  effect_count 1
same-token replay               -> blocked, effect_count 1
fresh token during recovery     -> blocked, effect_count 1
same fresh token after recovery -> permit,  effect_count 2
reload spent token              -> blocked
reload prior recent spent token -> blocked
new attempt identity            -> permit,  effect_count 3
```

## Bounded formal invariants

The reduced-width formal model checks:

```text
DOWNSTREAM_COMMAND_VALID
=> COMMAND_PERMIT

COMMAND_PERMIT
=> COMMAND_VALID
&& !RECOVERY_BEGIN
&& TOKEN_VALID
&& TOKEN_COMMITTED
&& !TOKEN_SPENT
&& EXACT_IDENTITY_MATCH
&& !IDENTITY_IN_SPENT_HISTORY

IDENTITY_IN_SPENT_HISTORY
=> NO_COMMAND_PERMIT

AUTHORITY_IDENTITY_IN_SPENT_HISTORY
=> LOAD_REJECT

RECOVERY_BEGIN
=> NO_COMMAND_PERMIT
&& NO_AUTHORITY_LOAD_ACCEPT

COMMAND_PERMIT at t
=> TOKEN_SPENT at t+1
&& exact command identity inserted into spent[0]

RECOVERY_BEGIN at t
=> token and spent state preserved at t+1
```

Formal scope:

```text
identity width: 2 bits per field
spent history depth: 2
safety: bounded model checking depth 18
cover: depth 24
```

## Files

```text
rtl/astra_capu_authority_gate_a4.sv
rtl/tb/astra_capu_authority_gate_a4_tb.sv
formal/astra_capu_authority_gate_a4_formal.sv
formal/astra_capu_authority_gate_a4.sby
formal/astra_capu_authority_gate_a4_cover.sby
```

## Claim boundary

A4 is a bounded one-token gate with a two-entry spent history. It does not provide an unbounded replay set. An identity older than the retained two-entry history is outside the verified anti-replay scope.

It also does not claim:

```text
cryptographic token authentication
production-width identity fields
multiple concurrent tokens
arbitrary command queues
persistent spent history across power loss
real GPU / TPU / NPU wiring
PCIe / CXL / NoC protocol behavior
FPGA timing closure
silicon PPA
liveness / fairness
unbounded correctness
external certification
```

The next milestone is **A5 — compose A4 with the A3 restart/readback adapter**, preserving spent authority across modeled checkpoint recovery and proving that a dropped host receipt cannot cause a second physical command pulse.

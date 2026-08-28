# ASTRA–CaPU v1.0-A4 — Synthesizable Authority Shim

Status: bounded RTL reference / draft research milestone.

A4 moves the A1 effect-authority decision onto the physical command path used by the A3 simulator device.

```text
A1 AuthorityTicket
  -> bounded hardware token
  -> A4 authority shim
  -> command_forward
  -> A3 effect device
```

The A3 device itself accepts any `command_valid`. A4 changes the integration boundary so the device sees a command only when the shim emits `command_forward`.

## Exact bounded token

The RTL token is:

```text
authority_tag
+ queue_incarnation
+ queue_epoch
+ slot_id
+ command_id
+ attempt_id
+ effect_id
+ committed bit
```

`authority_tag` is a reduced-width stand-in for the full A1 authority/commitment record. It is not a cryptographic verifier.

## Physical gate

```text
command_forward
=
active_authority
&& committed
&& exact_token_match
&& !attempt_spent
&& !revoke_pending
```

The effect device receives:

```text
command_valid = command_forward
```

Therefore a missing, uncommitted, stale, foreign, revoked, or already-issued token cannot increment the modeled external-effect counter.

## Reject codes

| Code | Meaning |
| ---: | --- |
| `0` | no rejection |
| `1` | no active authority |
| `2` | authority exists but is not committed |
| `3` | authority identity mismatch |
| `4` | this exact attempt was already issued |
| `5` | revoke is pending in the same cycle |

## Deterministic trajectory

```text
load committed token T0
-> exact T0 command commits
-> external effect count = 1

same T0 command again
-> REJECT_ALREADY_ISSUED
-> count remains 1

load uncommitted token
-> REJECT_UNCOMMITTED
-> count remains 1

load committed current token
+ stale-incarnation command
-> REJECT_IDENTITY
-> current token remains usable

exact current command, device does not commit
-> command physically forwarded once
-> attempt becomes spent
-> count remains 1

same attempt replay
-> REJECT_ALREADY_ISSUED

load exact successor-attempt token
-> command commits
-> count = 2

revoke successor token
-> later command gets REJECT_NO_AUTHORITY
```

## Formal properties

The bounded harness checks:

```text
DEVICE_COMMAND_ACCEPT
=> COMMAND_FORWARD

COMMAND_FORWARD
=> ACTIVE
&& COMMITTED
&& EXACT_IDENTITY
&& !ATTEMPT_SPENT
&& !REVOKE_PENDING

REJECTED_COMMAND
=> NO_EXTERNAL_EFFECT_INCREMENT
&& NO_AUTHORITY_STATE_MUTATION

FORWARDED_ATTEMPT
=> ATTEMPT_SPENT_NEXT

EXACT_REVOKE
=> NO_ACTIVE_AUTHORITY_NEXT
```

Safety uses bounded model checking. Cover witnesses establish reachability of committed and uncommitted loads, committed and non-committed device outcomes, identity rejection, duplicate-attempt rejection, and exact revocation.

## Relationship to A1–A3

- **A1** defines the implementation-neutral authority and recovery contract.
- **A2** demonstrates duplicate effects and false success under unsafe recovery.
- **A3** crosses a separate Icarus process boundary and obtains fresh device readback.
- **A4** physically gates the device command with a synthesizable exact-token comparator and one-shot attempt state.

A4 does not replace A1 recovery. If a forwarded device command has ambiguous completion, A1 must preserve `UNKNOWN`, obtain discriminating evidence, and authorize any successor attempt.

## Claim boundary

A4 is a bounded, reduced-width, single-active-token RTL shim connected to a synthetic effect counter. The comparator and registers are synthesizable.

It does **not** claim:

```text
cryptographic verification of authority_tag
power-loss-persistent anti-replay state
real PCIe / CXL / NoC command transport
real GPU / TPU / NPU integration
payload or memory-coherence correctness
arbitrary queue depth or concurrency
clock-domain crossing safety
FPGA timing closure or measured PPA
liveness / fairness
unbounded correctness
external certification
```

A real device integration must place durable issue/evidence state in an appropriate persistence or attestation domain. Resetting the shim and reloading the same bounded token is outside the A4 anti-replay claim.

# CaPU ↔ vCML replay-state recovery v0.10

Status: experimental hardware/semantic recovery boundary layered on top of the existing CaPU v0.9 one-shot authorization guard.

## Purpose

CaPU v0.9 remembers which root authorization references were consumed **within one volatile controller lifetime**. A hardware reset clears that local state. v0.10 adds an explicit recovery gate so reset does not silently turn previously spent authorization references into fresh ones.

The central rule is:

```text
RESET / RECOVERY_BEGIN
        ↓
recovery_ready = 0
        ↓
ALL NEW ROOT AUTHORIZATION FAILS CLOSED
        ↓
trusted CMC/vCML replay snapshot presented
        ↓
structural validation
        ↓
restore accepted
        ↓
recovery_ready = 1
        ↓
restored spent refs remain rejected
fresh refs may enter the existing v0.9 causal path
```

v0.10 is **replay-state recovery**, not autonomous persistent storage.

## Layering

The design deliberately keeps the existing v0.9 controller intact.

```text
CML / vCML causal history
        ↓
replay snapshot projection
        ↓
capu_replay_recovery_guard        ← v0.10
        ↓
root authorization gate
        ↓
capu_vcml_store_buffer            ← v0.9
        ↓
causal commit / STORE visibility
        ↓
vCML retirement evidence
```

Responsibilities are separated:

- **v0.9**: bounded one-shot authorization consumption during a live controller lifetime.
- **v0.10 recovery guard**: fail-closed restart and restoration of the finite spent-reference set.
- **vCML/CMC software**: reconstruct the spent-reference snapshot from trusted, scoped retirement history.

The recovery guard does not replace v0.9 authorization, parent, generation, SEAL, CTAG, or causal-commit checks.

## Recovery state machine

### Reset

`rst_n = 0` clears the guard's volatile local replay RAM and sets:

```text
recovery_ready = 0
spent_authorization_count = 0
```

The zero count after reset does **not** mean that prior references are known to be fresh. Because `recovery_ready = 0`, root authorization remains closed.

### Explicit recovery begin

`recovery_begin = 1` returns the replay guard to the same fail-closed recovery state:

```text
recovery_ready = 0
local spent set = empty
```

This is used for a warm or software-directed recovery cycle. It does not by itself authorize a cold start.

### Restore

A snapshot is accepted only when:

```text
restore_valid
&& !recovery_begin
&& !recovery_ready
&& restore_snapshot_well_formed
```

After the clock edge that accepts the snapshot:

```text
recovery_ready = 1
local spent set = restored snapshot
```

An empty snapshot is therefore an **explicit upstream cold-start decision**. The RTL never assumes an empty history merely because a reset occurred.

## Snapshot structural validity

The v0.10 hardware guard treats restore bytes as trusted upstream input but performs narrow structural validation.

For every occupied slot:

```text
authorization_ref != 0
```

All occupied references must also be unique:

```text
slot_i.valid && slot_j.valid && i != j
    => slot_i.ref != slot_j.ref
```

A snapshot containing a zero reference or duplicate occupied references is rejected and the controller remains fail-closed.

This validation is **not cryptographic authentication**. It does not establish who produced the snapshot, whether it is the newest snapshot, or whether an omitted reference should have been present.

## Root admission after recovery

The v0.10 replay guard opens its root side only when recovery has completed:

```text
RECOVERY_GATE_OPEN
    = recovery_ready
    && !recovery_begin
    && !restore_valid
```

A root authorization may pass the recovery guard only when:

```text
RECOVERY_GATE_OPEN
&& explicit_new_cause
&& root_authorized
&& root_authorization_ref != 0
&& root_authorization_ref not in restored/live spent set
&& spent set not full
```

The result then enters the existing v0.9 CaPU root policy. v0.10 does not bypass or weaken the v0.9 checks.

## Restored replay rejection

After a spent reference is restored, changing unrelated metadata such as the opaque policy epoch does not make the reference fresh:

```text
snapshot contains A
        ↓
reset/recovery completes
        ↓
root(auth_ref=A, different policy_epoch)
        ↓
REPLAY → REJECT
```

This is the primary new v0.10 boundary.

## Successful retirement after recovery

A fresh root that passes recovery and v0.9 may retire normally. At the same causal commit edge that makes the STORE visible, the wrapper presents the exact buffered root authorization reference to the recovery guard as a qualified retirement.

The recovery guard then adds that reference to its live spent set. This keeps the recovered set and newly consumed references in one replay window for the rest of the current controller lifetime.

The integration is deterministic-tested through `capu_vcml_store_buffer_v10.sv`. The standalone formal proof described below proves the recovery guard itself; it is not presented as a complete formal proof of the entire wrapper plus memory system.

## Restore overwrite protection

Once `recovery_ready = 1`, another `restore_valid` cannot silently erase or replace the live spent set:

```text
recovery_ready && restore_valid
    => restore_rejected
```

To load another snapshot, the caller must first assert `recovery_begin`, which closes root admission before local state is cleared.

This makes the recovery state transition explicit rather than allowing arbitrary live-state replacement.

## vCML snapshot projection

`tools/vcml_replay_snapshot.py` projects already-scoped vCML retirement history into the finite hardware restore format.

The software projection:

- includes only records qualified as authorized root retirements;
- requires a nonzero root authorization reference;
- rejects duplicate retired root references;
- rejects histories that exceed the selected hardware capacity;
- encodes the valid-mask and flattened reference bus expected by RTL.

The projection does not make an untrusted journal trustworthy. Snapshot authenticity, journal durability, rollback resistance, freshness, and provenance of the snapshot source remain outside v0.10.

## Deterministic verification trajectory

`rtl/tb/capu_vcml_recovery_v10_tb.sv` exercises the cross-reset path:

1. reset starts fail-closed;
2. a root before restore is rejected;
3. an explicit empty cold-start snapshot opens a new replay window;
4. root `A110` retires and becomes spent;
5. a real asynchronous reset clears local volatile state and closes the gate;
6. `A110` is rejected during the recovery gap;
7. snapshot `{A110}` is restored;
8. restored `A110` remains a replay and is rejected;
9. fresh `A120` may retire and joins the live spent set;
10. `recovery_begin` closes the gate again;
11. malformed duplicate snapshot `{A110, A110}` is rejected;
12. valid snapshot `{A110, A120}` is accepted;
13. restored `A120` remains rejected;
14. a restore attempt while live is rejected without erasing the recovered set.

Expected marker:

```text
CAPU_VCML_BRIDGE_V10_RECOVERY_PASS
```

The companion software test verifies snapshot construction, duplicate/zero/capacity rejection, vector encoding, and width validation.

## Bounded formal verification envelope

The standalone replay recovery guard is checked with SymbiYosys / Yosys / Z3 using a reduced-width instance:

```text
AUTHORIZATION_REF_WIDTH = 4
SPENT_AUTHORIZATION_SLOTS = 4
```

Safety BMC depth:

```text
20 formal sampling steps
```

Cover depth:

```text
24 formal sampling steps
```

Primary bounded invariants:

```text
RECOVERY_NOT_READY
    => NO_ROOT_AUTHORIZATION_ACCEPT

RESTORE_ACCEPT
    => SNAPSHOT_WELL_FORMED
    && !RECOVERY_READY

MALFORMED_SNAPSHOT
    => NO_RESTORE_ACCEPT

RESTORED_SPENT_REF
    => NO_ROOT_AUTHORIZATION_ACCEPT

RECOVERY_BEGIN
    => NEXT_STATE_NOT_READY_AND_EMPTY_LOCAL_SET

LIVE_RECOVERY_STATE && RESTORE_VALID
    => RESTORE_REJECTED

AUTHORIZATION_CAPACITY_EXHAUSTED
    => NO_FRESH_ROOT_ACCEPT
```

Cover checks make the proof non-vacuous by requiring reachable examples of restored replay rejection, recovery-begin followed by successful restore, malformed snapshot rejection, live restore rejection, and full-capacity fail-closed behavior.

CI is fail-closed: formal evidence is sealed only after literal `DONE (PASS)` and absence of `DONE (ERROR)` for both safety and cover.

## What v0.10 proves narrowly

Within the bounded finite replay-recovery guard model, CaPU can restart in a fail-closed state, accept a structurally valid spent-reference snapshot, keep restored authorization references spent, reject malformed or live overwrite restores, and allow only fresh references after recovery.

This closes the specific v0.9 hole:

```text
v0.9:
reset → local spent set erased → prior replay knowledge lost

v0.10:
reset → roots closed → restore prior spent set → prior refs still rejected
```

## Non-goals / claim boundary

v0.10 does **not** claim:

- nonvolatile replay memory inside the hardware block;
- autonomous persistence across power loss;
- crash-consistent durable snapshot storage;
- cryptographic authentication of restore snapshots;
- signature, MAC, key, certificate, or attestation verification;
- snapshot freshness, monotonic versioning, rollback protection, or anti-rollback storage;
- proof that the supplied snapshot is complete;
- correctness or trustworthiness of the upstream CMC/vCML journal;
- globally unique or unforgeable authorization references;
- distributed replay coordination across multiple cores, controllers, hosts, or agents;
- unbounded replay history or safe eviction/compaction;
- persistent recovery of the causal head, GEN, SEAL, or all other CaPU architectural state;
- a complete formal proof of the v0.10 wrapper, CPU, ISA, cache, coherence, or memory system;
- a parametric proof across every width or replay-set size.

A future persistence step may bind this recovery protocol to a durable CMC/vCML checkpoint with authenticated freshness and rollback resistance. That is intentionally outside v0.10.

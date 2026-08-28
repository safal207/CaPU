# CaPU / vCML v0.15 — Live Causal Execution Resumption

Status: experimental bounded hardware semantics.

v0.14 proved that a checkpoint can bind and recover the explicit committed causal record (`head_valid`, causal head transition ID, 4-bit GEN, SEAL) together with the finite replay spent-set. v0.15 closes the next local boundary: an accepted recovered causal record becomes the **live continuation state** used by the existing CaPU parent / GEN / SEAL admission rules after reset.

## Core invariant

```text
RECOVERED CAUSAL RECORD
        !=
LIVE EXECUTION STATE

until the accepted recovery atomically re-establishes
head + GEN + SEAL + replay state and reopens admission.
```

Given a full causal snapshot that has already been accepted by the upstream v0.14 checkpoint authority / commitment boundary, v0.15 restores that record into the same controllers that govern normal continuation.

```text
v0.14 accepted snapshot
        ↓
restore replay spent-set
        +
restore causal head / GEN / SEAL
        ↓
live_causal_state_ready
        ↓
ordinary v0.9 continuation policy
        ↓
parent == live head
GEN == live GEN + 1
SEAL == open
GEN != F
```

There is no second recovery-specific continuation policy. Once recovery completes, ordinary execution resumes through the existing causal admission path.

## Fail-closed recovery phase

All operation classes are blocked until both replay state and causal runtime state are ready. This intentionally strengthens the v0.10 behavior, where only new roots were gated because no live causal-head restore existed yet.

```text
!live_causal_state_ready
    => ISSUE REJECT
```

`recovery_begin` and every restore attempt are also speculation barriers:

```text
recovery_begin || restore_valid
    => old speculative STORE is flushed
    => no visible memory effect from that candidate
```

This prevents a STORE buffered before recovery from retiring across the recovery boundary.

## Runtime restore semantics

The v0.15 inner STORE path enables optional restore support in the existing causal-head and SEAL controllers. Earlier instances keep restore disabled by default, preserving the v0.9-v0.14 baseline behavior.

An accepted restore re-establishes:

- `causal_head_valid`;
- `causal_head_transition_id`;
- committed 4-bit `GEN`;
- `sealed_chain`;
- the existing finite replay spent-authorization set.

The empty causal state has one structural representation: invalid head, zero transition ID, GEN 0, SEAL 0. A non-empty causal record is assumed to have already passed the v0.14 commitment / anchor checks before it reaches the v0.15 runtime restore input.

## Continuation after recovery

An ordinary continuation is admitted only when the unchanged causal conditions hold against the restored live state:

```text
NORMAL_CONTINUATION_ADMIT
    => live_causal_state_ready
    && live_causal_head_valid
    && !live_sealed_chain
    && live_causal_head_gen != F
    && store_parent_ref == live_causal_head_transition_id
    && CTAG.GEN == live_causal_head_gen + 1
```

A successful retirement advances the same live causal head / GEN / SEAL state as normal pre-failure execution.

## Preserved barriers

Recovery does not weaken earlier invariants:

- a spent root authorization restored from the checkpoint remains replay-rejected;
- a recovered sealed chain blocks automatic continuation;
- recovered `GEN=F` remains an anti-wrap barrier and requires a legitimate new root;
- wrong parent and wrong next GEN are rejected before speculation;
- restore itself never produces a memory write or vCML retirement event.

## Deterministic trajectory

The v0.15 RTL trajectory exercises:

1. recovery of `head=0x2201`, `GEN=6`, `SEAL=0` and a spent authorization reference;
2. restored root-authorization replay rejection;
3. wrong-parent continuation rejection;
4. wrong-GEN continuation rejection;
5. exact `parent=0x2201`, `GEN=7` continuation admission and visible retirement to head `0x2202`;
6. immediate admission closure on `recovery_begin`;
7. recovery of a sealed chain and automatic-child rejection;
8. legitimate fresh explicit root from the recovered sealed state;
9. recovery of `GEN=F` and fail-closed automatic wrap rejection.

Marker: `CAPU_VCML_LIVE_RESUME_V15_PASS`.

## Bounded formal envelope

The v0.15 formal harness uses a deliberately reduced finite instance and proves safety to a bounded horizon, with independent cover reachability for resume and rejection paths.

Primary formal invariants:

```text
EXECUTION_BEFORE_RUNTIME_RESTORE => REJECT

RECOVERY_OR_RESTORE_ACTIVITY
    => SPECULATION_FLUSHED
    && NO_VISIBLE_EFFECT

RESTORE_ACCEPT
    => NEXT_LIVE_CAUSAL_STATE == ACCEPTED_CAUSAL_SNAPSHOT

NORMAL_CONTINUATION_ADMIT
    => PARENT == LIVE_HEAD
    && GEN == LIVE_GEN + 1
    && !SEAL
    && LIVE_GEN != F

RECOVERED_SEAL => AUTOMATIC_CONTINUATION_REJECT
RECOVERED_GEN_F => AUTOMATIC_WRAP_REJECT
RESTORED_SPENT_AUTHORIZATION_REF => ROOT_REPLAY_REJECT
```

The proof is fail-closed: CI accepts only literal SBY `DONE (PASS, rc=0)` results and separately requires non-vacuity cover success.

## Trust boundary and non-claims

v0.15 assumes that `restore_valid` is asserted only for a snapshot already accepted by the v0.14 full causal checkpoint authority / commitment boundary. The standalone v0.15 runtime proof does **not** independently re-prove checkpoint SHA-256, external anchor freshness, CAS correctness, media durability, or source-history completeness.

v0.15 also does not claim:

- complete CPU architectural-state recovery;
- register-file, cache, predictor, TLB, coherence or ISA recovery;
- cryptographic verification inside RTL;
- trusted commitment-engine integrity;
- distributed recovery correctness;
- power-loss persistence by the RTL itself;
- unbounded or parametric correctness.

The narrow result is: **given an already accepted full causal checkpoint snapshot, CaPU can fail closed during recovery, restore the finite replay state plus committed causal head / GEN / SEAL into the live execution controllers, and resume local STORE continuation under the same causal admission rules that governed execution before failure.**

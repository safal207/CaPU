# CaPU ↔ vCML checkpoint freshness v0.11

Status: experimental hardware/semantic checkpoint-freshness boundary layered on top of CaPU v0.10 replay-state recovery.

## Purpose

CaPU v0.10 restores the finite spent-authorization set after reset, but treats the restore snapshot itself as trusted input. That leaves a rollback question:

```text
newer replay snapshot exists
        ↓
controller resets
        ↓
older but structurally valid snapshot is presented
        ↓
old spent-state could be forgotten
```

v0.11 adds an explicit external checkpoint anchor and requires an anchored restore to match it exactly before the v0.10 restore path can see the snapshot.

The central rule is:

```text
EXTERNAL TRUSTED MONOTONIC ANCHOR
        ↓
(ref, epoch)
        ↓
RESET / RECOVERY
        ↓
presented checkpoint
        ↓
trusted binding decision
        ↓
exact ref + exact epoch match?
        ├─ no  → FAIL CLOSED
        └─ yes → v0.10 structural replay restore
```

## Exact-anchor policy

When `anchor_valid = 1`, restore admission requires:

```text
restore_valid
&& !recovery_begin
&& checkpoint_trusted
&& snapshot_checkpoint_ref != 0
&& anchor_checkpoint_ref != 0
&& snapshot_checkpoint_ref == anchor_checkpoint_ref
&& snapshot_checkpoint_epoch == anchor_checkpoint_epoch
```

The design intentionally does **not** use `snapshot_epoch >= anchor_epoch`. A numerically larger epoch is not automatically trustworthy. The hardware accepts only the checkpoint identity explicitly named by the trusted external anchor.

## Rollback detection

For an anchored, trusted candidate:

```text
snapshot_epoch < anchor_epoch
    => checkpoint_rollback_detected
    => NO checkpoint_restore_accept
    => v0.10 recovery remains closed
```

A same-epoch checkpoint with the wrong checkpoint reference is also rejected.

## Trust boundary

`checkpoint_trusted` is a trusted upstream decision that the presented checkpoint metadata is bound to the replay snapshot being restored.

v0.11 does **not** implement cryptographic verification inside RTL. The signal may later be driven by a MAC/signature/attestation verifier, but this prototype only enforces the result of that decision.

The external anchor is likewise an input. v0.11 assumes its persistence and monotonicity are provided outside this volatile CaPU block.

Therefore the narrow claim is:

> Given a trustworthy external anchor and trustworthy checkpoint-binding decision, CaPU v0.11 fails closed on stale, mismatched, or untrusted checkpoint restore attempts before they can reopen replay-state recovery.

## Explicit cold start

If `anchor_valid = 0`, recovery does not silently invent a history. The only accepted cold-start form is explicit:

```text
cold_start_authorized
&& snapshot_checkpoint_ref == 0
&& snapshot_checkpoint_epoch == 0
```

This preserves the v0.10 rule that an empty replay history must be an explicit upstream decision, not an inference from reset.

## Composition with v0.10

`capu_vcml_store_buffer_v11.sv` gates the v0.10 `restore_valid` input with `checkpoint_restore_accept`.

```text
checkpoint freshness guard      ← v0.11
        ↓ accepted restore only
replay recovery guard           ← v0.10
        ↓ structurally valid spent-set
one-shot authorization guard    ← v0.9
        ↓
causal STORE commit + vCML event
```

Thus v0.11 does not replace:

- v0.10 snapshot structural validation;
- v0.9 spent-reference replay rejection;
- CTAG validation;
- parent / GEN / SEAL rules;
- causal commit requirements.

It adds a checkpoint freshness gate before those layers.

## Deterministic trajectory

`rtl/tb/capu_vcml_recovery_v11_tb.sv` covers:

1. reset starts with replay recovery closed;
2. anchored stale checkpoint epoch is rollback-rejected;
3. same epoch with wrong checkpoint ref is rejected;
4. exact metadata without `checkpoint_trusted` is rejected;
5. exact trusted anchor restores spent ref `A110`;
6. restored `A110` remains replay-rejected;
7. fresh `A120` still retires through the existing causal path;
8. recovery begins again and the external anchor advances;
9. the old checkpoint is now rollback-rejected;
10. the new exact checkpoint restores both spent refs;
11. without an anchor, cold start remains rejected until explicitly authorized.

Expected marker:

```text
CAPU_VCML_BRIDGE_V11_CHECKPOINT_PASS
```

## Bounded formal envelope

The standalone checkpoint freshness guard is verified with a reduced-width instance:

```text
CHECKPOINT_REF_WIDTH   = 4
CHECKPOINT_EPOCH_WIDTH = 4
```

Safety BMC depth:

```text
16 formal sampling steps
```

Cover depth:

```text
20 formal sampling steps
```

Primary bounded invariants:

```text
ANCHORED_RESTORE_ACCEPT
    => CHECKPOINT_TRUSTED
    && SNAPSHOT_REF == ANCHOR_REF
    && SNAPSHOT_EPOCH == ANCHOR_EPOCH

SNAPSHOT_EPOCH < ANCHOR_EPOCH
    => ROLLBACK_DETECTED
    && NO_RESTORE_ACCEPT

SAME_EPOCH_WRONG_REF
    => NO_RESTORE_ACCEPT

UNTRUSTED_ANCHORED_CHECKPOINT
    => NO_RESTORE_ACCEPT

RECOVERY_BEGIN
    => NO_RESTORE_ACCEPT

COLD_START_ACCEPT
    => !ANCHOR_VALID
    && COLD_START_AUTHORIZED
    && REF == 0
    && EPOCH == 0
```

Reachability witnesses demonstrate exact-anchor acceptance, rollback rejection, wrong-ref rejection, untrusted rejection, explicit cold start, and unauthorized cold-start rejection.

## Non-claims

v0.11 does not claim:

- cryptographic checkpoint authentication inside CaPU;
- signature, MAC, key, certificate, TPM, TEE, or attestation verification;
- implementation of monotonic durable storage;
- persistence of the external anchor;
- checkpoint generation or atomic checkpoint commit;
- proof that the external anchor is newest or correct;
- journal durability or omission resistance;
- distributed or multi-controller recovery;
- power-loss persistence by the CaPU RTL itself;
- complete CPU / ISA / cache / coherence correctness;
- unbounded or parametric formal proof.

## Next boundary

The next architectural step is to move from **trusted checkpoint verdicts** to a concrete checkpoint-commit protocol:

```text
causal/replay state
      ↓
checkpoint candidate
      ↓
integrity/authentication
      ↓
monotonic anchor commit
      ↓
only then may the new checkpoint become the recovery authority
```

That would make durability and anchor advancement part of the causal commit protocol rather than an external assumption.

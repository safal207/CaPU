# CaPU v0.13 — Checkpoint Content Commitment Boundary

Status: experimental bounded hardware/software composition.

CaPU v0.12 separates persisted checkpoint bytes from committed recovery authority. v0.13 adds the missing content-binding layer:

```text
canonical replay snapshot
        ↓
off-path SHA-256 commitment
        ↓
PREPARE exact commitment
        ↓
PERSIST exact commitment
        ↓
ANCHOR COMMIT exact commitment
        ↓
anchored recovery verifies the same commitment
```

The central invariant is:

> **CHECKPOINT IDENTITY + AUTHORITY != CHECKPOINT CONTENT UNLESS THE CONTENT COMMITMENT IS BOUND THROUGH THE SAME COMMIT PATH.**

## What is committed

The v0.13 reference commitment covers the recovery-relevant replay snapshot currently implemented by CaPU v0.10:

- checkpoint reference;
- checkpoint epoch;
- authorization-reference width;
- finite replay-slot count;
- the semantic set of spent root-authorization references.

The spent-reference set is canonicalized by numeric sort before encoding because the replay guard treats the occupied refs as a set rather than an ordered history. Invalid slots are encoded as zero. The payload is domain-separated with the v0.13 schema/version and hashed with SHA-256.

Reference implementation:

- `tools/vcml_checkpoint_commitment.py`
- `tests/test_vcml_checkpoint_commitment.py`

The reference tests verify deterministic canonicalization, order independence for the same replay set, checkpoint identity binding, spent-ref tamper detection, malformed-snapshot rejection and digest verification.

## Hardware boundary

`rtl/capu_checkpoint_content_binding_v13.sv` is an adapter over the already verified v0.12 checkpoint/recovery path.

The existing v0.12 `state_tag` channel is not changed. v0.13 assigns an explicit ABI meaning to that exact-binding channel by carrying a checkpoint content commitment through it.

Default commitment width at the v0.13 boundary is 256 bits. The RTL performs equality/binding checks only; it does **not** compute SHA-256 in the critical path.

Two explicit trust signals enter from an off-path commitment engine/verifier:

- `candidate_commitment_verified` — the candidate commitment was computed from the canonical replay snapshot intended for checkpoint persistence;
- `snapshot_commitment_verified` — the recovery snapshot recomputes to the presented commitment.

These are trusted interface verdicts in v0.13, not cryptographic proofs generated inside the RTL.

## Prepare rule

A checkpoint request cannot enter the existing v0.12 commit protocol unless:

```text
checkpoint_prepare_valid
&& candidate_commitment_verified
&& candidate_checkpoint_commitment != 0
```

If accepted, v0.12 latches that exact commitment as the candidate state binding.

## Persistence rule

The persistence acknowledgement must echo the exact prepared checkpoint reference, epoch and commitment.

Therefore:

```text
PERSIST_ACCEPT
=> persisted_commitment == request_commitment
```

A wrong commitment does not mark the candidate snapshot durable.

## Anchor commit rule

The external durable-anchor acknowledgement must bind both sides of the compare-and-swap transition:

```text
base anchor commitment
        ↓
      CAS
        ↓
candidate checkpoint commitment
```

A commit event requires the acknowledgement's candidate commitment to equal the exact prepared/requested commitment. For an existing anchor, the request also carries the latched base-anchor commitment.

This preserves the v0.12 distinction:

```text
snapshot persisted
        !=
checkpoint authority committed
```

while adding:

```text
checkpoint authority committed
        =>
exact content commitment bound
```

## Anchored recovery rule

When an authoritative external anchor exists, the restore request is allowed to reach the existing v0.11/v0.10 recovery path only if:

```text
snapshot_commitment_verified
&& snapshot_checkpoint_commitment != 0
&& current_anchor_commitment != 0
&& snapshot_checkpoint_commitment == current_anchor_commitment
```

Thus an unverified or mismatched commitment fails closed before replay-state recovery can reopen.

The no-anchor cold-start path remains the explicit v0.11/v0.12 cold-start mechanism. v0.13's content-binding claim applies to **anchored recovery**, not to an unanchored cold start.

## Deterministic trajectory

`rtl/tb/capu_checkpoint_content_binding_v13_tb.sv` covers:

- unverified candidate commitment rejection;
- verified candidate commitment admission;
- wrong persisted commitment rejection;
- exact persistence commitment acceptance;
- wrong anchor-ack commitment rejection;
- exact checkpoint commit;
- unverified anchored restore rejection;
- mismatched anchored commitment rejection;
- verified exact anchored restore;
- fail-closed restore when an off-path verifier rejects tampered replay bytes;
- a second checkpoint transition whose CAS request binds the old commitment as base and the new commitment as candidate.

Marker:

`CAPU_VCML_CHECKPOINT_CONTENT_V13_PASS`

## Formal envelope

The v0.13 bounded harness uses reduced finite widths and proves the adapter/composition properties under arbitrary symbolic inputs.

Primary invariants:

```text
ANCHORED_RESTORE_ACCEPT
=> COMMITMENT_VERIFIED
&& SNAPSHOT_COMMITMENT == ANCHOR_COMMITMENT

UNVERIFIED_OR_MISMATCHED_ANCHORED_COMMITMENT
=> NO_RESTORE_ACCEPT

PREPARE_ACCEPT
=> CANDIDATE_COMMITMENT_VERIFIED
&& CANDIDATE_COMMITMENT != 0

PERSIST_ACCEPT
=> PERSISTED_COMMITMENT == REQUEST_COMMITMENT

CHECKPOINT_COMMIT_EVENT
=> ACK_COMMITMENT == REQUEST_COMMITMENT

ANCHOR_COMMIT_REQUEST
=> REQUEST_COMMITMENT != 0
```

Safety and cover are run through a fail-closed SBY workflow with pinned SBY, Yosys and Z3. A green wrapper is not sufficient: the workflow requires literal `DONE (PASS` and rejects `DONE (ERROR)`.

## What v0.13 does not prove

v0.13 does **not** claim:

- SHA-256 is implemented or verified inside CaPU RTL;
- the external commitment engine/verifier is trustworthy or uncompromised;
- the source vCML history is complete or omission-resistant;
- the current checkpoint snapshot includes full causal-head / GEN / SEAL state;
- durable-media persistence or crash-consistent storage internals are correct;
- the external anchor CAS implementation is correct;
- signatures, MACs, TPMs, TEEs or key management are implemented;
- distributed checkpoint consensus;
- complete CPU/ISA/cache/coherence correctness;
- unbounded or parametric proof of the full-width system.

The canonical v0.13 payload currently binds the **finite replay-state snapshot** used by v0.10 recovery, not every CaPU architectural state element.

## Narrow result

Given a trustworthy off-path canonical commitment verdict and the existing v0.12 authoritative checkpoint protocol, CaPU v0.13 ensures that a checkpoint content commitment cannot be silently changed between candidate admission, persistence acknowledgement, authority commit and anchored replay-state recovery.

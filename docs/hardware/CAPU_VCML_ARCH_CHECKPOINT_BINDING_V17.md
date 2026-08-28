# CaPU vCML Architectural Checkpoint Content Binding v0.17

## Claim

v0.17 closes the explicit content-authority gap left by v0.16. The minimal
architectural context and the already-bound causal/replay context are now one
canonical checkpoint record covered by one commitment:

```text
checkpoint ref + checkpoint epoch
+ recovery epoch
+ PC + GPR0..GPR3 + status
+ causal head valid/id + GEN + SEAL
+ canonical spent-authorization set
        ↓
domain-separated canonical bytes
        ↓
one SHA-256 commitment
        ↓
PREPARE → PERSIST → ANCHOR AUTHORITY → EXACT RESTORE
```

The narrow result is that a valid causal snapshot cannot be combined with a
different PC/register/status snapshot under the same checkpoint authority. The
same complete payload must survive every authority boundary.

## Threat model: valid components, invalid composition

```text
valid causal/replay snapshot A
+
valid architectural snapshot B
=
MIXED SNAPSHOT → REJECT
```

Recovery epoch equality from v0.16 remains useful, but equality alone is not a
content commitment. v0.17 binds the actual bytes represented by that epoch.

## Canonical software commitment

`tools/vcml_arch_checkpoint_v17.py` is the reference canonical encoder. It
domain-separates the v0.17 schema and encodes:

- checkpoint reference and checkpoint epoch;
- field widths and finite replay capacity;
- architectural recovery epoch;
- PC, exactly four GPRs and the status byte;
- causal-head validity, transition ID, committed GEN and SEAL;
- the spent-authorization semantic set in sorted order.

Changing any recovery-relevant architectural, causal or replay field changes
the SHA-256 digest. Reordering the same spent set does not. Speculative fields
are rejected by the schema.

SHA-256 remains off the RTL critical path. The RTL consumes trusted
`candidate_commitment_verified` and `snapshot_commitment_verified` verdicts;
the proof covers correct use of those verdicts, not implementation or
trustworthiness of the external digest engine.

## RTL authority lifecycle

`rtl/capu_arch_checkpoint_binding_v17.sv` carries an explicit complete payload
sideband alongside checkpoint identity and commitment.

### Prepare

```text
PREPARE_ACCEPT
  => candidate_commitment_verified
  && candidate_payload == authoritative_live_payload
```

### Persistence

```text
PERSIST_ACCEPT
  => persisted identity == pending identity
  && persisted commitment == pending commitment
  && persisted payload == pending payload
```

### Authority commit

```text
AUTHORITY_COMMIT
  => ACK candidate identity/commitment/payload == pending request
  && valid base anchor identity/commitment/payload == captured base
```

For a genesis checkpoint, base-anchor payload bytes are semantically absent
when `base_anchor_valid=0`; they are therefore not constrained. When the base
anchor is valid, its complete payload is compared exactly.

### Restore

```text
RESTORE_ACCEPT
  => snapshot commitment was verified
  && snapshot identity == authoritative anchor identity
  && snapshot commitment == authoritative anchor commitment
  && snapshot payload == authoritative anchor payload
```

On acceptance, the exact snapshot payload becomes the recovered checkpoint
record. On mismatch or concurrent `recovery_begin`, restore remains closed.
Any `restore_valid` cycle is also an authority-transition barrier: prepare,
persistence acceptance and authority commit cannot overlap state replacement.
Both `recovery_begin` and any restore attempt discard an older pending/durable
candidate, preventing pre-boundary bytes from gaining authority after live
state has been cleared or replaced.

## Deterministic trajectory

The executable RTL trajectory demonstrates:

1. a foreign PC under an otherwise valid candidate is rejected at prepare;
2. foreign GPR bytes are rejected at persistence;
3. foreign architectural bytes are rejected at anchor acknowledgement;
4. the exact complete payload commits authority;
5. the same commitment with a foreign PC is rejected at restore;
6. the exact anchored payload restores;
7. `recovery_begin + restore_valid` remains fail-closed.

Marker:

```text
CAPU_VCML_ARCH_CHECKPOINT_V17_PASS
```

## Bounded formal boundary

Safety depth: 24.

Reachability cover depth: 28, with five VCD witness traces.

The reduced formal instance uses small checkpoint, architectural, causal and
authorization widths while retaining the complete field structure. It proves:

```text
PREPARE_ACCEPT => CANDIDATE_PAYLOAD == LIVE_PAYLOAD
PERSIST_ACCEPT => PERSISTED_PAYLOAD == REQUEST_PAYLOAD
AUTHORITY_COMMIT => ACK_PAYLOAD == REQUEST_PAYLOAD
RESTORE_ACCEPT => SNAPSHOT_PAYLOAD == ANCHOR_PAYLOAD
MIXED_SNAPSHOT => NO_RESTORE_ACCEPT
RECOVERY_OR_RESTORE => NO_CONCURRENT_AUTHORITY_TRANSITION
RECOVERY_OR_RESTORE => PENDING_AUTHORITY_DISCARDED
RESTORE_ACCEPT => NEXT_RECOVERED_PAYLOAD == ACCEPTED_PAYLOAD
```

The first formal counterexample found an over-constrained shadow assertion:
genesis ACKs were being required to match bytes for a base anchor explicitly
marked invalid. Equality was restricted to the semantically valid base-anchor
case; the candidate/full-payload invariants were not weakened. Safety then
passed through depth 24.

## Relationship to v0.16

v0.16 remains the live execution result: a minimal architectural context and
causal/replay state resume atomically and preserve the STORE continuation
policy. v0.17 strengthens the upstream authority for that exact state vector:
the recovered record can no longer substitute different PC/GPR/status bytes
under a valid causal history and commitment.

The v0.17 workflow reruns the v0.16 deterministic trajectory and bounded
safety proof on the same head. It does not replace or weaken the v0.16 runtime
invariants.

## Non-claims

v0.17 does not prove:

- SHA-256 or canonical encoding implemented inside RTL;
- trustworthiness of the off-path commitment verifier;
- durable-media correctness or distributed anchor correctness;
- a full ISA, production-width register file or complete CSR set;
- precise exception, interrupt or privilege recovery;
- cache, TLB/MMU, predictor, coherence or multicore recovery;
- unbounded or parametric correctness.

The next natural boundary is v0.18: precise exception, interrupt and privilege
recovery using the same content-bound architectural+causal authority.

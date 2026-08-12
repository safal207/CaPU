# CaPU vCML Architectural Causal Resume v0.16

## Claim

v0.16 extends the already-verified v0.15 live causal resume boundary with a minimal architectural execution context and binds both domains to one recovery epoch.

The checkpoint-derived live state is now modeled as:

```text
causal state
  causal head
  GEN
  SEAL
  finite spent-authorization set

architectural state
  PC
  four GPRs
  status byte

+ one accepted recovery epoch
```

The new claim is narrow: after recovery, a local STORE may resume only when the architectural context and the causal/replay context came from the same accepted recovery epoch. The first visible resumed STORE uses the live restored PC and restored GPR values while the unchanged v0.15 causal admission path still enforces parent/GEN/SEAL policy.

## New threat model: Split-State Recovery

A recovery is invalid even if each component snapshot is independently plausible when the components refer to different recovery epochs.

```text
PC / GPR / status from checkpoint A
+
causal head / GEN / SEAL / replay set from checkpoint B
=
REJECT
```

This prevents a valid causal chain from authorizing execution with an unrelated architectural context, and prevents a valid architectural context from inheriting unrelated causal provenance.

## Core invariants

```text
SPLIT_STATE_EPOCH_MISMATCH
  => RESTORE_REJECT
  && NO_VISIBLE_EFFECT

RESTORE_ACCEPT
  => NEXT_LIVE_ARCH_STATE == ACCEPTED_ARCH_SNAPSHOT
  && NEXT_LIVE_CAUSAL_STATE == ACCEPTED_CAUSAL_SNAPSHOT
  && LIVE_EPOCH == ACCEPTED_EPOCH

EXECUTION_PC != LIVE_PC
  => REJECT

VISIBLE_STORE
  => ADDRESS == LIVE_GPR[addr_reg]
  && DATA == LIVE_GPR[data_reg]

RECOVERY_OR_RESTORE_ACTIVITY
  => NO_VISIBLE_EFFECT

PRE_RECOVERY_SPECULATION
  => NEVER_POST_RECOVERY_RETIRE
```

The downstream causal continuation rules remain those already verified in v0.15: exact parent, next GEN, unsealed chain, no generation wrap, and restored root-authorization replay rejection.

## Deterministic trajectory

1. Enter recovery and present architectural epoch `0x11` with causal epoch `0x12`; restore fails closed.
2. Present one epoch `0x21` containing:
   - `PC=0x40`
   - `GPR1=0x80` (STORE address)
   - `GPR2=0x55` (STORE data)
   - `status=0xA5`
   - causal head `0x2201`, `GEN=6`, `SEAL=0`
3. Attempt otherwise-valid continuation at `PC=0x41`; reject.
4. Execute at restored `PC=0x40` with `addr_reg=GPR1`, `data_reg=GPR2` and exact causal continuation `parent=0x2201`, `GEN=7`.
5. Retire one visible STORE to address `0x80`, data `0x55`; causal head becomes `0x2202`, `GEN=7`; architectural PC advances exactly once.
6. Buffer another STORE, start recovery before retirement, restore a different epoch/state, then assert commit; the pre-recovery speculative STORE cannot retire.

Marker:

```text
CAPU_VCML_ARCH_RESUME_V16_PASS
```

## Formal boundary

Safety proof depth: 28.

Reachability cover depth: 32.

The proof uses a reduced instance with 4-bit address/transition widths, 8-bit GPR data, four GPRs, a 3-bit recovery epoch and two spent-authorization slots. It composes the new architectural wrapper with the existing v0.15 runtime rather than replacing v0.15.

## Non-claims

v0.16 does **not** prove complete CPU recovery. In particular it does not model or prove:

- a full ISA or production-width register file;
- CSRs beyond the tiny status byte;
- precise exceptions or interrupts;
- privilege transitions;
- loads or general memory-order recovery;
- cache state;
- TLB/MMU state;
- branch predictor state;
- coherence or multicore recovery;
- cryptographic checkpoint verification inside RTL;
- durable-media correctness;
- arbitrary distributed recovery;
- unbounded or parametric correctness.

The verified progression intended by this milestone is:

```text
checkpoint content commitment
        ↓
full causal checkpoint-state binding
        ↓
live causal execution resumption
        ↓
causally bound architectural execution resumption
```

A natural next boundary is v0.17: precise recovery across exception / interrupt / privilege state, while preserving the same atomic architectural+causal recovery epoch.

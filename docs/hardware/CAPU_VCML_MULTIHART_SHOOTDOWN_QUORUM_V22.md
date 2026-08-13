# CaPU v0.22 — Multi-Hart Shootdown Delivery / Acknowledgement Quorum

## Purpose

v0.21 proved freshness-gated authority for one cached translation and one exact local shootdown acknowledgement. v0.22 extends that boundary to a bounded two-hart system: a memory-view change is not globally complete until every required hart has supplied an exact acknowledgement for the same shootdown generation and target.

```text
memory-view transition
  -> shootdown generation + target + required hart set
  -> exact per-hart acknowledgement
  -> acknowledgement bitmap
  -> exact quorum
  -> retire distributed shootdown authority
  -> reopen global translation authority
```

## Threat model

The model rejects:

- acknowledgement from a stale shootdown generation;
- acknowledgement for a foreign ASID, translation epoch, or VPN;
- acknowledgement from a hart not required by the pending request;
- duplicate acknowledgement from an already-counted hart;
- global translation authority while only a partial quorum exists;
- a zero-hart shootdown request;
- partial quorum state surviving recovery or restore.

## Core invariants

```text
ACK_ACCEPT(h)
=> PENDING
&& REQUIRED(h)
&& !ALREADY_ACKED(h)
&& ACK.GENERATION == PENDING.GENERATION
&& ACK.ASID == PENDING.ASID
&& ACK.EPOCH == PENDING.EPOCH
&& ACK.VPN == PENDING.VPN

SHOOTDOWN_PENDING
=> !GLOBAL_TRANSLATION_AUTHORITY_READY

QUORUM_COMPLETE
=> (ACK_BITMAP | ACCEPTED_NOW) covers REQUIRED_HARTS exactly

RECOVERY || RESTORE
=> PENDING = 0 && ACK_BITMAP = 0
```

## Claim boundary

This is a bounded reduced-width two-hart shootdown-authority model with one pending target and one generation. It does not model production IPI delivery, message loss/retry protocols, arbitrary hart count, cache coherence, multiple concurrent shootdowns, page-table walkers, virtualization, production speculation/ROB semantics, distributed durable state, or unbounded correctness.

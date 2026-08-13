# CaPU vCML MMU Translation Recovery v0.20

v0.20 extends the exact v0.19 checkpoint authority with a bounded memory-view record.

```text
verified v0.19 checkpoint state
+ translation root
+ ASID
+ translation epoch
+ one canonical VPN -> PPN mapping
+ R/W/X/U permissions
+ precise page-fault pending/address/cause
        ↓
one canonical checkpoint payload
        ↓
exact restore / fail-closed continuation
```

## Threat model

The same architectural, causal, privilege and nested-trap state must not resume under a different or stale address-translation authority.

Examples rejected by the model:

- foreign translation root under an otherwise valid checkpoint;
- foreign ASID;
- stale translation epoch;
- altered VPN/PPN mapping or permissions;
- foreign pending page-fault context;
- stale candidate checkpoint prepared against a newer committed memory view.

## Runtime invariants

```text
RESTORE_ACCEPT => EXACT_BOUND_MEMORY_VIEW
FOREIGN_ROOT_OR_ASID_OR_EPOCH => RESTORE_REJECT
TRANSLATION_HIT => EXACT_PPN_PLUS_OFFSET
PERMISSION_OR_PRIVILEGE_OR_MAPPING_FAILURE => PRECISE_PAGE_FAULT
PAGE_FAULT => NO_VISIBLE_EFFECT
PAGE_FAULT => SPECULATION_KILL
RECOVERY_OR_RESTORE => NO_VISIBLE_EFFECT
STALE_CANDIDATE_PAYLOAD => PREPARE_REJECT
```

The reduced model contains one canonical mapping entry rather than a production page-table walker or TLB. The point of v0.20 is authority and recovery semantics, not implementation fidelity of a full MMU.

## Claim boundary

This is a bounded reduced-width memory-view recovery model. It does not claim full page-table walking, multi-level page tables, TLB refill/shootdown, accessed/dirty bits, huge pages, PMP/PMA, full CSR semantics, virtualization, nested translation, cache/coherence interaction, multicore address-space synchronization, RTL SHA-256, durable-media correctness or unbounded correctness.

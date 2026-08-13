# CaPU vCML TLB Freshness / Shootdown Authority v0.21

v0.21 extends the exact v0.20 memory-view checkpoint boundary with one bounded TLB entry and one shootdown transaction.

## Authority record

- TLB valid bit
- ASID
- translation epoch
- VPN -> PPN mapping
- R/W/X/U permissions
- shootdown pending bit
- shootdown target ASID / epoch / VPN

## Core invariants

```text
TLB_HIT => ENTRY_ASID == LIVE_ASID
TLB_HIT => ENTRY_EPOCH == LIVE_TRANSLATION_EPOCH
TLB_HIT => ENTRY_VPN == REQUEST_VPN
TLB_HIT => PERMISSION_ALLOWED
SHOOTDOWN_ACK_ACCEPT => EXACT_PENDING_TARGET
STALE_ENTRY => NO_TLB_HIT
RECOVERY => OLD_TLB_AUTHORITY_DESTROYED
```

This is a bounded reduced-width one-entry TLB model. It does not claim a production multi-entry TLB, replacement policy, hardware page-table walker, multi-hart shootdown network, coherence, virtualization, or unbounded correctness.

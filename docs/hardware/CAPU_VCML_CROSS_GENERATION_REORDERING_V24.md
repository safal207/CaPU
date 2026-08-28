# CaPU vCML Cross-Generation Reordering v0.24

v0.24 extends verified v0.23 shootdown delivery/retry semantics with a bounded temporal-quarantine layer for delayed messages that arrive after one generation retires and its successor begins.

## Scope

The model is deliberately small:

- two harts;
- one pending shootdown target;
- one current generation plus one last-retired generation;
- exact successor launch rule without generation wrap;
- delayed delivery and ACK arrivals;
- per-hart quarantine evidence bitmaps and a bounded event count.

## Causal spine

```text
generation N authority
  -> exact delivery / ACK quorum
  -> retire N
  -> launch exact successor N+1
  -> delayed N delivery / ACK arrives
  -> quarantine N evidence
  -> no N+1 delivery/ACK authority mutation
  -> N+1 completes only from N+1 evidence
```

## Core invariants

```text
LAUNCH_ACCEPT && LAST_RETIRED_VALID
=> GENERATION == LAST_RETIRED + 1
&& NO_WRAP

STALE_OR_FOREIGN_DELIVERY
=> QUARANTINE
&& NO_DELIVERED_BITMAP_MUTATION

STALE_OR_FOREIGN_ACK
=> QUARANTINE
&& NO_ACK_BITMAP_MUTATION

ACK_ACCEPT(h)
=> EXACT_CURRENT_GENERATION_AND_TARGET
&& DELIVERY_OBSERVED(h)
&& !ALREADY_ACKED(h)

SHOOTDOWN_PENDING
=> !GLOBAL_TRANSLATION_AUTHORITY_READY

QUORUM_COMPLETE
=> LAST_RETIRED_GENERATION := CURRENT_GENERATION

RECOVERY || RESTORE
=> CURRENT_IN_FLIGHT_AND_QUARANTINE_STATE_DESTROYED
```

## Claim boundary

This is a bounded reduced-width two-hart temporal-reordering authority model. It does not model generation wrap/reuse, arbitrary in-flight queues, production IPI transport, timing/fairness/liveness, concurrent shootdowns, cache coherence, virtualization, production widths, durable distributed recovery, or unbounded correctness.

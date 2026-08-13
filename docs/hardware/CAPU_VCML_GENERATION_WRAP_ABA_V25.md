# CaPU v0.25 — Generation Wrap / ABA Protection

## Goal

Extend verified v0.24 temporal quarantine across a numeric generation-counter wrap. The bounded model proves that a historical message whose small generation number is reused after wrap does not regain authority merely because its generation field matches the current request.

## Authority identity

```text
incarnation + generation + ASID + translation epoch + VPN + hart
```

A non-wrap successor preserves incarnation and increments generation. A wrap successor sets generation to zero and increments incarnation. In this bounded scope, the incarnation counter itself is not allowed to wrap.

## Threat

```text
historical incarnation A / generation 0
  ...
incarnation A / generation MAX retires
  ↓
incarnation A+1 / generation 0 launches
  ↓
delayed historical generation-0 message arrives
  ↓
MUST NOT acquire current authority
```

Historical same-generation delivery or ACK with a foreign incarnation is quarantined and cannot mutate current delivery or acknowledgement authority.

## Core invariants

```text
NON_WRAP_SUCCESSOR
=> generation := retired_generation + 1
&& incarnation := retired_incarnation

WRAP_SUCCESSOR
=> generation := 0
&& incarnation := retired_incarnation + 1

SAME_GENERATION && FOREIGN_INCARNATION
=> NO_DELIVERY_OR_ACK_AUTHORITY

SHOOTDOWN_PENDING
=> GLOBAL_TRANSLATION_AUTHORITY_CLOSED

RECOVERY || RESTORE
=> MODELED_IN_FLIGHT_ABA_QUARANTINE_DESTROYED
```

## Claim boundary

Bounded reduced-width two-hart-compatible authority model using a 2-bit generation and 3-bit incarnation identity. It demonstrates one generation wrap and incarnation-separated ABA protection. It does not claim incarnation-wrap safety, arbitrary in-flight queues, cryptographic uniqueness, production IPI transport, timing/fairness/liveness, arbitrary hart count, concurrent shootdowns, cache coherence, virtualization, durable distributed recovery, production widths or unbounded correctness.

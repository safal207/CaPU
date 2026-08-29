# ASTRA–CaPU v1.0-A7 — Authenticated Device Outcome Receipts

## Purpose

A6 persists an unresolved accelerator attempt and accepts exact `NOT_COMMITTED`, `COMMITTED`, or `CONFLICT` outcome evidence. It checks that the evidence identity matches the current unresolved attempt, but it intentionally trusts the supplied outcome discriminator.

A7 inserts an authenticated device-receipt boundary before A6 reconciliation:

```text
accelerator device receipt
+ trusted device identity
+ trusted key epoch
+ monotonic receipt sequence
+ exact attempt identity
+ authenticated envelope tag
        ↓
receipt authentication gate
        ↓
A6 exact outcome reconciliation
```

Only an authenticated receipt is exposed to the A6 durable outcome store.

## Receipt identity

The authenticated envelope binds:

```text
device_id
+ key_epoch
+ receipt_seq
+ authority_tag
+ queue_incarnation
+ queue_epoch
+ slot_id
+ command_id
+ attempt_id
+ effect_id
+ outcome
```

The trust record retains:

```text
trusted_device_id
trusted_key_epoch
trusted_secret
trusted_next_receipt_seq
```

A receipt must exactly match the trusted device, key epoch, and next sequence number. Its envelope tag must verify over the complete receipt identity.

## Synthetic authentication function

The A7 RTL and software mirror use a transparent fixed-width rotate/XOR keyed tag. This is deliberately a **synthetic authentication primitive** for formal state-machine work. It is not claimed to be a secure MAC, digital signature, SPDM implementation, or production cryptography.

The verified architectural contract is independent of the toy primitive:

```text
AUTHENTICATED_RECEIPT
=> EXACT_DEVICE
&& EXACT_KEY_EPOCH
&& EXACT_SEQUENCE
&& EXACT_FULL_ATTEMPT_IDENTITY
&& EXACT_OUTCOME_BINDING
```

A production implementation must replace the synthetic tag with a reviewed cryptographic trust mechanism.

## Monotonic anti-replay sequence

```text
trusted_next_receipt_seq = N
receipt seq = N
+ exact authentication
        ↓
receipt accepted
trusted_next_receipt_seq = N + 1
```

Old, duplicate, delayed, or reordered sequence numbers fail closed.

Authentication failure does not consume the sequence number. An authenticated receipt does consume its sequence number even when A6 subsequently rejects it as semantically stale. This prevents a correctly authenticated but unusable envelope from being replayed indefinitely against later state.

## Deterministic discriminator

```text
attempt 0 → UNKNOWN
        ↓
forged NOT_COMMITTED receipt seq 0
→ AUTH_TAG reject
→ sequence remains 0
→ UNKNOWN preserved
        ↓
exact NOT_COMMITTED receipt seq 0
→ authenticated
→ A6 reconciliation accepted
→ sequence becomes 1
        ↓
attempt 1 → external effect → UNKNOWN
        ↓
replayed old seq 0 receipt
→ RECEIPT_SEQUENCE reject
        ↓
foreign device receipt seq 1
→ DEVICE_ID reject
        ↓
exact COMMITTED receipt seq 1
→ authenticated
→ A6 terminal committed
→ sequence becomes 2
        ↓
later attempt
→ terminal replay blocked
```

## Core invariants

```text
A6_RECONCILE_VALID
=> A7_AUTH_ACCEPT
```

```text
A7_AUTH_ACCEPT
=> TRUST_VALID
&& EXACT_DEVICE_ID
&& EXACT_KEY_EPOCH
&& RECEIPT_SEQ == TRUSTED_NEXT_RECEIPT_SEQ_PRE
&& AUTH_TAG_MATCH
&& !SEQUENCE_EXHAUSTED
```

```text
AUTH_REJECT
=> NO_A6_RECONCILIATION
&& NO_TRUST_STATE_MUTATION
```

```text
AUTH_ACCEPT
=> TRUSTED_NEXT_RECEIPT_SEQ_POST
   == TRUSTED_NEXT_RECEIPT_SEQ_PRE + 1
```

```text
AUTH_ACCEPT + A6_SEMANTIC_REJECT
=> RECEIPT_SEQUENCE_CONSUMED
&& NO_A6_PERSISTENT_OUTCOME_MUTATION
```

```text
LOGIC_RESTART
=> TRUST_RECORD_PRESERVED
&& RECEIPT_SEQUENCE_PRESERVED
&& A6_OUTCOME_STATE_PRESERVED
```

## Relation to A6

- A6 answers: “Does this outcome evidence belong to the exact unresolved attempt, and what authority transition follows?”
- A7 answers first: “Did the trusted accelerator-device identity authenticate this exact receipt envelope at the expected monotonic sequence?”

Together:

```text
trusted receipt envelope
→ authenticated device provenance
→ exact A6 attempt identity
→ durable outcome transition
→ replay decision
```

## Claim boundary

A7 is a bounded, reduced-width, single-trusted-device model with one key epoch, one persistent receipt sequence, one A6 lineage, and at most one unresolved attempt.

The rotate/XOR keyed tag is a synthetic formal device, not cryptographic security. A7 does not claim:

- resistance to forgery under a real adversarial cryptographic model;
- SPDM, DICE, TPM, secure-element, PKI, certificate-chain, or attestation conformance;
- key secrecy or side-channel resistance;
- secure key provisioning;
- key rotation or re-attestation;
- multiple trusted devices;
- Byzantine or multi-source outcome reconciliation;
- actual NVRAM or complete power-loss persistence;
- real GPU/TPU/NPU transport;
- CDC, memory ordering, timing, PPA, liveness, production widths, or unbounded correctness.

A7 verifies the **control-flow boundary around an authenticated receipt predicate**, not the security of a production authentication algorithm.

## Next useful milestone

A8 should model trust-key rotation and device re-attestation, including delayed receipts from a retired key epoch and fail-closed recovery when the trust record changes while an accelerator attempt remains unresolved.

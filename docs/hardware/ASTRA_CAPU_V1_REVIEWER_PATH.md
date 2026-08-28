# ASTRA–CaPU v1 Reviewer Path

Status: architecture package entrypoint.

## Visual map

[![ASTRA–CaPU 3D Flower poster](assets/astra-capu-v1-reference-architecture-poster.jpg)](assets/astra-capu-v1-reference-architecture.svg)

- Generated poster preview: [`assets/astra-capu-v1-reference-architecture-poster.jpg`](assets/astra-capu-v1-reference-architecture-poster.jpg)
- Repo-native vector map: [`assets/astra-capu-v1-reference-architecture.svg`](assets/astra-capu-v1-reference-architecture.svg)

The visual is a north-star architecture map, not evidence that every pictured block exists in production silicon.

## Recommended review order

```text
1. Reference architecture
2. Execution contract
3. Vendor-readiness gates
4. R0 fault-injected demonstrator
5. Verified v0.33 authority-incarnation base
```

### 1. Architecture

[`ASTRA_CAPU_V1_REFERENCE_ARCHITECTURE.md`](ASTRA_CAPU_V1_REFERENCE_ARCHITECTURE.md)

Defines the architectural split:

```text
Causal DNA = exact state identity, history, evidence and allowed futures
ASTRA      = possible transitions, dependencies and conflicts
CaPU       = execution authority, recovery, reconciliation and proof receipt
```

### 2. Executable contract

[`ASTRA_CAPU_V1_EXECUTION_CONTRACT.md`](ASTRA_CAPU_V1_EXECUTION_CONTRACT.md)

Defines the minimum implementation-neutral objects:

```text
IntentEnvelope
AuthorityTicket
OutcomeEvidence
ProofReceipt
```

### 3. Honest readiness boundary

[`ASTRA_CAPU_VENDOR_READINESS.md`](ASTRA_CAPU_VENDOR_READINESS.md)

Separates what is already credible from what is still required before a Google-, Anthropic-, accelerator-vendor-, or silicon-design-level claim.

### 4. Next falsifiable demonstrator

[`ASTRA_CAPU_R0_DEMO_PLAN.md`](ASTRA_CAPU_R0_DEMO_PLAN.md)

The R0 acceptance condition is deliberately concrete:

```text
unsafe baseline produces duplicate-effect or false-success evidence
AND
CaPU prevents it in the defined fault-injected scope
AND
accepted transitions are bound to machine-readable receipts
AND
overhead is measured
```

### 5. Verified base

This package is stacked on CaPU v0.33 / PR #87, exact head:

```text
f9d3832d84dc2415617a782cb226af83943b5ecd
```

The architecture package does not modify the v0.33 RTL or expand its bounded formal claim.

## Strategic position

```text
Do not claim another TPU.
Build and measure a causal execution/recovery control plane
that can sit beside existing CPU/GPU/TPU/NPU fabrics.
```

The next implementation milestone is the smallest end-to-end R0 adapter from committed authority through a synthetic accelerator fault boundary to outcome evidence, proof receipt, and gated memory update.

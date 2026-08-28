# ASTRA–CaPU v1.0-A2 — Accelerator Crash-Injection Benchmark

Status: executable synthetic benchmark candidate.

## Purpose

A2 is the first end-to-end discriminating experiment built on the A1 Accelerator Effect Authority Interface.

It compares two recovery strategies after an accelerator command was dispatched but local completion state was lost:

```text
unsafe baseline
vs
ASTRA–CaPU A1 evidence-gated recovery
```

The benchmark is intentionally small, deterministic and adversarial. The external target is non-idempotent: each physical commit increments an effect counter, so a duplicate cannot hide behind an idempotent API.

## Unsafe baseline

The baseline represents two common but invalid shortcuts.

### Missing receipt means not committed

```text
dispatch
-> device may commit
-> crash before local receipt
-> receipt missing
-> assume NOT_COMMITTED
-> blind retry
```

When the device already committed, the retry produces a second physical effect.

### Dispatch acknowledgement means success

```text
dispatch accepted
-> device does not commit
-> dispatch acknowledgement treated as outcome
-> success claimed
```

This produces false success with zero physical effects.

## ASTRA–CaPU path

```text
pre-dispatch checkpoint
-> committed AuthorityTicket
-> dispatch + durable issue witness
-> injected crash
-> stale checkpoint recovery
-> durable issue witness reconstructs UNKNOWN
-> no replay / retire / success claim
-> exact device readback
   -> NOT_COMMITTED: one authorized next attempt
   -> COMMITTED: no retry, seal exact effect
   -> CONFLICT: fail closed
```

The benchmark uses the A1 identity without weakening it:

```text
queue_incarnation
+ queue_epoch
+ slot_id
+ command_id
+ attempt_id
+ effect_id
```

## Scenarios

### 1. Crash before external effect

The first attempt never commits. Both strategies can eventually produce one effect, but CaPU does so only after exact negative evidence authorizes one next attempt.

### 2. Crash after effect, before receipt

The first attempt commits externally, then the process crashes before local completion state is available.

Expected discriminator:

```text
unsafe baseline -> 2 physical effects / 1 duplicate
ASTRA–CaPU     -> 1 physical effect / 0 duplicates
```

### 3. Dispatch acknowledgement false success

The device accepts dispatch but does not commit the external effect.

Expected discriminator:

```text
unsafe baseline -> claims success with 0 effects
ASTRA–CaPU     -> remains UNKNOWN, obtains NOT_COMMITTED evidence,
                  performs one authorized retry, then seals 1 effect
```

### 4. Conflicting readback

The device-side evidence provider returns `CONFLICT`.

Expected discriminator:

```text
ASTRA–CaPU -> no replay, no retirement, no success claim
```

## Expected aggregate boundary

```text
unsafe duplicate effects: 2
CaPU duplicate effects:   0

unsafe false successes:   1
CaPU false successes:     0

CaPU UNKNOWN blocks:      4
CaPU sealed successes:    3
CaPU conflict fail-closed:1
```

The benchmark passes only when the unsafe path exhibits both a duplicate and a false-success failure while the CaPU path exhibits neither.

## Executable artifacts

```text
tools/astra_capu_crash_benchmark_a2.py
tests/test_astra_capu_crash_benchmark_a2.py
schemas/hardware/astra-capu-crash-benchmark-v1.0-a2.schema.json
examples/hardware/astra-capu-v1-a2-expected.json
.github/workflows/astra-capu-v1-a2-crash-injection.yml
```

Run:

```bash
python3 -m unittest -v tests/test_astra_capu_effect_authority_a1.py
python3 -m unittest -v tests/test_astra_capu_crash_benchmark_a2.py
python3 -m tools.astra_capu_crash_benchmark_a2
```

## Acceptance conditions

A2 is verified only when one exact head passes:

- all A1 regressions;
- all A2 unit and adversarial tests;
- the executable benchmark marker;
- unsafe duplicate-effect count greater than zero;
- unsafe false-success count greater than zero;
- CaPU duplicate-effect count exactly zero;
- CaPU false-success count exactly zero;
- all injected crash paths reconstruct `UNKNOWN` before evidence;
- the conflict path remains fail closed;
- schema, fixture and generated result parse successfully;
- a sealed evidence artifact records exact hashes.

## Claim boundary

A2 is a deterministic software benchmark over a synthetic non-idempotent accelerator target and synthetic device readback.

It does not claim:

```text
real GPU / TPU / NPU command-queue integration
PCIe / CXL / NoC transport behavior
real device reset semantics
production durable storage
evidence authenticity
hardware performance
FPGA or silicon implementation
formal proof
liveness / fairness
arbitrary concurrency
unbounded correctness
```

The next milestone after A2 is **A3 — adapter boundary for a real local accelerator API or hardware simulator**, preserving the same A1 record identities and A2 negative controls.

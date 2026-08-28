# ASTRA–CaPU v1.0-A3 — Icarus Device Adapter

Status: executable hardware-simulator adapter candidate.

## Purpose

A3 moves the A1/A2 authority and crash-recovery contract across a real process boundary into an Icarus Verilog device simulation.

The adapter is not a mock function call. Every operation launches a fresh `vvp` process:

```text
host process
-> vvp reset process
-> vvp dispatch process
-> injected host/device receipt loss
-> vvp readback process
```

The synthetic external effect counter is persisted outside each simulator process. Therefore a later readback can observe an effect committed by a process that no longer exists.

## Hardware-simulator components

```text
rtl/astra_capu_effect_counter_a3.sv
rtl/tb/astra_capu_effect_counter_a3_tb.sv
```

The device model exposes:

```text
load durable effect count
accept command
optionally commit non-idempotent effect
emit completion signal
read current effect count
```

The testbench provides process-level operations through plusargs:

```text
+OP=reset
+OP=dispatch +COMMIT=0|1 +DROP_RECEIPT=0|1
+OP=readback
+STATE_FILE=<durable external state>
```

## Host adapter

```text
tools/astra_capu_icarus_adapter_a3.py
```

`IcarusDeviceAdapter` launches `vvp` independently for every reset, dispatch and readback. It requires the simulator pass marker and parses one machine-readable event line from each process.

## Discriminating experiment

### Unsafe duplicate path

```text
vvp process 1: dispatch commits effect, receipt dropped
process exits
vvp process 2: blind retry commits same effect again
vvp process 3: readback count = 2
```

### ASTRA–CaPU committed path

```text
pre-dispatch A1 checkpoint
-> durable issue witness
-> vvp dispatch commits effect, receipt dropped
-> process exits
-> recovery reconstructs UNKNOWN
-> new vvp readback count = 1
-> exact COMMITTED evidence
-> no retry
-> SEALED
```

### Unsafe false-success path

```text
vvp dispatch accepts but does not commit
-> baseline treats acceptance as success
-> new vvp readback count = 0
```

### ASTRA–CaPU negative path

```text
vvp dispatch does not commit, receipt absent
-> process exits
-> recovery reconstructs UNKNOWN
-> new vvp readback count = 0
-> exact NOT_COMMITTED evidence
-> one authorized next attempt
-> new vvp dispatch commits
-> new vvp readback count = 1
-> SEALED
```

## Expected aggregate result

```text
simulator process launches: 15
persistent restart verified: true

unsafe duplicate effects: 1
CaPU duplicate effects:   0

unsafe false successes:   1
CaPU false successes:     0

CaPU UNKNOWN recoveries:  2
CaPU authorized retries:  1
CaPU sealed successes:    2
```

## Run

```bash
iverilog -g2012 \
  -o /tmp/astra-capu-a3.vvp \
  rtl/astra_capu_effect_counter_a3.sv \
  rtl/tb/astra_capu_effect_counter_a3_tb.sv

A3_SIMULATOR=/tmp/astra-capu-a3.vvp \
  python3 -m unittest -v tests/test_astra_capu_icarus_adapter_a3.py

python3 -m tools.astra_capu_icarus_adapter_a3 \
  --simulator /tmp/astra-capu-a3.vvp
```

## Acceptance conditions

A3 becomes verified only when one exact head passes:

- RTL/testbench compilation with Icarus Verilog;
- direct reset, dispatch, dropped-receipt and fresh-process readback smoke checks;
- 12/12 A1 regression tests;
- 11/11 A2 regression tests;
- all A3 device-adapter tests;
- unsafe separate-process duplicate effect = 1;
- unsafe dispatch-ack false success = 1;
- CaPU duplicates = 0;
- CaPU false successes = 0;
- both CaPU crash paths reconstruct `UNKNOWN`;
- only exact negative readback authorizes one retry;
- generated JSON result and expected fixture agree;
- Validate Examples and Core RTL Smoke remain green;
- exact hashes and the simulator executable are sealed in the evidence artifact.

## What A3 establishes

A2 proved the recovery distinction inside a deterministic software model. A3 adds three materially stronger facts:

1. device execution occurs in a separate hardware simulator process;
2. the external effect survives process termination;
3. outcome evidence is obtained through a fresh simulator readback rather than retained host memory.

## Claim boundary

A3 is still a bounded synthetic adapter. The effect counter persistence is implemented by the testbench using a host file; it is not synthesizable durable storage.

A3 does not claim:

```text
real GPU / TPU / NPU integration
production command queue
PCIe / CXL / NoC semantics
real power-loss persistence
cryptographic evidence authenticity
hardware-rooted identity
performance or PPA
FPGA deployment
formal proof of the A3 composition
arbitrary concurrency
liveness / fairness
unbounded correctness
```

The next milestone is **A4 — synthesizable authority shim around the simulator command interface**, separating the host-side A1 reference from a small RTL gate that blocks command issue until an exact committed authority token is present.

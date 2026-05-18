# CMC Benchmark Results

Status: early developer benchmark / not a throughput SLA.

This document tracks reproducible benchmark output for the Causal Memory Controller (CMC) Rust simulator.

The benchmark is intentionally small. It exists to make CMC overhead visible as the simulator evolves, not to claim production performance or hardware readiness.

---

## How to run

From the repository root:

```bash
npm run bench:cmc
```

Or from this crate:

```bash
cargo run --release --bin cmc_bench --locked
```

---

## What the benchmark does

Current benchmark workload:

```text
10,000 causal writes
10,000 committed effects
1 audit pass
```

The benchmark prints:

```text
CMC-BENCH developer-microbenchmark v0
ops=10000
accepted_writes=<count>
accepted_effects=<count>
audit.entries=<count>
audit.effects=<count>
audit.findings=<count>
write.total_ns=<nanoseconds>
write.ns_per_op=<nanoseconds per write>
effect.total_ns=<nanoseconds>
effect.ns_per_op=<nanoseconds per effect>
audit.total_ns=<nanoseconds>
note=developer benchmark only; not a throughput SLA
```

---

## Current expected correctness signal

A healthy run should show:

```text
accepted_writes=10000
accepted_effects=10000
audit.entries=10000
audit.effects=10000
audit.findings=0
```

If these values change unexpectedly, the benchmark may indicate a semantic regression rather than only a performance change.

---

## Latest committed result

No machine-specific benchmark result is committed yet.

Reason: the first benchmark output should be produced from a known environment and recorded with machine/context metadata.

Recommended metadata for first committed result:

```text
Date:
Commit:
Machine / runner:
CPU:
OS:
Rust version:
Command:
Output:
```

---

## Interpretation rules

- Treat results as developer-machine baselines, not as product claims.
- Compare numbers only against runs from similar environments.
- Prefer trends over single measurements.
- Keep correctness fields (`accepted_*`, `audit.*`) as important as timing fields.
- Do not use these numbers as a CMC throughput SLA.

---

## Why this matters

CMC is a hardware-adjacent research path. Before discussing embedded profiles, FPGA state machines, or controller hardware, the software simulator needs visible evidence:

```text
semantic correctness
reproducible golden behavior
rough overhead baseline
trendable benchmark results
```

This file is the first benchmark-report anchor for that evidence ladder.

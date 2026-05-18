# cmc-core

`cmc-core` is the first Rust reference simulator for the Causal Memory Controller (CMC) research path.

It models a tiny causal metadata plane for memory/effect operations:

```text
write(address, value_hash, cause)
read(address, requester, cause)
effect(effect_id, parent_cause)
audit()
```

## Why this exists

Ordinary memory stores bytes. Causal Memory stores why a byte, transition, or effect was allowed.

The simulator exists to make the CMC thesis testable before embedded, FPGA, or hardware work begins.

## Run tests

From this directory:

```bash
cargo test
```

From the repository root:

```bash
npm run verify:cmc-golden
```

## Run developer benchmark

From the repository root:

```bash
npm run bench:cmc
```

Or from this directory:

```bash
cargo run --release --bin cmc_bench --locked
```

The benchmark runs 10,000 causal writes, 10,000 committed effects, and one audit pass, then prints rough developer-machine timing numbers.

These numbers are not a throughput SLA. They are an early reproducible baseline for tracking simulator overhead as CMC-0 evolves.

## Golden fixture

CMC-0 includes a golden fixture:

```text
fixtures/basic_flow.golden.txt
```

The fixture pins the expected output for a basic causal memory flow:

```text
known-cause write -> accepted
missing-cause write -> rejected
effect before commit -> rejected
effect after commit -> accepted
chain reconstruction -> [2, 1]
audit -> no findings
```

The test `basic_flow_matches_golden_fixture` verifies that simulator behavior remains stable against this snapshot.

## Current proof cases

The test suite currently checks:

- valid write with known cause is accepted
- write with missing cause is rejected
- write with unknown cause is rejected
- effect before causal commit is rejected
- committed effect is accepted
- memory-derived effect chain can be reconstructed
- basic flow matches the golden fixture

## Non-claims

This crate is not a hardware implementation, not a memory controller, and not a production runtime. It is a deterministic simulator for CMC-0 semantics.

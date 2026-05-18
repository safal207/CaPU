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

## Current proof cases

The test suite currently checks:

- valid write with known cause is accepted
- write with missing cause is rejected
- write with unknown cause is rejected
- effect before causal commit is rejected
- committed effect is accepted
- memory-derived effect chain can be reconstructed

## Non-claims

This crate is not a hardware implementation, not a memory controller, and not a production runtime. It is a deterministic simulator for CMC-0 semantics.

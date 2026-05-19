# CMC Baseline Status

Status: reviewer-ready baseline snapshot.

This document summarizes the current CMC baseline after the initial thesis, architecture, replay, integrity, fixture, and CI-gate work.

---

## Baseline claim

```text
transition legitimacy can be represented, replayed, checked, and regression-tested
```

The current repository does not claim a finished product. It claims an executable research scaffold for legitimacy-preserving computation.

---

## Current evidence chain

```text
thesis
 -> architecture
 -> simulator
 -> deterministic trace events
 -> JSONL replay fixtures
 -> fixture structure checks
 -> fixture fingerprint checks
 -> hash-chain integrity demo
 -> tampering detection demo
 -> divergence detection demo
 -> CI workflow gate
 -> evidence map
 -> reviewer quickstart
```

---

## Core documents

- [WHY_CAUSAL_COMPUTATION.md](WHY_CAUSAL_COMPUTATION.md)
- [CAUSAL_EXECUTION_ARCHITECTURE.md](CAUSAL_EXECUTION_ARCHITECTURE.md)
- [CAUSAL_MEMORY_CONTROLLER.md](CAUSAL_MEMORY_CONTROLLER.md)
- [CMC_REPLAY.md](CMC_REPLAY.md)
- [CMC_HASH_CHAIN.md](CMC_HASH_CHAIN.md)
- [CMC_EVIDENCE_MAP.md](CMC_EVIDENCE_MAP.md)
- [CMC_REVIEWER_QUICKSTART.md](CMC_REVIEWER_QUICKSTART.md)

---

## Executable checks

From `rust/cmc-core`:

```bash
cargo fmt --check
cargo test --all --locked
cargo run --bin cmc_demo --locked
cargo run --bin verify_trace --locked
cargo run --bin verify_trace_tampered --locked
cargo run --bin replay_fixture_verify --locked
cargo run --bin replay_fingerprint_verify --locked
cargo run --bin trace_divergence --locked
```

From repository root:

```bash
npm run demo:cmc
npm run verify:cmc-golden
npm run bench:cmc
```

---

## CI coverage

The CMC GitHub Actions workflow is configured to run on changes to:

```text
rust/cmc-core/**
.github/workflows/cmc-rust.yml
```

The workflow currently covers:

- formatting check
- Rust tests
- executable CMC demo
- valid trace hash-chain verifier
- tampering detection demo
- replay fixture structure verifier
- replay fixture fingerprint verifier
- replay divergence detector

Doc-only changes outside those paths do not necessarily trigger this workflow.

---

## Replay fixture fingerprints

The current replay fixture fingerprint verifier checks:

| Fixture | Expected decision | Events | Fingerprint |
| --- | --- | ---: | --- |
| `fixtures/replay/missing_cause.jsonl` | `REJECT_MISSING_CAUSE` | 1 | `88fd99689760140e` |
| `fixtures/replay/forbidden_effect_before_commit_fixture.jsonl` | `REJECT_EFFECT_BEFORE_COMMIT` | 1 | `28bf87f68e4ec6cb` |

These fingerprints are developer-stability fingerprints using the current FNV-1a64 demo implementation. They are not production cryptographic evidence.

---

## What is strong today

The baseline is strong because it turns a conceptual claim into executable artifacts:

- rejected illegal memory/effect transitions
- deterministic trace events
- replay fixture structure checks
- fixture fingerprint drift checks
- tampering detection demo
- divergence detection demo
- CI enforcement path

---

## Known limits

The baseline does not yet provide:

- production cryptographic sealing
- formal verification
- hardware implementation
- real workload performance evaluation
- full multi-agent benchmark coverage
- security certification

---

## Next phase

The next phase should focus on:

1. replacing developer hash demo with a stronger cryptographic hash-chain implementation,
2. expanding replay fixture coverage,
3. adding negative fixtures for more violation classes,
4. creating an auditor-facing report format,
5. measuring overhead and stability across repeated runs.

---

## One-line status

```text
CMC baseline is reviewer-ready as an executable research scaffold, not yet production-ready infrastructure.
```

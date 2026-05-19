# CMC Evidence Map

Status: reviewer evidence map / grant-readiness support.

This document maps the Causal Memory Controller thesis to concrete repository evidence.

The purpose is simple: every major research claim should point to an artifact, an executable check, or a CI gate.

---

## Core thesis

```text
Ordinary memory stores what changed.
Causal Memory stores why the change was allowed.
```

Broader thesis:

```text
Traditional computing verifies state transitions.
Causal computing verifies transition legitimacy.
```

---

## Evidence table

| Claim | Evidence artifact | Executable check | CI gate |
| --- | --- | --- | --- |
| CMC models causal memory/effect decisions | `rust/cmc-core/src/lib.rs` | `cargo test --all --locked` | Yes |
| Missing cause must reject memory write | Rust unit tests + replay fixture | `cargo test --all --locked` | Yes |
| Unknown cause must reject memory write | Rust unit tests | `cargo test --all --locked` | Yes |
| Effect cannot execute before causal commit | Rust unit tests + demo + replay fixture | `cargo run --bin cmc_demo --locked` | Yes |
| Committed cause can authorize effect | Rust unit tests | `cargo test --all --locked` | Yes |
| CMC emits deterministic trace events | `trace_events()` / `trace_jsonl()` | `cargo test --all --locked` | Yes |
| Basic flow has a stable golden snapshot | `fixtures/basic_flow.golden.txt` | `npm run verify:cmc-golden` | Via tests |
| Replay fixtures preserve semantic structure | `fixtures/replay/*.jsonl` | `cargo run --bin replay_fixture_verify --locked` | Yes |
| Replay fixture drift can be detected | `replay_fingerprint_verify.rs` | `cargo run --bin replay_fingerprint_verify --locked` | Yes |
| Trace hash chain can validate expected trace | `verify_trace.rs` | `cargo run --bin verify_trace --locked` | Yes |
| Tampered trace can be detected | `verify_trace_tampered.rs` | `cargo run --bin verify_trace_tampered --locked` | Yes |
| Diverged replay can be detected | `trace_divergence.rs` | `cargo run --bin trace_divergence --locked` | Yes |
| Full reviewer baseline can run as one command | `scripts/run-cmc-reviewer-demo.mjs` | `npm run review:cmc` | Yes |
| Architecture has a coherent conceptual model | `CAUSAL_EXECUTION_ARCHITECTURE.md` | Documentation review | No |
| Causal computation thesis is explicit | `WHY_CAUSAL_COMPUTATION.md` | Documentation review | No |
| Phase 2 has an explicit next-step roadmap | `CMC_PHASE_2_ROADMAP.md` | Documentation review | No |
| Invariants are explicitly mapped to evidence | `CMC_INVARIANTS.md` | Documentation review | No |
| Future hardware path is scoped but non-claimed | `CMC_FPGA_SKETCH.md` | Documentation review | No |

---

## Reviewer path

Recommended review order:

```text
1. WHY_CAUSAL_COMPUTATION.md
2. CAUSAL_EXECUTION_ARCHITECTURE.md
3. CAUSAL_MEMORY_CONTROLLER.md
4. CMC_REPLAY.md
5. CMC_HASH_CHAIN.md
6. CMC_EVIDENCE_MAP.md
7. CMC_REVIEWER_QUICKSTART.md
8. CMC_BASELINE_STATUS.md
9. CMC_PHASE_2_ROADMAP.md
10. CMC_INVARIANTS.md
11. rust/cmc-core/README.md
12. rust/cmc-core/src/lib.rs
13. scripts/run-cmc-reviewer-demo.mjs
14. .github/workflows/cmc-rust.yml
```

This path moves from thesis to architecture to executable validation.

---

## One-command validation

From repository root:

```bash
npm run review:cmc
```

This runs the full CMC reviewer baseline:

```text
cargo fmt --check
cargo test --all --locked
cargo run --bin cmc_demo --locked
cargo run --bin verify_trace --locked
cargo run --bin verify_trace_tampered --locked
cargo run --bin replay_fixture_verify --locked
cargo run --bin replay_fingerprint_verify --locked
cargo run --bin trace_divergence --locked
```

Expected final result:

```text
result=reviewer_baseline_passed
```

This command is also executed in the CMC GitHub Actions workflow.

---

## Local validation commands

From repository root:

```bash
npm run review:cmc
npm run demo:cmc
npm run verify:cmc-golden
npm run bench:cmc
```

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

---

## What the evidence proves today

Today, the repository demonstrates that a minimal CMC simulator can:

- reject memory writes without explicit cause
- reject writes with unknown cause
- reject effects before causal commit
- accept effects after commit
- emit replayable trace events
- export trace events as JSONL
- preserve a golden fixture snapshot
- verify replay fixture structure
- verify replay fixture fingerprints
- detect tampered trace decisions
- detect replay divergence
- run the full reviewer baseline through one command
- enforce these checks in CI

---

## What the evidence does not prove yet

The current evidence does not claim:

- production-grade cryptographic sealing
- hardware implementation
- performance under real production workloads
- formal proof of all transition semantics
- complete agent safety coverage
- replacement for sandboxing, policy design, or conventional security engineering

The current repository should be read as an executable research scaffold for legitimacy-preserving computation.

---

## Grant/research interpretation

The strongest claim is not that CMC is finished.

The strongest claim is:

```text
transition legitimacy can be made observable, replayable, testable, one-command verifiable, and CI-enforced.
```

That is the core research direction.

---

## One-line summary

```text
CMC turns causal legitimacy from prose into one-command executable evidence.
```

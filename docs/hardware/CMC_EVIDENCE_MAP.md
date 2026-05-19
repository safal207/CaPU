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

Current executable evidence chain:

```text
invariant -> scenario -> fixture -> manifest -> verifier -> reviewer command -> CI
```

---

## Evidence table

| Claim | Evidence artifact | Executable check | CI gate |
| --- | --- | --- | --- |
| CMC models causal memory/effect decisions | `rust/cmc-core/src/lib.rs` | `cargo test --all --locked` | Yes |
| I1: Missing cause must reject memory write | `CMC_INVARIANTS.md` + `missing_cause.jsonl` + `MANIFEST.tsv` | `cargo run --bin replay_fixture_verify --locked` | Yes |
| I2: Unknown cause must reject memory write | `CMC_INVARIANTS.md` + `unknown_cause.jsonl` + `MANIFEST.tsv` | `cargo run --bin replay_fixture_verify --locked` | Yes |
| I3: Effect cannot execute before causal commit | `CMC_INVARIANTS.md` + `forbidden_effect_before_commit_fixture.jsonl` + `MANIFEST.tsv` | `cargo run --bin replay_fixture_verify --locked` | Yes |
| I4: Committed cause can authorize effect | `CMC_INVARIANTS.md` + `valid_committed_effect.jsonl` + `MANIFEST.tsv` | `cargo run --bin replay_fixture_verify --locked` | Yes |
| CMC emits deterministic trace events | `trace_events()` / `trace_jsonl()` | `cargo test --all --locked` | Yes |
| Basic flow has a stable golden snapshot | `fixtures/basic_flow.golden.txt` | `npm run verify:cmc-golden` | Via tests |
| Replay fixtures preserve semantic structure | `fixtures/replay/MANIFEST.tsv` + `replay_fixture_verify.rs` | `cargo run --bin replay_fixture_verify --locked` | Yes |
| Replay fixture drift can be detected | `fixtures/replay/MANIFEST.tsv` + `replay_fingerprint_verify.rs` | `cargo run --bin replay_fingerprint_verify --locked` | Yes |
| Trace hash chain can validate expected trace | `verify_trace.rs` | `cargo run --bin verify_trace --locked` | Yes |
| Tampered trace can be detected | `verify_trace_tampered.rs` | `cargo run --bin verify_trace_tampered --locked` | Yes |
| Diverged replay can be detected | `trace_divergence.rs` | `cargo run --bin trace_divergence --locked` | Yes |
| Full reviewer baseline can run as one command | `scripts/run-cmc-reviewer-demo.mjs` | `npm run review:cmc` | Yes |
| Architecture has a coherent conceptual model | `CAUSAL_EXECUTION_ARCHITECTURE.md` | Documentation review | No |
| Causal computation thesis is explicit | `WHY_CAUSAL_COMPUTATION.md` | Documentation review | No |
| Phase 2 has an explicit next-step roadmap | `CMC_PHASE_2_ROADMAP.md` | Documentation review | No |
| Invariants are explicitly mapped to executable evidence | `CMC_INVARIANTS.md` + `fixtures/replay/MANIFEST.tsv` | `npm run review:cmc` | Yes |
| Future hardware path is scoped but non-claimed | `CMC_FPGA_SKETCH.md` | Documentation review | No |

---

## Manifest-linked replay evidence

The replay corpus is currently driven by:

```text
rust/cmc-core/fixtures/replay/MANIFEST.tsv
```

Current manifest shape:

```tsv
scenario_id	invariant_id	path	decision	events	fingerprint
```

Current checked scenarios:

| Scenario | Invariant | Fixture | Decision | Fingerprint |
| --- | --- | --- | --- | --- |
| `write_missing_cause` | `I1` | `missing_cause.jsonl` | `REJECT_MISSING_CAUSE` | `88fd99689760140e` |
| `write_unknown_cause` | `I2` | `unknown_cause.jsonl` | `REJECT_UNKNOWN_CAUSE` | `d8c4983b8a5a0ab0` |
| `effect_before_commit` | `I3` | `forbidden_effect_before_commit_fixture.jsonl` | `REJECT_EFFECT_BEFORE_COMMIT` | `28bf87f68e4ec6cb` |
| `valid_committed_effect` | `I4` | `valid_committed_effect.jsonl` | `ACCEPT_EFFECT` | `e3e96ba017e2c235` |

This makes the evidence chain explicit:

```text
thesis -> invariant -> scenario -> fixture -> fingerprint -> verifier -> CI
```

---

## Reviewer path

Recommended review order:

```text
1. WHY_CAUSAL_COMPUTATION.md
2. CAUSAL_EXECUTION_ARCHITECTURE.md
3. CAUSAL_MEMORY_CONTROLLER.md
4. CMC_REPLAY.md
5. CMC_HASH_CHAIN.md
6. CMC_INVARIANTS.md
7. rust/cmc-core/fixtures/replay/MANIFEST.md
8. rust/cmc-core/fixtures/replay/MANIFEST.tsv
9. CMC_EVIDENCE_MAP.md
10. CMC_REVIEWER_QUICKSTART.md
11. CMC_BASELINE_STATUS.md
12. CMC_PHASE_2_ROADMAP.md
13. rust/cmc-core/README.md
14. rust/cmc-core/src/lib.rs
15. scripts/run-cmc-reviewer-demo.mjs
16. .github/workflows/cmc-rust.yml
```

This path moves from thesis to architecture to invariants to executable validation.

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
- map I1-I4 invariants to replay scenarios
- verify replay fixture structure through a machine-readable manifest
- verify replay fixture fingerprints through the same manifest
- emit replayable trace events
- export trace events as JSONL
- preserve a golden fixture snapshot
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
transition legitimacy can be made observable, replayable, testable, one-command verifiable, manifest-linked, and CI-enforced.
```

That is the core research direction.

---

## One-line summary

```text
CMC turns causal legitimacy from prose into manifest-linked executable evidence.
```

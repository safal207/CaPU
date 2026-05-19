# CMC Reviewer Quickstart

Status: 5-minute reviewer path / executable evidence guide.

This document gives reviewers a short path from thesis to executable evidence.

Goal:

```text
verify that causal legitimacy is represented, replayed, and checked by executable artifacts
```

---

## 0. Read the thesis first

Start here:

1. [WHY_CAUSAL_COMPUTATION.md](WHY_CAUSAL_COMPUTATION.md)
2. [CAUSAL_EXECUTION_ARCHITECTURE.md](CAUSAL_EXECUTION_ARCHITECTURE.md)
3. [CMC_EVIDENCE_MAP.md](CMC_EVIDENCE_MAP.md)
4. [CMC_BASELINE_STATUS.md](CMC_BASELINE_STATUS.md)

Core claim:

```text
Traditional computing verifies state transitions.
Causal computing verifies transition legitimacy.
```

---

## 1. Run the one-command reviewer demo

From repository root:

```bash
npm run review:cmc
```

This command runs the full CMC baseline evidence path:

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

Expected final output:

```text
result=reviewer_baseline_passed
```

Evidence claim:

```text
transition legitimacy can be represented, replayed, checked, and regression-tested
```

---

## 2. What the one-command demo proves

The reviewer demo checks that:

```text
missing cause -> reject
unknown cause -> reject
effect before commit -> reject
committed cause -> accept effect
trace events -> emitted deterministically
valid trace -> accepted
tampered decision -> detected
fixture structure -> valid
fixture fingerprints -> stable
expected trace vs diverged trace -> mismatch detected
```

Evidence claim:

```text
CMC can model memory/effect decisions using explicit causal authorization and executable replay evidence.
```

---

## 3. Manual command breakdown

If you want to inspect each step manually, run the following from `rust/cmc-core`.

### Simulator tests

```bash
cargo test --all --locked
```

Checks basic causal memory/effect invariants:

```text
missing cause -> reject
unknown cause -> reject
effect before commit -> reject
committed cause -> accept effect
trace events -> emitted deterministically
```

### Blocked-transition demo

```bash
cargo run --bin cmc_demo --locked
```

Expected meaning:

```text
write_without_cause -> rejected
effect_before_commit -> rejected
trace_events -> emitted
result -> blocked illegitimate transition
```

### Trace integrity and tampering detection

```bash
cargo run --bin verify_trace --locked
cargo run --bin verify_trace_tampered --locked
```

Expected meaning:

```text
valid trace -> accepted
tampered decision -> detected
```

Note: this is currently a developer hash-chain demo, not production cryptography.

### Replay fixtures and fingerprint stability

```bash
cargo run --bin replay_fixture_verify --locked
cargo run --bin replay_fingerprint_verify --locked
```

Expected meaning:

```text
fixture structure -> valid
expected decisions -> present
fixture fingerprints -> stable
```

### Divergence detection

```bash
cargo run --bin trace_divergence --locked
```

Expected meaning:

```text
expected trace vs diverged trace -> mismatch detected
```

---

## 4. Optional root-level commands

From repository root:

```bash
npm run demo:cmc
npm run verify:cmc-golden
npm run bench:cmc
```

These provide npm-facing entrypoints for demo, golden snapshot verification, and developer benchmark.

---

## What this quickstart proves

This quickstart demonstrates that CMC currently has executable evidence for:

- causal write rejection
- unknown cause rejection
- commit-before-effect enforcement
- deterministic trace emission
- replay fixture checking
- fixture fingerprint stability
- tampering detection
- divergence detection
- one-command reviewer verification
- CI-enforced replay checks

---

## What this quickstart does not prove

It does not claim:

- production cryptography
- hardware implementation
- formal verification
- complete AI safety coverage
- production workload performance

The current repository is an executable research scaffold.

---

## Reviewer interpretation

The key thing to evaluate is not whether CMC is finished.

The key thing to evaluate is whether the project has made this claim testable:

```text
transition legitimacy can be represented, replayed, checked, and regression-tested
```

That is the current proof point.

---

## One-line summary

```text
Run npm run review:cmc; it turns the CMC causal legitimacy claim into one executable reviewer check.
```

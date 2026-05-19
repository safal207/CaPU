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

Core claim:

```text
Traditional computing verifies state transitions.
Causal computing verifies transition legitimacy.
```

---

## 1. Run the CMC simulator tests

From repository root:

```bash
cd rust/cmc-core
cargo test --all --locked
```

This checks that the simulator enforces basic causal memory/effect invariants.

Expected meaning:

```text
missing cause -> reject
unknown cause -> reject
effect before commit -> reject
committed cause -> accept effect
trace events -> emitted deterministically
```

Evidence claim:

```text
CMC can model memory/effect decisions using explicit causal authorization.
```

---

## 2. Run the blocked-transition demo

From `rust/cmc-core`:

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

Evidence claim:

```text
A requested transition is not automatically legitimate.
```

---

## 3. Verify trace integrity and tampering detection

From `rust/cmc-core`:

```bash
cargo run --bin verify_trace --locked
cargo run --bin verify_trace_tampered --locked
```

Expected meaning:

```text
valid trace -> accepted
tampered decision -> detected
```

Evidence claim:

```text
CMC traces can be sealed and checked for decision-level tampering in the developer integrity demo.
```

Note: this is currently a developer hash-chain demo, not production cryptography.

---

## 4. Verify replay fixtures and fingerprint stability

From `rust/cmc-core`:

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

Evidence claim:

```text
Replay fixtures are not only examples; they are checked for semantic structure and drift.
```

---

## 5. Verify divergence detection

From `rust/cmc-core`:

```bash
cargo run --bin trace_divergence --locked
```

Expected meaning:

```text
expected trace vs diverged trace -> mismatch detected
```

Evidence claim:

```text
Replay divergence can be surfaced as executable evidence.
```

---

## 6. Optional root-level commands

From repository root:

```bash
npm run demo:cmc
npm run verify:cmc-golden
npm run bench:cmc
```

These provide the npm-facing entrypoints for demo, golden snapshot verification, and developer benchmark.

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
Run the tests, demos, trace verifiers, fixture verifiers, and divergence detector; each step turns a causal legitimacy claim into executable evidence.
```

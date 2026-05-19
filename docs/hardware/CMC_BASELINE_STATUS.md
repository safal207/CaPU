# CMC Baseline Status

Status: reviewer-ready baseline snapshot.

This document summarizes the current CMC baseline after thesis, architecture, invariants, replay fixtures, manifest-linked evidence, integrity demos, one-command reviewer demo, and CI-gate work.

---

## Baseline claim

```text
transition legitimacy can be represented, replayed, checked, one-command verified, manifest-linked, and regression-tested
```

The current repository does not claim a finished product. It claims an executable research scaffold for legitimacy-preserving computation.

---

## Current evidence chain

```text
thesis
 -> architecture
 -> invariants
 -> simulator
 -> deterministic trace events
 -> JSONL replay fixtures
 -> machine-readable replay manifest
 -> manifest-linked fixture structure checks
 -> manifest-linked fixture fingerprint checks
 -> hash-chain integrity demo
 -> tampering detection demo
 -> divergence detection demo
 -> one-command reviewer demo
 -> CI workflow gate
 -> evidence map
 -> reviewer quickstart
```

Short form:

```text
invariant -> scenario -> fixture -> manifest -> verifier -> reviewer command -> CI
```

---

## Core documents

- [WHY_CAUSAL_COMPUTATION.md](WHY_CAUSAL_COMPUTATION.md)
- [CAUSAL_EXECUTION_ARCHITECTURE.md](CAUSAL_EXECUTION_ARCHITECTURE.md)
- [CAUSAL_MEMORY_CONTROLLER.md](CAUSAL_MEMORY_CONTROLLER.md)
- [CMC_REPLAY.md](CMC_REPLAY.md)
- [CMC_HASH_CHAIN.md](CMC_HASH_CHAIN.md)
- [CMC_INVARIANTS.md](CMC_INVARIANTS.md)
- [CMC_EVIDENCE_MAP.md](CMC_EVIDENCE_MAP.md)
- [CMC_REVIEWER_QUICKSTART.md](CMC_REVIEWER_QUICKSTART.md)
- [CMC_BASELINE_STATUS.md](CMC_BASELINE_STATUS.md)
- [CMC_PHASE_2_ROADMAP.md](CMC_PHASE_2_ROADMAP.md)

---

## Replay corpus source of truth

Machine-readable replay manifest:

```text
rust/cmc-core/fixtures/replay/MANIFEST.tsv
```

Human-readable manifest explanation:

```text
rust/cmc-core/fixtures/replay/MANIFEST.md
```

Current manifest shape:

```tsv
scenario_id	invariant_id	path	decision	events	fingerprint
```

Current checked scenarios:

| Scenario | Invariant | Fixture | Decision | Events | Fingerprint |
| --- | --- | --- | --- | ---: | --- |
| `write_missing_cause` | `I1` | `fixtures/replay/missing_cause.jsonl` | `REJECT_MISSING_CAUSE` | 1 | `88fd99689760140e` |
| `write_unknown_cause` | `I2` | `fixtures/replay/unknown_cause.jsonl` | `REJECT_UNKNOWN_CAUSE` | 1 | `d8c4983b8a5a0ab0` |
| `effect_before_commit` | `I3` | `fixtures/replay/forbidden_effect_before_commit_fixture.jsonl` | `REJECT_EFFECT_BEFORE_COMMIT` | 1 | `28bf87f68e4ec6cb` |
| `valid_committed_effect` | `I4` | `fixtures/replay/valid_committed_effect.jsonl` | `ACCEPT_EFFECT` | 1 | `e3e96ba017e2c235` |

These fingerprints are developer-stability fingerprints using the current FNV-1a64 demo implementation. They are not production cryptographic evidence.

---

## One-command reviewer check

From repository root:

```bash
npm run review:cmc
```

Expected final result:

```text
result=reviewer_baseline_passed
```

This command runs:

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

---

## CI coverage

The CMC GitHub Actions workflow is configured to run on changes to:

```text
rust/cmc-core/**
scripts/run-cmc-reviewer-demo.mjs
package.json
.github/workflows/cmc-rust.yml
```

The workflow currently covers:

- formatting check
- Rust tests
- executable CMC demo
- valid trace hash-chain verifier
- tampering detection demo
- manifest-linked replay fixture structure verifier
- manifest-linked replay fixture fingerprint verifier
- replay divergence detector
- one-command reviewer demo via `npm run review:cmc`

Doc-only changes outside those paths do not necessarily trigger this workflow.

---

## What is strong today

The baseline is strong because it turns a conceptual claim into executable artifacts:

- rejected illegal memory/effect transitions
- accepted legitimate committed effect transition
- invariant-to-scenario replay mapping for I1-I4
- deterministic trace events
- machine-readable replay manifest
- manifest-linked replay fixture structure checks
- manifest-linked fixture fingerprint drift checks
- tampering detection demo
- divergence detection demo
- one-command reviewer verification
- CI enforcement path

---

## Known limits

The baseline does not yet provide:

- production cryptographic sealing
- formal verification
- hardware implementation
- real workload performance evaluation
- full multi-agent benchmark coverage
- certification-grade assurance

The current repository should be read as an executable research scaffold for legitimacy-preserving computation.

---

## Next phase

The next phase should focus on:

1. replacing developer hash demo with a stronger cryptographic hash-chain implementation,
2. expanding replay fixture coverage toward at least 8 legitimacy violation classes,
3. adding richer manifest metadata such as category, severity, and expected verdict,
4. creating an auditor-facing report format,
5. measuring overhead and stability across repeated runs.

---

## One-line status

```text
CMC baseline is reviewer-ready as a one-command, manifest-linked, CI-enforced executable research scaffold, not yet production-ready infrastructure.
```

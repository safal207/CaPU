# CMC Baseline Status

Status: reviewer-ready baseline snapshot.

This document summarizes the current CMC baseline after thesis, architecture, invariants, replay fixtures, manifest-linked evidence, audit report output, field-level verified audit examples, integrity demos, one-command reviewer demo, and CI-gate work.

---

## Baseline claim

```text
transition legitimacy can be represented, replayed, checked, reported, field-level example-verified, one-command verified, manifest-linked, and regression-tested
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
 -> JSONL audit report output
 -> saved valid/drift audit examples
 -> field-level audit report example verifier
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
invariant -> scenario -> fixture -> manifest -> verifier -> audit report -> saved examples -> field-level example verifier -> reviewer command -> CI
```

---

## Core documents

- [WHY_CAUSAL_COMPUTATION.md](WHY_CAUSAL_COMPUTATION.md)
- [CAUSAL_EXECUTION_ARCHITECTURE.md](CAUSAL_EXECUTION_ARCHITECTURE.md)
- [CAUSAL_MEMORY_CONTROLLER.md](CAUSAL_MEMORY_CONTROLLER.md)
- [CMC_REPLAY.md](CMC_REPLAY.md)
- [CMC_HASH_CHAIN.md](CMC_HASH_CHAIN.md)
- [CMC_INVARIANTS.md](CMC_INVARIANTS.md)
- [CMC_AUDITOR_REPORT.md](CMC_AUDITOR_REPORT.md)
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
scenario_id	invariant_id	path	decision	events	fingerprint	category	severity	expected_verdict
```

Current checked scenarios:

| Scenario | Invariant | Fixture | Decision | Category | Severity | Verdict |
| --- | --- | --- | --- | --- | --- | --- |
| `write_missing_cause` | `I1` | `fixtures/replay/missing_cause.jsonl` | `REJECT_MISSING_CAUSE` | `write_authorization` | `high` | `blocked_illegitimate_transition` |
| `write_unknown_cause` | `I2` | `fixtures/replay/unknown_cause.jsonl` | `REJECT_UNKNOWN_CAUSE` | `write_authorization` | `high` | `blocked_illegitimate_transition` |
| `effect_before_commit` | `I3` | `fixtures/replay/forbidden_effect_before_commit_fixture.jsonl` | `REJECT_EFFECT_BEFORE_COMMIT` | `effect_commit_boundary` | `critical` | `blocked_illegitimate_transition` |
| `valid_committed_effect` | `I4` | `fixtures/replay/valid_committed_effect.jsonl` | `ACCEPT_EFFECT` | `effect_commit_boundary` | `info` | `accepted_legitimate_transition` |

These fingerprints are developer-stability fingerprints using the current FNV-1a64 demo implementation. They are not production cryptographic evidence.

---

## Audit report output

Current auditor-facing command:

```bash
cd rust/cmc-core
cargo run --bin cmc_audit_report --locked
```

It emits JSONL records derived from `MANIFEST.tsv` and fails if a fixture is missing, drifted, has the wrong event count, or no longer contains the expected decision.

Saved audit examples:

```text
examples/audit_reports/cmc_audit_report_valid.jsonl
examples/audit_reports/cmc_audit_report_drift.jsonl
```

Field-level executable example verifier:

```bash
cd rust/cmc-core
cargo run --bin audit_report_example_verify --locked
```

The verifier parses each saved JSONL line as a flat object and checks typed fields such as `type`, `scenario_id`, `invariant_id`, `ok`, `status`, `cases`, `passed`, and `failed`.

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
cargo run --bin cmc_audit_report --locked
cargo run --bin audit_report_example_verify --locked
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
- manifest-linked audit report JSONL output
- field-level executable verification of saved valid/drift audit report examples
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
- manifest-linked audit report output
- saved valid/drift audit report examples
- field-level executable verification of audit report examples
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
3. hardening audit report validation beyond lightweight flat JSON parsing if external dependencies become acceptable,
4. adding richer manifest validation rules,
5. measuring overhead and stability across repeated runs.

---

## One-line status

```text
CMC baseline is reviewer-ready as a one-command, manifest-linked, JSONL-reporting, field-level example-verified, CI-enforced executable research scaffold, not yet production-ready infrastructure.
```

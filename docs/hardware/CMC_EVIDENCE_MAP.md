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
invariant -> scenario -> fixture -> manifest -> verifier -> audit report -> saved examples -> field-level example verifier -> reviewer command -> CI
```

---

## Evidence table

| Claim | Evidence artifact | Executable check | CI gate |
| --- | --- | --- | --- |
| CMC models causal memory/read/effect decisions | `rust/cmc-core/src/lib.rs` | `cargo test --all --locked` | Yes |
| I1: Missing cause must reject memory write | `CMC_INVARIANTS.md` + `missing_cause.jsonl` + `MANIFEST.tsv` | `cargo run --bin replay_fixture_verify --locked` | Yes |
| I2: Unknown cause must reject memory write | `CMC_INVARIANTS.md` + `unknown_cause.jsonl` + `MANIFEST.tsv` | `cargo run --bin replay_fixture_verify --locked` | Yes |
| I3: Effect cannot execute before causal commit | `CMC_INVARIANTS.md` + `forbidden_effect_before_commit_fixture.jsonl` + `MANIFEST.tsv` | `cargo run --bin replay_fixture_verify --locked` | Yes |
| I4: Committed cause can authorize effect | `CMC_INVARIANTS.md` + `valid_committed_effect.jsonl` + `MANIFEST.tsv` | `cargo run --bin replay_fixture_verify --locked` | Yes |
| I5: Missing cause must reject memory read | `CMC_INVARIANTS.md` + `read_missing_cause.jsonl` + `MANIFEST.tsv` | `cargo run --bin replay_fixture_verify --locked` | Yes |
| I6: Unknown cause/address must reject memory read | `CMC_INVARIANTS.md` + `read_unknown_cause_or_address.jsonl` + `MANIFEST.tsv` | `cargo run --bin replay_fixture_verify --locked` | Yes |
| I7: Missing parent cause must reject effect | `CMC_INVARIANTS.md` + `effect_missing_parent.jsonl` + `MANIFEST.tsv` | `cargo run --bin replay_fixture_verify --locked` | Yes |
| I8: Known cause can authorize read after write | `CMC_INVARIANTS.md` + `valid_read_after_write.jsonl` + `MANIFEST.tsv` | `cargo run --bin replay_fixture_verify --locked` | Yes |
| CMC emits deterministic trace events | `trace_events()` / `trace_jsonl()` | `cargo test --all --locked` | Yes |
| Basic flow has a stable golden snapshot | `fixtures/basic_flow.golden.txt` | `npm run verify:cmc-golden` | Via tests |
| Replay fixtures preserve semantic structure | `fixtures/replay/MANIFEST.tsv` + `replay_fixture_verify.rs` | `cargo run --bin replay_fixture_verify --locked` | Yes |
| Replay fixture drift can be detected | `fixtures/replay/MANIFEST.tsv` + `replay_fingerprint_verify.rs` | `cargo run --bin replay_fingerprint_verify --locked` | Yes |
| Manifest-linked audit evidence can be emitted | `cmc_audit_report.rs` + `fixtures/replay/MANIFEST.tsv` | `cargo run --bin cmc_audit_report --locked` | Yes |
| Saved audit examples are field-level verified | `examples/audit_reports/*.jsonl` + `audit_report_example_verify.rs` | `cargo run --bin audit_report_example_verify --locked` | Yes |
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
scenario_id	invariant_id	path	decision	events	fingerprint	category	severity	expected_verdict
```

Current checked scenarios:

| Scenario | Invariant | Fixture | Decision | Events | Fingerprint | Category | Severity | Verdict |
| --- | --- | --- | --- | ---: | --- | --- | --- | --- |
| `write_missing_cause` | `I1` | `missing_cause.jsonl` | `REJECT_MISSING_CAUSE` | 1 | `88fd99689760140e` | `write_authorization` | high | `blocked_illegitimate_transition` |
| `write_unknown_cause` | `I2` | `unknown_cause.jsonl` | `REJECT_UNKNOWN_CAUSE` | 1 | `d8c4983b8a5a0ab0` | `write_authorization` | high | `blocked_illegitimate_transition` |
| `effect_before_commit` | `I3` | `forbidden_effect_before_commit_fixture.jsonl` | `REJECT_EFFECT_BEFORE_COMMIT` | 1 | `28bf87f68e4ec6cb` | `effect_commit_boundary` | critical | `blocked_illegitimate_transition` |
| `valid_committed_effect` | `I4` | `valid_committed_effect.jsonl` | `ACCEPT_EFFECT` | 1 | `e3e96ba017e2c235` | `effect_commit_boundary` | info | `accepted_legitimate_transition` |
| `read_missing_cause` | `I5` | `read_missing_cause.jsonl` | `REJECT_MISSING_CAUSE` | 1 | `9f49c650fcd31fff` | `read_authorization` | high | `blocked_illegitimate_transition` |
| `read_unknown_cause_or_address` | `I6` | `read_unknown_cause_or_address.jsonl` | `REJECT_UNKNOWN_CAUSE` | 1 | `91768923fb87d345` | `read_authorization` | high | `blocked_illegitimate_transition` |
| `effect_missing_parent` | `I7` | `effect_missing_parent.jsonl` | `REJECT_MISSING_CAUSE` | 1 | `da78371555a0b983` | `effect_commit_boundary` | critical | `blocked_illegitimate_transition` |
| `valid_read_after_write` | `I8` | `valid_read_after_write.jsonl` | `ACCEPT_READ` | 2 | `d6b83bfe3651c60d` | `read_authorization` | info | `accepted_legitimate_transition` |

This makes the evidence chain explicit:

```text
thesis -> invariant -> scenario -> fixture -> fingerprint -> verifier -> audit report -> saved examples -> field-level example verifier -> CI
```

---

## Auditor-facing report

The current auditor-facing command is:

```bash
cd rust/cmc-core
cargo run --bin cmc_audit_report --locked
```

It emits JSONL records for each manifest-linked replay scenario and validates:

```text
fixture exists
fingerprint is stable
event count matches
expected decision is present
scenario/invariant/category/severity/verdict metadata is carried into output
```

Saved examples are available at:

```text
examples/audit_reports/cmc_audit_report_valid.jsonl
examples/audit_reports/cmc_audit_report_drift.jsonl
```

They are field-level checked by:

```bash
cd rust/cmc-core
cargo run --bin audit_report_example_verify --locked
```

The verifier parses each saved JSONL line as a flat JSON object and checks typed fields such as `type`, `scenario_id`, `invariant_id`, `ok`, `status`, `cases`, `passed`, and `failed`. It now expects 8 valid audit cases.

This is still an early developer report format, not a certification-grade audit artifact.

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
9. rust/cmc-core/src/bin/cmc_audit_report.rs
10. rust/cmc-core/src/bin/audit_report_example_verify.rs
11. examples/audit_reports/cmc_audit_report_valid.jsonl
12. examples/audit_reports/cmc_audit_report_drift.jsonl
13. CMC_AUDITOR_REPORT.md
14. CMC_EVIDENCE_MAP.md
15. CMC_REVIEWER_QUICKSTART.md
16. CMC_BASELINE_STATUS.md
17. CMC_PHASE_2_ROADMAP.md
18. rust/cmc-core/README.md
19. rust/cmc-core/src/lib.rs
20. scripts/run-cmc-reviewer-demo.mjs
21. .github/workflows/cmc-rust.yml
```

This path moves from thesis to architecture to invariants to executable validation and auditor-facing output.

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
cargo run --bin cmc_audit_report --locked
cargo run --bin audit_report_example_verify --locked
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
cargo run --bin cmc_audit_report --locked
cargo run --bin audit_report_example_verify --locked
cargo run --bin trace_divergence --locked
```

---

## What the evidence proves today

Today, the repository demonstrates that a minimal CMC simulator can:

- reject memory writes without explicit cause
- reject writes with unknown cause
- reject effects before causal commit
- accept effects after commit
- reject memory reads without explicit cause
- reject reads with unknown cause or unavailable address
- reject effects without parent cause
- accept reads after a legitimate write under a known cause
- map I1-I8 invariants to replay scenarios
- verify replay fixture structure through a machine-readable manifest
- verify replay fixture fingerprints through the same manifest
- emit manifest-linked audit evidence as JSONL
- preserve saved valid and drift audit examples for 8 cases
- verify those saved audit examples at field level
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
transition legitimacy can be made observable, replayable, testable, reportable, field-level example-verified, one-command verifiable, manifest-linked, and CI-enforced.
```

That is the core research direction.

---

## One-line summary

```text
CMC turns causal legitimacy from prose into 8 manifest-linked replay scenarios, executable evidence, JSONL audit output, and field-level verified audit examples.
```

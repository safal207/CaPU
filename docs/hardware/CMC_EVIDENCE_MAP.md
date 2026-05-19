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

Persona-boundary thesis:

```text
Future AI personas require causal legitimacy, not only conversational coherence.
```

Current executable evidence chain:

```text
invariant -> scenario -> fixture -> manifest -> verifier -> audit report -> saved examples -> field-level example verifier -> persona boundary -> trace integrity -> sealed trace fixtures -> reviewer command -> CI
```

---

## Evidence table

| Claim | Evidence artifact | Executable check | CI gate |
| --- | --- | --- | --- |
| CMC models causal memory/read/effect decisions | `rust/cmc-core/src/lib.rs` | `cargo test --all --locked` | Yes |
| Future AI personas require causal legitimacy, not only conversational coherence | `CMC_PERSONA_BOUNDARY.md` | Documentation review | No |
| P1: Persona memory requires cause | `fixtures/persona/MANIFEST.tsv` + persona fixtures + `persona_boundary_verify.rs` | `cargo run --bin persona_boundary_verify --locked` | Yes |
| Inferred persona preference must not become memory without confirmation/cause | `inferred_preference_rejected.jsonl` + `MANIFEST.tsv` | `cargo run --bin persona_boundary_verify --locked` | Yes |
| Confirmed persona preference can become memory with confirmation/cause | `confirmed_preference_accepted.jsonl` + `MANIFEST.tsv` | `cargo run --bin persona_boundary_verify --locked` | Yes |
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
| Legacy trace hash chain can validate expected trace | `verify_trace.rs` | `cargo run --bin verify_trace --locked` | Yes |
| Legacy tampered trace can be detected | `verify_trace_tampered.rs` | `cargo run --bin verify_trace_tampered --locked` | Yes |
| SHA-256 trace chain can validate generated trace | `CMC_TRACE_INTEGRITY.md` + `trace_crypto.rs` + `verify_trace_sha256.rs` | `cargo run --bin verify_trace_sha256 --locked` | Yes |
| SHA-256 tampered generated trace can be detected | `CMC_TRACE_INTEGRITY.md` + `verify_trace_sha256_tampered.rs` | `cargo run --bin verify_trace_sha256_tampered --locked` | Yes |
| SHA-256 sealed trace fixtures are executable-verified | `fixtures/trace_integrity/sha256_valid.jsonl` + `sha256_tampered.jsonl` + `verify_trace_sha256_fixture.rs` | `cargo run --bin verify_trace_sha256_fixture --locked` | Yes |
| Diverged replay can be detected | `trace_divergence.rs` | `cargo run --bin trace_divergence --locked` | Yes |
| Full reviewer baseline can run as one command | `scripts/run-cmc-reviewer-demo.mjs` | `npm run review:cmc` | Yes |
| Architecture has a coherent conceptual model | `CAUSAL_EXECUTION_ARCHITECTURE.md` | Documentation review | No |
| Causal computation thesis is explicit | `WHY_CAUSAL_COMPUTATION.md` | Documentation review | No |
| Phase 2 has an explicit next-step roadmap | `CMC_PHASE_2_ROADMAP.md` | Documentation review | No |
| Invariants are explicitly mapped to executable evidence | `CMC_INVARIANTS.md` + `fixtures/replay/MANIFEST.tsv` | `npm run review:cmc` | Yes |
| Future hardware path is scoped but non-claimed | `CMC_FPGA_SKETCH.md` | Documentation review | No |

---

## Manifest-linked persona boundary evidence

The persona boundary corpus is currently driven by:

```text
rust/cmc-core/fixtures/persona/MANIFEST.tsv
```

Current manifest shape:

```tsv
scenario_id	invariant_id	path	boundary	user_confirmation	decision	cause_id	expected_verdict
```

Current checked scenarios:

| Scenario | Invariant | Fixture | Boundary | Confirmation | Decision | Cause | Verdict |
| --- | --- | --- | --- | --- | --- | --- | --- |
| `inferred_preference_rejected` | `P1` | `inferred_preference_rejected.jsonl` | `persona_memory_requires_cause` | `false` | `REJECT_INFERRED_MEMORY` | `null` | `blocked_unconfirmed_persona_memory` |
| `confirmed_preference_accepted` | `P1` | `confirmed_preference_accepted.jsonl` | `persona_memory_requires_cause` | `true` | `ACCEPT_CONFIRMED_MEMORY` | `42` | `accepted_confirmed_persona_memory` |

Verifier command:

```bash
cd rust/cmc-core
cargo run --bin persona_boundary_verify --locked
```

Expected output includes:

```text
CMC-PERSONA-BOUNDARY-MANIFEST v0
cases=2
result=persona_boundary_manifest_valid
```

This gives the persona boundary the same evidence pattern as replay:

```text
persona invariant -> manifest row -> JSONL fixture -> verifier -> reviewer demo -> CI
```

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

This makes the replay evidence chain explicit:

```text
thesis -> invariant -> scenario -> fixture -> fingerprint -> verifier -> audit report -> saved examples -> field-level example verifier -> CI
```

---

## Trace integrity evidence

Trace integrity is documented in:

```text
docs/hardware/CMC_TRACE_INTEGRITY.md
```

Current integrity coverage:

| Integrity layer | Artifact | Check |
| --- | --- | --- |
| Legacy developer hash-chain demo | `verify_trace.rs` | `cargo run --bin verify_trace --locked` |
| Legacy tamper detection | `verify_trace_tampered.rs` | `cargo run --bin verify_trace_tampered --locked` |
| SHA-256 reference sealing | `trace_crypto.rs` + `verify_trace_sha256.rs` | `cargo run --bin verify_trace_sha256 --locked` |
| SHA-256 generated tamper detection | `verify_trace_sha256_tampered.rs` | `cargo run --bin verify_trace_sha256_tampered --locked` |
| SHA-256 sealed golden fixtures | `fixtures/trace_integrity/sha256_valid.jsonl` + `sha256_tampered.jsonl` | `cargo run --bin verify_trace_sha256_fixture --locked` |

The saved sealed fixtures are important because they turn trace integrity from a runtime-only demo into stable audit artifacts.

Current sealed fixture semantics:

```text
sha256_valid.jsonl    -> verifies successfully
sha256_tampered.jsonl -> fails at event 1
```

The SHA-256 reference path is std-only so that `cargo --locked` remains stable.

This is stronger than the initial developer hash-chain demo, but it is still not a production security certification.

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

The verifier parses each saved JSONL line as a flat JSON object and checks typed fields such as `type`, `scenario_id`, `invariant_id`, `ok`, `status`, `cases`, `passed`, and `failed`. It expects 8 valid audit cases.

This is still an early developer report format, not a certification-grade audit artifact.

---

## Reviewer path

Recommended review order:

```text
1. WHY_CAUSAL_COMPUTATION.md
2. CAUSAL_EXECUTION_ARCHITECTURE.md
3. CMC_PERSONA_BOUNDARY.md
4. rust/cmc-core/fixtures/persona/MANIFEST.tsv
5. rust/cmc-core/fixtures/persona/inferred_preference_rejected.jsonl
6. rust/cmc-core/fixtures/persona/confirmed_preference_accepted.jsonl
7. rust/cmc-core/src/bin/persona_boundary_verify.rs
8. CAUSAL_MEMORY_CONTROLLER.md
9. CMC_REPLAY.md
10. CMC_HASH_CHAIN.md
11. CMC_TRACE_INTEGRITY.md
12. CMC_INVARIANTS.md
13. rust/cmc-core/fixtures/replay/MANIFEST.md
14. rust/cmc-core/fixtures/replay/MANIFEST.tsv
15. rust/cmc-core/fixtures/trace_integrity/sha256_valid.jsonl
16. rust/cmc-core/fixtures/trace_integrity/sha256_tampered.jsonl
17. rust/cmc-core/src/bin/verify_trace_sha256_fixture.rs
18. rust/cmc-core/src/bin/cmc_audit_report.rs
19. rust/cmc-core/src/bin/audit_report_example_verify.rs
20. examples/audit_reports/cmc_audit_report_valid.jsonl
21. examples/audit_reports/cmc_audit_report_drift.jsonl
22. CMC_AUDITOR_REPORT.md
23. CMC_EVIDENCE_MAP.md
24. CMC_REVIEWER_QUICKSTART.md
25. CMC_BASELINE_STATUS.md
26. CMC_PHASE_2_ROADMAP.md
27. rust/cmc-core/README.md
28. rust/cmc-core/src/lib.rs
29. rust/cmc-core/src/trace_crypto.rs
30. scripts/run-cmc-reviewer-demo.mjs
31. .github/workflows/cmc-rust.yml
```

This path moves from thesis to persona boundary to architecture to invariants to executable validation, sealed trace artifacts, and auditor-facing output.

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
cargo run --bin verify_trace_sha256 --locked
cargo run --bin verify_trace_sha256_tampered --locked
cargo run --bin verify_trace_sha256_fixture --locked
cargo run --bin persona_boundary_verify --locked
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

## What the evidence proves today

Today, the repository demonstrates that a minimal CMC simulator can:

- reject inferred persona memory without confirmation/cause
- accept confirmed persona memory with confirmation/cause
- verify persona boundary fixtures through a machine-readable manifest
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
- detect tampered trace decisions with the legacy developer hash path
- seal and verify trace events with a std-only SHA-256 reference path
- detect tampered trace decisions with the SHA-256 reference path
- preserve saved SHA-256 valid/tampered sealed fixtures
- verify saved SHA-256 sealed fixtures at executable level
- detect replay divergence
- run the full reviewer baseline through one command
- enforce these checks in CI

---

## What the evidence does not prove yet

The current evidence does not claim:

- production-grade cryptographic sealing
- certified trace storage
- hardware root of trust
- hardware implementation
- performance under real production workloads
- formal proof of all transition semantics
- complete agent safety coverage
- AI consciousness or personhood
- therapeutic diagnosis or treatment
- replacement for sandboxing, policy design, or conventional security engineering

The current repository should be read as an executable research scaffold for legitimacy-preserving computation.

---

## Grant/research interpretation

The strongest claim is not that CMC is finished.

The strongest claim is:

```text
transition legitimacy can be made observable, replayable, testable, reportable, persona-boundary-verified, field-level example-verified, SHA-256 sealed, fixture-verified, one-command verifiable, manifest-linked, and CI-enforced.
```

That is the core research direction.

---

## One-line summary

```text
CMC turns causal legitimacy from prose into manifest-linked persona boundary fixtures, 8 manifest-linked replay scenarios, executable evidence, JSONL audit output, field-level verified audit examples, and saved SHA-256 trace-integrity fixtures.
```

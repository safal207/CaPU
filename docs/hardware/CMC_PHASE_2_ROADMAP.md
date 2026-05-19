# CMC Phase 2 Roadmap

Status: next-phase roadmap after reviewer-ready baseline.

This roadmap starts after the current CMC baseline:

```text
thesis -> architecture -> invariants -> simulator -> replay fixtures -> manifest-linked verifiers -> audit report output -> integrity demos -> one-command reviewer demo -> CI gate -> evidence map -> reviewer quickstart -> baseline status
```

Phase 2 goal:

```text
move from executable research scaffold toward stronger replay integrity, broader violation coverage, and auditor-facing evidence
```

---

## Phase 2 principle

Do not overclaim hardware or production security.

The next phase should strengthen the claim that:

```text
transition legitimacy can be represented, replayed, checked, reported, one-command verified, manifest-linked, and regression-tested
```

---

## Phase 2 progress snapshot

Done:

- `CMC_INVARIANTS.md`
- `scripts/run-cmc-reviewer-demo.mjs`
- npm script: `review:cmc`
- CI step: `npm run review:cmc`
- reviewer quickstart updated to prefer `npm run review:cmc`
- evidence map updated for one-command reviewer baseline
- baseline status updated for one-command reviewer baseline
- replay corpus expanded from 2 to 4 checked fixtures
- `unknown_cause.jsonl`
- `valid_committed_effect.jsonl`
- `fixtures/replay/MANIFEST.md`
- `fixtures/replay/MANIFEST.tsv`
- replay verifiers now read the machine-readable manifest
- manifest links `scenario_id` to `invariant_id`
- manifest includes `category`, `severity`, and `expected_verdict`
- `cmc_audit_report` CLI emits manifest-linked JSONL audit output
- `npm run review:cmc` includes `cmc_audit_report`
- `CMC_INVARIANTS.md` synced with I1-I4 replay fixtures
- `CMC_EVIDENCE_MAP.md` synced with manifest-linked audit evidence
- `CMC_BASELINE_STATUS.md` synced with manifest-linked audit evidence
- `CMC_REVIEWER_QUICKSTART.md` synced with `cmc_audit_report`

Current checked replay evidence:

| Scenario | Invariant | Fixture | Decision | Category | Severity | Verdict |
| --- | --- | --- | --- | --- | --- | --- |
| `write_missing_cause` | `I1` | `missing_cause.jsonl` | `REJECT_MISSING_CAUSE` | `write_authorization` | `high` | `blocked_illegitimate_transition` |
| `write_unknown_cause` | `I2` | `unknown_cause.jsonl` | `REJECT_UNKNOWN_CAUSE` | `write_authorization` | `high` | `blocked_illegitimate_transition` |
| `effect_before_commit` | `I3` | `forbidden_effect_before_commit_fixture.jsonl` | `REJECT_EFFECT_BEFORE_COMMIT` | `effect_commit_boundary` | `critical` | `blocked_illegitimate_transition` |
| `valid_committed_effect` | `I4` | `valid_committed_effect.jsonl` | `ACCEPT_EFFECT` | `effect_commit_boundary` | `info` | `accepted_legitimate_transition` |

Next:

- harden the JSONL audit report schema
- save example audit reports under `examples/audit_reports/`
- expand replay fixture coverage toward at least 8 legitimacy violation classes
- strengthen hash-chain implementation beyond developer FNV-1a64 demo
- add repeated-run benchmark/stability reporting

---

## Workstream 1: Cryptographic hash-chain upgrade

Current state:

- developer FNV-1a64 hash-chain demo
- trace tampering detection demo
- manifest-linked fixture fingerprint stability checks
- one-command reviewer baseline runs current integrity checks
- audit report currently uses developer FNV-1a64 fingerprint validation

Target:

- replace developer hash demo with a stronger cryptographic hash function
- make hash-chain format explicit
- separate canonical trace encoding from hash implementation
- add positive and negative verifier fixtures

Candidate deliverables:

- `trace_hash.rs` module
- `canonical_trace_event.rs` module
- `verify_trace_crypto.rs` CLI
- `fixtures/replay/hash_chain_valid.jsonl`
- `fixtures/replay/hash_chain_tampered.jsonl`
- updated `CMC_HASH_CHAIN.md`

Definition of done:

```text
A trace hash-chain can be generated, verified, and tampering can be detected using a documented cryptographic hash implementation.
```

---

## Workstream 2: Replay fixture expansion

Current state:

- 4 checked replay fixtures
- machine-readable `MANIFEST.tsv`
- human-readable `MANIFEST.md`
- manifest-driven structure verifier
- manifest-driven fingerprint verifier
- manifest-driven JSONL audit report
- one-command reviewer baseline runs fixture checks and audit report output

Target:

Expand to at least 8 legitimacy classes.

Candidate next fixtures:

- duplicate cause
- read without sufficient cause
- effect with missing parent cause
- replay nonce mismatch
- branch divergence
- trace event ordering violation
- missing trace event
- mismatched invariant/decision pair

Candidate deliverables:

- expanded `fixtures/replay/*.jsonl`
- richer `fixtures/replay/MANIFEST.tsv` validation rules
- stricter manifest parser
- scenario/invariant/category/severity/verdict consistency checks

Definition of done:

```text
The replay fixture corpus covers at least 8 legitimacy violation classes and is fully checked in CI.
```

---

## Workstream 3: Auditor report format

Current state:

- `cmc_audit_report` CLI exists
- command output is JSONL
- report is manifest-linked
- output carries `scenario_id`, `invariant_id`, `category`, `severity`, and `expected_verdict`
- reviewer quickstart includes `cargo run --bin cmc_audit_report --locked`
- one-command reviewer baseline includes `cmc_audit_report`

Current example output shape:

```json
{
  "type": "cmc_audit_case",
  "scenario_id": "effect_before_commit",
  "invariant_id": "I3",
  "category": "effect_commit_boundary",
  "severity": "critical",
  "expected_verdict": "blocked_illegitimate_transition",
  "fixture": "fixtures/replay/forbidden_effect_before_commit_fixture.jsonl",
  "decision": "REJECT_EFFECT_BEFORE_COMMIT",
  "ok": true,
  "status": "audit_case_valid"
}
```

Remaining target:

- document the JSONL schema
- add saved example reports in `examples/audit_reports/`
- add negative example report for drift/failure
- decide whether the report should stay JSONL or gain a summary JSON mode

Candidate deliverables:

- doc: `CMC_AUDITOR_REPORT.md`
- `examples/audit_reports/cmc_audit_report_valid.jsonl`
- `examples/audit_reports/cmc_audit_report_drift.jsonl`
- optional `--json` / `--jsonl` mode split

Definition of done:

```text
A reviewer can run one command and receive a documented structured report explaining which invariant/scenario passed or failed.
```

Current status:

```text
Partially done: CLI exists and is in reviewer baseline; schema docs and saved examples remain.
```

---

## Workstream 4: Overhead and stability measurement

Current state:

- developer benchmark exists
- no official machine-specific benchmark claim

Target:

Measure overhead and stability without overclaiming performance.

Candidate deliverables:

- repeated-run benchmark script
- benchmark output format
- CI/non-CI distinction
- benchmark report with machine metadata

Metrics to collect:

- writes/sec
- effects/sec
- trace events/sec
- hash-chain overhead
- replay verification time
- fixture verification time
- audit report generation time

Definition of done:

```text
The project can report reproducible developer benchmark numbers with clear environment metadata and no production SLA claims.
```

---

## Workstream 5: Formal invariants and decision semantics

Current state:

- canonical invariants map exists: `CMC_INVARIANTS.md`
- I1-I4 map to manifest-linked replay fixtures
- executable tests exist in Rust
- decision codes exist
- audit report carries invariant/scenario metadata

Completed deliverables:

- `CMC_INVARIANTS.md`
- invariant-to-evidence map
- invariant-to-command map
- invariant-to-scenario manifest linkage
- invariant-to-audit-report linkage
- Phase 2 gaps table

Remaining target:

- add dedicated tests for exactly-one TraceEvent per decision
- expand invariant-to-fixture coverage as replay corpus grows
- add decision-code table if decision semantics expand

Definition of done:

```text
Each major CMC invariant maps to documentation, at least one test, and where possible a replay fixture plus audit report output.
```

---

## Workstream 6: Reviewer-facing demo polish

Current state:

- reviewer quickstart exists
- evidence map exists
- baseline status exists
- one-command reviewer script exists: `scripts/run-cmc-reviewer-demo.mjs`
- npm script exists: `npm run review:cmc`
- CI runs the reviewer command
- reviewer command now exercises manifest-linked replay checks and audit report output

Completed deliverables:

- `scripts/run-cmc-reviewer-demo.mjs`
- npm script: `review:cmc`
- workflow step: `npm run review:cmc`
- README entry
- updated reviewer quickstart
- updated evidence map
- updated baseline status
- manifest-linked replay fixture checks
- manifest-linked audit report output

Expected output summary:

```text
CMC reviewer demo
formatting: ok
simulator tests: ok
blocked-transition demo: ok
valid trace hash-chain demo: ok
tampering detection demo: ok
replay fixture structure: ok
replay fixture fingerprints: ok
audit report jsonl: ok
replay divergence detection: ok
result=reviewer_baseline_passed
```

Definition of done:

```text
A reviewer can run one top-level command and see the whole baseline pass/fail summary.
```

Current status:

```text
Done for baseline; future work should add saved audit examples and schema documentation.
```

---

## Suggested implementation order from here

```text
1. CMC_AUDITOR_REPORT.md
2. saved audit report examples
3. expanded replay fixtures toward 8 classes
4. crypto hash-chain module
5. overhead benchmark report
```

Reasoning:

- Invariants are now linked to replay scenarios.
- The manifest is machine-readable and consumed by verifiers.
- Audit metadata is in the manifest.
- Audit report CLI exists and is in the reviewer baseline.
- Schema docs and saved examples make the report easier to review.
- Additional fixtures broaden evidence coverage.
- Crypto hash-chain strengthens integrity.
- Benchmarks add engineering credibility without overclaiming.

---

## Non-goals for Phase 2

Phase 2 should not claim:

- production memory controller
- finished hardware architecture
- certified security system
- complete AI safety layer
- replacement for sandboxing or policy design

Phase 2 should remain honest:

```text
stronger executable evidence for legitimacy-preserving computation
```

---

## Phase 2 success criterion

Phase 2 succeeds when a reviewer can say:

```text
This project does not merely describe causal legitimacy.
It defines invariants, links them to replay scenarios, verifies fixtures through a manifest, emits audit reports, detects drift, detects tampering, and detects divergence.
```

---

## One-line roadmap summary

```text
Phase 1 made causal legitimacy executable; Phase 2 makes it manifest-linked, reportable, broader, stronger, easier to verify, and easier to audit.
```

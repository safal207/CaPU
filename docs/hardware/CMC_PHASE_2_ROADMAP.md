# CMC Phase 2 Roadmap

Status: next-phase roadmap after reviewer-ready baseline.

This roadmap starts after the current CMC baseline:

```text
thesis -> architecture -> 8 replay invariants -> simulator -> replay fixtures -> manifest-linked verifiers -> audit report output -> saved audit examples -> field-level example verifier -> legacy integrity demos -> SHA-256 trace-integrity reference path -> one-command reviewer demo -> CI gate -> evidence map -> reviewer quickstart -> baseline status
```

Phase 2 goal:

```text
move from executable research scaffold toward stronger replay integrity, broader workload coverage, and auditor-facing evidence
```

---

## Phase 2 principle

Do not overclaim hardware or production security.

The next phase should strengthen the claim that:

```text
transition legitimacy can be represented, replayed, checked, reported, field-level example-verified, SHA-256 sealed, one-command verified, manifest-linked, and regression-tested
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
- replay corpus expanded from 4 to 8 checked scenarios
- `unknown_cause.jsonl`
- `valid_committed_effect.jsonl`
- `read_missing_cause.jsonl`
- `read_unknown_cause_or_address.jsonl`
- `effect_missing_parent.jsonl`
- `valid_read_after_write.jsonl`
- `fixtures/replay/MANIFEST.md`
- `fixtures/replay/MANIFEST.tsv`
- replay verifiers now read the machine-readable manifest
- manifest links `scenario_id` to `invariant_id`
- manifest includes `category`, `severity`, and `expected_verdict`
- manifest now covers I1-I8 replay invariants
- `cmc_audit_report` CLI emits manifest-linked JSONL audit output
- `CMC_AUDITOR_REPORT.md` documents the audit report schema
- saved valid audit report example exists and covers 8 cases
- saved drift/failure audit report example exists for an 8-case corpus
- `audit_report_example_verify` checks saved audit examples
- `audit_report_example_verify` now uses field-level JSONL parsing and typed field checks
- `npm run review:cmc` includes `cmc_audit_report`
- `npm run review:cmc` includes `audit_report_example_verify`
- `CMC_INVARIANTS.md` synced with I1-I8 replay fixtures
- `CMC_AUDITOR_REPORT.md` synced with field-level example verification
- `CMC_EVIDENCE_MAP.md` synced with 8 replay scenarios, field-level verified audit examples, and SHA-256 trace integrity
- `CMC_BASELINE_STATUS.md` synced with 8 replay scenarios, field-level verified audit examples, and SHA-256 trace integrity
- `CMC_REVIEWER_QUICKSTART.md` synced with `cmc_audit_report`
- `CMC_TRACE_INTEGRITY.md` documents the trace-integrity evidence path
- `trace_crypto.rs` provides a std-only SHA-256 reference implementation
- `verify_trace_sha256` checks the positive SHA-256 trace sealing path
- `verify_trace_sha256_tampered` checks the SHA-256 tamper-detection path
- GitHub Actions now runs SHA-256 positive and tamper-detection checks as explicit CI steps

Current checked replay evidence:

| Scenario | Invariant | Fixture | Decision | Events | Category | Severity | Verdict |
| --- | --- | --- | --- | ---: | --- | --- | --- |
| `write_missing_cause` | `I1` | `missing_cause.jsonl` | `REJECT_MISSING_CAUSE` | 1 | `write_authorization` | high | `blocked_illegitimate_transition` |
| `write_unknown_cause` | `I2` | `unknown_cause.jsonl` | `REJECT_UNKNOWN_CAUSE` | 1 | `write_authorization` | high | `blocked_illegitimate_transition` |
| `effect_before_commit` | `I3` | `forbidden_effect_before_commit_fixture.jsonl` | `REJECT_EFFECT_BEFORE_COMMIT` | 1 | `effect_commit_boundary` | critical | `blocked_illegitimate_transition` |
| `valid_committed_effect` | `I4` | `valid_committed_effect.jsonl` | `ACCEPT_EFFECT` | 1 | `effect_commit_boundary` | info | `accepted_legitimate_transition` |
| `read_missing_cause` | `I5` | `read_missing_cause.jsonl` | `REJECT_MISSING_CAUSE` | 1 | `read_authorization` | high | `blocked_illegitimate_transition` |
| `read_unknown_cause_or_address` | `I6` | `read_unknown_cause_or_address.jsonl` | `REJECT_UNKNOWN_CAUSE` | 1 | `read_authorization` | high | `blocked_illegitimate_transition` |
| `effect_missing_parent` | `I7` | `effect_missing_parent.jsonl` | `REJECT_MISSING_CAUSE` | 1 | `effect_commit_boundary` | critical | `blocked_illegitimate_transition` |
| `valid_read_after_write` | `I8` | `valid_read_after_write.jsonl` | `ACCEPT_READ` | 2 | `read_authorization` | info | `accepted_legitimate_transition` |

Audit report examples:

| Example | Meaning | Checked by |
| --- | --- | --- |
| `examples/audit_reports/cmc_audit_report_valid.jsonl` | clean valid 8-case audit report | field-level `audit_report_example_verify` |
| `examples/audit_reports/cmc_audit_report_drift.jsonl` | illustrative 8-case fingerprint drift/failure report | field-level `audit_report_example_verify` |

Trace integrity checks:

| Check | Meaning |
| --- | --- |
| `cargo run --bin verify_trace --locked` | legacy FNV developer hash-chain positive demo |
| `cargo run --bin verify_trace_tampered --locked` | legacy FNV tamper-detection demo |
| `cargo run --bin verify_trace_sha256 --locked` | std-only SHA-256 trace sealing positive demo |
| `cargo run --bin verify_trace_sha256_tampered --locked` | std-only SHA-256 tamper-detection demo |

Next:

- define canonical trace-event encoding more explicitly
- add golden SHA-256 sealed trace fixtures
- connect manifest entries to SHA-256 sealed trace evidence
- add richer manifest validation rules
- add repeated-run benchmark/stability reporting
- optionally replace the lightweight flat JSON parser with a dedicated JSON dependency if external dependencies become acceptable
- expand beyond current memory/read/effect cases into broader workloads

---

## Workstream 1: Trace integrity and SHA-256 evidence deepening

Current state:

- developer FNV-1a64 hash-chain demo exists
- legacy trace tampering detection demo exists
- std-only SHA-256 reference module exists: `trace_crypto.rs`
- SHA-256 positive verifier exists: `verify_trace_sha256`
- SHA-256 tamper verifier exists: `verify_trace_sha256_tampered`
- `CMC_TRACE_INTEGRITY.md` documents the honest trace-integrity boundary
- CI runs legacy positive/tamper checks and SHA-256 positive/tamper checks
- manifest-linked fixture fingerprint stability checks still use developer-stability fingerprints
- 8 replay scenarios currently depend on developer-stability fixture fingerprints, not SHA-256 sealed replay files

Target:

- make canonical trace-event encoding explicit
- preserve golden SHA-256 sealed trace fixtures
- connect manifest entries to SHA-256 trace evidence where useful
- separate fixture drift fingerprints from trace-integrity hashes
- keep legacy developer hash demo only as backward-compatible evidence, not as the primary integrity story

Candidate deliverables:

- `canonical_trace_event.rs` module or documented canonical encoding rules
- `fixtures/trace_integrity/sha256_valid.jsonl`
- `fixtures/trace_integrity/sha256_tampered.jsonl`
- `verify_trace_sha256_fixture.rs` CLI
- manifest extension or companion manifest for sealed trace evidence
- updated `CMC_TRACE_INTEGRITY.md`
- optional update to `CMC_HASH_CHAIN.md` clarifying legacy vs SHA-256 roles

Definition of done:

```text
A reviewer can inspect stable SHA-256 sealed trace fixtures, run a verifier against them, and see both positive and tamper-detection paths exercised in CI.
```

---

## Workstream 2: Replay fixture expansion

Current state:

- 8 checked replay scenarios
- machine-readable `MANIFEST.tsv`
- human-readable `MANIFEST.md`
- manifest-driven structure verifier
- manifest-driven fingerprint verifier
- manifest-driven JSONL audit report
- saved valid/drift audit examples
- field-level verifier for saved audit examples
- one-command reviewer baseline runs fixture checks, audit report output, audit example checks, and SHA-256 trace-integrity checks

Current status:

```text
Done for baseline: replay corpus now covers 8 legitimacy scenarios across write authorization, read authorization, and effect commit boundaries.
```

Future target:

Expand beyond baseline memory/read/effect cases into broader workloads and adversarial replay classes.

Candidate future fixtures:

- duplicate cause
- replay nonce mismatch
- branch divergence
- trace event ordering violation
- missing trace event
- mismatched invariant/decision pair
- multi-step causal chain read
- multi-actor authorization conflict

Candidate deliverables:

- expanded `fixtures/replay/*.jsonl`
- richer `fixtures/replay/MANIFEST.tsv` validation rules
- stricter manifest parser
- scenario/invariant/category/severity/verdict consistency checks

Definition of done:

```text
The replay fixture corpus covers baseline CMC transition legitimacy and can be extended to broader adversarial replay classes without changing the reviewer command.
```

---

## Workstream 3: Auditor report format

Current state:

- `cmc_audit_report` CLI exists
- command output is JSONL
- report is manifest-linked
- output carries `scenario_id`, `invariant_id`, `category`, `severity`, and `expected_verdict`
- `CMC_AUDITOR_REPORT.md` documents the JSONL schema
- saved valid report example exists and covers 8 cases
- saved drift/failure report example exists for an 8-case corpus
- `audit_report_example_verify` uses field-level JSONL parsing and typed field checks
- reviewer quickstart includes `cargo run --bin cmc_audit_report --locked`
- one-command reviewer baseline includes `cmc_audit_report`
- one-command reviewer baseline includes `audit_report_example_verify`

Current example output shape:

```json
{
  "type": "cmc_audit_case",
  "scenario_id": "read_missing_cause",
  "invariant_id": "I5",
  "category": "read_authorization",
  "severity": "high",
  "expected_verdict": "blocked_illegitimate_transition",
  "fixture": "fixtures/replay/read_missing_cause.jsonl",
  "decision": "REJECT_MISSING_CAUSE",
  "ok": true,
  "status": "audit_case_valid"
}
```

Remaining target:

- decide whether the report should stay JSONL or gain a summary JSON mode
- optionally add generated report snapshot comparison
- optionally replace lightweight flat JSON parsing with a dedicated JSON dependency if external dependencies become acceptable
- optionally include trace-integrity references in future audit records once sealed trace fixtures exist

Candidate deliverables:

- optional `--json` / `--jsonl` mode split
- optional report snapshot/golden check
- optional serde-based JSON parser if dependency policy changes
- optional trace-integrity reference fields

Definition of done:

```text
A reviewer can run one command and receive a documented structured report explaining which invariant/scenario passed or failed, with saved examples verified by field-level executable checks.
```

Current status:

```text
Done for baseline: CLI, schema doc, valid 8-case example, drift 8-case example, and field-level example verifier exist.
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
- reads/sec
- effects/sec
- trace events/sec
- legacy hash-chain overhead
- SHA-256 trace sealing overhead
- replay verification time
- fixture verification time
- audit report generation time
- audit example verification time

Definition of done:

```text
The project can report reproducible developer benchmark numbers with clear environment metadata and no production SLA claims.
```

---

## Workstream 5: Formal invariants and decision semantics

Current state:

- canonical invariants map exists: `CMC_INVARIANTS.md`
- I1-I8 map to manifest-linked replay fixtures
- executable tests exist in Rust
- decision codes exist
- audit report carries invariant/scenario metadata
- saved examples preserve success and drift/failure semantics
- saved examples are field-level verified
- trace-integrity evidence now includes legacy and SHA-256 positive/tamper checks

Completed deliverables:

- `CMC_INVARIANTS.md`
- invariant-to-evidence map
- invariant-to-command map
- invariant-to-scenario manifest linkage for I1-I8
- invariant-to-audit-report linkage
- invariant-to-saved-example linkage
- field-level saved-example verification
- SHA-256 trace-integrity reference checks
- Phase 2 gaps table

Remaining target:

- add dedicated tests for exactly-one TraceEvent per decision
- add decision-code table if decision semantics expand
- add richer manifest validation rules for scenario/category/severity consistency
- add canonical trace encoding rules for SHA-256 sealed events

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
- trace integrity doc exists
- one-command reviewer script exists: `scripts/run-cmc-reviewer-demo.mjs`
- npm script exists: `npm run review:cmc`
- CI runs the reviewer command
- reviewer command now exercises manifest-linked replay checks, audit report output, field-level saved audit example verification, and SHA-256 trace-integrity checks
- valid audit example now covers 8 cases

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
- saved valid/drift audit report examples
- field-level executable verification of saved audit examples
- SHA-256 trace-integrity positive and tamper checks

Expected output summary:

```text
CMC reviewer demo
formatting: ok
simulator tests: ok
blocked-transition demo: ok
valid trace hash-chain demo: ok
tampering detection demo: ok
sha256 trace verification demo: ok
sha256 tampering detection demo: ok
replay fixture structure: ok
replay fixture fingerprints: ok
audit report jsonl: ok
audit report examples: ok
replay divergence detection: ok
result=reviewer_baseline_passed
```

Definition of done:

```text
A reviewer can run one top-level command and see the whole baseline pass/fail summary.
```

Current status:

```text
Done for baseline; future work should strengthen canonical encoding, validation strictness, sealed fixtures, and benchmark evidence.
```

---

## Suggested implementation order from here

```text
1. canonical trace-event encoding rules
2. golden SHA-256 sealed trace fixtures
3. manifest link or companion manifest for SHA-256 sealed trace evidence
4. richer replay manifest validation rules
5. overhead benchmark report including SHA-256 sealing overhead
6. optional JSON/JSONL mode split
7. broader workload replay cases
```

Reasoning:

- Invariants are now linked to 8 replay scenarios.
- The manifest is machine-readable and consumed by verifiers.
- Audit metadata is in the manifest.
- Audit report CLI exists and is in the reviewer baseline.
- Schema docs and saved examples exist.
- Saved examples are field-level executable-verified.
- SHA-256 trace sealing now exists as a reference path.
- Canonical encoding and golden sealed fixtures make the SHA-256 path more reviewer-auditable.
- Richer manifest validation reduces schema drift.
- Benchmarks add engineering credibility without overclaiming.
- Broader workload cases become more meaningful once integrity and validation are stronger.

---

## Non-goals for Phase 2

Phase 2 should not claim:

- production memory controller
- finished hardware architecture
- certified security system
- complete AI safety layer
- replacement for sandboxing or policy design
- hardware root of trust
- production cryptographic protocol

Phase 2 should remain honest:

```text
stronger executable evidence for legitimacy-preserving computation
```

---

## Phase 2 success criterion

Phase 2 succeeds when a reviewer can say:

```text
This project does not merely describe causal legitimacy.
It defines invariants, links them to 8 replay scenarios, verifies fixtures through a manifest, emits audit reports, field-level verifies saved audit examples, seals traces with a SHA-256 reference path, detects drift, detects tampering, and detects divergence.
```

---

## One-line roadmap summary

```text
Phase 1 made causal legitimacy executable; Phase 2 makes it 8-scenario, manifest-linked, reportable, field-level example-verified, SHA-256 trace-integrity checked, broader, stronger, easier to verify, and easier to audit.
```

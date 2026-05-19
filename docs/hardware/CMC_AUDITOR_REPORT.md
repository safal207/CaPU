# CMC Auditor Report

Status: early auditor-facing JSONL report contract with executable field-level example verification.

This document defines the current CMC audit report output produced by:

```bash
cd rust/cmc-core
cargo run --bin cmc_audit_report --locked
```

The report is generated from the replay manifest:

```text
rust/cmc-core/fixtures/replay/MANIFEST.tsv
```

The goal is to make replay evidence easier to inspect outside Rust test output.

---

## Current claim

```text
transition legitimacy can be represented, replayed, checked, reported, field-level example-verified, one-command verified, manifest-linked, and regression-tested
```

The audit report does not claim certification-grade assurance. It is an early structured evidence artifact.

---

## Evidence chain

```text
invariant -> scenario -> fixture -> manifest -> verifier -> audit report -> saved examples -> field-level example verifier -> reviewer command -> CI
```

The audit report is downstream of the manifest and fixture corpus. The saved examples are executable-checked by a dedicated field-level verifier.

---

## Commands

Generate the live audit report from `rust/cmc-core`:

```bash
cargo run --bin cmc_audit_report --locked
```

Verify the saved valid and drift examples from `rust/cmc-core`:

```bash
cargo run --bin audit_report_example_verify --locked
```

From repository root, both commands are included in:

```bash
npm run review:cmc
```

---

## Output format

The command emits JSONL: one JSON object per line.

Current record types:

```text
cmc_audit_report_start
cmc_audit_case
cmc_audit_report_summary
```

---

## Start record

Example:

```json
{"type":"cmc_audit_report_start","manifest":"fixtures/replay/MANIFEST.tsv"}
```

Fields:

| Field | Type | Meaning |
| --- | --- | --- |
| `type` | string | Always `cmc_audit_report_start` |
| `manifest` | string | Manifest path used to build the report |

---

## Case record

Example:

```json
{"type":"cmc_audit_case","scenario_id":"effect_before_commit","invariant_id":"I3","category":"effect_commit_boundary","severity":"critical","expected_verdict":"blocked_illegitimate_transition","fixture":"fixtures/replay/forbidden_effect_before_commit_fixture.jsonl","decision":"REJECT_EFFECT_BEFORE_COMMIT","expected_events":1,"actual_events":1,"expected_fingerprint":"28bf87f68e4ec6cb","actual_fingerprint":"28bf87f68e4ec6cb","ok":true,"status":"audit_case_valid"}
```

Fields:

| Field | Type | Meaning |
| --- | --- | --- |
| `type` | string | Always `cmc_audit_case` |
| `scenario_id` | string | Stable replay scenario identifier |
| `invariant_id` | string | Invariant mapped to the scenario |
| `category` | string | Evidence category from manifest |
| `severity` | string | Review severity from manifest |
| `expected_verdict` | string | Expected reviewer/auditor verdict |
| `fixture` | string | JSONL fixture path |
| `decision` | string | Expected CMC decision code |
| `expected_events` | number | Expected non-empty event lines |
| `actual_events` | number | Observed non-empty event lines |
| `expected_fingerprint` | string | Manifest fingerprint |
| `actual_fingerprint` | string | Fingerprint computed from fixture content |
| `ok` | boolean | Whether this case passed report checks |
| `status` | string | Machine-readable case status |

---

## Summary record

Example:

```json
{"type":"cmc_audit_report_summary","ok":true,"cases":4,"passed":4,"failed":0,"status":"audit_report_valid"}
```

Failure example:

```json
{"type":"cmc_audit_report_summary","ok":false,"cases":4,"passed":3,"failed":1,"status":"audit_report_failed"}
```

Fields:

| Field | Type | Meaning |
| --- | --- | --- |
| `type` | string | Always `cmc_audit_report_summary` |
| `ok` | boolean | Overall report pass/fail |
| `cases` | number | Total audit cases |
| `passed` | number | Passed audit cases |
| `failed` | number | Failed audit cases |
| `status` | string | Machine-readable summary status |

---

## Current success statuses

```text
audit_case_valid
audit_report_valid
audit_report_examples_valid
```

---

## Current failure statuses

The current report and example verifier can surface these failure statuses:

```text
manifest_error
missing_fixture
fixture_fingerprint_drift
event_count_drift
decision_drift
audit_report_failed
result=failed report=valid
result=failed report=drift
```

Failures return a non-zero process exit code.

---

## Current manifest columns

The report reads this manifest shape:

```tsv
scenario_id	invariant_id	path	decision	events	fingerprint	category	severity	expected_verdict
```

Current examples:

| Scenario | Invariant | Category | Severity | Verdict |
| --- | --- | --- | --- | --- |
| `write_missing_cause` | `I1` | `write_authorization` | `high` | `blocked_illegitimate_transition` |
| `write_unknown_cause` | `I2` | `write_authorization` | `high` | `blocked_illegitimate_transition` |
| `effect_before_commit` | `I3` | `effect_commit_boundary` | `critical` | `blocked_illegitimate_transition` |
| `valid_committed_effect` | `I4` | `effect_commit_boundary` | `info` | `accepted_legitimate_transition` |

---

## Saved examples

Valid report:

```text
examples/audit_reports/cmc_audit_report_valid.jsonl
```

Drift/failure report:

```text
examples/audit_reports/cmc_audit_report_drift.jsonl
```

These are static reviewer artifacts showing both expected success and expected failure semantics.

They are verified by:

```bash
cd rust/cmc-core
cargo run --bin audit_report_example_verify --locked
```

The verifier parses each JSONL line as a flat JSON object and checks fields by type and value, including:

```text
type
scenario_id
invariant_id
category
severity
expected_verdict
decision
expected_events
actual_events
expected_fingerprint
actual_fingerprint
ok
status
cases
passed
failed
```

It also checks record counts and duplicate keys. This is still a lightweight internal parser, not a full JSON Schema implementation.

---

## Drift example meaning

The drift example demonstrates the shape of a failed audit case:

```json
{"type":"cmc_audit_case","scenario_id":"write_missing_cause","invariant_id":"I1","category":"write_authorization","severity":"high","expected_verdict":"blocked_illegitimate_transition","fixture":"fixtures/replay/missing_cause.jsonl","decision":"REJECT_MISSING_CAUSE","expected_events":1,"actual_events":1,"expected_fingerprint":"88fd99689760140e","actual_fingerprint":"0000000000000000","ok":false,"status":"fixture_fingerprint_drift"}
```

This is an illustrative saved report, not the expected output of the current clean fixture corpus.

---

## Non-claims

This report is not:

- production cryptographic evidence
- a formal proof
- a certification artifact
- a replacement for sandboxing, policy design, or conventional security engineering

It is a structured developer/reviewer evidence report.

---

## Next hardening steps

- decide whether JSONL should remain the only format or whether a summary JSON mode is needed
- replace developer FNV-1a64 fingerprints with stronger cryptographic evidence
- include report generation timing in benchmark/stability work
- optionally replace the lightweight parser with a dedicated JSON dependency if external dependencies become acceptable

---

## One-line summary

```text
CMC Auditor Report turns manifest-linked replay evidence into machine-readable JSONL and field-level executable-verified examples for reviewer inspection.
```

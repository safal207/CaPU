# CMC Auditor Report

Status: early auditor-facing JSONL report contract.

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
transition legitimacy can be represented, replayed, checked, reported, one-command verified, manifest-linked, and regression-tested
```

The audit report does not claim certification-grade assurance. It is an early structured evidence artifact.

---

## Evidence chain

```text
invariant -> scenario -> fixture -> manifest -> verifier -> audit report -> reviewer command -> CI
```

The audit report is downstream of the manifest and fixture corpus.

---

## Command

From `rust/cmc-core`:

```bash
cargo run --bin cmc_audit_report --locked
```

From repository root, the report is included in:

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
```

---

## Current failure statuses

The current CLI can emit these failure statuses:

```text
manifest_error
missing_fixture
fixture_fingerprint_drift
event_count_drift
decision_drift
audit_report_failed
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

## Saved example

A valid example report is saved at:

```text
examples/audit_reports/cmc_audit_report_valid.jsonl
```

It is a static reviewer artifact showing the intended report shape.

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

- add negative drift example report
- add schema validation tests
- decide whether JSONL should remain the only format or whether a summary JSON mode is needed
- replace developer FNV-1a64 fingerprints with stronger cryptographic evidence
- include report generation timing in benchmark/stability work

---

## One-line summary

```text
CMC Auditor Report turns manifest-linked replay evidence into machine-readable JSONL for reviewer inspection.
```

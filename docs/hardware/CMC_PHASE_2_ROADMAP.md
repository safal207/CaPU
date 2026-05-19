# CMC Phase 2 Roadmap

Status: next-phase roadmap after reviewer-ready baseline.

This roadmap starts after the current CMC baseline:

```text
thesis -> architecture -> 8 replay invariants -> simulator -> replay fixtures -> manifest-linked verifiers -> audit report output -> saved audit examples -> field-level example verifier -> legacy integrity demos -> SHA-256 trace-integrity reference path -> saved SHA-256 sealed fixtures -> one-command reviewer demo -> CI gate -> evidence map -> reviewer quickstart -> baseline status
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
transition legitimacy can be represented, replayed, checked, reported, field-level example-verified, SHA-256 sealed, fixture-verified, one-command verified, manifest-linked, and regression-tested
```

---

## Phase 2 progress snapshot

Done for the current baseline:

- `CMC_INVARIANTS.md`
- `CMC_TRACE_INTEGRITY.md`
- `CMC_EVIDENCE_MAP.md`
- `CMC_BASELINE_STATUS.md`
- `CMC_REVIEWER_QUICKSTART.md`
- `CMC_AUDITOR_REPORT.md`
- `scripts/run-cmc-reviewer-demo.mjs`
- npm script: `review:cmc`
- CI step: `npm run review:cmc`
- replay corpus expanded to 8 checked scenarios
- replay manifest links `scenario_id` to `invariant_id`
- replay manifest includes `category`, `severity`, and `expected_verdict`
- replay verifiers read the machine-readable manifest
- `cmc_audit_report` emits manifest-linked JSONL audit output
- saved valid audit report example covers 8 cases
- saved drift/failure audit report example covers an 8-case corpus
- `audit_report_example_verify` checks saved audit examples at field level
- `trace_crypto.rs` provides a std-only SHA-256 reference implementation
- `verify_trace_sha256` checks the positive SHA-256 generated trace path
- `verify_trace_sha256_tampered` checks generated SHA-256 tamper detection
- `fixtures/trace_integrity/sha256_valid.jsonl` exists as a saved sealed fixture
- `fixtures/trace_integrity/sha256_tampered.jsonl` exists as a saved tampered sealed fixture
- `verify_trace_sha256_fixture` verifies saved valid/tampered sealed fixtures
- GitHub Actions runs legacy, SHA-256 generated, SHA-256 fixture, replay, audit, divergence, and reviewer checks

---

## Current checked replay evidence

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

---

## Current trace-integrity evidence

| Check | Meaning |
| --- | --- |
| `cargo run --bin verify_trace --locked` | legacy FNV developer hash-chain positive demo |
| `cargo run --bin verify_trace_tampered --locked` | legacy FNV tamper-detection demo |
| `cargo run --bin verify_trace_sha256 --locked` | std-only SHA-256 generated trace sealing positive demo |
| `cargo run --bin verify_trace_sha256_tampered --locked` | std-only SHA-256 generated trace tamper-detection demo |
| `cargo run --bin verify_trace_sha256_fixture --locked` | saved SHA-256 valid/tampered sealed fixture verification |

Saved sealed fixtures:

```text
rust/cmc-core/fixtures/trace_integrity/sha256_valid.jsonl
rust/cmc-core/fixtures/trace_integrity/sha256_tampered.jsonl
```

Current fixture semantics:

```text
sha256_valid.jsonl    -> verifies successfully
sha256_tampered.jsonl -> fails at event 1
```

---

## Current audit evidence

| Example | Meaning | Checked by |
| --- | --- | --- |
| `examples/audit_reports/cmc_audit_report_valid.jsonl` | clean valid 8-case audit report | field-level `audit_report_example_verify` |
| `examples/audit_reports/cmc_audit_report_drift.jsonl` | illustrative 8-case fingerprint drift/failure report | field-level `audit_report_example_verify` |

The current auditor-facing command is:

```bash
cd rust/cmc-core
cargo run --bin cmc_audit_report --locked
```

The saved examples are checked by:

```bash
cd rust/cmc-core
cargo run --bin audit_report_example_verify --locked
```

---

## Workstream 1: Canonical trace-event encoding

Current state:

- CMC emits deterministic trace events
- `trace_jsonl()` provides canonical-looking event lines
- SHA-256 generated traces can be sealed and verified
- saved SHA-256 valid/tampered fixtures exist
- saved fixture verifier exists and is in CI

Target:

- define canonical trace-event encoding rules explicitly
- separate fixture drift fingerprints from trace-integrity hashes
- make event ordering, field ordering, null representation, and escaping rules clear

Candidate deliverables:

- `CMC_CANONICAL_TRACE_ENCODING.md`
- optional `canonical_trace_event.rs` helper
- tests for stable field ordering and null encoding
- updated `CMC_TRACE_INTEGRITY.md`

Definition of done:

```text
A reviewer can explain exactly which bytes are hashed for each trace event and why the result is stable across runs.
```

---

## Workstream 2: Manifest-to-integrity linkage

Current state:

- replay manifest exists for 8 scenarios
- replay fixture fingerprints detect developer drift
- SHA-256 sealed fixtures exist, but they are not yet linked from `MANIFEST.tsv`

Target:

- connect manifest entries to SHA-256 sealed trace evidence where useful
- keep developer fixture fingerprints and cryptographic trace hashes conceptually separate

Candidate deliverables:

- manifest extension or companion manifest for sealed trace evidence
- `trace_integrity/MANIFEST.tsv`
- verifier that checks sealed fixture references from a manifest
- optional audit report fields for trace-integrity references

Definition of done:

```text
A reviewer can move from scenario -> manifest -> replay fixture -> sealed trace fixture -> verifier without guessing file relationships.
```

---

## Workstream 3: Richer negative integrity fixtures

Current state:

- saved tampered fixture modifies a decision and must fail at event 1

Target:

- broaden trace-integrity negative coverage beyond changed decision text

Candidate fixtures:

- removed event
- reordered events
- changed `cause_id`
- changed `address`
- changed `prev_hash`
- appended unauthorized event

Definition of done:

```text
The SHA-256 fixture verifier demonstrates multiple realistic trace-integrity failure classes, not only one decision edit.
```

---

## Workstream 4: Replay fixture expansion

Current state:

- 8 checked replay scenarios
- machine-readable `MANIFEST.tsv`
- human-readable `MANIFEST.md`
- manifest-driven structure verifier
- manifest-driven fingerprint verifier
- manifest-driven JSONL audit report
- saved valid/drift audit examples
- field-level verifier for saved audit examples
- one-command reviewer baseline runs fixture checks, audit report output, audit example checks, SHA-256 trace checks, and sealed fixture checks

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

Definition of done:

```text
The replay fixture corpus covers baseline CMC transition legitimacy and can be extended to broader adversarial replay classes without changing the reviewer command.
```

---

## Workstream 5: Auditor report format

Current state:

- `cmc_audit_report` CLI exists
- command output is JSONL
- report is manifest-linked
- output carries `scenario_id`, `invariant_id`, `category`, `severity`, and `expected_verdict`
- `CMC_AUDITOR_REPORT.md` documents the JSONL schema
- saved valid report example exists and covers 8 cases
- saved drift/failure report example exists for an 8-case corpus
- `audit_report_example_verify` uses field-level JSONL parsing and typed field checks

Remaining target:

- decide whether the report should stay JSONL or gain a summary JSON mode
- optionally add generated report snapshot comparison
- optionally include trace-integrity references in future audit records once manifest linkage exists

Definition of done:

```text
A reviewer can run one command and receive a documented structured report explaining which invariant/scenario passed or failed, with saved examples verified by field-level executable checks.
```

---

## Workstream 6: Overhead and stability measurement

Current state:

- developer benchmark exists
- no official machine-specific benchmark claim

Target:

Measure overhead and stability without overclaiming performance.

Metrics to collect:

- writes/sec
- reads/sec
- effects/sec
- trace events/sec
- legacy hash-chain overhead
- SHA-256 trace sealing overhead
- sealed fixture verification time
- replay verification time
- audit report generation time
- audit example verification time

Definition of done:

```text
The project can report reproducible developer benchmark numbers with clear environment metadata and no production SLA claims.
```

---

## Workstream 7: Reviewer-facing demo polish

Current state:

- reviewer quickstart exists
- evidence map exists
- baseline status exists
- trace integrity doc exists
- one-command reviewer script exists: `scripts/run-cmc-reviewer-demo.mjs`
- npm script exists: `npm run review:cmc`
- CI runs the reviewer command
- reviewer command exercises manifest-linked replay checks, audit report output, field-level saved audit example verification, SHA-256 generated trace checks, SHA-256 sealed fixture checks, and divergence detection

Expected output summary now includes:

```text
CMC reviewer demo
formatting: ok
simulator tests: ok
blocked-transition demo: ok
valid trace hash-chain demo: ok
tampering detection demo: ok
sha256 trace verification demo: ok
sha256 tampering detection demo: ok
sha256 sealed fixture verification: ok
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
Done for baseline; future work should strengthen canonical encoding, manifest-to-integrity linkage, validation strictness, negative fixture coverage, and benchmark evidence.
```

---

## Suggested implementation order from here

```text
1. canonical trace-event encoding rules
2. manifest link or companion manifest for SHA-256 sealed trace evidence
3. removed-event / reordered-event / changed-cause negative fixtures
4. richer replay manifest validation rules
5. overhead benchmark report including SHA-256 sealing and fixture verification overhead
6. optional JSON/JSONL mode split
7. broader workload replay cases
```

Reasoning:

- Invariants are linked to 8 replay scenarios.
- The manifest is machine-readable and consumed by verifiers.
- Audit metadata is in the manifest.
- Audit report CLI exists and is in the reviewer baseline.
- Schema docs and saved examples exist.
- Saved examples are field-level executable-verified.
- SHA-256 trace sealing exists as a reference path.
- Golden SHA-256 valid/tampered sealed fixtures now exist and are checked by CI.
- Canonical encoding and manifest-to-integrity linkage are the next credibility step.
- Richer negative fixtures reduce the chance that trace integrity looks like a single happy-path demo.
- Benchmarks add engineering credibility without overclaiming.

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
It defines invariants, links them to 8 replay scenarios, verifies fixtures through a manifest, emits audit reports, field-level verifies saved audit examples, seals traces with a SHA-256 reference path, verifies saved sealed fixtures, detects drift, detects tampering, and detects divergence.
```

---

## One-line roadmap summary

```text
Phase 1 made causal legitimacy executable; Phase 2 makes it 8-scenario, manifest-linked, reportable, field-level example-verified, SHA-256 sealed-fixture-verified, broader, stronger, easier to verify, and easier to audit.
```

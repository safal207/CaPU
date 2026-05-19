# CMC Phase 2 Roadmap

Status: next-phase roadmap after reviewer-ready baseline.

This roadmap starts after the current CMC baseline:

```text
thesis -> architecture -> simulator -> replay fixtures -> integrity demos -> one-command reviewer demo -> CI gate -> evidence map -> reviewer quickstart -> baseline status
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
transition legitimacy can be represented, replayed, checked, one-command verified, regression-tested, and reported
```

---

## Phase 2 progress snapshot

Done:

- `CMC_INVARIANTS.md`
- `scripts/run-cmc-reviewer-demo.mjs`
- npm script: `review:cmc`
- CI step: `npm run review:cmc`
- README links for Phase 2 roadmap and invariants
- reviewer quickstart updated to prefer `npm run review:cmc`
- evidence map updated for one-command reviewer baseline
- baseline status updated for one-command, CI-enforced scaffold

Next:

- expand replay fixture coverage
- introduce a canonical replay fixture manifest
- strengthen hash-chain implementation beyond developer FNV-1a64 demo
- add auditor-facing JSON report output
- add repeated-run benchmark/stability reporting

---

## Workstream 1: Cryptographic hash-chain upgrade

Current state:

- developer FNV-1a64 hash-chain demo
- trace tampering detection demo
- fixture fingerprint stability checks
- one-command reviewer baseline runs current integrity checks

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

- missing cause fixture
- effect before commit fixture
- fixture structure verifier
- fixture fingerprint verifier
- one-command reviewer baseline runs fixture checks

Target:

Add fixtures for more violation classes:

- unknown cause
- duplicate cause
- read without sufficient cause
- effect with missing parent cause
- replay nonce mismatch
- branch divergence
- trace event ordering violation
- missing trace event

Candidate deliverables:

- expanded `fixtures/replay/*.jsonl`
- `fixtures/replay/MANIFEST.md`
- stricter fixture verifier
- stable fixture fingerprint manifest

Definition of done:

```text
The replay fixture corpus covers at least 8 legitimacy violation classes and is fully checked in CI.
```

---

## Workstream 3: Auditor report format

Current state:

- command output is human-readable
- evidence map exists
- reviewer quickstart exists
- one-command reviewer demo exists

Target:

Create a structured auditor-facing report format.

Candidate output:

```json
{
  "scenario": "effect_before_commit",
  "decision": "REJECT_EFFECT_BEFORE_COMMIT",
  "accepted": false,
  "cause_id": 2,
  "effect_id": 9001,
  "evidence": {
    "trace_event_count": 1,
    "fixture_fingerprint": "...",
    "hash_chain_status": "valid"
  },
  "verdict": "blocked_illegitimate_transition"
}
```

Candidate deliverables:

- `cmc_audit_report` CLI
- JSON report schema
- example reports in `examples/audit_reports/`
- doc: `CMC_AUDITOR_REPORT.md`

Definition of done:

```text
A reviewer can run one command and receive a structured JSON report explaining why a transition was accepted, rejected, or blocked.
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

Definition of done:

```text
The project can report reproducible developer benchmark numbers with clear environment metadata and no production SLA claims.
```

---

## Workstream 5: Formal invariants and decision semantics

Current state:

- informal invariants in docs
- executable tests in Rust
- decision codes exist
- canonical invariants map exists: `CMC_INVARIANTS.md`

Completed deliverables:

- `CMC_INVARIANTS.md`
- invariant-to-evidence map
- invariant-to-command map
- Phase 2 gaps table

Remaining target:

- add dedicated tests for exactly-one TraceEvent per decision
- expand invariant-to-fixture coverage as replay corpus grows
- add decision-code table if decision semantics expand

Definition of done:

```text
Each major CMC invariant maps to documentation, at least one test, and where possible a replay fixture.
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

Completed deliverables:

- `scripts/run-cmc-reviewer-demo.mjs`
- npm script: `review:cmc`
- workflow step: `npm run review:cmc`
- README entry
- updated reviewer quickstart
- updated evidence map
- updated baseline status

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
replay divergence detection: ok
result=reviewer_baseline_passed
```

Definition of done:

```text
A reviewer can run one top-level command and see the whole baseline pass/fail summary.
```

Current status:

```text
Done for baseline; future work may add auditor JSON output.
```

---

## Suggested implementation order from here

```text
1. expanded replay fixtures
2. replay fixture manifest
3. crypto hash-chain module
4. auditor JSON report CLI
5. overhead benchmark report
```

Reasoning:

- Invariants are now present and give discipline to fixture expansion.
- One-command reviewer demo is now present and CI-enforced.
- Fixtures broaden evidence coverage.
- A manifest makes fixture expectations less hardcoded.
- Crypto hash-chain strengthens integrity.
- Auditor report makes the project usable outside code review.
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
It defines invariants, produces traces, verifies fixtures, detects drift, detects tampering, detects divergence, and emits auditor-facing evidence.
```

---

## One-line roadmap summary

```text
Phase 1 made causal legitimacy executable; Phase 2 makes it broader, stronger, easier to verify, and easier to audit.
```

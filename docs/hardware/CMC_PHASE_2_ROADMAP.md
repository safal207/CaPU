# CMC Phase 2 Roadmap

Status: next-phase roadmap after reviewer-ready baseline.

This roadmap starts after the current CMC baseline:

```text
thesis -> architecture -> simulator -> replay fixtures -> integrity demos -> CI gate -> evidence map -> reviewer quickstart -> baseline status
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
transition legitimacy can be represented, replayed, checked, regression-tested, and reported
```

---

## Workstream 1: Cryptographic hash-chain upgrade

Current state:

- developer FNV-1a64 hash-chain demo
- trace tampering detection demo
- fixture fingerprint stability checks

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

Target:

Turn invariants into canonical semantics.

Candidate invariants:

```text
I1: WRITE without cause must reject.
I2: WRITE with unknown cause must reject.
I3: EFFECT before COMMIT must reject.
I4: Every decision must emit exactly one TraceEvent.
I5: TraceEvent decision must match runtime decision.
I6: Replay divergence must be observable.
I7: Fixture drift must fail verification.
```

Candidate deliverables:

- `CMC_INVARIANTS.md`
- decision-code table
- invariant-to-test map
- invariant-to-fixture map

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

Target:

Create a single reviewer command or script.

Candidate deliverables:

- `scripts/run-cmc-reviewer-demo.mjs`
- npm script: `review:cmc`
- output summary:

```text
CMC reviewer demo
tests: ok
blocked transition demo: ok
trace integrity: ok
tampering detection: ok
fixture structure: ok
fixture fingerprints: ok
replay divergence: ok
result: reviewer_baseline_passed
```

Definition of done:

```text
A reviewer can run one top-level command and see the whole baseline pass/fail summary.
```

---

## Suggested implementation order

```text
1. CMC_INVARIANTS.md
2. scripts/run-cmc-reviewer-demo.mjs + npm review:cmc
3. expanded replay fixtures
4. crypto hash-chain module
5. auditor JSON report CLI
6. overhead benchmark report
```

Reasoning:

- Invariants make the next work disciplined.
- One-command reviewer demo improves adoption immediately.
- Fixtures broaden evidence coverage.
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
Phase 1 made causal legitimacy executable; Phase 2 makes it broader, stronger, and easier to audit.
```

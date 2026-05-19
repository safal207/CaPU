# CMC Invariants

Status: canonical invariants / Phase 2 foundation.

This document defines the current Causal Memory Controller invariants and maps them to executable evidence.

The goal is to make the CMC research claim testable:

```text
transition legitimacy can be represented, replayed, checked, and regression-tested
```

---

## Core principle

CMC is not only about storing state.

CMC is about preserving and checking the legitimacy of transitions near memory/effect boundaries.

```text
A requested transition is not automatically legitimate.
```

---

## Replay manifest linkage

The current replay corpus is linked to invariants through:

```text
rust/cmc-core/fixtures/replay/MANIFEST.tsv
```

Current manifest shape:

```tsv
scenario_id	invariant_id	path	decision	events	fingerprint
```

This means the evidence chain is now explicit:

```text
invariant -> scenario -> fixture -> verifier -> reviewer command -> CI
```

---

## Invariant summary

| ID | Invariant | Current evidence | CI gate |
| --- | --- | --- | --- |
| I1 | Write without explicit cause must reject | Rust tests + manifest-linked replay fixture | Yes |
| I2 | Write with unknown cause must reject | Rust tests + manifest-linked replay fixture | Yes |
| I3 | Effect before causal commit must reject | Rust tests + demo + manifest-linked replay fixture | Yes |
| I4 | Committed cause can authorize effect | Rust tests + manifest-linked replay fixture | Yes |
| I5 | Every accepted/rejected decision emits trace evidence | Rust tests + trace APIs | Yes |
| I6 | Trace decision must match runtime decision | Trace verifier demos | Yes |
| I7 | Tampered trace decision must be detectable | Tampering demo | Yes |
| I8 | Replay fixture structure must be stable | Manifest-driven fixture verifier | Yes |
| I9 | Replay fixture fingerprint drift must be detectable | Manifest-driven fingerprint verifier | Yes |
| I10 | Replay divergence must be observable | Divergence detector | Yes |

---

## I1: Write without explicit cause must reject

Definition:

```text
A memory write that does not carry an explicit cause is illegitimate and must be rejected.
```

Reason:

Ordinary memory may accept a byte-level write, but CMC requires causal authorization.

Expected decision:

```text
REJECT_MISSING_CAUSE
```

Replay scenario:

```text
scenario_id=write_missing_cause
invariant_id=I1
fixture=rust/cmc-core/fixtures/replay/missing_cause.jsonl
```

Evidence:

- Rust simulator tests
- manifest-linked replay fixture
- fixture fingerprint verifier

Commands:

```bash
cd rust/cmc-core
cargo test --all --locked
cargo run --bin replay_fixture_verify --locked
cargo run --bin replay_fingerprint_verify --locked
```

---

## I2: Write with unknown cause must reject

Definition:

```text
A memory write that references a cause unknown to the controller must be rejected.
```

Reason:

A cause identifier is not sufficient unless it belongs to the known causal context.

Expected decision:

```text
REJECT_UNKNOWN_CAUSE
```

Replay scenario:

```text
scenario_id=write_unknown_cause
invariant_id=I2
fixture=rust/cmc-core/fixtures/replay/unknown_cause.jsonl
```

Evidence:

- Rust simulator tests
- manifest-linked replay fixture
- fixture fingerprint verifier

Commands:

```bash
cd rust/cmc-core
cargo test --all --locked
cargo run --bin replay_fixture_verify --locked
cargo run --bin replay_fingerprint_verify --locked
```

---

## I3: Effect before causal commit must reject

Definition:

```text
An effect cannot execute before its cause has been committed.
```

Reason:

This is the core commit-before-effect boundary.

Expected decision:

```text
REJECT_EFFECT_BEFORE_COMMIT
```

Replay scenario:

```text
scenario_id=effect_before_commit
invariant_id=I3
fixture=rust/cmc-core/fixtures/replay/forbidden_effect_before_commit_fixture.jsonl
```

Evidence:

- Rust simulator tests
- executable demo: `cmc_demo`
- manifest-linked replay fixture
- fixture fingerprint verifier

Commands:

```bash
cd rust/cmc-core
cargo test --all --locked
cargo run --bin cmc_demo --locked
cargo run --bin replay_fixture_verify --locked
cargo run --bin replay_fingerprint_verify --locked
```

---

## I4: Committed cause can authorize effect

Definition:

```text
An effect with a known and committed cause may be accepted.
```

Reason:

CMC must not only reject illegal transitions; it must also allow legitimate committed transitions.

Expected decision:

```text
ACCEPT_EFFECT
```

Replay scenario:

```text
scenario_id=valid_committed_effect
invariant_id=I4
fixture=rust/cmc-core/fixtures/replay/valid_committed_effect.jsonl
```

Evidence:

- Rust simulator tests
- manifest-linked replay fixture
- fixture fingerprint verifier
- golden fixture path

Commands:

```bash
cd rust/cmc-core
cargo test --all --locked
cargo run --bin replay_fixture_verify --locked
cargo run --bin replay_fingerprint_verify --locked
```

---

## I5: Every accepted/rejected decision emits trace evidence

Definition:

```text
Every write, read, or effect decision must produce a deterministic trace event.
```

Reason:

Legitimacy is not useful unless it is inspectable and replayable.

Evidence:

- `trace_events()`
- `trace_jsonl()`
- Rust tests
- demo output

Commands:

```bash
cd rust/cmc-core
cargo test --all --locked
cargo run --bin cmc_demo --locked
```

Future Phase 2 hardening:

```text
Add explicit invariant tests for exactly-one TraceEvent per decision.
```

---

## I6: Trace decision must match runtime decision

Definition:

```text
The decision recorded in a trace event must match the runtime decision returned by the controller.
```

Reason:

If runtime and trace disagree, replay evidence is not trustworthy.

Evidence:

- hash-chain trace verifier demo
- tampering detector

Commands:

```bash
cd rust/cmc-core
cargo run --bin verify_trace --locked
cargo run --bin verify_trace_tampered --locked
```

Future Phase 2 hardening:

```text
Move from demo-level validation to canonical trace event signing/hash-chain verification.
```

---

## I7: Tampered trace decision must be detectable

Definition:

```text
If a trace decision is modified after emission, verification must detect it.
```

Reason:

A causal trace that can be silently rewritten is not audit-grade evidence.

Evidence:

- `verify_trace_tampered.rs`

Command:

```bash
cd rust/cmc-core
cargo run --bin verify_trace_tampered --locked
```

Current limit:

```text
The current implementation is a developer integrity demo, not production cryptography.
```

---

## I8: Replay fixture structure must be stable

Definition:

```text
Replay fixtures must preserve expected JSONL structure, event count, decision fields, scenario IDs, and invariant IDs.
```

Reason:

Fixtures are not examples only; they are regression artifacts.

Evidence:

- `replay_fixture_verify.rs`
- `rust/cmc-core/fixtures/replay/MANIFEST.tsv`

Command:

```bash
cd rust/cmc-core
cargo run --bin replay_fixture_verify --locked
```

---

## I9: Replay fixture fingerprint drift must be detectable

Definition:

```text
If a replay fixture changes unexpectedly, fingerprint verification must fail.
```

Reason:

Fixture drift can otherwise silently weaken the evidence corpus.

Evidence:

- `replay_fingerprint_verify.rs`
- `rust/cmc-core/fixtures/replay/MANIFEST.tsv`

Command:

```bash
cd rust/cmc-core
cargo run --bin replay_fingerprint_verify --locked
```

Current manifest-linked fingerprints:

| Scenario | Invariant | Fixture | Fingerprint |
| --- | --- | --- | --- |
| `write_missing_cause` | `I1` | `fixtures/replay/missing_cause.jsonl` | `88fd99689760140e` |
| `write_unknown_cause` | `I2` | `fixtures/replay/unknown_cause.jsonl` | `d8c4983b8a5a0ab0` |
| `effect_before_commit` | `I3` | `fixtures/replay/forbidden_effect_before_commit_fixture.jsonl` | `28bf87f68e4ec6cb` |
| `valid_committed_effect` | `I4` | `fixtures/replay/valid_committed_effect.jsonl` | `e3e96ba017e2c235` |

Current limit:

```text
These are developer-stability fingerprints, not production cryptographic evidence.
```

---

## I10: Replay divergence must be observable

Definition:

```text
If expected and actual replay traces diverge, the system must surface the mismatch.
```

Reason:

Replay is only useful if divergence is detectable.

Evidence:

- `trace_divergence.rs`

Command:

```bash
cd rust/cmc-core
cargo run --bin trace_divergence --locked
```

---

## CI mapping

The CMC GitHub Actions workflow currently runs:

```bash
cargo fmt --check
cargo test --all --locked
cargo run --bin cmc_demo --locked
cargo run --bin verify_trace --locked
cargo run --bin verify_trace_tampered --locked
cargo run --bin replay_fixture_verify --locked
cargo run --bin replay_fingerprint_verify --locked
cargo run --bin trace_divergence --locked
```

From repository root, the reviewer path is:

```bash
npm run review:cmc
```

This means the current invariant set is at least partially CI-enforced.

---

## Phase 2 gaps

The following gaps should be closed next:

| Gap | Target artifact |
| --- | --- |
| Exactly-one trace event invariant not isolated | dedicated Rust test |
| Fixture corpus still small | at least 8 legitimacy violation classes |
| Production crypto absent | cryptographic hash-chain module |
| Auditor report absent | `cmc_audit_report` CLI |
| Manifest lacks richer metadata | add categories/severity/expected verdict fields |

---

## Reviewer interpretation

The invariants should be read as the bridge between thesis and executable evidence.

```text
Thesis without invariants is philosophy.
Invariants without tests are wishful thinking.
Tests without replay evidence are local behavior only.
Replay evidence without CI is not stable enough.
```

CMC Phase 2 should keep all four together:

```text
thesis -> invariant -> test -> fixture -> CI gate
```

---

## One-line summary

```text
CMC invariants define what must never happen, what may happen after causal commit, and how evidence must survive replay, drift, tampering, and divergence checks.
```

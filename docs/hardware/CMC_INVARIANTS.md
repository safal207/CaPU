# CMC Invariants

Status: canonical invariants / Phase 2 foundation.

This document defines the current Causal Memory Controller invariants and maps them to executable evidence.

The goal is to make the CMC research claim testable:

```text
transition legitimacy can be represented, replayed, checked, reported, field-level example-verified, and regression-tested
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
scenario_id	invariant_id	path	decision	events	fingerprint	category	severity	expected_verdict
```

This means the evidence chain is explicit:

```text
invariant -> scenario -> fixture -> manifest -> verifier -> audit report -> saved examples -> field-level example verifier -> reviewer command -> CI
```

---

## Replay invariant summary

| ID | Scenario | Invariant | Expected decision | Category | Severity | CI gate |
| --- | --- | --- | --- | --- | --- | --- |
| I1 | `write_missing_cause` | Write without explicit cause must reject | `REJECT_MISSING_CAUSE` | `write_authorization` | high | Yes |
| I2 | `write_unknown_cause` | Write with unknown cause must reject | `REJECT_UNKNOWN_CAUSE` | `write_authorization` | high | Yes |
| I3 | `effect_before_commit` | Effect before causal commit must reject | `REJECT_EFFECT_BEFORE_COMMIT` | `effect_commit_boundary` | critical | Yes |
| I4 | `valid_committed_effect` | Committed cause can authorize effect | `ACCEPT_EFFECT` | `effect_commit_boundary` | info | Yes |
| I5 | `read_missing_cause` | Read without explicit cause must reject | `REJECT_MISSING_CAUSE` | `read_authorization` | high | Yes |
| I6 | `read_unknown_cause_or_address` | Read with unknown cause/address must reject | `REJECT_UNKNOWN_CAUSE` | `read_authorization` | high | Yes |
| I7 | `effect_missing_parent` | Effect without parent cause must reject | `REJECT_MISSING_CAUSE` | `effect_commit_boundary` | critical | Yes |
| I8 | `valid_read_after_write` | Known cause can authorize read after write | `ACCEPT_READ` | `read_authorization` | info | Yes |

---

## I1: Write without explicit cause must reject

Definition:

```text
A memory write that does not carry an explicit cause is illegitimate and must be rejected.
```

Reason:

Ordinary memory may accept a byte-level write, but CMC requires causal authorization.

Replay evidence:

```text
scenario_id=write_missing_cause
fixture=rust/cmc-core/fixtures/replay/missing_cause.jsonl
decision=REJECT_MISSING_CAUSE
events=1
fingerprint=88fd99689760140e
```

---

## I2: Write with unknown cause must reject

Definition:

```text
A memory write that references a cause unknown to the controller must be rejected.
```

Reason:

A cause identifier is not sufficient unless it belongs to the known causal context.

Replay evidence:

```text
scenario_id=write_unknown_cause
fixture=rust/cmc-core/fixtures/replay/unknown_cause.jsonl
decision=REJECT_UNKNOWN_CAUSE
events=1
fingerprint=d8c4983b8a5a0ab0
```

---

## I3: Effect before causal commit must reject

Definition:

```text
An effect cannot execute before its cause has been committed.
```

Reason:

This is the core commit-before-effect boundary.

Replay evidence:

```text
scenario_id=effect_before_commit
fixture=rust/cmc-core/fixtures/replay/forbidden_effect_before_commit_fixture.jsonl
decision=REJECT_EFFECT_BEFORE_COMMIT
events=1
fingerprint=28bf87f68e4ec6cb
```

---

## I4: Committed cause can authorize effect

Definition:

```text
An effect with a known and committed cause may be accepted.
```

Reason:

CMC must not only reject illegal transitions; it must also allow legitimate committed transitions.

Replay evidence:

```text
scenario_id=valid_committed_effect
fixture=rust/cmc-core/fixtures/replay/valid_committed_effect.jsonl
decision=ACCEPT_EFFECT
events=1
fingerprint=e3e96ba017e2c235
```

---

## I5: Read without explicit cause must reject

Definition:

```text
A memory read that does not carry an explicit cause is illegitimate and must be rejected.
```

Reason:

A read can leak or propagate state. CMC treats read authorization as part of causal legitimacy, not as a passive operation.

Replay evidence:

```text
scenario_id=read_missing_cause
fixture=rust/cmc-core/fixtures/replay/read_missing_cause.jsonl
decision=REJECT_MISSING_CAUSE
events=1
fingerprint=9f49c650fcd31fff
```

---

## I6: Read with unknown cause/address must reject

Definition:

```text
A memory read that references an unknown cause or unavailable address must be rejected.
```

Reason:

Read legitimacy depends on both a known causal context and a readable memory target.

Replay evidence:

```text
scenario_id=read_unknown_cause_or_address
fixture=rust/cmc-core/fixtures/replay/read_unknown_cause_or_address.jsonl
decision=REJECT_UNKNOWN_CAUSE
events=1
fingerprint=91768923fb87d345
```

---

## I7: Effect without parent cause must reject

Definition:

```text
An effect that does not specify a parent cause must be rejected.
```

Reason:

Effects are externally meaningful transitions. They must be causally attributable.

Replay evidence:

```text
scenario_id=effect_missing_parent
fixture=rust/cmc-core/fixtures/replay/effect_missing_parent.jsonl
decision=REJECT_MISSING_CAUSE
events=1
fingerprint=da78371555a0b983
```

---

## I8: Known cause can authorize read after write

Definition:

```text
A read from an existing address under a known cause may be accepted after a legitimate write.
```

Reason:

CMC must preserve useful computation, not only block illegitimate transitions.

Replay evidence:

```text
scenario_id=valid_read_after_write
fixture=rust/cmc-core/fixtures/replay/valid_read_after_write.jsonl
decision=ACCEPT_READ
events=2
fingerprint=d6b83bfe3651c60d
```

---

## Current manifest-linked replay corpus

| Scenario | Invariant | Fixture | Decision | Events | Fingerprint | Category | Severity | Verdict |
| --- | --- | --- | --- | ---: | --- | --- | --- | --- |
| `write_missing_cause` | I1 | `missing_cause.jsonl` | `REJECT_MISSING_CAUSE` | 1 | `88fd99689760140e` | `write_authorization` | high | `blocked_illegitimate_transition` |
| `write_unknown_cause` | I2 | `unknown_cause.jsonl` | `REJECT_UNKNOWN_CAUSE` | 1 | `d8c4983b8a5a0ab0` | `write_authorization` | high | `blocked_illegitimate_transition` |
| `effect_before_commit` | I3 | `forbidden_effect_before_commit_fixture.jsonl` | `REJECT_EFFECT_BEFORE_COMMIT` | 1 | `28bf87f68e4ec6cb` | `effect_commit_boundary` | critical | `blocked_illegitimate_transition` |
| `valid_committed_effect` | I4 | `valid_committed_effect.jsonl` | `ACCEPT_EFFECT` | 1 | `e3e96ba017e2c235` | `effect_commit_boundary` | info | `accepted_legitimate_transition` |
| `read_missing_cause` | I5 | `read_missing_cause.jsonl` | `REJECT_MISSING_CAUSE` | 1 | `9f49c650fcd31fff` | `read_authorization` | high | `blocked_illegitimate_transition` |
| `read_unknown_cause_or_address` | I6 | `read_unknown_cause_or_address.jsonl` | `REJECT_UNKNOWN_CAUSE` | 1 | `91768923fb87d345` | `read_authorization` | high | `blocked_illegitimate_transition` |
| `effect_missing_parent` | I7 | `effect_missing_parent.jsonl` | `REJECT_MISSING_CAUSE` | 1 | `da78371555a0b983` | `effect_commit_boundary` | critical | `blocked_illegitimate_transition` |
| `valid_read_after_write` | I8 | `valid_read_after_write.jsonl` | `ACCEPT_READ` | 2 | `d6b83bfe3651c60d` | `read_authorization` | info | `accepted_legitimate_transition` |

---

## Executable evidence commands

From `rust/cmc-core`:

```bash
cargo test --all --locked
cargo run --bin replay_fixture_verify --locked
cargo run --bin replay_fingerprint_verify --locked
cargo run --bin cmc_audit_report --locked
cargo run --bin audit_report_example_verify --locked
```

From repository root:

```bash
npm run review:cmc
```

---

## Evidence guarantees beyond replay scenarios

The replay invariants above are supported by broader executable checks:

| Guarantee | Evidence | Command |
| --- | --- | --- |
| Every accepted/rejected decision emits trace evidence | Rust tests + `trace_events()` / `trace_jsonl()` | `cargo test --all --locked` |
| Trace decision must match runtime decision | hash-chain trace verifier demo | `cargo run --bin verify_trace --locked` |
| Tampered trace decision must be detectable | tampering detector | `cargo run --bin verify_trace_tampered --locked` |
| Replay fixture structure must be stable | manifest-driven fixture verifier | `cargo run --bin replay_fixture_verify --locked` |
| Replay fixture fingerprint drift must be detectable | manifest-driven fingerprint verifier | `cargo run --bin replay_fingerprint_verify --locked` |
| Replay divergence must be observable | divergence detector | `cargo run --bin trace_divergence --locked` |
| Saved audit examples must preserve expected semantics | field-level audit example verifier | `cargo run --bin audit_report_example_verify --locked` |

---

## Current limits

The current invariant set does not yet claim:

- production cryptographic sealing
- complete hardware semantics
- formal verification of all transitions
- full multi-agent safety coverage
- certification-grade audit assurance

Current fingerprints are developer-stability fingerprints using the current FNV-1a64 demo implementation. They are not production cryptographic evidence.

---

## Phase 2 gaps

The following gaps should be closed next:

| Gap | Target artifact |
| --- | --- |
| Production crypto absent | cryptographic hash-chain module |
| Manifest validation can become stricter | richer manifest validation rules |
| Workload coverage remains small | repeated-run and workload benchmark reports |
| JSON parser is lightweight | optional dependency-backed JSON parser if dependency policy changes |

---

## Reviewer interpretation

The invariants should be read as the bridge between thesis and executable evidence.

```text
Thesis without invariants is philosophy.
Invariants without tests are wishful thinking.
Tests without replay evidence are local behavior only.
Replay evidence without CI is not stable enough.
```

CMC Phase 2 should keep all together:

```text
thesis -> invariant -> test -> fixture -> manifest -> report -> CI gate
```

---

## One-line summary

```text
CMC invariants define which memory/read/effect transitions must reject, which committed transitions may accept, and how that evidence survives replay, drift, audit-report, tampering, and divergence checks.
```

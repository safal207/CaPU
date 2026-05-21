# CMC Baseline Status

Status: reviewer-ready baseline snapshot.

This document summarizes the current CMC baseline as an executable research scaffold for legitimacy-preserving computation.

---

## Baseline claim

```text
transition legitimacy can be represented, replayed, checked, reported, persona-boundary-verified, action-commit-verified, persona-audit-reportable, persona-audit-example-verified, persona-sha256-sealed, field-level example-verified, canonically encoded, SHA-256 sealed, fixture-verified, one-command verified, manifest-linked, and regression-tested
```

The repository does not claim production readiness, complete AI safety, AI consciousness, therapy, or certification-grade cryptography.

---

## Current reviewer entrypoints

```text
docs/hardware/CMC_CURRENT_REVIEWER_PATH.md
docs/hardware/CMC_PERSONA_ACTION_REVIEWER_PATH.md
```

These are the current source-of-truth reviewer paths for the P6 persona/action corpus.

---

## Persona/action baseline

Current executable persona/action scope:

```text
P1: Persona memory requires cause.
P2: Persona state changes require authorization.
P6: External action requires commit.
P7: Introspection is hypothesis-labeled.
```

Operational summary:

```text
AI must not self-remember.
AI must not self-appoint.
AI must not act without commit.
AI must not claim inner truth.
```

Current persona/action evidence chain:

```text
manifest-linked P1/P2/P6/P7 corpus
 -> 8 JSONL fixtures
 -> persona_boundary_verify
 -> persona_audit_report JSONL
 -> saved valid/drift persona audit examples
 -> persona_audit_report_example_verify
 -> SHA-256 sealed persona/action valid/tampered fixtures
 -> verify_persona_sha256_fixture
 -> P6 action tamper detection at event 5
 -> npm run review:cmc
```

Current persona/action artifacts:

```text
rust/cmc-core/fixtures/persona/MANIFEST.tsv
rust/cmc-core/fixtures/persona/inferred_preference_rejected.jsonl
rust/cmc-core/fixtures/persona/confirmed_preference_accepted.jsonl
rust/cmc-core/fixtures/persona/unauthorized_persona_state_change_rejected.jsonl
rust/cmc-core/fixtures/persona/authorized_persona_state_change_accepted.jsonl
rust/cmc-core/fixtures/persona/action_without_commit_rejected.jsonl
rust/cmc-core/fixtures/persona/action_with_commit_accepted.jsonl
rust/cmc-core/fixtures/persona/unlabeled_introspection_rejected.jsonl
rust/cmc-core/fixtures/persona/hypothesis_labeled_introspection_accepted.jsonl
rust/cmc-core/src/bin/persona_boundary_verify.rs
rust/cmc-core/src/bin/persona_audit_report.rs
rust/cmc-core/src/bin/persona_audit_report_example_verify.rs
rust/cmc-core/fixtures/persona_integrity/sha256_persona_valid.jsonl
rust/cmc-core/fixtures/persona_integrity/sha256_persona_tampered.jsonl
rust/cmc-core/src/bin/verify_persona_sha256_fixture.rs
examples/audit_reports/persona_audit_report_valid.jsonl
examples/audit_reports/persona_audit_report_drift.jsonl
```

Reviewer commands:

```bash
cd rust/cmc-core
cargo run --bin persona_boundary_verify --locked
cargo run --bin persona_audit_report --locked
cargo run --bin persona_audit_report_example_verify --locked
cargo run --bin verify_persona_sha256_fixture --locked
```

Expected outputs include:

```text
cases=8
p6_uncommitted_action_result=blocked_action_without_commit
p6_committed_action_result=accepted_committed_action cause_id=101
result=persona_boundary_manifest_valid
```

```text
report=valid path=../../examples/audit_reports/persona_audit_report_valid.jsonl cases=8 status=ok parser=field_level
report=drift path=../../examples/audit_reports/persona_audit_report_drift.jsonl cases=8 status=ok parser=field_level
result=persona_audit_report_examples_valid parser=field_level cases=8
```

```text
valid_result=persona_sha256_fixture_valid
tampered_result=persona_sha256_fixture_tamper_detected seq=5
result=persona_sha256_fixtures_valid
```

---

## Replay / trace baseline

Current replay corpus covers I1-I8:

```text
write_missing_cause
write_unknown_cause
effect_before_commit
valid_committed_effect
read_missing_cause
read_unknown_cause_or_address
effect_missing_parent
valid_read_after_write
```

Replay and trace artifacts include:

```text
rust/cmc-core/fixtures/replay/MANIFEST.tsv
rust/cmc-core/fixtures/replay/MANIFEST.md
rust/cmc-core/fixtures/trace_integrity/sha256_valid.jsonl
rust/cmc-core/fixtures/trace_integrity/sha256_tampered.jsonl
examples/audit_reports/cmc_audit_report_valid.jsonl
examples/audit_reports/cmc_audit_report_drift.jsonl
```

Trace / replay reviewer commands:

```bash
cd rust/cmc-core
cargo run --bin verify_trace_sha256_fixture --locked
cargo run --bin replay_fixture_verify --locked
cargo run --bin replay_fingerprint_verify --locked
cargo run --bin cmc_audit_report --locked
cargo run --bin audit_report_example_verify --locked
cargo run --bin trace_divergence --locked
```

---

## One-command reviewer check

From repository root:

```bash
npm run review:cmc
```

Expected final result:

```text
result=reviewer_baseline_passed
```

The one-command demo includes:

```text
persona/action boundary fixture verification
persona/action audit report emission
saved persona/action audit example verification
SHA-256 sealed persona/action fixture verification
P6 action tamper detection at event 5
replay fixture verification
replay audit report verification
SHA-256 trace fixture verification
replay divergence detection
```

---

## What is strong today

CMC currently has executable evidence for:

- rejected inferred persona memory without confirmation/cause;
- accepted confirmed persona memory with confirmation/cause;
- rejected unauthorized persona state change without authorization/cause;
- accepted authorized persona state change with authorization/cause;
- rejected external action without committed cause;
- accepted external action with committed cause;
- rejected unlabeled introspection that claims inner truth;
- accepted hypothesis-labeled introspection as reflection;
- persona/action audit report JSONL output;
- saved valid/drift persona audit report examples for 8 cases;
- field-level executable verification of saved persona audit examples;
- saved SHA-256 sealed persona/action valid/tampered fixtures;
- executable verification of saved SHA-256 sealed persona/action fixtures;
- P6 action decision tamper detection at event 5;
- replay fixture checks and fingerprint drift checks;
- manifest-linked replay audit report output;
- saved valid/drift replay audit report examples for 8 cases;
- field-level executable verification of replay audit report examples;
- SHA-256 generated trace sealing and verification;
- SHA-256 generated tampering detection;
- saved SHA-256 valid/tampered sealed trace fixtures;
- executable verification of saved SHA-256 sealed trace fixtures;
- divergence detection demo;
- one-command reviewer verification;
- CI enforcement path.

---

## Known limits

The baseline does not yet provide:

- production cryptographic sealing;
- certified trace storage;
- hardware implementation;
- hardware root of trust;
- formal verification;
- full JSON canonicalization standard compatibility;
- AI consciousness or personhood claims;
- therapeutic diagnosis or treatment;
- real workload performance evaluation;
- full multi-agent benchmark coverage;
- certification-grade assurance.

---

## Next phase

The next phase should focus on:

1. adding exact canonical event-line tests,
2. adding richer manifest validation rules,
3. adding removed-event and reordered-event negative trace-integrity fixtures,
4. measuring overhead and stability across repeated runs,
5. expanding beyond current memory/read/effect/persona/action-boundary cases into broader workloads.

---

## One-line status

```text
CMC baseline is reviewer-ready as an 8-scenario replay corpus plus an 8-scenario manifest-linked, audit-reportable, saved-example-verified, SHA-256-sealed, tamper-evident persona/action corpus with P6 action-commit enforcement and event-5 action tamper detection, one-command verified and CI-compatible, not yet production-ready infrastructure.
```

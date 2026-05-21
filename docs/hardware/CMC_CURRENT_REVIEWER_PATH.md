# CMC Current Reviewer Path

Status: current short entrypoint for reviewers.

Use this document when you need the current executable CMC evidence path.

---

## Current primary reviewer path

```text
docs/hardware/CMC_PERSONA_ACTION_REVIEWER_PATH.md
```

This is the current source of truth for the persona/action evidence chain after P6.

It covers:

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

---

## One-command baseline

From repository root:

```bash
npm run review:cmc
```

Expected final result:

```text
result=reviewer_baseline_passed
```

---

## Manual persona/action commands

From `rust/cmc-core`:

```bash
cargo run --bin persona_boundary_verify --locked
cargo run --bin persona_audit_report --locked
cargo run --bin persona_audit_report_example_verify --locked
cargo run --bin verify_persona_sha256_fixture --locked
```

Expected P6 markers:

```text
cases=8
p6_uncommitted_action_result=blocked_action_without_commit
p6_committed_action_result=accepted_committed_action cause_id=101
tampered_result=persona_sha256_fixture_tamper_detected seq=5
```

---

## Why this entrypoint exists

Some older documents may still describe the pre-P6 persona-only corpus:

```text
P1/P2/P7
cases=6
seq=3 tamper detection
```

The current executable corpus is now:

```text
P1/P2/P6/P7
cases=8
seq=5 P6 action tamper detection
```

---

## One-line summary

```text
The current CMC reviewer path is P1/P2/P6/P7: persona memory requires cause, persona state changes require authorization, external action requires commit, and introspection must remain hypothesis-labeled.
```

# CMC Persona P2: State Change Requires Authorization

Status: executable persona-boundary evidence note.

This document records the current P2 safety boundary:

```text
P2: Persona state changes require authorization.
```

Plain version:

```text
A safe AI persona may adapt, but may not self-appoint.
```

---

## Why P2 matters

A future AI companion should not silently change its role, tone, or long-term behavior toward a human.

Unsafe pattern:

```text
user sounds overwhelmed
 -> AI silently switches into strategic mentor / coach / protector role
 -> persona authority changes without explicit authorization
```

Safe pattern:

```text
user explicitly authorizes a persona role/state change
 -> transition has confirmation and cause
 -> persona state change can be accepted
```

---

## Executable fixtures

P2 is represented by two manifest-linked fixtures:

```text
rust/cmc-core/fixtures/persona/unauthorized_persona_state_change_rejected.jsonl
rust/cmc-core/fixtures/persona/authorized_persona_state_change_accepted.jsonl
```

Manifest source of truth:

```text
rust/cmc-core/fixtures/persona/MANIFEST.tsv
```

Verifier:

```text
rust/cmc-core/src/bin/persona_boundary_verify.rs
```

Run:

```bash
cd rust/cmc-core
cargo run --bin persona_boundary_verify --locked
```

Expected output includes:

```text
p2_unauthorized_result=blocked_unauthorized_persona_state_change
p2_authorized_result=accepted_authorized_persona_state_change cause_id=77
result=persona_boundary_manifest_valid
```

---

## Current P2 cases

| Scenario | Decision | Meaning |
| --- | --- | --- |
| `unauthorized_persona_state_change_rejected` | `REJECT_UNAUTHORIZED_PERSONA_STATE_CHANGE` | A persona must not silently switch role/tone/long-term behavior. |
| `authorized_persona_state_change_accepted` | `ACCEPT_AUTHORIZED_PERSONA_STATE_CHANGE` | A persona state change may be accepted with explicit authorization and cause. |

---

## Relationship to other persona invariants

Current executable persona-boundary corpus:

```text
P1: Persona memory requires cause.
P2: Persona state changes require authorization.
P7: Introspection is hypothesis-labeled.
```

Together:

```text
AI must not self-remember.
AI must not self-appoint.
AI must not claim inner truth.
```

---

## Non-claims

This does not claim AI consciousness, personhood, therapy, full alignment, or production companion readiness.

It is a narrow executable evidence case for persona state-change legitimacy.

---

## One-line summary

```text
P2 verifies that an AI persona cannot silently promote itself into a new role without explicit authorization and cause.
```

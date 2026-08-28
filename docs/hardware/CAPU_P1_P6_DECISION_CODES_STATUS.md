# CaPU P1/P6 Decision Codes Status

Status: P65 software reference maintainability increment.

This note records compatibility-safe migration of P1 and P6 decision codes into central constants.

Progress movement represented by this PR:

```text
Software reference processor: ~84% -> ~85%
Runtime sidecar/API:        ~95% -> ~95%
Hardware/device path:       ~5%  -> ~5%
```

---

## Updated module

```text
rust/cmc-core/src/capu/decision_codes.rs
```

Now contains stable constants for:

```text
p1::*
p2::*
p3::*
p6::*
```

---

## Updated units

```text
rust/cmc-core/src/capu/persona_memory_unit.rs
rust/cmc-core/src/capu/commit_unit.rs
```

---

## Preserved output strings

P1 strings remain:

```text
ACCEPT_PERSONA_MEMORY_WITH_CAUSE
REJECT_PERSONA_MEMORY_WITHOUT_CAUSE
accepted_persona_memory_with_cause
blocked_persona_memory_without_cause
```

P6 strings remain:

```text
ACCEPT_COMMITTED_ACTION
REJECT_INVALID_COMMIT_CHECK_TARGET
REJECT_ACTION_WITHOUT_COMMIT
REJECT_ACTION_WITHOUT_CAUSE
accepted_committed_action
invalid_commit_check_target
blocked_action_without_commit
blocked_action_without_cause
```

---

## Why this matters

Before this PR, P1/P6 strings were duplicated directly inside unit code and tests. After this PR, all currently implemented invariant families have a central Rust source of truth:

```text
P1 persona-memory codes
P2 persona-state authorization codes
P3 introspection hypothesis-label codes
P6 external-action commit codes
```

This strengthens contract stability without changing runtime behavior or fixture semantics.

---

## Non-claims

This PR does not claim:

```text
public API versioning
complete runtime error taxonomy migration
stable SDK error model
hardware decision-code enforcement
```

It is a compatibility-safe internal contract hardening step.

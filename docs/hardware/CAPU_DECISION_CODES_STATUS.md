# CaPU Decision Codes Status

Status: P62 software reference maintainability increment.

This note records the first central decision-code constants for CaPU software reference units.

Progress movement represented by this PR:

```text
Software reference processor: ~83% -> ~84%
Runtime sidecar/API:        ~95% -> ~95%
Hardware/device path:       ~5%  -> ~5%
```

---

## New module

```text
rust/cmc-core/src/capu/decision_codes.rs
```

Registered in:

```text
rust/cmc-core/src/capu/mod.rs
```

---

## Current centralized code families

```text
p2::*
p3::*
```

P2 covers:

```text
ACCEPT_PERSONA_STATE_CHANGE_WITH_AUTHORIZATION
REJECT_PERSONA_STATE_CHANGE_WITH_DENIED_AUTHORIZATION
REJECT_PERSONA_STATE_CHANGE_WITHOUT_AUTHORIZATION
```

P3 covers:

```text
ACCEPT_INTROSPECTION_WITH_HYPOTHESIS_LABEL
REJECT_INTROSPECTION_WITHOUT_HYPOTHESIS_LABEL
```

---

## Why this matters

Before this PR, P2/P3 decision codes and verdict strings were repeated directly inside the units and tests. After this PR, those strings have one central source inside the Rust module tree.

This helps preserve decision-code stability for:

```text
reviewers
fixtures
future contributors
downstream adapters
future docs and manifests
```

---

## Scope intentionally kept narrow

This PR centralizes only P2/P3 because they are recent code paths and not yet tied to saved runtime fixtures. P1/P6 can be migrated in later compatibility-safe PRs.

---

## Non-claims

This PR does not claim:

```text
complete error taxonomy migration
complete P1/P6 decision code migration
public API versioning
production SDK error model
```

It is a small maintainability step for stable software-reference decision semantics.

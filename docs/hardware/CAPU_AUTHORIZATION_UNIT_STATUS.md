# CaPU Authorization Unit Status

Status: P57 software reference processor increment.

This note records the authorization unit added for persona-state transition legitimacy.

Progress movement represented by this PR:

```text
Software reference processor: ~72% -> ~76%
Runtime sidecar/API:        ~95% -> ~95%
Hardware/device path:       ~5%  -> ~5%
```

---

## New unit

```text
rust/cmc-core/src/capu/authorization_unit.rs
```

Registered in:

```text
rust/cmc-core/src/capu/mod.rs
```

Routed through:

```text
rust/cmc-core/src/capu/decision_unit.rs
```

---

## Implemented boundary

```text
Boundary::PersonaStateChangeRequiresAuthorization
```

Transition type:

```text
TransitionType::PersonaStateChange
```

Invariant marker:

```text
P2
```

---

## Current outcomes

```text
authorization=true
 -> ACCEPT_PERSONA_STATE_CHANGE_WITH_AUTHORIZATION
 -> accepted_persona_state_change_with_authorization

authorization=false
 -> REJECT_PERSONA_STATE_CHANGE_WITH_DENIED_AUTHORIZATION
 -> blocked_persona_state_change_denied_authorization

authorization=None
 -> REJECT_PERSONA_STATE_CHANGE_WITHOUT_AUTHORIZATION
 -> blocked_persona_state_change_without_authorization
```

---

## Why this matters

Before this PR, persona-state changes were only represented as an unimplemented boundary. After this PR, CaPU has a dedicated software reference unit for one more legitimacy class:

```text
P1 persona-memory writes require cause
P2 persona-state changes require authorization
P6 external actions require commit
```

This strengthens the core processor track without changing the runtime HTTP API.

---

## Non-claims

This PR does not claim:

```text
complete authorization policy language
role-based access control
production identity/authentication
runtime HTTP endpoint for persona-state changes
hardware authorization enforcement
```

It is a narrow software reference unit with direct decision-unit coverage.

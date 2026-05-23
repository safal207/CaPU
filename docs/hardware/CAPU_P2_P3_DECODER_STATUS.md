# CaPU P2/P3 Typed Decoder Status

Status: P60 software reference processor increment.

This note records typed decoder request paths for P2 persona-state changes and P3 introspection.

Progress movement represented by this PR:

```text
Software reference processor: ~80% -> ~83%
Runtime sidecar/API:        ~95% -> ~95%
Hardware/device path:       ~5%  -> ~5%
```

---

## New module

```text
rust/cmc-core/src/capu/p2_p3_decoder.rs
```

Registered in:

```text
rust/cmc-core/src/capu/mod.rs
```

---

## New typed requests

```text
PersonaStateChangeRequest
IntrospectionRequest
```

---

## New decoder paths

```text
PersonaStateChangeRequest
 -> decode_persona_state_change
 -> TransitionType::PersonaStateChange
 -> Boundary::PersonaStateChangeRequiresAuthorization
 -> decide_transition
 -> P2 authorization unit
```

```text
IntrospectionRequest
 -> decode_introspection
 -> TransitionType::Introspection
 -> Boundary::IntrospectionRequiresHypothesisLabel
 -> decide_transition
 -> P3 hypothesis unit
```

---

## Why this matters

Before this PR, P2/P3 legitimacy units existed, but tests mainly constructed generic `Transition` values directly. After this PR, P2/P3 have typed request envelopes that prove the path:

```text
request -> decode -> route boundary -> decision unit -> ACCEPT/REJECT
```

This closes a software-reference gap without changing the runtime HTTP API.

---

## Non-claims

This PR does not claim:

```text
runtime HTTP P2/P3 endpoints
production persona-state authorization model
complete hypothesis model
route-specific JSON schemas
stable public SDK support for P2/P3
```

It is a typed software reference decoder layer for P2/P3.

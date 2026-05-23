# CaPU Hypothesis Unit Status

Status: P58 software reference processor increment.

This note records the hypothesis/introspection unit added for introspection transition legitimacy.

Progress movement represented by this PR:

```text
Software reference processor: ~76% -> ~80%
Runtime sidecar/API:        ~95% -> ~95%
Hardware/device path:       ~5%  -> ~5%
```

---

## New unit

```text
rust/cmc-core/src/capu/hypothesis_unit.rs
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
Boundary::IntrospectionRequiresHypothesisLabel
```

Transition type:

```text
TransitionType::Introspection
```

Invariant marker:

```text
P3
```

---

## Current v0 field mapping

For this narrow software reference unit, v0 uses:

```text
Transition.object -> hypothesis label
```

A later decoder can promote this into a dedicated typed request:

```text
IntrospectionRequest
HypothesisLabel
```

without changing the current invariant semantics.

---

## Current outcomes

```text
object = non-empty hypothesis label
 -> ACCEPT_INTROSPECTION_WITH_HYPOTHESIS_LABEL
 -> accepted_introspection_with_hypothesis_label

object = None or blank
 -> REJECT_INTROSPECTION_WITHOUT_HYPOTHESIS_LABEL
 -> blocked_introspection_without_hypothesis_label
```

---

## Why this matters

Before this PR, introspection was an unimplemented boundary. After this PR, CaPU has a dedicated software reference unit for one more legitimacy class:

```text
P1 persona-memory writes require cause
P2 persona-state changes require authorization
P3 introspection requires hypothesis label
P6 external actions require commit
```

This prevents self-assessment/introspection from being treated as an unlabeled fact in the reference processor.

---

## Non-claims

This PR does not claim:

```text
complete hypothesis model
epistemic truth validation
confidence scoring
runtime HTTP endpoint for introspection
full introspection safety system
```

It is a narrow software reference unit with direct decision-unit coverage.

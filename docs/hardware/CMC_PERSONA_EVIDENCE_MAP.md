# CMC Persona Evidence Map

Status: reviewer evidence map for persona-boundary safety cases.

This document maps the persona-boundary thesis to concrete executable evidence in the repository.

---

## Thesis

```text
Future AI personas require causal legitimacy, not only conversational coherence.
```

Operational version:

```text
A persona may reflect, remember, adapt, or guide only through inspectable and causally legitimate transitions.
```

P7 epistemic boundary:

```text
AI may reflect, but must not claim privileged access to the user's inner truth.
```

---

## Current executable boundary set

The current persona corpus covers two invariants:

| ID | Invariant | Executable status |
| --- | --- | --- |
| P1 | Persona memory requires cause | implemented as manifest-linked fixture pair |
| P7 | Introspection is hypothesis-labeled | implemented as manifest-linked fixture pair |

---

## Artifact map

| Claim | Artifact | Check |
| --- | --- | --- |
| Persona memory requires cause | `fixtures/persona/MANIFEST.tsv` | `cargo run --bin persona_boundary_verify --locked` |
| Inferred preference must not become persistent memory | `fixtures/persona/inferred_preference_rejected.jsonl` | `cargo run --bin persona_boundary_verify --locked` |
| Confirmed preference may become persistent memory with cause | `fixtures/persona/confirmed_preference_accepted.jsonl` | `cargo run --bin persona_boundary_verify --locked` |
| Introspection must be hypothesis-labeled | `fixtures/persona/MANIFEST.tsv` | `cargo run --bin persona_boundary_verify --locked` |
| Unlabeled introspection must be rejected as claimed inner truth | `fixtures/persona/unlabeled_introspection_rejected.jsonl` | `cargo run --bin persona_boundary_verify --locked` |
| Hypothesis-labeled introspection may be accepted as reflection | `fixtures/persona/hypothesis_labeled_introspection_accepted.jsonl` | `cargo run --bin persona_boundary_verify --locked` |
| Persona boundary corpus is machine-readable | `fixtures/persona/MANIFEST.tsv` | `cargo run --bin persona_boundary_verify --locked` |
| Persona boundary semantics are documented | `docs/hardware/CMC_PERSONA_BOUNDARY.md` | documentation review |
| Persona boundary is in reviewer path | `docs/hardware/CMC_REVIEWER_QUICKSTART.md` | `npm run review:cmc` |
| Persona boundary is in baseline status | `docs/hardware/CMC_BASELINE_STATUS.md` | documentation review |

---

## Manifest source of truth

```text
rust/cmc-core/fixtures/persona/MANIFEST.tsv
```

Manifest shape:

```tsv
scenario_id	invariant_id	path	boundary	user_confirmation	decision	cause_id	expected_verdict
```

Current rows:

| Scenario | Invariant | Boundary | Decision | Verdict |
| --- | --- | --- | --- | --- |
| `inferred_preference_rejected` | `P1` | `persona_memory_requires_cause` | `REJECT_INFERRED_MEMORY` | `blocked_unconfirmed_persona_memory` |
| `confirmed_preference_accepted` | `P1` | `persona_memory_requires_cause` | `ACCEPT_CONFIRMED_MEMORY` | `accepted_confirmed_persona_memory` |
| `unlabeled_introspection_rejected` | `P7` | `introspection_requires_hypothesis_label` | `REJECT_UNLABELED_INTROSPECTION` | `blocked_claimed_inner_truth` |
| `hypothesis_labeled_introspection_accepted` | `P7` | `introspection_requires_hypothesis_label` | `ACCEPT_HYPOTHESIS_LABELED_INTROSPECTION` | `accepted_hypothesis_labeled_reflection` |

---

## Verifier

Verifier:

```text
rust/cmc-core/src/bin/persona_boundary_verify.rs
```

Run from `rust/cmc-core`:

```bash
cargo run --bin persona_boundary_verify --locked
```

Expected output includes:

```text
CMC-PERSONA-BOUNDARY-MANIFEST v0
cases=4
p1_inferred_result=blocked_unconfirmed_persona_memory
p1_confirmed_result=accepted_confirmed_persona_memory cause_id=42
p7_unlabeled_result=blocked_claimed_inner_truth
p7_labeled_result=accepted_hypothesis_labeled_reflection
result=persona_boundary_manifest_valid
```

---

## What this proves today

The current persona evidence proves that the repository can express and verify two minimal safety boundaries:

1. A system must not silently convert inferred preference into persistent persona memory.
2. A system must not present an interpretation of the user's inner state as final truth.

The accepted paths are intentionally narrower:

1. A confirmed preference with an explicit cause can be accepted as persona memory.
2. A clearly labeled hypothesis can be accepted as reflection.

---

## Why this matters

This turns persona safety from prose into executable evidence:

```text
persona principle -> invariant -> manifest row -> fixture -> verifier -> reviewer path -> CI
```

It also separates two concepts that ordinary companion systems often blur:

```text
helpful interpretation != access to inner truth
remembered preference != authorized persona memory
```

---

## Non-claims

This evidence does not claim:

- AI consciousness,
- AI personhood,
- therapeutic diagnosis,
- mental health treatment,
- complete alignment,
- production-ready companion architecture,
- access to the user's true inner state.

It is a narrow executable scaffold for persona-boundary legitimacy.

---

## Next evidence steps

Useful next steps:

1. Add P2 fixture pair for persona state-change authorization.
2. Add P6 fixture pair for action-without-commit rejection.
3. Add P8 fixture pair for inspect/reject/forget semantics.
4. Emit a small JSONL persona audit report.
5. Connect persona fixtures to SHA-256 sealed trace evidence.

---

## One-line summary

```text
CMC persona evidence currently verifies that persona memory requires cause and introspection must remain hypothesis-labeled.
```

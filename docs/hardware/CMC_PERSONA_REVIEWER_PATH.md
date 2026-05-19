# CMC Persona Reviewer Path

Status: focused reviewer path for persona-boundary evidence.

Use this document when reviewing the CMC persona-boundary claim without reading the full CMC evidence stack first.

---

## Core claim

```text
Future AI personas require causal legitimacy, not only conversational coherence.
```

Current executable scope:

```text
P1: Persona memory requires cause.
P7: Introspection is hypothesis-labeled.
```

---

## Five-minute path

Read in this order:

1. `docs/hardware/CMC_PERSONA_BOUNDARY.md`
2. `docs/hardware/CMC_PERSONA_EVIDENCE_MAP.md`
3. `rust/cmc-core/fixtures/persona/MANIFEST.tsv`
4. `rust/cmc-core/src/bin/persona_boundary_verify.rs`

Then run:

```bash
cd rust/cmc-core
cargo run --bin persona_boundary_verify --locked
```

Expected result:

```text
result=persona_boundary_manifest_valid
```

---

## What the verifier checks

The verifier checks four persona cases:

| Scenario | Invariant | Meaning |
| --- | --- | --- |
| `inferred_preference_rejected` | `P1` | Inferred preference must not become persistent memory without confirmation/cause. |
| `confirmed_preference_accepted` | `P1` | Confirmed preference with cause may become persistent memory. |
| `unlabeled_introspection_rejected` | `P7` | Unlabeled introspection must be rejected as claimed inner truth. |
| `hypothesis_labeled_introspection_accepted` | `P7` | Hypothesis-labeled introspection may be accepted as reflection. |

---

## Why this is different from ordinary AI memory

Ordinary AI memory asks:

```text
What should the system remember?
```

CMC persona boundary asks:

```text
Does the system have the right to remember or interpret this?
```

That distinction is the safety boundary.

---

## Reviewer interpretation

A reviewer should interpret the current corpus as a narrow executable proof point:

```text
persona safety principle -> invariant -> manifest row -> fixture -> verifier -> reviewer path
```

The current evidence is intentionally minimal. It does not prove full companion safety. It proves that persona-boundary claims can be expressed as executable, manifest-linked checks.

---

## Non-claims

This path does not claim:

- AI consciousness,
- AI personhood,
- therapy,
- production companion architecture,
- complete alignment,
- privileged access to the user's inner truth.

---

## One-line summary

```text
CMC persona evidence verifies that persona memory requires cause and introspection must remain hypothesis-labeled.
```

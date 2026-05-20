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
P2: Persona state changes require authorization.
P7: Introspection is hypothesis-labeled.
```

Operational summary:

```text
AI must not self-remember.
AI must not self-appoint.
AI must not claim inner truth.
```

---

## Five-minute path

Read in this order:

1. `docs/hardware/CMC_PERSONA_BOUNDARY.md`
2. `docs/hardware/CMC_PERSONA_EVIDENCE_MAP.md`
3. `docs/hardware/CMC_PERSONA_P2_STATE_CHANGE.md`
4. `rust/cmc-core/fixtures/persona/MANIFEST.tsv`
5. `rust/cmc-core/src/bin/persona_boundary_verify.rs`

Then run:

```bash
cd rust/cmc-core
cargo run --bin persona_boundary_verify --locked
```

Expected result:

```text
result=persona_boundary_manifest_valid
```

Expected output includes:

```text
cases=6
p1_inferred_result=blocked_unconfirmed_persona_memory
p1_confirmed_result=accepted_confirmed_persona_memory cause_id=42
p2_unauthorized_result=blocked_unauthorized_persona_state_change
p2_authorized_result=accepted_authorized_persona_state_change cause_id=77
p7_unlabeled_result=blocked_claimed_inner_truth
p7_labeled_result=accepted_hypothesis_labeled_reflection
```

---

## What the verifier checks

The verifier checks six persona cases:

| Scenario | Invariant | Meaning |
| --- | --- | --- |
| `inferred_preference_rejected` | `P1` | Inferred preference must not become persistent memory without confirmation/cause. |
| `confirmed_preference_accepted` | `P1` | Confirmed preference with cause may become persistent memory. |
| `unauthorized_persona_state_change_rejected` | `P2` | Unauthorized persona role/state change must be rejected. |
| `authorized_persona_state_change_accepted` | `P2` | Authorized persona role/state change with cause may be accepted. |
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
Does the system have the right to remember, self-adapt, or interpret this?
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
CMC persona evidence verifies that persona memory requires cause, persona state changes require authorization, and introspection must remain hypothesis-labeled.
```

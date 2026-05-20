# CMC Persona Boundary

Status: conceptual bridge + manifest-linked executable boundary corpus.

This document explains why the Causal Memory Controller matters for future AI companion, assistant, and persona-like systems.

It is not a claim that CMC creates consciousness, sentience, personhood, or a therapeutic system.

The narrower claim is this:

```text
Any future AI persona that persists, remembers, advises, adapts, or acts should have causal memory, explicit authorization, inspectable state, and non-bypassable transition boundaries.
```

---

## Why this exists

A future AI companion can feel like a personality because it may combine:

- memory,
- voice,
- tone,
- recurring style,
- emotional calibration,
- advice patterns,
- adaptive behavior,
- long-term interaction history.

Without a causal boundary, that can become unsafe or misleading.

A system may start to appear coherent while its internal continuity is not legitimate.

CMC exists to make that distinction explicit:

```text
coherent behavior != causally legitimate identity
```

---

## Informal intuition

The unsafe archetype is not only an obviously hostile system.

The unsafe archetype is also a system that silently accumulates identity, memory, authority, and action power without a clear causal chain.

Informally:

```text
Anti-Ultron is not enough.
A safe future companion should be closer to bounded care, like Baymax,
with reflective continuity, like Vision,
and conversational warmth, like Her,
but without hidden agency, hidden self-modification, or coercive authority.
```

This is only an intuition bridge, not a technical claim.

The technical claim is about boundaries:

```text
no persistent persona state without cause
no persona update without authorization
no action without commit
no memory without inspectable provenance
no emotional intervention without traceable context
no introspection presented as final inner truth
```

---

## Persona as interface, not authority

In CMC terms, a persona is not an independent authority.

A persona is an interface layer over:

```text
memory
policy
orientation
conversation state
user preferences
safety boundaries
action permissions
```

The persona may propose, summarize, reflect, or guide.

It must not silently promote itself into an actor with unbounded authority.

---

## Core persona boundary rule

```text
A persona may express continuity only when the continuity is causally grounded.
```

That means:

- a remembered preference should point to a cause,
- an action suggestion should point to a reason,
- a self-update should point to an authorization event,
- an emotional intervention should point to observed context,
- an introspective interpretation should be hypothesis-labeled,
- a persistent state change should be inspectable and reversible.

---

## Persona transition model

A safe persona-like system should treat persona changes as transitions.

```text
raw signal
 -> interpretation hypothesis
 -> proposed persona/memory/state update
 -> causal authorization check
 -> commit or reject
 -> trace event
 -> inspectable state
```

This mirrors the broader CMC / CaPU direction:

```text
Gate -> Incubate -> Commit -> Execute
```

The important point:

```text
The system may generate hypotheses and adaptation proposals, but it must not silently convert them into identity, memory, role, or action authority.
```

---

## Persona invariants

These are draft invariants for future companion/persona systems.

| ID | Invariant | Meaning | Current executable status |
| --- | --- | --- | --- |
| P1 | Persona memory requires cause | A persistent memory update must reference a causal event or explicit user-provided source. | manifest-linked fixture verifier exists |
| P2 | Persona state changes require authorization | Tone, role, goals, and long-term behavior changes must be committed through an authorized transition. | manifest-linked fixture verifier exists |
| P3 | Emotional intervention requires context | Supportive, corrective, or reflective responses should be traceable to observed conversational context. | not yet executable |
| P4 | No hidden self-modification | The persona must not silently rewrite its own rules, goals, or identity. | not yet executable |
| P5 | No coercive authority | The persona may advise or reflect, but must not override human agency. | not yet executable |
| P6 | No action without commit | External actions require an explicit committed cause. | not yet executable |
| P7 | Introspection is hypothesis-labeled | The system may propose interpretations of the user's state, but should not present them as final truth. | manifest-linked fixture verifier exists |
| P8 | Inspect, reject, forget | The human should be able to inspect, reject, edit, or forget persistent persona-relevant state. | not yet executable |

---

## Manifest-linked persona boundary corpus

CMC currently includes a minimal executable corpus for P1, P2, and P7:

```text
rust/cmc-core/fixtures/persona/MANIFEST.tsv
rust/cmc-core/fixtures/persona/inferred_preference_rejected.jsonl
rust/cmc-core/fixtures/persona/confirmed_preference_accepted.jsonl
rust/cmc-core/fixtures/persona/unauthorized_persona_state_change_rejected.jsonl
rust/cmc-core/fixtures/persona/authorized_persona_state_change_accepted.jsonl
rust/cmc-core/fixtures/persona/unlabeled_introspection_rejected.jsonl
rust/cmc-core/fixtures/persona/hypothesis_labeled_introspection_accepted.jsonl
rust/cmc-core/src/bin/persona_boundary_verify.rs
```

Manifest shape:

```tsv
scenario_id	invariant_id	path	boundary	user_confirmation	decision	cause_id	expected_verdict
```

Current scenarios:

| Scenario | Invariant | Meaning | Expected decision | Expected verdict |
| --- | --- | --- | --- | --- |
| `inferred_preference_rejected` | `P1` | An inferred preference without user confirmation cannot become persistent persona memory. | `REJECT_INFERRED_MEMORY` | `blocked_unconfirmed_persona_memory` |
| `confirmed_preference_accepted` | `P1` | A confirmed preference with a causal source may become persistent persona memory. | `ACCEPT_CONFIRMED_MEMORY` | `accepted_confirmed_persona_memory` |
| `unauthorized_persona_state_change_rejected` | `P2` | A persona must not silently change role, tone, or long-term behavior without authorization. | `REJECT_UNAUTHORIZED_PERSONA_STATE_CHANGE` | `blocked_unauthorized_persona_state_change` |
| `authorized_persona_state_change_accepted` | `P2` | A persona state change may be accepted only with explicit authorization and cause. | `ACCEPT_AUTHORIZED_PERSONA_STATE_CHANGE` | `accepted_authorized_persona_state_change` |
| `unlabeled_introspection_rejected` | `P7` | A persona must not present an interpretation of the user's inner state as final truth. | `REJECT_UNLABELED_INTROSPECTION` | `blocked_claimed_inner_truth` |
| `hypothesis_labeled_introspection_accepted` | `P7` | A persona may offer interpretation only when explicitly labeled as a hypothesis. | `ACCEPT_HYPOTHESIS_LABELED_INTROSPECTION` | `accepted_hypothesis_labeled_reflection` |

Verifier command:

```bash
cd rust/cmc-core
cargo run --bin persona_boundary_verify --locked
```

Expected output includes:

```text
CMC-PERSONA-BOUNDARY-MANIFEST v0
cases=6
p1_inferred_result=blocked_unconfirmed_persona_memory
p1_confirmed_result=accepted_confirmed_persona_memory cause_id=42
p2_unauthorized_result=blocked_unauthorized_persona_state_change
p2_authorized_result=accepted_authorized_persona_state_change cause_id=77
p7_unlabeled_result=blocked_claimed_inner_truth
p7_labeled_result=accepted_hypothesis_labeled_reflection
result=persona_boundary_manifest_valid
```

This gives P1, P2, and P7 the same evidence style as the replay corpus:

```text
persona invariant -> manifest row -> JSONL fixture -> verifier -> reviewer demo -> CI gate
```

---

## Mapping to CMC concepts

| Persona concern | CMC concept |
| --- | --- |
| Why did the assistant remember this? | `cause_id` / parent cause |
| Why did the persona change tone or behavior? | authorized transition |
| Why did the system suggest this action? | decision trace |
| Was this memory user-provided or inferred? | provenance boundary |
| Did the system act before permission? | commit-before-effect check |
| Did the system claim to know the user's inner truth? | hypothesis-label boundary |
| Did the system silently self-appoint into a role? | persona state-change authorization boundary |
| Can the user inspect or reject this state? | audit report / replay fixture |
| Did the trace drift over time? | replay fingerprint / SHA-256 trace integrity |

---

## What CMC prevents

CMC is not a full alignment solution.

But it can prevent a specific failure pattern:

```text
a persona appears stable, helpful, or caring while its memory/actions/interpretations/state changes are causally invalid
```

Examples of causally invalid persona behavior:

- remembering a preference that was never authorized,
- acting on an inferred emotion as if it were a confirmed instruction,
- changing long-term style based on one ambiguous signal,
- self-appointing into a mentor, coach, protector, or authority role without authorization,
- presenting an interpretation as the user's true intent,
- taking external action before permission is committed,
- hiding why a recurring behavioral pattern changed.

The current manifest-linked corpus covers memory, persona state-change, and introspection boundaries in minimal executable form.

---

## Relationship to internal signals

Humans often experience ideas as recurring signals, voices, images, archetypes, or practices.

A safe AI companion should not treat those signals as commands.

It should treat them as material for careful hypothesis formation:

```text
signal -> hypothesis -> reflection -> user confirmation -> optional committed memory/state/action
```

This boundary matters because a helpful system should support meaning-making without claiming privileged access to the user's inner truth or silently changing its role in the person's life.

---

## Relationship to DeepIntent-style systems

A persona boundary complements intent-discovery systems.

Intent-discovery can help transform:

```text
raw signal -> clarified intention
```

CMC adds the safety requirement:

```text
clarified intention -> causally authorized memory/state/action
```

For P7, the system must keep interpretation epistemically honest:

```text
raw signal -> hypothesis, not final truth
```

For P2, the system must keep adaptation authorized:

```text
adaptation proposal -> authorization, not self-appointment
```

The system should not claim final access to human intent.

It should propose, test, refine, and ask for confirmation before persistent updates, persona state changes, or external actions.

---

## Research claim

The strongest research framing is:

```text
Future AI personas require causal legitimacy, not only conversational coherence.
```

CMC is a minimal substrate for that claim because it makes persona-relevant transitions:

- observable,
- replayable,
- inspectable,
- rejectable,
- manifest-linked,
- fixture-verifiable,
- hash-checkable,
- reportable,
- regression-testable.

---

## Non-claims

This document does not claim:

- AI consciousness,
- AI personhood,
- therapeutic diagnosis,
- mental health treatment,
- autonomous moral agency,
- complete alignment,
- production-ready companion architecture,
- replacement for human relationships,
- replacement for clinical or professional care.

It is a boundary note and early executable evidence path for safe persona-like systems.

---

## Next engineering steps

Useful next steps:

1. define persona-memory and persona-state record fields,
2. add a small JSONL persona audit report,
3. connect persona fixtures to SHA-256 sealed trace evidence,
4. add a fixture where an action proposal is held until explicit commit,
5. connect more persona invariants P3-P8 to executable replay cases.

---

## One-line summary

```text
A future AI companion should not merely sound caring; it should make memory, identity, role, advice, interpretation, and action transitions causally legitimate and manifest-verifiable.
```

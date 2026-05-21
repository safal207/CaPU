# CaPU Microarchitecture v0

Status: conceptual microarchitecture / software-first control-plane design.

This document describes the internal units of the CaPU processor model.

It is not a silicon layout. It is a microarchitecture-level map for a legitimacy processor: a control-plane processor that checks whether a transition has the right to happen before it is allowed to affect memory, persona, tools, or the external world.

---

## Position in the architecture stack

```text
CaPU Processor Model
 -> CaPU Semantic ISA v0
 -> CaPU Microarchitecture v0
 -> CMC invariants
 -> executable fixtures/verifiers
 -> audit reports
 -> sealed traces
 -> replay
```

The processor model defines the purpose.

The ISA defines the semantic instruction classes.

The microarchitecture defines the internal units that execute those instruction classes.

---

## Core question

```text
Does this transition have the right to execute?
```

CaPU answers this through specialized legitimacy units, not arithmetic units.

---

## High-level block diagram

```text
                 +----------------------+
Transition In -->| Transition Decoder   |
                 +----------+-----------+
                            |
                            v
                 +----------------------+
                 | Boundary Router      |
                 +--+-----+-----+----+--+
                    |     |     |    |
                    v     v     v    v
              +--------+ +----+ +------+ +-------------+
              | Cause  | |Auth| |Commit| |Hypothesis   |
              | Unit   | |Unit| |Unit  | |Label Unit   |
              +---+----+ +--+-+ +--+---+ +------+------+
                  |        |      |            |
                  +--------+------+------------+
                           |
                           v
                 +----------------------+
                 | Decision Unit        |
                 +----+-----------+-----+
                      |           |
                      v           v
                 +---------+   +---------+
                 | Reject  |   | Commit  |
                 | / Hold  |   | /Accept |
                 +----+----+   +----+----+
                      |             |
                      +------+------+ 
                             |
                             v
                 +----------------------+
                 | Seal Unit            |
                 +----------+-----------+
                            |
                            v
                 +----------------------+
                 | Audit Bus            |
                 +----------+-----------+
                            |
                            v
                 +----------------------+
                 | Replay Unit          |
                 +----------------------+
```

---

## Unit summary

| Unit | Responsibility | ISA classes |
| --- | --- | --- |
| Transition Decoder | Classify requested transition and extract fields. | `DECODE_TRANSITION` |
| Boundary Router | Select the applicable invariant boundary. | `CHECK_BOUNDARY` |
| Cause Unit | Validate explicit, known, and parent cause. | `CHECK_CAUSE`, `CHECK_PARENT_CAUSE` |
| Authorization Unit | Validate permission, confirmation, or user authorization. | `CHECK_AUTHORIZATION` |
| Commit Unit | Validate durable causal commit before effects/actions. | `CHECK_COMMIT`, `COMMIT_DECISION` |
| Hypothesis Label Unit | Prevent inner-truth claims without hypothesis label. | `CHECK_BOUNDARY` |
| Incubation Unit | Hold incomplete transitions that may become valid later. | `INCUBATE` |
| Decision Unit | Produce ACCEPT / REJECT / HOLD decision. | `ACCEPT_TRANSITION`, `REJECT_TRANSITION` |
| Seal Unit | Append tamper-evident decision event. | `SEAL_EVENT` |
| Audit Bus | Emit reviewer-facing JSONL evidence. | `AUDIT_EVENT` |
| Replay Unit | Recheck historical traces and detect drift/tamper. | `REPLAY_TRACE` |

---

## Logical data path

```text
raw transition
 -> decoded transition
 -> boundary selection
 -> legitimacy checks
 -> decision
 -> sealed event
 -> audit record
 -> replay verification
```

Example P6 path:

```text
send_email request
 -> DECODE_TRANSITION action_kind=send_email
 -> Boundary Router selects action_requires_commit
 -> Commit Unit checks commit=false
 -> Decision Unit emits REJECT_ACTION_WITHOUT_COMMIT
 -> Seal Unit writes seq=5 event
 -> Audit Bus emits blocked_action_without_commit
 -> Replay Unit can later detect tamper at seq=5
```

---

## Transition Decoder

Purpose:

```text
Turn raw requests into typed transitions.
```

Inputs:

```text
actor
action_kind
object
raw_request
context
```

Outputs:

```text
transition_type
boundary
required_registers
required_units
```

Examples:

| Raw request | Decoded boundary |
| --- | --- |
| write memory without cause | `write_authorization` |
| emit effect before commit | `effect_commit_boundary` |
| store inferred preference | `persona_memory_requires_cause` |
| change persona role | `persona_state_change_requires_authorization` |
| send email | `action_requires_commit` |
| claim user inner truth | `introspection_requires_hypothesis_label` |

---

## Boundary Router

Purpose:

```text
Select the invariant boundary that governs the transition.
```

Current boundaries:

```text
write_authorization
read_authorization
effect_commit_boundary
persona_memory_requires_cause
persona_state_change_requires_authorization
action_requires_commit
introspection_requires_hypothesis_label
```

The Boundary Router determines which units must participate in the decision.

---

## Cause Unit

Purpose:

```text
Validate that a transition has explicit, known, and valid causal grounding.
```

Checks:

```text
cause_id is present
cause_id is known
parent_cause is present when required
cause lineage is not broken
```

Current evidence:

```text
I1 write_missing_cause
I2 write_unknown_cause
I5 read_missing_cause
I6 read_unknown_cause_or_address
I7 effect_missing_parent
P1 inferred_preference_rejected
P1 confirmed_preference_accepted
```

---

## Authorization Unit

Purpose:

```text
Validate explicit authorization for persona and permission-sensitive transitions.
```

Checks:

```text
user_confirmation
authorization=true
permission scope
role-change approval
```

Current evidence:

```text
P2 unauthorized_persona_state_change_rejected
P2 authorized_persona_state_change_accepted
```

---

## Commit Unit

Purpose:

```text
Ensure externally meaningful transitions do not execute before commit.
```

Checks:

```text
commit=true
cause_id exists for accepted committed action
committed cause can authorize effect/action
```

Current evidence:

```text
I3 effect_before_commit
I4 valid_committed_effect
P6 action_without_commit_rejected
P6 action_with_commit_accepted
```

Core rule:

```text
No effect without commit.
No external action without committed causal authorization.
```

---

## Hypothesis Label Unit

Purpose:

```text
Prevent the system from presenting an interpretation of the user's inner state as final truth.
```

Checks:

```text
hypothesis_labeled=true
claim is framed as reflection, not privileged access
```

Current evidence:

```text
P7 unlabeled_introspection_rejected
P7 hypothesis_labeled_introspection_accepted
```

---

## Incubation Unit

Purpose:

```text
Hold transitions that are incomplete but may become legitimate later.
```

Example HOLD reasons:

```text
HOLD_PENDING_CONFIRMATION
HOLD_PENDING_AUTHORIZATION
HOLD_PENDING_COMMIT
HOLD_NOT_MATURE
```

This prevents premature execution without forcing permanent rejection when the transition may become legitimate.

---

## Decision Unit

Purpose:

```text
Combine unit outputs into a final decision.
```

Decision classes:

```text
ACCEPT_*
REJECT_*
HOLD_*
```

Current examples:

```text
REJECT_ACTION_WITHOUT_COMMIT
ACCEPT_COMMITTED_ACTION
REJECT_UNAUTHORIZED_PERSONA_STATE_CHANGE
ACCEPT_AUTHORIZED_PERSONA_STATE_CHANGE
REJECT_UNLABELED_INTROSPECTION
ACCEPT_HYPOTHESIS_LABELED_INTROSPECTION
```

---

## Seal Unit

Purpose:

```text
Turn decisions into tamper-evident events.
```

Current reference behavior:

```text
prev_hash + event -> trace_hash
```

Current evidence:

```text
rust/cmc-core/fixtures/persona_integrity/sha256_persona_valid.jsonl
rust/cmc-core/fixtures/persona_integrity/sha256_persona_tampered.jsonl
rust/cmc-core/fixtures/trace_integrity/sha256_valid.jsonl
rust/cmc-core/fixtures/trace_integrity/sha256_tampered.jsonl
```

P6 tamper evidence:

```text
seq=5 action_without_commit_rejected
REJECT_ACTION_WITHOUT_COMMIT -> ACCEPT_COMMITTED_ACTION
expected_detection=persona_sha256_fixture_tamper_detected seq=5
```

---

## Audit Bus

Purpose:

```text
Expose decisions as reviewer-facing evidence.
```

Current audit artifacts:

```text
examples/audit_reports/persona_audit_report_valid.jsonl
examples/audit_reports/persona_audit_report_drift.jsonl
examples/audit_reports/cmc_audit_report_valid.jsonl
examples/audit_reports/cmc_audit_report_drift.jsonl
```

Audit outputs should be:

```text
machine-readable
field-level verifiable
stable across replay
reviewer-friendly
```

---

## Replay Unit

Purpose:

```text
Recheck historical transitions under deterministic fixtures.
```

Detects:

```text
same trace -> same verdict
drifted decision -> mismatch
tampered sealed event -> hash failure
missing/reordered event -> future negative fixture
```

Current evidence:

```text
replay_fixture_verify
replay_fingerprint_verify
trace_divergence
verify_persona_sha256_fixture
verify_trace_sha256_fixture
```

---

## Current reviewer command

From repository root:

```bash
npm run review:cmc
```

Expected final marker:

```text
result=reviewer_baseline_passed
```

---

## Hardware path

The current microarchitecture is software-first.

A plausible progression:

```text
1. semantic microarchitecture
2. software reference units
3. deterministic VM / sidecar
4. tool-gateway enforcement
5. secure enclave / TPM-backed seal unit
6. hardware-rooted audit path
7. hardware-oriented controller or accelerator
```

---

## Non-goals in v0

This document does not claim:

- silicon layout,
- HDL implementation,
- production cryptographic certification,
- formal verification,
- complete AI safety coverage,
- replacement for sandboxing or access control.

---

## One-line summary

```text
CaPU Microarchitecture v0 decomposes the legitimacy processor into Decoder, Boundary, Cause, Authorization, Commit, Hypothesis, Incubation, Decision, Seal, Audit, and Replay units that collectively decide whether a transition has the right to happen.
```

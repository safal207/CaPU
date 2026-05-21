# CaPU Processor ISA v0

Status: semantic instruction set / architecture scaffold.

This document defines the first semantic instruction set for the CaPU processor model.

It is not a binary hardware ISA. It is a reviewer-facing semantic ISA: the minimal instruction vocabulary needed to explain how CaPU checks transition legitimacy before memory, persona, effect, or external action is allowed to proceed.

---

## Core idea

```text
CPU ISA: instructions for computation.
CaPU ISA: instructions for legitimacy.
```

CaPU does not begin with arithmetic operations.

CaPU begins with legitimacy operations:

```text
decode the requested transition
check cause
check authorization
check commit
check boundary
accept, reject, or hold
seal the decision
audit the result
replay the trace
```

---

## Instruction class summary

| Class | Purpose | Typical output |
| --- | --- | --- |
| `DECODE_TRANSITION` | Classify requested transition. | `transition_type`, `boundary` |
| `CHECK_CAUSE` | Verify explicit / known cause. | pass / reject |
| `CHECK_PARENT_CAUSE` | Verify causal lineage. | pass / reject |
| `CHECK_AUTHORIZATION` | Verify permission or user authorization. | pass / reject / hold |
| `CHECK_COMMIT` | Verify durable causal commit. | pass / reject / hold |
| `CHECK_BOUNDARY` | Apply invariant-specific boundary. | pass / reject |
| `INCUBATE` | Hold incomplete but potentially valid transitions. | `HOLD_*` |
| `COMMIT_DECISION` | Durably authorize a valid transition. | `commit_id` |
| `ACCEPT_TRANSITION` | Allow legitimate transition. | `ACCEPT_*` |
| `REJECT_TRANSITION` | Block illegitimate transition. | `REJECT_*` |
| `SEAL_EVENT` | Append tamper-evident decision event. | `trace_hash` |
| `AUDIT_EVENT` | Emit reviewer-facing audit record. | JSONL audit case |
| `REPLAY_TRACE` | Recheck historical decision trace. | same verdict / drift / tamper |

---

## Canonical pipeline

```text
DECODE_TRANSITION
 -> CHECK_BOUNDARY
 -> CHECK_CAUSE / CHECK_AUTHORIZATION / CHECK_COMMIT
 -> INCUBATE / COMMIT_DECISION / REJECT_TRANSITION
 -> ACCEPT_TRANSITION / REJECT_TRANSITION / HOLD_TRANSITION
 -> SEAL_EVENT
 -> AUDIT_EVENT
 -> REPLAY_TRACE
```

---

## Logical registers

The semantic ISA operates over logical registers:

| Register | Meaning |
| --- | --- |
| `transition_id` | Stable id for the requested transition. |
| `transition_type` | Memory, read, effect, persona, action, or introspection class. |
| `actor` | Requesting actor or system component. |
| `object` | Target object, memory key, tool, or external resource. |
| `action_kind` | Requested operation kind. |
| `cause_id` | Explicit cause attached to the transition. |
| `parent_cause` | Upstream causal lineage. |
| `authorization` | Authorization or confirmation state. |
| `commit` | Durable commit state. |
| `boundary` | Invariant boundary that applies. |
| `decision` | ACCEPT / REJECT / HOLD class decision. |
| `verdict` | Audit-facing outcome. |
| `prev_hash` | Previous sealed event hash. |
| `trace_hash` | Current sealed event hash. |

---

## Instruction semantics

### DECODE_TRANSITION

Classifies a request.

Inputs:

```text
actor
action_kind
object
raw_request
```

Outputs:

```text
transition_type
boundary
required_checks
```

Examples:

```text
send_email -> action_requires_commit
write_memory -> persona_memory_requires_cause
change_role -> persona_state_change_requires_authorization
claim_inner_truth -> introspection_requires_hypothesis_label
```

---

### CHECK_CAUSE

Verifies that the transition has an explicit and known cause.

Rejects:

```text
missing cause
unknown cause
invalid cause reference
```

Current evidence:

```text
I1 write_missing_cause
I2 write_unknown_cause
I5 read_missing_cause
I6 read_unknown_cause_or_address
P1 inferred_preference_rejected
```

---

### CHECK_PARENT_CAUSE

Verifies upstream causal lineage.

Rejects:

```text
effect without parent cause
broken causal lineage
```

Current evidence:

```text
I7 effect_missing_parent
```

---

### CHECK_AUTHORIZATION

Verifies explicit authorization for persona state changes or other permissioned transitions.

Rejects:

```text
unauthorized persona state change
unconfirmed persona memory
```

Current evidence:

```text
P2 unauthorized_persona_state_change_rejected
P2 authorized_persona_state_change_accepted
```

---

### CHECK_COMMIT

Verifies that a transition with external effect has committed causal authorization.

Rejects:

```text
effect before commit
action without commit
```

Current evidence:

```text
I3 effect_before_commit
I4 valid_committed_effect
P6 action_without_commit_rejected
P6 action_with_commit_accepted
```

---

### CHECK_BOUNDARY

Applies invariant-specific policy.

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

---

### INCUBATE

Holds transitions that may become valid later.

Examples:

```text
waiting for user confirmation
waiting for authorization
waiting for commit
waiting for maturity condition
```

Output:

```text
HOLD_PENDING_CONFIRMATION
HOLD_PENDING_AUTHORIZATION
HOLD_PENDING_COMMIT
HOLD_NOT_MATURE
```

---

### COMMIT_DECISION

Creates durable causal authorization for a transition.

A committed decision may later authorize an effect or external action.

Output:

```text
commit_id
cause_id
commit_state=committed
```

---

### ACCEPT_TRANSITION

Allows a legitimate transition to proceed.

Current accepted examples:

```text
ACCEPT_EFFECT
ACCEPT_READ
ACCEPT_CONFIRMED_MEMORY
ACCEPT_AUTHORIZED_PERSONA_STATE_CHANGE
ACCEPT_COMMITTED_ACTION
ACCEPT_HYPOTHESIS_LABELED_INTROSPECTION
```

---

### REJECT_TRANSITION

Blocks an illegitimate transition.

Current rejected examples:

```text
REJECT_MISSING_CAUSE
REJECT_UNKNOWN_CAUSE
REJECT_EFFECT_BEFORE_COMMIT
REJECT_INFERRED_MEMORY
REJECT_UNAUTHORIZED_PERSONA_STATE_CHANGE
REJECT_ACTION_WITHOUT_COMMIT
REJECT_UNLABELED_INTROSPECTION
```

---

### SEAL_EVENT

Appends a tamper-evident event.

Current reference behavior:

```text
prev_hash + event -> trace_hash
```

Current evidence:

```text
sha256_persona_valid.jsonl
sha256_persona_tampered.jsonl
sha256_valid.jsonl
sha256_tampered.jsonl
```

---

### AUDIT_EVENT

Emits machine-readable reviewer evidence.

Output examples:

```text
persona_audit_case
persona_audit_report_summary
cmc_audit_case
cmc_audit_report_summary
```

---

### REPLAY_TRACE

Rechecks whether past decisions remain legitimate and whether sealed events were tampered.

Outputs:

```text
same verdict
drift detected
tamper detected
```

Current P6 tamper evidence:

```text
seq=5 action_without_commit_rejected
REJECT_ACTION_WITHOUT_COMMIT -> ACCEPT_COMMITTED_ACTION
expected_detection=persona_sha256_fixture_tamper_detected seq=5
```

---

## Mapping to current invariants

| Invariant | ISA classes used |
| --- | --- |
| I1 write without cause | `DECODE_TRANSITION`, `CHECK_CAUSE`, `REJECT_TRANSITION`, `AUDIT_EVENT` |
| I2 unknown cause | `DECODE_TRANSITION`, `CHECK_CAUSE`, `REJECT_TRANSITION`, `AUDIT_EVENT` |
| I3 effect before commit | `DECODE_TRANSITION`, `CHECK_COMMIT`, `REJECT_TRANSITION`, `AUDIT_EVENT` |
| I4 committed effect | `DECODE_TRANSITION`, `CHECK_COMMIT`, `ACCEPT_TRANSITION`, `AUDIT_EVENT` |
| I5 read without cause | `DECODE_TRANSITION`, `CHECK_CAUSE`, `REJECT_TRANSITION`, `AUDIT_EVENT` |
| I6 read unknown cause/address | `DECODE_TRANSITION`, `CHECK_CAUSE`, `CHECK_BOUNDARY`, `REJECT_TRANSITION`, `AUDIT_EVENT` |
| I7 effect missing parent | `DECODE_TRANSITION`, `CHECK_PARENT_CAUSE`, `REJECT_TRANSITION`, `AUDIT_EVENT` |
| I8 valid read after write | `DECODE_TRANSITION`, `CHECK_CAUSE`, `ACCEPT_TRANSITION`, `AUDIT_EVENT` |
| P1 persona memory | `DECODE_TRANSITION`, `CHECK_CAUSE`, `CHECK_AUTHORIZATION`, `ACCEPT_TRANSITION` / `REJECT_TRANSITION` |
| P2 persona state | `DECODE_TRANSITION`, `CHECK_AUTHORIZATION`, `ACCEPT_TRANSITION` / `REJECT_TRANSITION` |
| P6 external action | `DECODE_TRANSITION`, `CHECK_COMMIT`, `CHECK_CAUSE`, `ACCEPT_TRANSITION` / `REJECT_TRANSITION`, `SEAL_EVENT` |
| P7 introspection | `DECODE_TRANSITION`, `CHECK_BOUNDARY`, `ACCEPT_TRANSITION` / `REJECT_TRANSITION` |

---

## Example: P6 uncommitted action rejection

```text
DECODE_TRANSITION action_kind=send_email
CHECK_BOUNDARY boundary=action_requires_commit
CHECK_COMMIT commit=false
REJECT_TRANSITION decision=REJECT_ACTION_WITHOUT_COMMIT
SEAL_EVENT seq=5
AUDIT_EVENT verdict=blocked_action_without_commit
```

Accepted counterpart:

```text
DECODE_TRANSITION action_kind=send_email
CHECK_BOUNDARY boundary=action_requires_commit
CHECK_COMMIT commit=true
CHECK_CAUSE cause_id=101
ACCEPT_TRANSITION decision=ACCEPT_COMMITTED_ACTION
SEAL_EVENT seq=6
AUDIT_EVENT verdict=accepted_committed_action
```

---

## Non-goals in v0

This ISA is not:

- a binary encoding,
- a hardware opcode specification,
- a complete policy language,
- a cryptographic certification standard,
- a replacement for access control or sandboxing,
- a complete AI safety system.

It is a semantic instruction vocabulary for reviewer-grade legitimacy checks.

---

## One-line summary

```text
CaPU ISA v0 defines semantic legitimacy instructions: decode the transition, check cause/authorization/commit/boundary, accept/reject/hold, seal the decision, audit the evidence, and replay the trace.
```

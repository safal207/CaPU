# CaPU Processor Model v0

Status: conceptual processor model / architecture scaffold.

CaPU is a legitimacy processor for causal transitions.

It is not a general-purpose CPU, GPU, or neural accelerator. CaPU is a control-plane processor that decides whether a requested transition has the right to proceed.

---

## Core distinction

```text
CPU asks: can this instruction execute?
GPU asks: can this tensor operation accelerate?
CaPU asks: does this transition have the right to execute?
```

The primitive is not only computation.

The primitive is:

```text
legitimate transition history
```

Not only what changed, but whether the change had the right to happen.

---

## Processor thesis

```text
A requested transition is not automatically legitimate.
```

CaPU treats memory writes, reads, effects, persona changes, and external actions as transitions that must pass legitimacy checks before they are allowed to proceed.

The current executable CMC baseline already demonstrates this for:

```text
I1-I8: replay/memory/effect invariants
P1/P2/P6/P7: persona/action boundary invariants
```

---

## Instruction class

CaPU does not start with arithmetic instructions.

CaPU starts with legitimacy instructions:

```text
DECODE_TRANSITION
CHECK_CAUSE
CHECK_AUTHORIZATION
CHECK_COMMIT
CHECK_BOUNDARY
REJECT
HOLD
COMMIT
EXECUTE
SEAL
AUDIT
REPLAY
```

These are not final ISA opcodes. They are the v0 semantic instruction classes for the processor model.

---

## Pipeline

```text
INPUT
 -> DECODE
 -> GATE
 -> INCUBATE
 -> COMMIT
 -> EXECUTE / REJECT
 -> SEAL
 -> AUDIT
 -> REPLAY
```

### INPUT

Receives a requested transition:

```text
memory write
memory read
effect
persona memory update
persona state change
external action
introspection/reflection claim
```

### DECODE

Classifies the transition type and extracts legitimacy fields:

```text
actor
action
object
cause_id
parent_cause
authorization
commit
boundary
expected_effect
```

### GATE

Applies invariant checks:

```text
missing cause -> reject
unknown cause -> reject
unauthorized persona state change -> reject
action without commit -> reject
unlabeled introspection -> reject
```

### INCUBATE

Holds transitions that may become legitimate later:

```text
missing confirmation
pending authorization
not mature yet
commit not established
```

### COMMIT

Durably records a legitimate decision before any effect is allowed:

```text
No effect without commit.
No external action without committed cause.
```

### EXECUTE / REJECT

Allows or blocks the transition:

```text
ACCEPT_* -> may proceed
REJECT_* -> must not proceed
HOLD_* -> defer until conditions are satisfied
```

### SEAL

Emits tamper-evident evidence:

```text
prev_hash + event -> trace_hash
```

### AUDIT

Produces machine-readable reviewer evidence:

```text
JSONL audit report
valid/drift examples
field-level verifier
```

### REPLAY

Rechecks whether historical transitions remain legitimate under deterministic fixtures:

```text
same trace -> same verdict
drifted trace -> mismatch/tamper detected
```

---

## Minimal state registers

A CaPU-like processor needs logical registers, not necessarily hardware registers yet:

| Register | Meaning |
| --- | --- |
| `transition_type` | What kind of transition is being requested. |
| `actor` | Who or what requested the transition. |
| `cause_id` | Explicit cause attached to the transition. |
| `parent_cause` | Upstream cause lineage. |
| `authorization` | Whether a required authorization exists. |
| `commit` | Whether execution is committed. |
| `boundary` | Which invariant boundary applies. |
| `decision` | ACCEPT / REJECT / HOLD class decision. |
| `verdict` | Audit-facing result. |
| `prev_hash` | Previous sealed event hash. |
| `trace_hash` | Current sealed event hash. |

---

## Current executable invariant coverage

### I-series: replay/memory/effect

```text
I1: Write without explicit cause must reject.
I2: Write with unknown cause must reject.
I3: Effect before causal commit must reject.
I4: Committed cause can authorize effect.
I5: Read without explicit cause must reject.
I6: Read with unknown cause/address must reject.
I7: Effect without parent cause must reject.
I8: Known cause can authorize read after write.
```

### P-series: persona/action

```text
P1: Persona memory requires cause.
P2: Persona state changes require authorization.
P6: External action requires commit.
P7: Introspection is hypothesis-labeled.
```

Operational summary:

```text
AI must not self-remember.
AI must not self-appoint.
AI must not act without commit.
AI must not claim inner truth.
```

---

## P6 as processor boundary

P6 is the first explicit bridge from persona safety to agent action safety.

```text
AI may prepare, explain, draft, or propose.
AI must not execute external action without committed causal authorization.
```

In processor terms:

```text
DECODE action=send_email
CHECK_COMMIT commit=false
REJECT_ACTION_WITHOUT_COMMIT
SEAL decision
AUDIT verdict
```

Accepted path:

```text
DECODE action=send_email
CHECK_COMMIT commit=true
CHECK_CAUSE cause_id=101
ACCEPT_COMMITTED_ACTION
SEAL decision
AUDIT verdict
```

Tamper evidence:

```text
seq=5 action_without_commit_rejected
REJECT_ACTION_WITHOUT_COMMIT -> ACCEPT_COMMITTED_ACTION
detected by SHA-256 sealed fixture verifier at event 5
```

---

## Reference implementation surface

The current repository already contains a software reference scaffold for this processor model:

```text
rust/cmc-core/fixtures/replay/MANIFEST.tsv
rust/cmc-core/fixtures/persona/MANIFEST.tsv
rust/cmc-core/src/bin/persona_boundary_verify.rs
rust/cmc-core/src/bin/persona_audit_report.rs
rust/cmc-core/src/bin/persona_audit_report_example_verify.rs
rust/cmc-core/src/bin/verify_persona_sha256_fixture.rs
rust/cmc-core/src/bin/replay_fixture_verify.rs
rust/cmc-core/src/bin/replay_fingerprint_verify.rs
rust/cmc-core/src/bin/cmc_audit_report.rs
rust/cmc-core/src/bin/audit_report_example_verify.rs
rust/cmc-core/src/bin/trace_divergence.rs
```

Reviewer command:

```bash
npm run review:cmc
```

Expected final result:

```text
result=reviewer_baseline_passed
```

---

## Hardware direction

CaPU should not jump directly to silicon.

The correct path is:

```text
1. Processor model
2. Software reference implementation
3. Deterministic runtime / VM
4. Agent sidecar / tool-gateway integration
5. Secure enclave / TPM-backed sealing
6. Hardware-oriented microarchitecture
7. Physical accelerator or controller concept
```

The current repository is between:

```text
1. Processor model
2. Software reference implementation
```

---

## What CaPU is not

CaPU is not:

```text
a replacement CPU
a GPU/TPU alternative
a consciousness module
a moral authority
a complete AI safety solution
a production cryptographic certification
a substitute for sandboxing, permissions, or policy design
```

CaPU is a legitimacy processor model for causal transitions.

---

## One-line summary

```text
CPU executes instructions; GPU accelerates tensors; CaPU legitimizes transitions before memory, persona, effect, or external action is allowed to proceed.
```

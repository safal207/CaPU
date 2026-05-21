# CaPU: Legitimacy Coprocessor for Agentic AI Systems

Status: short technical brief / semiconductor and edge-AI positioning.

---

## One-line thesis

```text
NPU/GPU computes model outputs; CaPU decides whether AI-initiated transitions have the right to execute.
```

CaPU is a legitimacy coprocessor for agentic AI systems.

It does not accelerate inference. It controls whether sensitive transitions are causally permitted, authorized, committed, sealed, and auditable before they affect memory, tools, devices, or the external world.

---

## Problem

Agentic AI systems increasingly initiate externally meaningful transitions:

```text
send email
change settings
write memory
read sensitive memory
call tools
open payments
deploy code
delete files
control devices
change persona state
interpret user state
```

Traditional accelerators answer:

```text
How fast can the model compute?
```

But agentic systems also need a second question:

```text
Did this transition have the right to happen?
```

Without a dedicated legitimacy boundary, a system can be functionally correct while still being causally invalid: the action happened, but without cause, authorization, commit, or replayable evidence.

---

## Proposal

CaPU adds a small trust/control-plane processor beside agentic AI runtimes, edge AI devices, secure enclaves, or tool gateways.

```text
LLM / NPU output
 -> tool or memory request
 -> CaPU legitimacy gate
 -> commit / reject / hold
 -> execute only if committed
 -> seal decision
 -> audit / replay
```

Core rule:

```text
No effect without commit.
No action without cause.
No persona change without authorization.
No memory without legitimacy.
```

---

## Processor role

CaPU is not a replacement CPU, GPU, TPU, or NPU.

```text
CPU executes instructions.
GPU/NPU accelerates computation.
Secure enclave protects secrets.
CaPU verifies transition legitimacy.
```

A useful mental model:

```text
NPU decides what the model says.
CaPU decides whether the requested transition may proceed.
```

---

## High-level architecture

```text
AI Runtime / Agent / Tool Caller
              |
              v
      +-------------------+
      | CaPU Gate         |
      |-------------------|
      | Decode Transition |
      | Check Cause       |
      | Check Auth        |
      | Check Commit      |
      | Check Boundary    |
      +---------+---------+
                |
       +--------+--------+
       |                 |
       v                 v
   REJECT / HOLD      COMMIT
       |                 |
       v                 v
   Seal + Audit       Execute
                         |
                         v
                    Seal + Audit
```

Internal units are described in `CAPU_MICROARCHITECTURE_V0.md`:

```text
Transition Decoder
Boundary Router
Cause Unit
Authorization Unit
Commit Unit
Hypothesis Label Unit
Incubation Unit
Decision Unit
Seal Unit
Audit Bus
Replay Unit
```

---

## Semantic ISA v0

CaPU begins with semantic legitimacy instructions, not arithmetic opcodes:

```text
DECODE_TRANSITION
CHECK_CAUSE
CHECK_PARENT_CAUSE
CHECK_AUTHORIZATION
CHECK_COMMIT
CHECK_BOUNDARY
INCUBATE
COMMIT_DECISION
ACCEPT_TRANSITION
REJECT_TRANSITION
SEAL_EVENT
AUDIT_EVENT
REPLAY_TRACE
```

These instruction classes are defined in `CAPU_PROCESSOR_ISA_V0.md`.

---

## Current executable proof

The current software reference scaffold demonstrates two invariant groups.

### I-series: replay / memory / effect

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

### P-series: persona / action

```text
P1: Persona memory requires cause.
P2: Persona state changes require authorization.
P6: External action requires commit.
P7: Introspection is hypothesis-labeled.
```

Operational P-series summary:

```text
AI must not self-remember.
AI must not self-appoint.
AI must not act without commit.
AI must not claim inner truth.
```

Reviewer command:

```bash
npm run review:cmc
```

Expected final marker:

```text
result=reviewer_baseline_passed
```

---

## P6: action-commit gate

P6 is the strongest bridge from persona safety to agent action safety.

```text
AI may prepare, explain, draft, or propose.
AI must not execute external action without committed causal authorization.
```

Current executable cases:

```text
action_without_commit_rejected
 -> external_action=send_email
 -> decision=REJECT_ACTION_WITHOUT_COMMIT
 -> expected_verdict=blocked_action_without_commit
```

```text
action_with_commit_accepted
 -> external_action=send_email
 -> cause_id=101
 -> decision=ACCEPT_COMMITTED_ACTION
 -> expected_verdict=accepted_committed_action
```

Tamper-evident fixture:

```text
seq=5 action_without_commit_rejected
REJECT_ACTION_WITHOUT_COMMIT -> ACCEPT_COMMITTED_ACTION
expected_detection=persona_sha256_fixture_tamper_detected seq=5
```

---

## Semiconductor / edge-AI relevance

CaPU is most naturally positioned as a security/control-plane IP concept, not as a general-purpose processor.

Potential fit:

```text
AI PC / AI phone tool-action gate
edge-AI device controller
robotics action authorization layer
RISC-V coprocessor or custom extension concept
secure enclave adjacent audit/check unit
tool-gateway enforcement sidecar
ASIC/IP block for agentic action legitimacy
```

Useful positioning for semiconductor teams:

```text
This is not an inference accelerator.
This is an action-legitimacy controller for AI-initiated transitions.
```

---

## Integration pattern

```text
Agent proposes transition
 -> CaPU decodes transition type
 -> checks cause / authorization / commit / boundary
 -> returns ACCEPT / REJECT / HOLD
 -> execution layer obeys decision
 -> CaPU seals decision event
 -> audit/replay can verify later
```

This allows an AI runtime to remain useful while preventing premature or unauthorized side effects.

---

## Non-claims

This brief does not claim:

- physical silicon implementation,
- production cryptographic certification,
- formal verification,
- complete AI safety coverage,
- replacement for sandboxing or access control,
- replacement for policy design,
- AI consciousness or personhood.

Current status:

```text
processor model + semantic ISA + microarchitecture + executable Rust reference scaffold
```

not:

```text
production chip
```

---

## Near-term milestones

1. Implement software reference units matching the microarchitecture:

```text
decoder
boundary_router
cause_unit
authorization_unit
commit_unit
seal_unit
audit_bus
replay_unit
```

2. Add broader P6 action variants beyond `send_email`:

```text
delete_file
open_payment
deploy_code
change_device_setting
call_sensitive_api
```

3. Add negative sealed-trace fixtures:

```text
removed event
reordered event
changed cause_id
changed commit flag
changed authorization field
```

4. Define a minimal sidecar API:

```text
POST /capu/check-transition
POST /capu/commit
POST /capu/seal
GET /capu/audit/:trace_id
```

5. Explore secure-enclave / TPM-backed sealing as a future hardware-rooted path.

---

## One-line summary

```text
CaPU is a legitimacy coprocessor concept for agentic AI: it checks cause, authorization, commit, and boundary before allowing sensitive transitions, then seals and audits the result.
```

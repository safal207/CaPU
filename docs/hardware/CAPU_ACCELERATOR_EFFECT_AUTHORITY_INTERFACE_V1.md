# CaPU v1.0-A1 — Accelerator Effect Authority Interface

Status: **alpha reference contract**.

Issue: `#91`.

This interface is the first executable milestone under the ASTRA–CaPU v1.0 reference architecture.

It composes the strongest verified CaPU primitives into one implementation-neutral boundary between an agent/runtime and an accelerator or consequential external-effect system.

---

## Core separation

```text
authorization evidence
!=
execution evidence
!=
outcome evidence
```

A request can be authorized without having started.

An operation can have started without a known outcome.

A success-shaped response is not sufficient evidence that the expected external effect committed.

---

## Request envelope

Schema:

```text
capu.accelerator-effect-authority.request.v1
```

Authority identity:

```text
intent_id
+ principal_id
+ policy_commitment
+ state_commitment
+ queue_incarnation
+ queue_epoch
+ slot_id
+ command_id
+ execution_epoch
+ attempt_id
+ effect_id
+ resource_commitment
+ expected_outcome_class
+ expires_at_epoch
```

The SHA-256 request commitment is computed over the canonical binary encoding defined below.

Changing any authority-bearing field changes the commitment.

---

## Evidence envelope

Schema:

```text
capu.accelerator-effect-authority.evidence.v1
```

Each evidence object binds:

```text
request_commitment
sequence
previous_evidence_commitment
decision
execution_state
completion_state
authorization evidence
execution evidence
negative outcome evidence
committed outcome evidence
receipt
next state
reason code
```

Evidence forms an append-only commitment chain:

```text
E0
 ↓ sha256(canonical(E0))
E1.previous
 ↓ sha256(canonical(E1))
E2.previous
 ...
```

This prevents a later record from silently detaching itself from the earlier authorization and recovery history.

---

## Decision states

```text
ACCEPTED
REJECTED
HELD
```

`HELD` means the system refuses to create new effect authority until exact evidence or recovery conditions are satisfied.

---

## Execution states

```text
NOT_STARTED
STARTED
RECOVERING
RECONCILE_REQUIRED
CLOSED
```

---

## Completion states

```text
NOT_COMMITTED
UNKNOWN
COMMITTED
```

### UNKNOWN

```text
UNKNOWN
=> evidence_required = true
=> no resolved outcome commitment
=> no receipt commitment
=> no next-state commitment
=> no retire authority
=> no same-attempt replay authority
```

### COMMITTED

```text
COMMITTED
=> decision = ACCEPTED
=> execution_state = CLOSED
=> exact execution evidence
=> exact committed-outcome evidence
=> receipt commitment
=> next-state commitment
=> replay permanently closed for this request identity
```

### NOT_COMMITTED after execution

```text
NOT_COMMITTED
=> decision = HELD
=> execution_state = CLOSED
=> exact execution evidence
=> exact negative-outcome evidence
=> no committed receipt
=> a successor attempt may be authorized under a new exact request commitment
```

The negative result does not authorize replay of the same request identity. It supplies evidence from which a separately identified successor attempt may be constructed.

---

## Allowed reference lifecycle

```text
ACCEPTED / NOT_STARTED / NOT_COMMITTED
        ↓
ACCEPTED / STARTED / UNKNOWN
        ↓
HELD / RECOVERING / UNKNOWN
        ↓
HELD / RECONCILE_REQUIRED / UNKNOWN
        ↓
        ├─ ACCEPTED / CLOSED / COMMITTED
        └─ HELD / CLOSED / NOT_COMMITTED
```

A `CLOSED` evidence chain is terminal.

A rejected request terminates at sequence zero.

---

## Canonical encoding

The reference implementation uses deterministic length-prefixed binary encoding.

### Primitive encoding

```text
uint8      = 1 byte
uint32     = 4-byte unsigned big-endian
boolean    = uint8 0 or 1
string     = uint32 byte length + UTF-8 bytes
commitment = 32 raw bytes decoded from 64 lowercase hex characters
optional commitment = presence uint8 + commitment when present
```

### Domain separation

```text
CAPU:ACCELERATOR-EFFECT-AUTHORITY:REQUEST:V1\0
CAPU:ACCELERATOR-EFFECT-AUTHORITY:EVIDENCE:V1\0
```

### Request field order

```text
schema
intent_id
principal_id
policy_commitment
state_commitment
queue_incarnation
queue_epoch
slot_id
command_id
execution_epoch
attempt_id
effect_id
resource_commitment
expected_outcome_class
expires_at_epoch
```

### Evidence field order

```text
schema
request_commitment
sequence
previous_evidence_commitment
decision code
execution-state code
completion-state code
authorization_evidence_commitment
execution_evidence_commitment
negative_outcome_evidence_commitment
committed_outcome_evidence_commitment
receipt_commitment
next_state_commitment
evidence_required
recovery_required
reason_code
```

JSON property order is irrelevant; canonical binary field order is normative for this alpha reference implementation.

---

## Reference fixtures

The valid lifecycle deliberately exercises:

```text
authorized request
→ execution started
→ completion UNKNOWN
→ recovery barrier
→ stale evidence rejected
→ reconciliation required
→ exact committed outcome
→ proof receipt
→ next state commitment
```

The adversarial fixture set includes:

```text
foreign request commitment
broken evidence chain
UNKNOWN without evidence gate
false success without outcome evidence
receipt attached to UNKNOWN
non-contiguous evidence sequence
state transition after CLOSED
```

---

## Bounded RTL reference model

The A1 RTL reference model is intentionally small:

```text
one active request identity
one issue witness
one completion decision
one checkpoint
one recovery/restore boundary
```

It verifies the contract-level safety split:

```text
UNKNOWN
=> evidence required
&& no retire authority
&& no successor-attempt authority

FOREIGN EVIDENCE
=> rejected
&& no authority-state mutation

STALE CHECKPOINT
+ durable issue witness
=> restore UNKNOWN, not NOT_COMMITTED

EXACT NEGATIVE EVIDENCE
=> current attempt CLOSED
&& successor-attempt authority exposed

EXACT COMMITTED EVIDENCE
=> proof receipt valid
&& retire authority exposed
```

---

## Integration intent

The interface is designed to sit at boundaries such as:

```text
agent tool call → external API
runtime command → accelerator descriptor queue
host driver → DMA engine
orchestrator → laboratory device
```

It does not prescribe a specific transport.

---

## Claim boundary

A1 is an alpha interface and bounded reference model.

It does not prove:

```text
cryptographic authenticity of evidence
secure key storage
production PCIe/CXL/NoC transport
real accelerator attestation
payload-value correctness
arbitrary queue depth
IOMMU/cache coherence
liveness or fairness
performance suitability
FPGA/ASIC feasibility
unbounded correctness
```

The intended claim is narrower:

> A deterministic, commitment-bound interface can preserve the distinction between authorization, execution, uncertainty, outcome evidence, recovery, and terminal proof without allowing stale or foreign evidence to create effect authority in the modeled scope.

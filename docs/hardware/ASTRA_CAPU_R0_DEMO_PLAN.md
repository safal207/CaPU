# ASTRA–CaPU R0 Demonstrator Plan

Status: next executable bridge.

## Demonstrator question

```text
Can CaPU preserve truthful execution authority when an accelerator-like command
crosses a crash boundary and the external outcome is initially unknown?
```

## Scenario

```text
1. Agent proposes a consequential action.
2. CaPU grounds the request in state and policy.
3. CaPU commits an AuthorityTicket.
4. A synthetic accelerator accepts a DMA-like command.
5. The process crashes after dispatch but before a completion receipt is stored.
6. Recovery loads a stale pre-dispatch checkpoint.
7. Durable issue evidence preserves DISPATCHED_UNKNOWN.
8. Blind replay, success, retirement, and trusted memory update remain blocked.
9. External evidence resolves the outcome as NOT_COMMITTED or COMMITTED.
10. CaPU either reopens exact replay authority or closes replay and emits a ProofReceipt.
11. Trusted memory updates only from the reconciled receipt.
```

## Baseline path

The unsafe baseline should intentionally use a common but flawed rule:

```text
timeout or missing receipt -> assume not executed -> retry
```

Expected negative result:

```text
external effect may execute twice
or trusted memory may claim success without outcome evidence
```

## CaPU path

```text
missing receipt + durable issue witness -> DISPATCHED_UNKNOWN
DISPATCHED_UNKNOWN -> no blind replay, no success, no retirement
exact outcome evidence -> reconcile
reconcile -> proof receipt -> memory update
```

## Required artifacts

```text
schemas/astra/intent-envelope.v1.schema.json
schemas/astra/authority-ticket.v1.schema.json
schemas/astra/outcome-evidence.v1.schema.json
schemas/astra/proof-receipt.v1.schema.json
examples/astra-r0/*.json
rust/cmc-core/src/capu/astra_adapter.rs
rust/cmc-core/tests/astra_r0.rs
rtl/capu_astra_command_guard_v1.sv
formal/capu_astra_command_guard_v1_formal.sv
formal/capu_astra_command_guard_v1.sby
results/astra-r0/result.json
```

Names are proposed and may be adjusted to repository conventions before implementation.

## Core tests

### Positive

- committed authority dispatches once;
- exact `NOT_COMMITTED` evidence reopens replay;
- exact `COMMITTED` evidence closes replay and permits receipt/memory update;
- exact recovery reconstructs authority from durable evidence.

### Negative

- no commit;
- stale checkpoint;
- foreign incarnation;
- foreign queue epoch;
- same numeric IDs under foreign authority;
- duplicate dispatch;
- outcome conflict;
- false-success report without external evidence;
- memory update before receipt;
- negative evidence reused after a fresh retry.

## Metrics

```text
decision latency
command-queue throughput
receipt bytes per effect
durable state bytes per in-flight command
recovery decision latency
false-success count
duplicate-effect count
blocked-valid-action count
```

## Acceptance condition

R0 is complete only when:

```text
unsafe baseline produces at least one duplicate-effect or false-success witness
AND
CaPU path produces zero such witnesses in the defined deterministic/fault-injected scope
AND
all accepted state transitions are bound to machine-readable receipts
AND
claim boundaries are explicit
```

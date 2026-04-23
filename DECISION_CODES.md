# Decision Codes

This document lists the standardized codes used by CaPU to explain state transitions and decisions. These codes should be included in trace events.

## Terminology note

The canonical concept is **decision_code**.
In serialized port outputs, the field name **reason_code** carries the canonical decision_code value.
This preserves wire compatibility while keeping the spec vocabulary stable.

## Canonical Decision Codes (v0.1)

The semantics of the codes listed below MUST NOT change. New codes MAY be added, but existing codes are only allowed to be deprecated, not repurposed.

| Code | Meaning | Typical Decision / Stage |
| :--- | :--- | :--- |
| `PERMIT_OK` | Cause is causally valid and permitted for execution. | ACCEPT / gate or incubator release |
| `REJECT_INVALID_CAUSE` | Cause is malformed or violates schema/structural constraints. | REJECT / gate |
| `REJECT_POLICY` | Cause violates an explicit policy constraint. | REJECT / gate |
| `REJECT_CAPACITY_LIMIT` | Execution is valid in principle but denied due to insufficient capacity. | REJECT / gate |
| `REJECT_CAUSAL_ORDER` | Cause violates required causal or temporal ordering. | REJECT / gate |
| `REJECT_STATE_CONFLICT` | Cause conflicts with current committed state. | REJECT / gate/commit |
| `DEFER_PENDING_CONTEXT` | Decision cannot be made until additional context becomes available. | HOLD / gate |
| `TTL_EXPIRED` | Held cause exceeded its TTL before becoming mature. | EXPIRE / incubator |
| `ABORT_INTERNAL_ERROR` | Internal CaPU failure prevented a safe decision or durable commit. | REJECT / commit or execute path |
| `COMMIT_EXECUTED` | Decision committed and effects executed successfully. | EXECUTE_OK |
| `COMMIT_NO_EFFECT` | Decision committed and produced no side effects by design. | EXECUTE_OK |

## Current Runtime / Example Usage

The current reference runtime, demo, and golden flow fixtures use the following canonical codes directly:

- `PERMIT_OK`
- `REJECT_INVALID_CAUSE`
- `REJECT_CAPACITY_LIMIT`
- `DEFER_PENDING_CONTEXT`
- `TTL_EXPIRED`
- `ABORT_INTERNAL_ERROR`
- `COMMIT_EXECUTED`

This document is the single source of truth for those values.

## Decisions

| Decision | Meaning |
| :--- | :--- |
| **ACCEPT** | The cause is valid and allowed to proceed to commit. |
| **HOLD** | The cause is valid but not yet ready (e.g., missing parent). |
| **REJECT** | The cause is invalid or denied by policy. Terminal. |
| **EXPIRE** | The cause timed out in the Incubate stage. Terminal. |

## Operational / Legacy Diagnostic Codes

The codes below are operational or legacy diagnostics. They MAY still appear inside implementation-specific explanations or migration layers, but they are **not** the preferred wire-stable contract unless promoted into the canonical table above.

Recommended usage patterns:
- `reason_code` (wire field) SHOULD carry a **canonical decision_code** whenever one exists.
- Implementations MAY include additional structured detail (e.g., `explain`, `policy_snapshot`, or future fields like `subreason_code`) for diagnostic specificity.

| Code | Description | Typical Decision | Preferred Canonical Alternative |
| :--- | :--- | :--- | :--- |
| `BAD_SIGNATURE` | Cryptographic signature verification failed. | REJECT | `REJECT_INVALID_CAUSE` or `REJECT_POLICY` |
| `REPLAY_NONCE` | Nonce has been used before (replay attack). | REJECT | `REJECT_POLICY` |
| `SCOPE_DENIED` | Cause scope is not authorized for this actor. | REJECT | `REJECT_POLICY` |
| `MISSING_PARENT` | Referenced parent cause not found in memory. | HOLD | `DEFER_PENDING_CONTEXT` |
| `PRECONDITIONS_UNMET` | Logic preconditions (e.g. time-lock) not satisfied. | HOLD | `DEFER_PENDING_CONTEXT` |
| `RATE_LIMIT` | Sender exceeded rate limits. | REJECT | `REJECT_POLICY` |
| `STORAGE_COMMIT_FAILED` | Persistence layer failed to write the record. | REJECT (or retry) | `ABORT_INTERNAL_ERROR` |

> Note: If any diagnostic code above becomes part of the wire-stable contract,
> it MUST be added to **Canonical Decision Codes** with frozen semantics.

# Decision Codes

This document lists the standardized codes used by CaPU to explain state transitions and decisions. These codes should be included in trace events.

## Terminology note

The canonical concept is **decision_code**.
In serialized port outputs, the field name **reason_code** carries the canonical decision_code value.
This preserves wire compatibility while keeping the spec vocabulary stable.

## Canonical Decision Codes (v0.1)

The semantics of the codes listed below MUST NOT change. New codes MAY be added, but existing codes are only allowed to be deprecated, not repurposed.

| Code | Meaning |
| :--- | :--- |
| `PERMIT_OK` | Cause is causally valid and permitted for execution. |
| `REJECT_INVALID_CAUSE` | Cause is malformed or violates schema/structural constraints. |
| `REJECT_POLICY` | Cause violates an explicit policy constraint. |
| `REJECT_CAPACITY_LIMIT` | Execution is valid in principle but denied due to insufficient capacity. |
| `REJECT_CAUSAL_ORDER` | Cause violates required causal or temporal ordering. |
| `REJECT_STATE_CONFLICT` | Cause conflicts with current committed state. |
| `DEFER_PENDING_CONTEXT` | Decision cannot be made until additional context becomes available. |
| `ABORT_INTERNAL_ERROR` | Internal CaPU failure prevented a safe decision. |
| `COMMIT_EXECUTED` | Decision committed and effects executed successfully. |
| `COMMIT_NO_EFFECT` | Decision committed and produced no side effects by design. |

## Decisions

| Decision | Meaning |
| :--- | :--- |
| **ACCEPT** | The cause is valid and allowed to proceed to commit. |
| **HOLD** | The cause is valid but not yet ready (e.g., missing parent). |
| **REJECT** | The cause is invalid or denied by policy. Terminal. |
| **EXPIRE** | The cause timed out in the Incubator. Terminal. |

## Reason Codes

| Code | Description | Typical Decision |
| :--- | :--- | :--- |
| `BAD_SIGNATURE` | Cryptographic signature verification failed. | REJECT |
| `REPLAY_NONCE` | Nonce has been used before (replay attack). | REJECT |
| `SCOPE_DENIED` | Cause scope is not authorized for this actor. | REJECT |
| `MISSING_PARENT` | Referenced parent cause not found in memory. | HOLD |
| `PRECONDITIONS_UNMET`| Logic preconditions (e.g. time-lock) not satisfied. | HOLD |
| `RATE_LIMIT` | Sender exceeded rate limits. | REJECT |
| `TTL_EXPIRED` | Cause stayed in HOLD longer than allowed TTL. | EXPIRE |
| `STORAGE_COMMIT_FAILED`| Persistence layer failed to write the record. | REJECT (or retry) |

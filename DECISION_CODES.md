# Decision Codes

This document lists the standardized codes used by CaPU to explain state transitions and decisions. These codes should be included in trace events.

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

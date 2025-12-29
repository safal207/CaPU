# Device Envelope

The device envelope wraps a **vCML record** when it crosses the CaPU device boundary.
It does **not** replace vCML; it only describes how the device receives or emits a cause
in a transport-agnostic way.

Canonical dependency: see [DEPENDENCIES.md](../DEPENDENCIES.md) for vCML ownership.

## Envelope Fields

| Field | Type | Required | Notes |
| --- | --- | --- | --- |
| `cause_id` | string | yes | Identifier for the underlying vCML cause. |
| `received_at` | string (RFC3339) | yes | Device ingress timestamp. |
| `source` | string | yes | Origin (e.g., `lpt`, `file`, `local`). |
| `correlation_id` | string | no | Optional `trace_id` for linking events. |
| `ttl_ms` | number | no | Optional time-to-live for the cause. |
| `metadata` | object | no | Freeform metadata map. |

## Notes

- The envelope is compatible with any transport (LPT, file, in-memory, etc.).
- The vCML record remains canonical; no alternative cause schema is introduced.
- Decision codes referenced elsewhere remain defined in [DECISION_CODES.md](../DECISION_CODES.md).

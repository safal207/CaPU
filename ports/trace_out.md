# TraceOut Port

The **TraceOut** port emits structured trace events from the device.
Adapters should map these events into **T-Trace JSONL**.

See [DEPENDENCIES.md](../DEPENDENCIES.md) for T-Trace ownership and
[DECISION_CODES.md](../DECISION_CODES.md) for decision/reason enums.

## Canonical Event Taxonomy

The canonical `event_type` namespace is stage-oriented:

- `gate.accept`
- `gate.hold`
- `gate.reject`
- `incubator.release`
- `incubator.expire`
- `commit.ok`
- `commit.fail`
- `execute.ok`
- `execute.fail`

TraceOut payloads MUST use these exact names in `trace_event.event_type`.
`details` is a fixed, schema-validated map for the fields listed below; implementations
SHOULD NOT add ad-hoc keys there or invent alternative top-level event names.

## Output Contract

```
trace_event:
  timestamp: string (RFC3339)
  cause_id: string
  correlation_id: string (optional)
  component: "CaPU"
  event_type: string (one of the canonical taxonomy values above)
  details:
    decision: string (optional)
    reason_code: string (optional)
    state_from: string (optional)
    state_to: string (optional)
    latency_ms: number (optional)
```

## Recommended Mapping

| Situation | event_type | details.decision | details.reason_code |
| :--- | :--- | :--- | :--- |
| Gate permits immediate progress | `gate.accept` | `ACCEPT` | canonical permit/reject code |
| Gate defers pending context | `gate.hold` | `HOLD` | e.g. `DEFER_PENDING_CONTEXT` |
| Gate rejects cause | `gate.reject` | `REJECT` | canonical reject code |
| Incubate stage releases held cause | `incubator.release` | `ACCEPT` | canonical permit code |
| Held cause TTL elapsed | `incubator.expire` | `EXPIRE` | e.g. `TTL_EXPIRED` |
| Commit succeeded | `commit.ok` | optional | optional |
| Commit failed | `commit.fail` | `REJECT` or implementation-defined | e.g. `ABORT_INTERNAL_ERROR` |
| Execution succeeded | `execute.ok` | optional | e.g. `COMMIT_EXECUTED` |
| Execution failed after commit | `execute.fail` | optional | implementation-defined |

## Notes

- The device emits structured events using the canonical taxonomy above.
- `details` is a small fixed context map, not an extensible event schema.
- Prefer stage-oriented event names over outcome-specific aliases.

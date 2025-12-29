# TraceOut Port

The **TraceOut** port emits structured trace events from the device.
Adapters should map these events into **T-Trace JSONL**.

See [DEPENDENCIES.md](../DEPENDENCIES.md) for T-Trace ownership and
[DECISION_CODES.md](../DECISION_CODES.md) for decision/reason enums.

## Output Contract

```
trace_event:
  timestamp: string (RFC3339)
  cause_id: string
  correlation_id: string (optional)
  component: "CaPU"
  event_type: string (e.g., gate.accept, gate.hold, commit.ok, execute.fail)
  details:
    decision: string (optional)
    reason_code: string (optional)
    state_from: string (optional)
    state_to: string (optional)
    latency_ms: number (optional)
```

## Notes

- The device emits structured events only; adapters map to T-Trace taxonomy.
- `details` is a small context map, not a full event schema.
- `event_type` should be namespaced (e.g., `gate.*`, `incubator.*`, `commit.*`, `execute.*`).

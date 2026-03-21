# Trace Sink Interface

This interface defines how CaPU emits observability events. It is designed to feed into **T-Trace**.

## Responsibilities
*   **Decoupling:** CaPU does not know how traces are stored or viewed, only that it emits them.
*   **Structured Logging:** All events must be structured data.
*   **Stable Taxonomy:** Event names should stay aligned with the canonical stage-oriented trace taxonomy.

## Methods

### `emit(trace_event)`
Records a lifecycle event.

*   **Input:** `trace_event` object containing:
    *   `timestamp`: ISO 8601
    *   `cause_id`: The causal record identifier (vCML id).
    *   `correlation_id`: Optional correlation id / trace id (session/span), may differ from `cause_id`.
    *   `component`: "CaPU"
    *   `event_type`: One canonical lifecycle event name.
    *   `details`: Object with `decision`, `reason_code`, etc.

## Canonical Event Types

| Event Type | Trigger |
| :--- | :--- |
| `gate.accept` | Cause passed validation/policy and can proceed. |
| `gate.hold` | Cause moved to incubator. |
| `gate.reject` | Cause failed validation or policy. |
| `incubator.release` | Held cause became mature and returned to ACCEPTED. |
| `incubator.expire` | Held cause timed out before maturity. |
| `commit.ok` | Storage commit success. |
| `commit.fail` | Storage commit failure. |
| `execute.ok` | Execution success after commit. |
| `execute.fail` | Execution failure after commit. |

## Relationship to T-Trace
Implementations of this interface should adapt these events into the canonical **T-Trace** JSONL format and taxonomy.

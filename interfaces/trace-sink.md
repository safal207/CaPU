# Trace Sink Interface

This interface defines how CaPU emits observability events. It is designed to feed into **T-Trace**.

## Responsibilities
*   ** decoupling:** CaPU does not know how traces are stored or viewed, only that it emits them.
*   **Structured Logging:** All events must be structured data.

## Methods

### `emit(trace_event)`
Records a lifecycle event.

*   **Input:** `trace_event` object containing:
    *   `timestamp`: ISO 8601
    *   `trace_id`: Correlated with the cause ID.
    *   `component`: "CaPU"
    *   `event_type`: One of the defined events (see below).
    *   `details`: Object with `decision`, `reason_code`, etc.

## Event Types

| Event Type | Trigger |
| :--- | :--- |
| `gate.accept` | Cause passed validation. |
| `gate.hold` | Cause moved to incubator. |
| `gate.reject` | Cause failed validation. |
| `commit.ok` | Storage commit success. |
| `commit.fail` | Storage commit failure. |
| `execute.ok` | Execution success. |
| `execute.fail` | Execution failure. |

## Relationship to T-Trace
Implementations of this interface should adapt these events into the canonical **T-Trace** JSONL format.

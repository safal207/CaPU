# CaPU embedded profile — draft v0

This profile translates the Phase 2 roadmap into bounded requirements for an edge device or robotics middleware implementation. It is a design target, not certification evidence.

## Bounded resources

- Use fixed-size action, authority, outcome, and trace records with explicit schema versions.
- Configure maximum pending actions, parent depth, evidence entries, and trace entries at build time.
- Reject oversize records and capacity exhaustion deterministically; do not silently truncate authority-bearing fields.
- Keep executable payloads outside the authority record and bind them by a fixed-size commitment.

## Bounded execution

- Each Gate/Incubate/Commit decision has a documented worst-case step or time budget.
- External waits use explicit deadlines or logical epochs.
- Budget exhaustion transitions to `HOLD`, `EXPIRED`, or fail-closed `UNKNOWN`; it never implies success.
- Retry is permitted only by exact negative outcome evidence for the current attempt and its defined successor.

## Safe defaults

```text
invalid identity          -> REJECT
missing parent/evidence   -> HOLD
commit failure            -> NO EXECUTE
ambiguous completion      -> UNKNOWN + NO BLIND REPLAY
trace capacity exhausted  -> FAIL CLOSED before a new effect
```

## Trace ring

A minimal implementation may use a fixed-size ring whose entries contain:

```text
sequence | action_id | authority_digest | state | decision_code
logical_time | evidence_digest | previous_trace_digest
```

Overwriting an entry that is still required to justify live authority must be rejected. Export and acknowledgement policy must be explicit before reuse.

## Example bounded path

```text
robot action arrives
-> Gate validates a fixed-size record
-> Incubate waits up to SENSOR_TTL epochs
-> sensor evidence arrives
-> Commit persists the exact authority digest
-> Execute emits one actuator permit
-> TraceOut records the terminal decision
```

If the sensor deadline expires or durable commit fails, the permit output remains deasserted.

## Non-claims

This draft does not establish hard real-time schedulability, power-loss-safe storage, cryptographic key protection, device attestation, SIL/ASIL certification, WCET evidence, FPGA timing, or production robotics safety. Those require target-specific implementation and measurement.

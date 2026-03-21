# CaPU State Machine

This document defines the lifecycle of a cause within the CaPU.

## States

| State | Description |
| :--- | :--- |
| **RECEIVED** | Initial state when a cause enters the Gate. |
| **VALIDATING** | The cause is undergoing structural validation (and optional record-level attestation checks if present). |
| **HELD** | Valid cause waiting for preconditions (Incubator). |
| **ACCEPTED** | Valid cause ready for commitment. |
| **COMMITTED** | Cause successfully persisted in causal memory. Point of no return. |
| **EXECUTED** | Execution stage (side effects attempted). Outcome is recorded via `execute_ok` / `execute_fail`. |
| **REJECTED** | Cause failed validation or policy check. Terminal state. |
| **EXPIRED** | Held cause timed out before preconditions were met. Terminal state. |

## Events

| Event | Description |
| :--- | :--- |
| `submit` | External system submits a vCML record. |
| `valid` | Validation passed. |
| `invalid` | Validation failed (bad sig, format). |
| `policy_deny` | Policy check failed (rate limit, scope). |
| `preconditions_unmet` | Valid, but dependencies missing. |
| `preconditions_met` | All dependencies satisfied. |
| `timeout` | TTL expired while in HOLD. |
| `commit_ok` | Storage write successful. |
| `commit_fail` | Storage write failed. |
| `execute_ok` | Execution successful. |
| `execute_fail` | Execution failed. |

## Transition Table

| Current State | Event | Next State | Action/Notes |
| :--- | :--- | :--- | :--- |
| **(Start)** | `submit` | **RECEIVED** | |
| **RECEIVED** | (internal) | **VALIDATING** | Start validation logic |
| **VALIDATING** | `invalid` | **REJECTED** | Reason: BAD_SIGNATURE, etc. |
| **VALIDATING** | `policy_deny` | **REJECTED** | Reason: SCOPE_DENIED, etc. |
| **VALIDATING** | `preconditions_unmet`| **HELD** | Move to Incubator |
| **VALIDATING** | `valid` | **ACCEPTED** | Ready to commit |
| **HELD** | `preconditions_met` | **ACCEPTED** | Incubator releases cause |
| **HELD** | `timeout` | **EXPIRED** | TTL reached |
| **ACCEPTED** | (internal) | **ACCEPTED** | Attempt storage commit |
| **ACCEPTED** | `commit_ok` | **COMMITTED** | Point of no return |
| **ACCEPTED** | `commit_fail` | **REJECTED** | Storage error (retry logic dependent on impl) |
| **COMMITTED** | (internal) | **EXECUTED** | Trigger Executor (invoke side effects) |
| **EXECUTED** | `execute_ok` | **(End)** | Trace success |
| **EXECUTED** | `execute_fail` | **(End)** | Trace failure after attempted execution; committed cause remains durable |

## Trace Mapping

The trace stream SHOULD use a stable stage-oriented taxonomy aligned with these transitions.

Implementation note: if a held cause becomes mature exactly at or after its TTL boundary, the reference runtime gives **release** precedence over **expire** at evaluation time.

| Transition / Outcome | Canonical `event_type` | Decision / Code Expectations |
| :--- | :--- | :--- |
| VALIDATING → ACCEPTED | `gate.accept` | `decision=ACCEPT`, canonical permit code |
| VALIDATING → HELD | `gate.hold` | `decision=HOLD`, defer/pending-context code |
| VALIDATING → REJECTED | `gate.reject` | `decision=REJECT`, canonical reject code |
| HELD → ACCEPTED | `incubator.release` | `decision=ACCEPT`, permit code |
| HELD → EXPIRED | `incubator.expire` | `decision=EXPIRE`, timeout/TTL code |
| ACCEPTED → COMMITTED | `commit.ok` | commit metadata may omit decision |
| ACCEPTED → REJECTED (storage error) | `commit.fail` | implementation should include a stable failure code |
| COMMITTED → end success | `execute.ok` | should include executed/no-effect style code when useful |
| COMMITTED → end failure | `execute.fail` | execution failure recorded after durable commit |

## Invariants

1.  **Execute MUST happen only after Commit.**
2.  **REJECT never leads to EXECUTE.**
3.  **HOLD → ACCEPT only when preconditions are satisfied.**
4.  **CaPU decisions are explainable via decision codes.**

# CaPU Specification

This document formally describes the architecture and logic of the Causal Processing Unit (CaPU).

## Core Components

The CaPU pipeline consists of four distinct stages:

### 1. Gate
**Function:** Entry point for all incoming causes.
*   **Validation:** Verifies the structural integrity of the vCML record.
*   **Optional Attestation:** If the vCML record includes record-level attestation/proofs, Gate may validate them as part of policy.
    *   **Note:** This is distinct from LTP transport/session crypto.
*   **Permission Decision:** Determines if the action may advance toward execution.
*   **Outcome:** `PERMIT` or `REJECT`.

### 2. Incubator
**Function:** Holding area for permitted but premature causes.
*   **Purpose:** Handles causes that are permitted but still have unmet preconditions (e.g., waiting for a parent cause, time-lock, or quorum).
*   **Mechanism:** Event-driven or scheduled re-evaluation of maturity/preconditions.
*   **Outcome:** `HOLD`/`DEFER` while unmet; `MATURE` when preconditions are satisfied; `EXPIRE` if TTL is reached.

### 3. Commit
**Function:** Durable authorization before effects.
*   **Action:** Persists the mature cause into append-only causal memory.
*   **Guarantee:** Side effects are forbidden before successful durable commit.
*   **Outcome:** `COMMIT_OK` or `COMMIT_FAIL` (storage error).

### 4. Executor
**Function:** Bridge to the external world.
*   **Trigger:** strictly triggered *after* a successful commit.
*   **Action:** Interprets the committed cause and performs the side effect (e.g., database write, API call, compute task).
*   **Outcome:** `EXECUTE_OK` or `EXECUTE_FAIL`.

---

## Core Rules & Invariants

The following invariants MUST be maintained by any implementation of CaPU:

1.  **Execution Safety:** `EXECUTE` MUST happen only **after** `COMMIT`. No side effects are allowed for uncommitted causes.
2.  **Rejection Finality:** `REJECT` never leads to `EXECUTE`.
3.  **Maturity Check:** `HOLD`/`DEFER` transitions to commit eligibility **only** when all defined preconditions are satisfied.
4.  **Explainability:** All CaPU runtime decisions (`PERMIT`, `HOLD`, `REJECT`, `EXPIRE`) MUST be explainable via standard [Decision Codes](DECISION_CODES.md).

---

## References

*   **Record Format:** CaPU consumes records defined by **vCML** (Virtual Causal Memory Layer).
    *   [vCML Spec](https://github.com/safal207/Causal-Memory-Layer/tree/main/vcml)
*   **Tracing:** CaPU emits telemetry adhering to the **T-Trace** JSONL format.
    *   [T-Trace Spec](https://github.com/safal207/T-Trace)

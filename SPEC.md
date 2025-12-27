# CaPU Specification

This document formally describes the architecture and logic of the Causal Processing Unit (CaPU).

## Core Components

The CaPU pipeline consists of four distinct stages:

### 1. Gate
**Function:** Entry point for all incoming causes.
*   **Validation:** Verifies the structural integrity of the vCML record.
*   **Optional Attestation:** If the vCML record includes record-level attestation/proofs, Gate may validate them as part of policy.
    *   **Note:** This is distinct from LPT transport/session crypto.
*   **Policy Decision:** Determines if the action is currently allowed based on policies, rate limits, or static rules.
*   **Outcome:** Can result in `ACCEPT`, `REJECT`, or `HOLD`.

### 2. Incubator
**Function:** Holding area for valid but premature causes.
*   **Purpose:** Handles causes that have passed initial validation but have unmet preconditions (e.g., waiting for a parent cause, time-lock, or quorum).
*   **Mechanism:** Periodically or event-driven re-evaluation of preconditions.
*   **Outcome:** Transitions to `ACCEPT` when preconditions are met, or `EXPIRE` if TTL is reached.

### 3. Commit
**Function:** The point of no return.
*   **Action:** Persists the accepted cause into the append-only causal memory.
*   **Guarantee:** Once committed, a cause is part of the immutable history.
*   **Outcome:** `COMMIT_OK` or `COMMIT_FAIL` (storage error).

### 4. Executor
**Function:** Bridge to the external world.
*   **Trigger:** strictly triggered *after* a successful commit.
*   **Action:** Interprets the cause and performs the actual side effect (e.g., database write, API call, compute task).
*   **Outcome:** `EXECUTE_OK` or `EXECUTE_FAIL`.

---

## Core Rules & Invariants

The following invariants MUST be maintained by any implementation of CaPU:

1.  **Execution Safety:** `EXECUTE` MUST happen only **after** `COMMIT`. No side effects are allowed for uncommitted causes.
2.  **Rejection Finality:** `REJECT` never leads to `EXECUTE`. A rejected cause is terminal.
3.  **Maturity Check:** `HOLD` transitions to `ACCEPT` **only** when all defined preconditions are satisfied.
4.  **Explainability:** All CaPU decisions (Accept, Reject, Hold) MUST be explainable via standard [Decision Codes](DECISION_CODES.md).

---

## References

*   **Record Format:** CaPU consumes records defined by **vCML** (Virtual Causal Memory Layer).
    *   [vCML Spec](https://github.com/safal207/Causal-Memory-Layer/tree/main/vcml)
*   **Tracing:** CaPU emits telemetry adhering to the **T-Trace** JSONL format.
    *   [T-Trace Spec](https://github.com/safal207/T-Trace)

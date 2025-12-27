# Executor Interface

This interface defines the contract for the side-effect engine.

## Responsibilities
*   **Bridge:** Connects the abstract causal commit to concrete system actions.
*   **Idempotency:** Implementations should handle potential re-delivery of the same committed cause (though CaPU strives to execute once).

## Methods

### `execute(effect_plan) -> Result<ExecutionReceipt, ExecutionError>`
 Performs the side effect described by the cause.

*   **Input:** `effect_plan`
    *   **Note:** The `effect_plan` is derived from the committed vCML record. It is an output of CaPU processing, formatted for the specific executor.
*   **Output:** `ExecutionReceipt`
    *   Contains status (`OK`, `FAIL`), timestamp, and any resulting artifacts or return values.

## Context
The Executor is **only** invoked after a successful `commit` in the Storage layer.

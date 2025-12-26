# Storage Interface

This interface defines the contract for the immutable causal memory.

## Responsibilities
*   **Append-Only:** New records can only be added, never modified or deleted.
*   **Integrity:** Ensures the stored data matches the accepted cause.

## Methods

### `commit(cause_record) -> Result<CauseId, StorageError>`
Persists a validated vCML record.
*   **Input:** Full vCML record.
*   **Output:** The unique ID (or hash) of the stored record, or an error.
*   **Guarantee:** On success, the record is durable.

### `get(cause_id) -> Result<CauseRecord, NotFound>`
Retrieves a record by its ID.
*   **Input:** Unique ID/Hash.
*   **Output:** The vCML record or error if not found.

### `exists(cause_id) -> boolean`
Quick check if a cause exists (useful for parent validation).

## Future Extensions
*   **Merkle Proofs:** Support for retrieving inclusion proofs.
*   **Hash Chain:** traversing the causal graph.

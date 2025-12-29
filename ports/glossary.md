# Ports Glossary

Short terms used in the CaPU port contracts.
See [DEPENDENCIES.md](../DEPENDENCIES.md) for canonical ownership and
[DECISION_CODES.md](../DECISION_CODES.md) for decision/reason enums.

- **CauseRecord (vCML):** Canonical causal record format defined by vCML.
- **CauseId:** Stable identifier for a cause record.
- **Decision:** One of ACCEPT/HOLD/REJECT/EXPIRE as listed in `DECISION_CODES.md`.
- **ReasonCode:** Standardized reason code (e.g. `MISSING_PARENT`).
- **Preconditions:** Policy or causal requirements that must be satisfied before commit.
- **CommitReceipt:** Proof that a cause was appended/committed.
- **EffectPlan:** Neutral plan of intended side effects derived after commit.
- **TraceEvent:** Structured device event emitted to a trace sink.
- **CorrelationId:** Optional `trace_id` used to connect events across systems.

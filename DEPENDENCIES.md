# Dependencies & Canonical Ownership

This document establishes the hard boundaries of the CaPU project. CaPU is a **permission-first execution runtime** for high-risk actions. It enforces a runtime lifecycle (**Gate -> Incubate -> Commit -> Execute**) so side effects occur only after permission, maturity, and durable commit.

## 1. CML / vCML (Causal Memory Layer)
* **Role:** Canonical causal and authorization record semantics.
* **Responsibility:** Defines what constitutes a causal record, including structure and serialization.
* **CaPU Relation:** CaPU consumes these records as input. CaPU does **NOT** define an alternative cause format.
* **Link:** [https://github.com/safal207/Causal-Memory-Layer/tree/main/vcml](https://github.com/safal207/Causal-Memory-Layer/tree/main/vcml)

## 2. LTP (Liminal Thread Protocol)
* **Role:** Canonical transport, session, and crypto layer.
* **Responsibility:** Handles secure delivery, ordering, replay protection, and admissibility/oversight flows outside CaPU's runtime core.
* **CaPU Relation:** CaPU is transport-agnostic and can accept input delivered by LTP. CaPU does **NOT** implement sockets, session management, or transport cryptography.
* **Note on signatures:** Record-level attestation checks (if present in vCML records) may be validated by CaPU policy, but those checks are distinct from LTP transport/session crypto.
* **Link:** [https://github.com/safal207/L-THREAD-Liminal-Thread-Secure-Protocol-LTP-/](https://github.com/safal207/L-THREAD-Liminal-Thread-Secure-Protocol-LTP-/)

## 3. T-Trace
* **Role:** Canonical observability and tracing.
* **Responsibility:** Defines trace formats, inspection workflows, and debug visualization for runtime events.
* **CaPU Relation:** CaPU emits deterministic lifecycle events into a trace sink. CaPU does **NOT** invent a separate tracing standard.
* **Link:** [https://github.com/safal207/T-Trace](https://github.com/safal207/T-Trace)

## 4. DRP / DMP
* **Role:** Governance policy and durable decision memory layers.
* **Responsibility:** Maintain policy governance and long-lived decision memory outside the execution boundary.
* **CaPU Relation:** CaPU depends on governance inputs and durable policy context but is **not** itself the governance or memory system.

## 5. CaPU (This Repository)
* **Role:** Execution-control runtime for side effects.
* **Responsibility:**
    * **Gate:** Validate record + permission decision.
    * **Incubate:** Hold/defer until maturity and preconditions are satisfied.
    * **Commit:** Durably authorize before side effects.
    * **Execute:** Permit side effects only after successful commit.

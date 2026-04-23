# Dependencies & Canonical Ownership

This document establishes the hard boundaries of the CaPU project. CaPU is a **permission-first execution runtime** for high-risk actions. It enforces a runtime lifecycle (**Gate -> Incubate -> Commit -> Execute**) so side effects occur only after permission, maturity, and durable commit.

## 1. CML / vCML (Causal Memory Layer)
* **Role:** Canonical causal and authorization record semantics.
* **Responsibility:** Defines what constitutes a causal record, including structure and serialization.
* **CaPU Relation:** CaPU consumes these records as input. CaPU does **NOT** define an alternative cause format.
* **Link:** [https://github.com/safal207/Causal-Memory-Layer/tree/main/vcml](https://github.com/safal207/Causal-Memory-Layer/tree/main/vcml)

## 2. LTP
* **Role:** Canonical boundary layer for ingress/egress transport compatibility, replay control, admissibility checks, and operational oversight.
* **Responsibility:** Provides delivery compatibility plus replay/inspection surfaces around the execution boundary.
* **CaPU Relation:** CaPU remains transport-agnostic and can accept causes delivered through LTP or equivalent adapters, while relying on LTP-aligned replay/admissibility context for boundary safety.
* **What CaPU does NOT do:** implement socket/session transport internals, transport crypto, or LTP governance workflows.
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
* **DRP Link:** [https://github.com/safal207/DRP](https://github.com/safal207/DRP)
* **DMP Link:** [https://github.com/safal207/DMP](https://github.com/safal207/DMP)

## 5. CaPU (This Repository)
* **Role:** Execution-control runtime for side effects.
* **Responsibility:**
    * **Gate:** Validate record + permission decision.
    * **Incubate:** Hold/defer until maturity and preconditions are satisfied.
    * **Commit:** Durably authorize before side effects.
    * **Execute:** Permit side effects only after successful commit.

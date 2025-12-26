# Dependencies & Canonical Ownership

This document establishes the hard boundaries of the CaPU project. CaPU is a **spec-first core** for causal decision-making. It strictly adheres to the following canonical dependencies and does **not** re-implement their responsibilities.

## 1. vCML (Virtual Causal Memory Layer)
* **Role:** Single source of truth for the **Causal Record Format**.
* **Responsibility:** Defines what constitutes a "cause", its structure, and serialization.
* **CaPU Relation:** CaPU references vCML records as input. CaPU does **NOT** introduce a new cause format.
* **Link:** [https://github.com/safal207/Causal-Memory-Layer/tree/main/vcml](https://github.com/safal207/Causal-Memory-Layer/tree/main/vcml)

## 2. LPT (Liminal Protocol Thread)
* **Role:** Canonical **Transport**, Session, and Crypto layer.
* **Responsibility:** Handles secure delivery of causes, session management, and cryptographic verification logic (signatures, encryption).
* **CaPU Relation:** CaPU is compatible with LPT as a delivery mechanism but remains transport-agnostic. CaPU does **NOT** implement transport logic or socket handling.
* **Link:** [https://github.com/safal207/L-THREAD-Liminal-Thread-Secure-Protocol-LTP-/](https://github.com/safal207/L-THREAD-Liminal-Thread-Secure-Protocol-LTP-/)

## 3. T-Trace
* **Role:** Canonical **Observability** and Tracing.
* **Responsibility:** Defines the JSONL trace format, trace inspection tools, and debug visualization.
* **CaPU Relation:** CaPU emits lifecycle events into a trace-sink interface. CaPU does **NOT** invent a new tracing format.
* **Link:** [https://github.com/safal207/T-Trace](https://github.com/safal207/T-Trace)

## 4. CaPU (This Repository)
* **Role:** Permission-based Causal Engine.
* **Responsibility:**
    * **Gate:** Validate cause & policy decision.
    * **Incubate:** Hold until preconditions mature.
    * **Commit:** Append-only commit to causal memory.
    * **Execute:** Bridge to external effects.

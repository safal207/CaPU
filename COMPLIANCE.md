# CaPU Compliance Specification (v0.1)

This document defines the minimum requirements for a system to be considered
**CaPU-compliant**.

Keywords **MUST**, **SHOULD**, and **MAY** are to be interpreted as described in RFC 2119.

---

## 1. Scope

This specification defines compliance at the **device boundary** level.
It does not mandate any specific runtime, language, or execution environment.

---

## 2. Core Principles

A CaPU-compliant system MUST:
- process **causes**, not commands
- separate **decision** from **execution**
- make all transitions **traceable and replayable**
- prevent side effects before causal permission

---

## 3. Required Interfaces

A compliant CaPU MUST expose the following logical ports:

- **CauseIn**
- **PermissionOut**
- **EffectOut**
- **TraceOut**

The physical or transport implementation of ports is out of scope.

---

## 4. Processing Stages

A compliant CaPU MUST implement the following stages in order:

1. Gate
2. Incubate
3. Commit
4. Execute

Skipping or reordering stages is NOT permitted.

---

## 5. Decision Semantics

- Every input cause MUST result in exactly one decision.
- Decisions MUST be explicit (no implicit fallthrough).
- A decision MUST be emitted before any side effect.

---

## 6. Traceability

A compliant CaPU MUST:
- emit a trace record for every decision
- include a stable **decision_code**
- support deterministic replay given the same input and state

---

## 7. Side Effects

- Side effects MUST NOT occur before Commit.
- Side effects MUST be derivable from the committed decision.
- Side effects MAY be executed asynchronously after Commit.

---

## 8. Versioning

- Decision codes are considered part of the public contract.
- Existing decision codes MUST NOT change semantics.
- New codes MAY be added in a backward-compatible manner.

---

## 9. Non-Goals

CaPU compliance does NOT imply:
- transport guarantees
- policy completeness
- ML-based decision making
- global orchestration

---

## 10. Compliance Statement

A system MAY claim CaPU compliance only if all MUST requirements
in this document are satisfied.

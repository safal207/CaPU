# CaPU glossary

Practical definitions for terms used by the software reference, hardware experiments, and review documents.

| Term | Definition |
|---|---|
| **Gate** | The first decision point. It validates the record, identity, cause, and policy before work may proceed. |
| **Incubate** | A bounded hold state for permitted work whose maturity or required context is not available yet. |
| **Commit** | The durable authorization boundary that must succeed before an externally visible effect is allowed. |
| **Execute** | The step that allows the authorized effect to reach a device, service, memory location, or other external target. |
| **Side effect** | A change outside the current decision, such as a write, message, payment, actuator command, or device operation. |
| **Causal record** | A record binding an action to its actor, object, cause, policy/permission, identity, and relevant evidence. |
| **Permission** | A policy decision allowing a specific action and identity to continue. Permission alone is not a commit or proof of execution. |
| **Maturity** | The point at which all required parent state, time, evidence, and preconditions for a permitted action are available. |
| **Durable commit** | Authorization recorded in state that survives the failure boundary claimed by the implementation. The exact durability boundary must be stated. |
| **Decision code** | A stable machine-readable reason for accepting, rejecting, or holding a transition. |
| **TraceOut** | The output stream of lifecycle decisions and evidence used for deterministic review, replay, and audit. |
| **Commit-before-effect** | The invariant that no externally visible execution may occur before successful commit for the same action identity. |
| **Causal co-processor** | A controller or adjacent processing block that gates effects using causal authority; it is not a claim of a complete CPU, GPU, or production chip. |
| **Authority ticket** | A committed record identifying exactly which command, attempt, effect, epoch, and resource may execute. |
| **Outcome evidence** | Evidence that discriminates whether the intended effect was committed, not committed, conflicting, or still unknown. |
| **Proof receipt** | A terminal record binding authority, execution evidence, outcome evidence, and the resulting state commitment. |
| **UNKNOWN** | An ambiguous completion state. It grants no success, retirement, trusted-memory update, or blind replay authority. |

These definitions describe repository contracts and bounded experiments. They do not imply production hardware, certification, or cryptographic authenticity unless a narrower document explicitly demonstrates those properties.

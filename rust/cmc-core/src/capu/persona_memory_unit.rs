use super::cause_unit::{check_cause_present, CauseCheck};
use super::transition::{Boundary, DecisionClass, Transition, UnitDecision};

/// Check P1: persona memory writes require explicit causal support.
pub fn check_persona_memory_cause(transition: &Transition) -> UnitDecision {
    let cause_check = check_cause_present(transition.cause_id);

    match cause_check {
        CauseCheck::Missing => UnitDecision {
            class: DecisionClass::Reject,
            code: "REJECT_PERSONA_MEMORY_WITHOUT_CAUSE",
            invariant_id: "P1",
            boundary: Boundary::PersonaMemoryRequiresCause,
            verdict: "blocked_persona_memory_without_cause",
            cause_id: None,
        },
        CauseCheck::Present(_) => UnitDecision {
            class: DecisionClass::Accept,
            code: "ACCEPT_PERSONA_MEMORY_WITH_CAUSE",
            invariant_id: "P1",
            boundary: Boundary::PersonaMemoryRequiresCause,
            verdict: "accepted_persona_memory_with_cause",
            cause_id: cause_check.cause_id(),
        },
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::capu::decoder::{decode_persona_memory, PersonaMemoryRequest};

    #[test]
    fn p1_rejects_persona_memory_without_cause() {
        let transition = decode_persona_memory(PersonaMemoryRequest::new(
            "p1-unconfirmed-memory",
            "prefers concise technical summaries",
            None,
        ));

        let decision = check_persona_memory_cause(&transition);

        assert_eq!(decision.class, DecisionClass::Reject);
        assert_eq!(decision.code, "REJECT_PERSONA_MEMORY_WITHOUT_CAUSE");
        assert_eq!(decision.invariant_id, "P1");
        assert_eq!(decision.boundary, Boundary::PersonaMemoryRequiresCause);
        assert_eq!(decision.verdict, "blocked_persona_memory_without_cause");
        assert_eq!(decision.cause_id, None);
    }

    #[test]
    fn p1_accepts_persona_memory_with_cause() {
        let transition = decode_persona_memory(PersonaMemoryRequest::new(
            "p1-confirmed-memory",
            "prefers concise technical summaries",
            Some(42),
        ));

        let decision = check_persona_memory_cause(&transition);

        assert_eq!(decision.class, DecisionClass::Accept);
        assert_eq!(decision.code, "ACCEPT_PERSONA_MEMORY_WITH_CAUSE");
        assert_eq!(decision.invariant_id, "P1");
        assert_eq!(decision.boundary, Boundary::PersonaMemoryRequiresCause);
        assert_eq!(decision.verdict, "accepted_persona_memory_with_cause");
        assert_eq!(decision.cause_id, Some(42));
    }
}

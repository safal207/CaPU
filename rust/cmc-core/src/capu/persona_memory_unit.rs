use super::cause_unit::{check_cause_present, CauseCheck};
use super::decision_codes::p1;
use super::transition::{Boundary, DecisionClass, Transition, UnitDecision};

/// Check P1: persona memory writes require explicit causal support.
pub fn check_persona_memory_cause(transition: &Transition) -> UnitDecision {
    let cause_check = check_cause_present(transition.cause_id);

    match cause_check {
        CauseCheck::Missing => UnitDecision {
            class: DecisionClass::Reject,
            code: p1::REJECT_WITHOUT_CAUSE,
            invariant_id: p1::INVARIANT_ID,
            boundary: Boundary::PersonaMemoryRequiresCause,
            verdict: p1::VERDICT_BLOCKED_WITHOUT_CAUSE,
            cause_id: None,
        },
        CauseCheck::Present(_) => UnitDecision {
            class: DecisionClass::Accept,
            code: p1::ACCEPT_WITH_CAUSE,
            invariant_id: p1::INVARIANT_ID,
            boundary: Boundary::PersonaMemoryRequiresCause,
            verdict: p1::VERDICT_ACCEPTED_WITH_CAUSE,
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
        assert_eq!(decision.code, p1::REJECT_WITHOUT_CAUSE);
        assert_eq!(decision.invariant_id, p1::INVARIANT_ID);
        assert_eq!(decision.boundary, Boundary::PersonaMemoryRequiresCause);
        assert_eq!(decision.verdict, p1::VERDICT_BLOCKED_WITHOUT_CAUSE);
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
        assert_eq!(decision.code, p1::ACCEPT_WITH_CAUSE);
        assert_eq!(decision.invariant_id, p1::INVARIANT_ID);
        assert_eq!(decision.boundary, Boundary::PersonaMemoryRequiresCause);
        assert_eq!(decision.verdict, p1::VERDICT_ACCEPTED_WITH_CAUSE);
        assert_eq!(decision.cause_id, Some(42));
    }
}

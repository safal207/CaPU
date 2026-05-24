use super::decision_codes::p3;
use super::transition::{Boundary, DecisionClass, Transition, UnitDecision};

/// Check that introspection transitions are explicitly labeled as hypotheses.
///
/// v0 uses `Transition.object` as the hypothesis label field for this narrow
/// software reference unit. A later typed decoder can promote this into a
/// dedicated IntrospectionRequest/HypothesisLabel type without changing the
/// invariant semantics.
pub fn check_introspection_hypothesis_label(transition: &Transition) -> UnitDecision {
    let has_label = transition
        .object
        .as_deref()
        .is_some_and(|label| !label.trim().is_empty());

    if has_label {
        UnitDecision {
            class: DecisionClass::Accept,
            code: p3::ACCEPT_WITH_HYPOTHESIS_LABEL,
            invariant_id: p3::INVARIANT_ID,
            boundary: Boundary::IntrospectionRequiresHypothesisLabel,
            verdict: p3::VERDICT_ACCEPTED_WITH_HYPOTHESIS_LABEL,
            cause_id: transition.cause_id,
        }
    } else {
        UnitDecision {
            class: DecisionClass::Reject,
            code: p3::REJECT_WITHOUT_HYPOTHESIS_LABEL,
            invariant_id: p3::INVARIANT_ID,
            boundary: Boundary::IntrospectionRequiresHypothesisLabel,
            verdict: p3::VERDICT_BLOCKED_WITHOUT_HYPOTHESIS_LABEL,
            cause_id: transition.cause_id,
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::capu::transition::TransitionType;

    fn introspection_transition(label: Option<&str>) -> Transition {
        Transition {
            transition_id: "introspection-check".to_string(),
            transition_type: TransitionType::Introspection,
            actor: Some("agent".to_string()),
            action_kind: Some("self_assessment".to_string()),
            object: label.map(str::to_string),
            cause_id: Some(303),
            parent_cause: None,
            authorization: None,
            commit: None,
            boundary: Boundary::IntrospectionRequiresHypothesisLabel,
        }
    }

    #[test]
    fn accepts_introspection_with_hypothesis_label() {
        let transition = introspection_transition(Some("hypothesis:memory-drift-risk"));
        let decision = check_introspection_hypothesis_label(&transition);

        assert_eq!(decision.class, DecisionClass::Accept);
        assert!(decision.accepted());
        assert_eq!(decision.code, p3::ACCEPT_WITH_HYPOTHESIS_LABEL);
        assert_eq!(decision.invariant_id, p3::INVARIANT_ID);
        assert_eq!(decision.boundary, Boundary::IntrospectionRequiresHypothesisLabel);
        assert_eq!(decision.verdict, p3::VERDICT_ACCEPTED_WITH_HYPOTHESIS_LABEL);
        assert_eq!(decision.cause_id, Some(303));
    }

    #[test]
    fn rejects_introspection_without_hypothesis_label() {
        let transition = introspection_transition(None);
        let decision = check_introspection_hypothesis_label(&transition);

        assert_eq!(decision.class, DecisionClass::Reject);
        assert!(!decision.accepted());
        assert_eq!(decision.code, p3::REJECT_WITHOUT_HYPOTHESIS_LABEL);
        assert_eq!(decision.invariant_id, p3::INVARIANT_ID);
        assert_eq!(decision.boundary, Boundary::IntrospectionRequiresHypothesisLabel);
        assert_eq!(decision.verdict, p3::VERDICT_BLOCKED_WITHOUT_HYPOTHESIS_LABEL);
    }

    #[test]
    fn rejects_introspection_with_blank_hypothesis_label() {
        let transition = introspection_transition(Some("   "));
        let decision = check_introspection_hypothesis_label(&transition);

        assert_eq!(decision.class, DecisionClass::Reject);
        assert_eq!(decision.code, p3::REJECT_WITHOUT_HYPOTHESIS_LABEL);
        assert_eq!(decision.verdict, p3::VERDICT_BLOCKED_WITHOUT_HYPOTHESIS_LABEL);
    }
}

use super::transition::{Boundary, DecisionClass, Transition, UnitDecision};

/// Check explicit authorization for persona-state transitions.
///
/// v0 keeps this deliberately narrow: persona state changes are accepted only
/// when the transition carries `authorization=true`. Missing or false
/// authorization is rejected rather than held, because this boundary is already
/// explicit in the semantic ISA.
pub fn check_persona_state_change_authorization(transition: &Transition) -> UnitDecision {
    match transition.authorization {
        Some(true) => UnitDecision {
            class: DecisionClass::Accept,
            code: "ACCEPT_PERSONA_STATE_CHANGE_WITH_AUTHORIZATION",
            invariant_id: "P2",
            boundary: Boundary::PersonaStateChangeRequiresAuthorization,
            verdict: "accepted_persona_state_change_with_authorization",
            cause_id: transition.cause_id,
        },
        Some(false) => UnitDecision {
            class: DecisionClass::Reject,
            code: "REJECT_PERSONA_STATE_CHANGE_WITH_DENIED_AUTHORIZATION",
            invariant_id: "P2",
            boundary: Boundary::PersonaStateChangeRequiresAuthorization,
            verdict: "blocked_persona_state_change_denied_authorization",
            cause_id: transition.cause_id,
        },
        None => UnitDecision {
            class: DecisionClass::Reject,
            code: "REJECT_PERSONA_STATE_CHANGE_WITHOUT_AUTHORIZATION",
            invariant_id: "P2",
            boundary: Boundary::PersonaStateChangeRequiresAuthorization,
            verdict: "blocked_persona_state_change_without_authorization",
            cause_id: transition.cause_id,
        },
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::capu::transition::{TransitionType};

    fn persona_state_transition(authorization: Option<bool>) -> Transition {
        Transition {
            transition_id: "persona-state-change".to_string(),
            transition_type: TransitionType::PersonaStateChange,
            actor: Some("agent".to_string()),
            action_kind: Some("persona_state_update".to_string()),
            object: Some("tone=more_careful".to_string()),
            cause_id: Some(77),
            parent_cause: None,
            authorization,
            commit: None,
            boundary: Boundary::PersonaStateChangeRequiresAuthorization,
        }
    }

    #[test]
    fn accepts_persona_state_change_with_authorization() {
        let transition = persona_state_transition(Some(true));
        let decision = check_persona_state_change_authorization(&transition);

        assert_eq!(decision.class, DecisionClass::Accept);
        assert!(decision.accepted());
        assert_eq!(decision.code, "ACCEPT_PERSONA_STATE_CHANGE_WITH_AUTHORIZATION");
        assert_eq!(decision.invariant_id, "P2");
        assert_eq!(decision.boundary, Boundary::PersonaStateChangeRequiresAuthorization);
        assert_eq!(decision.verdict, "accepted_persona_state_change_with_authorization");
        assert_eq!(decision.cause_id, Some(77));
    }

    #[test]
    fn rejects_persona_state_change_with_denied_authorization() {
        let transition = persona_state_transition(Some(false));
        let decision = check_persona_state_change_authorization(&transition);

        assert_eq!(decision.class, DecisionClass::Reject);
        assert!(!decision.accepted());
        assert_eq!(decision.code, "REJECT_PERSONA_STATE_CHANGE_WITH_DENIED_AUTHORIZATION");
        assert_eq!(decision.invariant_id, "P2");
        assert_eq!(decision.boundary, Boundary::PersonaStateChangeRequiresAuthorization);
        assert_eq!(decision.verdict, "blocked_persona_state_change_denied_authorization");
    }

    #[test]
    fn rejects_persona_state_change_without_authorization() {
        let transition = persona_state_transition(None);
        let decision = check_persona_state_change_authorization(&transition);

        assert_eq!(decision.class, DecisionClass::Reject);
        assert!(!decision.accepted());
        assert_eq!(decision.code, "REJECT_PERSONA_STATE_CHANGE_WITHOUT_AUTHORIZATION");
        assert_eq!(decision.invariant_id, "P2");
        assert_eq!(decision.boundary, Boundary::PersonaStateChangeRequiresAuthorization);
        assert_eq!(decision.verdict, "blocked_persona_state_change_without_authorization");
    }
}

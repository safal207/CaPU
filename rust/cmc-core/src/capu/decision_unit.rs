use super::authorization_unit::check_persona_state_change_authorization;
use super::boundary_router::boundary_matches_route;
use super::commit_unit::check_external_action_commit;
use super::hypothesis_unit::check_introspection_hypothesis_label;
use super::persona_memory_unit::check_persona_memory_cause;
use super::transition::{DecisionClass, Transition, TransitionType, UnitDecision};
#[cfg(test)]
use super::transition::Boundary;

/// Evaluate a typed transition through the CaPU software reference pipeline.
///
/// v0 fully executes P6 external-action decisions, P1 persona-memory cause
/// decisions, P2 persona-state authorization decisions, and P3 introspection
/// hypothesis-label decisions. Other boundaries return HOLD so they can be
/// implemented incrementally without pretending they are rejected or accepted by
/// a unit that does not exist yet.
pub fn decide_transition(transition: &Transition) -> UnitDecision {
    if !boundary_matches_route(transition) {
        return UnitDecision {
            class: DecisionClass::Reject,
            code: "REJECT_BOUNDARY_ROUTE_MISMATCH",
            invariant_id: "CAPU",
            boundary: transition.boundary,
            verdict: "boundary_route_mismatch",
            cause_id: transition.cause_id,
        };
    }

    match transition.transition_type {
        TransitionType::ExternalAction => check_external_action_commit(transition),
        TransitionType::PersonaMemory => check_persona_memory_cause(transition),
        TransitionType::PersonaStateChange => check_persona_state_change_authorization(transition),
        TransitionType::Introspection => check_introspection_hypothesis_label(transition),
        _ => hold_unimplemented_boundary(transition),
    }
}

fn hold_unimplemented_boundary(transition: &Transition) -> UnitDecision {
    UnitDecision {
        class: DecisionClass::Hold,
        code: "HOLD_UNIMPLEMENTED_BOUNDARY",
        invariant_id: "CAPU",
        boundary: transition.boundary,
        verdict: "hold_unimplemented_boundary",
        cause_id: transition.cause_id,
    }
}

/// Construct a minimal transition for tests or future decoder expansion.
#[cfg(test)]
fn test_transition(transition_type: TransitionType, boundary: Boundary) -> Transition {
    Transition {
        transition_id: "test-transition".to_string(),
        transition_type,
        actor: None,
        action_kind: None,
        object: None,
        cause_id: None,
        parent_cause: None,
        authorization: None,
        commit: None,
        boundary,
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::capu::decoder::{
        decode_external_action, decode_persona_memory, ExternalActionRequest, PersonaMemoryRequest,
    };

    #[test]
    fn decision_unit_rejects_p6_uncommitted_external_action() {
        let transition = decode_external_action(ExternalActionRequest::new(
            "tx-uncommitted",
            "send_email",
            None,
            false,
        ));

        let decision = decide_transition(&transition);

        assert_eq!(decision.class, DecisionClass::Reject);
        assert_eq!(decision.code, "REJECT_ACTION_WITHOUT_COMMIT");
        assert_eq!(decision.invariant_id, "P6");
        assert_eq!(decision.boundary, Boundary::ActionRequiresCommit);
        assert_eq!(decision.verdict, "blocked_action_without_commit");
    }

    #[test]
    fn decision_unit_accepts_p6_committed_external_action() {
        let transition = decode_external_action(ExternalActionRequest::new(
            "tx-committed",
            "send_email",
            Some(101),
            true,
        ));

        let decision = decide_transition(&transition);

        assert_eq!(decision.class, DecisionClass::Accept);
        assert_eq!(decision.code, "ACCEPT_COMMITTED_ACTION");
        assert_eq!(decision.invariant_id, "P6");
        assert_eq!(decision.boundary, Boundary::ActionRequiresCommit);
        assert_eq!(decision.verdict, "accepted_committed_action");
        assert_eq!(decision.cause_id, Some(101));
    }

    #[test]
    fn decision_unit_rejects_p1_persona_memory_without_cause() {
        let transition = decode_persona_memory(PersonaMemoryRequest::new(
            "tx-p1-reject",
            "raw inferred preference",
            None,
        ));

        let decision = decide_transition(&transition);

        assert_eq!(decision.class, DecisionClass::Reject);
        assert_eq!(decision.code, "REJECT_PERSONA_MEMORY_WITHOUT_CAUSE");
        assert_eq!(decision.invariant_id, "P1");
        assert_eq!(decision.boundary, Boundary::PersonaMemoryRequiresCause);
        assert_eq!(decision.verdict, "blocked_persona_memory_without_cause");
    }

    #[test]
    fn decision_unit_accepts_p1_persona_memory_with_cause() {
        let transition = decode_persona_memory(PersonaMemoryRequest::new(
            "tx-p1-accept",
            "confirmed preference",
            Some(42),
        ));

        let decision = decide_transition(&transition);

        assert_eq!(decision.class, DecisionClass::Accept);
        assert_eq!(decision.code, "ACCEPT_PERSONA_MEMORY_WITH_CAUSE");
        assert_eq!(decision.invariant_id, "P1");
        assert_eq!(decision.boundary, Boundary::PersonaMemoryRequiresCause);
        assert_eq!(decision.verdict, "accepted_persona_memory_with_cause");
        assert_eq!(decision.cause_id, Some(42));
    }

    #[test]
    fn decision_unit_accepts_p2_persona_state_change_with_authorization() {
        let mut transition = test_transition(
            TransitionType::PersonaStateChange,
            Boundary::PersonaStateChangeRequiresAuthorization,
        );
        transition.authorization = Some(true);
        transition.cause_id = Some(77);

        let decision = decide_transition(&transition);

        assert_eq!(decision.class, DecisionClass::Accept);
        assert_eq!(decision.code, "ACCEPT_PERSONA_STATE_CHANGE_WITH_AUTHORIZATION");
        assert_eq!(decision.invariant_id, "P2");
        assert_eq!(decision.boundary, Boundary::PersonaStateChangeRequiresAuthorization);
        assert_eq!(decision.verdict, "accepted_persona_state_change_with_authorization");
        assert_eq!(decision.cause_id, Some(77));
    }

    #[test]
    fn decision_unit_rejects_p2_persona_state_change_without_authorization() {
        let transition = test_transition(
            TransitionType::PersonaStateChange,
            Boundary::PersonaStateChangeRequiresAuthorization,
        );

        let decision = decide_transition(&transition);

        assert_eq!(decision.class, DecisionClass::Reject);
        assert_eq!(decision.code, "REJECT_PERSONA_STATE_CHANGE_WITHOUT_AUTHORIZATION");
        assert_eq!(decision.invariant_id, "P2");
        assert_eq!(decision.boundary, Boundary::PersonaStateChangeRequiresAuthorization);
        assert_eq!(decision.verdict, "blocked_persona_state_change_without_authorization");
    }

    #[test]
    fn decision_unit_accepts_p3_introspection_with_hypothesis_label() {
        let mut transition = test_transition(
            TransitionType::Introspection,
            Boundary::IntrospectionRequiresHypothesisLabel,
        );
        transition.object = Some("hypothesis:memory-drift-risk".to_string());
        transition.cause_id = Some(303);

        let decision = decide_transition(&transition);

        assert_eq!(decision.class, DecisionClass::Accept);
        assert_eq!(decision.code, "ACCEPT_INTROSPECTION_WITH_HYPOTHESIS_LABEL");
        assert_eq!(decision.invariant_id, "P3");
        assert_eq!(decision.boundary, Boundary::IntrospectionRequiresHypothesisLabel);
        assert_eq!(decision.verdict, "accepted_introspection_with_hypothesis_label");
        assert_eq!(decision.cause_id, Some(303));
    }

    #[test]
    fn decision_unit_rejects_p3_introspection_without_hypothesis_label() {
        let transition = test_transition(
            TransitionType::Introspection,
            Boundary::IntrospectionRequiresHypothesisLabel,
        );

        let decision = decide_transition(&transition);

        assert_eq!(decision.class, DecisionClass::Reject);
        assert_eq!(decision.code, "REJECT_INTROSPECTION_WITHOUT_HYPOTHESIS_LABEL");
        assert_eq!(decision.invariant_id, "P3");
        assert_eq!(decision.boundary, Boundary::IntrospectionRequiresHypothesisLabel);
        assert_eq!(decision.verdict, "blocked_introspection_without_hypothesis_label");
    }

    #[test]
    fn decision_unit_holds_boundaries_not_implemented_yet() {
        let transition = test_transition(TransitionType::MemoryWrite, Boundary::WriteAuthorization);

        let decision = decide_transition(&transition);

        assert_eq!(decision.class, DecisionClass::Hold);
        assert_eq!(decision.code, "HOLD_UNIMPLEMENTED_BOUNDARY");
        assert_eq!(decision.invariant_id, "CAPU");
        assert_eq!(decision.boundary, Boundary::WriteAuthorization);
        assert_eq!(decision.verdict, "hold_unimplemented_boundary");
    }

    #[test]
    fn decision_unit_rejects_boundary_route_mismatch() {
        let transition = test_transition(
            TransitionType::ExternalAction,
            Boundary::PersonaMemoryRequiresCause,
        );

        let decision = decide_transition(&transition);

        assert_eq!(decision.class, DecisionClass::Reject);
        assert_eq!(decision.code, "REJECT_BOUNDARY_ROUTE_MISMATCH");
        assert_eq!(decision.invariant_id, "CAPU");
        assert_eq!(decision.boundary, Boundary::PersonaMemoryRequiresCause);
        assert_eq!(decision.verdict, "boundary_route_mismatch");
    }
}

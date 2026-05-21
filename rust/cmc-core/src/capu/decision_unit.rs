use super::boundary_router::boundary_matches_route;
use super::commit_unit::check_external_action_commit;
use super::transition::{Boundary, DecisionClass, Transition, TransitionType, UnitDecision};

/// Evaluate a typed transition through the CaPU software reference pipeline.
///
/// v0 only fully executes P6 external-action decisions. Other boundaries return
/// HOLD so they can be implemented incrementally without pretending they are
/// rejected or accepted by a unit that does not exist yet.
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
    use crate::capu::decoder::{decode_external_action, ExternalActionRequest};

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
    fn decision_unit_holds_boundaries_not_implemented_yet() {
        let transition = test_transition(
            TransitionType::PersonaMemory,
            Boundary::PersonaMemoryRequiresCause,
        );

        let decision = decide_transition(&transition);

        assert_eq!(decision.class, DecisionClass::Hold);
        assert_eq!(decision.code, "HOLD_UNIMPLEMENTED_BOUNDARY");
        assert_eq!(decision.invariant_id, "CAPU");
        assert_eq!(decision.boundary, Boundary::PersonaMemoryRequiresCause);
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

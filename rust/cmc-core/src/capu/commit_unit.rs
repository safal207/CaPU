use super::cause_unit::{check_cause_present, CauseCheck};
use super::transition::{Boundary, DecisionClass, Transition, TransitionType, UnitDecision};

/// Enforce P6: external action requires committed causal authorization.
///
/// This is the first software reference unit extracted from the CaPU
/// microarchitecture. It is deliberately pure and side-effect free so it can be
/// reused by future decoders, sidecars, and fixture verifiers.
pub fn check_external_action_commit(transition: &Transition) -> UnitDecision {
    if transition.transition_type != TransitionType::ExternalAction
        || transition.boundary != Boundary::ActionRequiresCommit
    {
        return UnitDecision {
            class: DecisionClass::Reject,
            code: "REJECT_INVALID_COMMIT_CHECK_TARGET",
            invariant_id: "P6",
            boundary: transition.boundary,
            verdict: "invalid_commit_check_target",
            cause_id: transition.cause_id,
        };
    }

    if transition.commit != Some(true) {
        return UnitDecision {
            class: DecisionClass::Reject,
            code: "REJECT_ACTION_WITHOUT_COMMIT",
            invariant_id: "P6",
            boundary: Boundary::ActionRequiresCommit,
            verdict: "blocked_action_without_commit",
            cause_id: None,
        };
    }

    let CauseCheck::Present(cause_id) = check_cause_present(transition.cause_id) else {
        return UnitDecision {
            class: DecisionClass::Reject,
            code: "REJECT_ACTION_WITHOUT_CAUSE",
            invariant_id: "P6",
            boundary: Boundary::ActionRequiresCommit,
            verdict: "blocked_action_without_cause",
            cause_id: None,
        };
    };

    UnitDecision {
        class: DecisionClass::Accept,
        code: "ACCEPT_COMMITTED_ACTION",
        invariant_id: "P6",
        boundary: Boundary::ActionRequiresCommit,
        verdict: "accepted_committed_action",
        cause_id: Some(cause_id),
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn p6_rejects_external_action_without_commit() {
        let transition = Transition::external_action("p6-uncommitted", "send_email", None, false);

        let decision = check_external_action_commit(&transition);

        assert_eq!(decision.class, DecisionClass::Reject);
        assert_eq!(decision.code, "REJECT_ACTION_WITHOUT_COMMIT");
        assert_eq!(decision.invariant_id, "P6");
        assert_eq!(decision.boundary, Boundary::ActionRequiresCommit);
        assert_eq!(decision.verdict, "blocked_action_without_commit");
        assert_eq!(decision.cause_id, None);
        assert!(!decision.accepted());
    }

    #[test]
    fn p6_accepts_external_action_with_commit_and_cause() {
        let transition = Transition::external_action("p6-committed", "send_email", Some(101), true);

        let decision = check_external_action_commit(&transition);

        assert_eq!(decision.class, DecisionClass::Accept);
        assert_eq!(decision.code, "ACCEPT_COMMITTED_ACTION");
        assert_eq!(decision.invariant_id, "P6");
        assert_eq!(decision.boundary, Boundary::ActionRequiresCommit);
        assert_eq!(decision.verdict, "accepted_committed_action");
        assert_eq!(decision.cause_id, Some(101));
        assert!(decision.accepted());
    }

    #[test]
    fn p6_rejects_committed_external_action_without_cause() {
        let transition = Transition::external_action("p6-no-cause", "send_email", None, true);

        let decision = check_external_action_commit(&transition);

        assert_eq!(decision.class, DecisionClass::Reject);
        assert_eq!(decision.code, "REJECT_ACTION_WITHOUT_CAUSE");
        assert_eq!(decision.verdict, "blocked_action_without_cause");
        assert_eq!(decision.cause_id, None);
    }
}

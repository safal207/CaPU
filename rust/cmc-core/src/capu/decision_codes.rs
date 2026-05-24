//! Stable decision code and verdict constants for CaPU software reference units.
//!
//! These constants keep reviewer-visible decision codes centralized while
//! preserving the exact strings already used by tests, fixtures, and docs.

pub mod p1 {
    pub const INVARIANT_ID: &str = "P1";

    pub const ACCEPT_WITH_CAUSE: &str = "ACCEPT_PERSONA_MEMORY_WITH_CAUSE";
    pub const REJECT_WITHOUT_CAUSE: &str = "REJECT_PERSONA_MEMORY_WITHOUT_CAUSE";

    pub const VERDICT_ACCEPTED_WITH_CAUSE: &str = "accepted_persona_memory_with_cause";
    pub const VERDICT_BLOCKED_WITHOUT_CAUSE: &str = "blocked_persona_memory_without_cause";
}

pub mod p2 {
    pub const INVARIANT_ID: &str = "P2";

    pub const ACCEPT_WITH_AUTHORIZATION: &str = "ACCEPT_PERSONA_STATE_CHANGE_WITH_AUTHORIZATION";
    pub const REJECT_DENIED_AUTHORIZATION: &str =
        "REJECT_PERSONA_STATE_CHANGE_WITH_DENIED_AUTHORIZATION";
    pub const REJECT_WITHOUT_AUTHORIZATION: &str =
        "REJECT_PERSONA_STATE_CHANGE_WITHOUT_AUTHORIZATION";

    pub const VERDICT_ACCEPTED_WITH_AUTHORIZATION: &str =
        "accepted_persona_state_change_with_authorization";
    pub const VERDICT_BLOCKED_DENIED_AUTHORIZATION: &str =
        "blocked_persona_state_change_denied_authorization";
    pub const VERDICT_BLOCKED_WITHOUT_AUTHORIZATION: &str =
        "blocked_persona_state_change_without_authorization";
}

pub mod p3 {
    pub const INVARIANT_ID: &str = "P3";

    pub const ACCEPT_WITH_HYPOTHESIS_LABEL: &str = "ACCEPT_INTROSPECTION_WITH_HYPOTHESIS_LABEL";
    pub const REJECT_WITHOUT_HYPOTHESIS_LABEL: &str =
        "REJECT_INTROSPECTION_WITHOUT_HYPOTHESIS_LABEL";

    pub const VERDICT_ACCEPTED_WITH_HYPOTHESIS_LABEL: &str =
        "accepted_introspection_with_hypothesis_label";
    pub const VERDICT_BLOCKED_WITHOUT_HYPOTHESIS_LABEL: &str =
        "blocked_introspection_without_hypothesis_label";
}

pub mod p6 {
    pub const INVARIANT_ID: &str = "P6";

    pub const ACCEPT_COMMITTED_ACTION: &str = "ACCEPT_COMMITTED_ACTION";
    pub const REJECT_INVALID_COMMIT_CHECK_TARGET: &str = "REJECT_INVALID_COMMIT_CHECK_TARGET";
    pub const REJECT_ACTION_WITHOUT_COMMIT: &str = "REJECT_ACTION_WITHOUT_COMMIT";
    pub const REJECT_ACTION_WITHOUT_CAUSE: &str = "REJECT_ACTION_WITHOUT_CAUSE";

    pub const VERDICT_ACCEPTED_COMMITTED_ACTION: &str = "accepted_committed_action";
    pub const VERDICT_INVALID_COMMIT_CHECK_TARGET: &str = "invalid_commit_check_target";
    pub const VERDICT_BLOCKED_ACTION_WITHOUT_COMMIT: &str = "blocked_action_without_commit";
    pub const VERDICT_BLOCKED_ACTION_WITHOUT_CAUSE: &str = "blocked_action_without_cause";
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn p1_codes_are_stable() {
        assert_eq!(p1::INVARIANT_ID, "P1");
        assert_eq!(p1::ACCEPT_WITH_CAUSE, "ACCEPT_PERSONA_MEMORY_WITH_CAUSE");
        assert_eq!(p1::REJECT_WITHOUT_CAUSE, "REJECT_PERSONA_MEMORY_WITHOUT_CAUSE");
    }

    #[test]
    fn p2_codes_are_stable() {
        assert_eq!(p2::INVARIANT_ID, "P2");
        assert_eq!(
            p2::ACCEPT_WITH_AUTHORIZATION,
            "ACCEPT_PERSONA_STATE_CHANGE_WITH_AUTHORIZATION"
        );
        assert_eq!(
            p2::REJECT_DENIED_AUTHORIZATION,
            "REJECT_PERSONA_STATE_CHANGE_WITH_DENIED_AUTHORIZATION"
        );
        assert_eq!(
            p2::REJECT_WITHOUT_AUTHORIZATION,
            "REJECT_PERSONA_STATE_CHANGE_WITHOUT_AUTHORIZATION"
        );
    }

    #[test]
    fn p3_codes_are_stable() {
        assert_eq!(p3::INVARIANT_ID, "P3");
        assert_eq!(
            p3::ACCEPT_WITH_HYPOTHESIS_LABEL,
            "ACCEPT_INTROSPECTION_WITH_HYPOTHESIS_LABEL"
        );
        assert_eq!(
            p3::REJECT_WITHOUT_HYPOTHESIS_LABEL,
            "REJECT_INTROSPECTION_WITHOUT_HYPOTHESIS_LABEL"
        );
    }

    #[test]
    fn p6_codes_are_stable() {
        assert_eq!(p6::INVARIANT_ID, "P6");
        assert_eq!(p6::ACCEPT_COMMITTED_ACTION, "ACCEPT_COMMITTED_ACTION");
        assert_eq!(
            p6::REJECT_INVALID_COMMIT_CHECK_TARGET,
            "REJECT_INVALID_COMMIT_CHECK_TARGET"
        );
        assert_eq!(p6::REJECT_ACTION_WITHOUT_COMMIT, "REJECT_ACTION_WITHOUT_COMMIT");
        assert_eq!(p6::REJECT_ACTION_WITHOUT_CAUSE, "REJECT_ACTION_WITHOUT_CAUSE");
    }
}

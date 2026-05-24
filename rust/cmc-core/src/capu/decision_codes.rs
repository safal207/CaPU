//! Stable decision code and verdict constants for CaPU software reference units.
//!
//! v0 starts with P2/P3 because those units are newly introduced and not yet
//! tied to saved runtime fixtures. P1/P6 can be migrated later in smaller
//! compatibility-safe steps.

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

#[cfg(test)]
mod tests {
    use super::*;

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
}

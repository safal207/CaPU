use crate::CauseId;

/// High-level transition class understood by the CaPU reference units.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum TransitionType {
    MemoryWrite,
    MemoryRead,
    Effect,
    PersonaMemory,
    PersonaStateChange,
    ExternalAction,
    Introspection,
}

/// Invariant boundary selected for a transition.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum Boundary {
    WriteAuthorization,
    ReadAuthorization,
    EffectCommitBoundary,
    PersonaMemoryRequiresCause,
    PersonaStateChangeRequiresAuthorization,
    ActionRequiresCommit,
    IntrospectionRequiresHypothesisLabel,
}

impl Boundary {
    pub fn as_str(self) -> &'static str {
        match self {
            Self::WriteAuthorization => "write_authorization",
            Self::ReadAuthorization => "read_authorization",
            Self::EffectCommitBoundary => "effect_commit_boundary",
            Self::PersonaMemoryRequiresCause => "persona_memory_requires_cause",
            Self::PersonaStateChangeRequiresAuthorization => {
                "persona_state_change_requires_authorization"
            }
            Self::ActionRequiresCommit => "action_requires_commit",
            Self::IntrospectionRequiresHypothesisLabel => "introspection_requires_hypothesis_label",
        }
    }
}

/// Coarse decision class for CaPU reference units.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum DecisionClass {
    Accept,
    Reject,
    Hold,
}

/// Minimal typed transition used by software reference units.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct Transition {
    pub transition_id: String,
    pub transition_type: TransitionType,
    pub actor: Option<String>,
    pub action_kind: Option<String>,
    pub object: Option<String>,
    pub cause_id: Option<CauseId>,
    pub parent_cause: Option<CauseId>,
    pub authorization: Option<bool>,
    pub commit: Option<bool>,
    pub boundary: Boundary,
}

impl Transition {
    pub fn external_action(
        transition_id: impl Into<String>,
        action_kind: impl Into<String>,
        cause_id: Option<CauseId>,
        commit: bool,
    ) -> Self {
        Self {
            transition_id: transition_id.into(),
            transition_type: TransitionType::ExternalAction,
            actor: None,
            action_kind: Some(action_kind.into()),
            object: None,
            cause_id,
            parent_cause: None,
            authorization: None,
            commit: Some(commit),
            boundary: Boundary::ActionRequiresCommit,
        }
    }
}

/// Decision emitted by a CaPU reference unit.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct UnitDecision {
    pub class: DecisionClass,
    pub code: &'static str,
    pub invariant_id: &'static str,
    pub boundary: Boundary,
    pub verdict: &'static str,
    pub cause_id: Option<CauseId>,
}

impl UnitDecision {
    pub fn accepted(&self) -> bool {
        self.class == DecisionClass::Accept
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn external_action_sets_p6_boundary() {
        let transition = Transition::external_action("t1", "send_email", None, false);

        assert_eq!(transition.transition_type, TransitionType::ExternalAction);
        assert_eq!(transition.boundary, Boundary::ActionRequiresCommit);
        assert_eq!(transition.boundary.as_str(), "action_requires_commit");
        assert_eq!(transition.action_kind.as_deref(), Some("send_email"));
    }
}

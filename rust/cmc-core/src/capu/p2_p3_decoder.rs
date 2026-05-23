use crate::CauseId;

use super::boundary_router::route_boundary;
use super::transition::{Transition, TransitionType};

/// Typed request shape for P2 persona-state changes.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct PersonaStateChangeRequest {
    pub transition_id: String,
    pub state_change: String,
    pub actor: Option<String>,
    pub cause_id: Option<CauseId>,
    pub authorization: Option<bool>,
}

impl PersonaStateChangeRequest {
    pub fn new(
        transition_id: impl Into<String>,
        state_change: impl Into<String>,
        cause_id: Option<CauseId>,
        authorization: Option<bool>,
    ) -> Self {
        Self {
            transition_id: transition_id.into(),
            state_change: state_change.into(),
            actor: None,
            cause_id,
            authorization,
        }
    }

    pub fn with_actor(mut self, actor: impl Into<String>) -> Self {
        self.actor = Some(actor.into());
        self
    }
}

/// Typed request shape for P3 introspection.
///
/// v0 stores the hypothesis label in `Transition.object` to preserve the
/// existing Transition shape while making the input boundary explicit.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct IntrospectionRequest {
    pub transition_id: String,
    pub hypothesis_label: Option<String>,
    pub actor: Option<String>,
    pub cause_id: Option<CauseId>,
}

impl IntrospectionRequest {
    pub fn new(
        transition_id: impl Into<String>,
        hypothesis_label: Option<impl Into<String>>,
        cause_id: Option<CauseId>,
    ) -> Self {
        Self {
            transition_id: transition_id.into(),
            hypothesis_label: hypothesis_label.map(Into::into),
            actor: None,
            cause_id,
        }
    }

    pub fn with_actor(mut self, actor: impl Into<String>) -> Self {
        self.actor = Some(actor.into());
        self
    }
}

/// Decode a P2 persona-state-change request into a typed CaPU transition.
pub fn decode_persona_state_change(request: PersonaStateChangeRequest) -> Transition {
    let transition_type = TransitionType::PersonaStateChange;

    Transition {
        transition_id: request.transition_id,
        transition_type,
        actor: request.actor,
        action_kind: Some("persona_state_update".to_string()),
        object: Some(request.state_change),
        cause_id: request.cause_id,
        parent_cause: None,
        authorization: request.authorization,
        commit: None,
        boundary: route_boundary(transition_type),
    }
}

/// Decode a P3 introspection request into a typed CaPU transition.
pub fn decode_introspection(request: IntrospectionRequest) -> Transition {
    let transition_type = TransitionType::Introspection;

    Transition {
        transition_id: request.transition_id,
        transition_type,
        actor: request.actor,
        action_kind: Some("introspection".to_string()),
        object: request.hypothesis_label,
        cause_id: request.cause_id,
        parent_cause: None,
        authorization: None,
        commit: None,
        boundary: route_boundary(transition_type),
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::capu::authorization_unit::check_persona_state_change_authorization;
    use crate::capu::boundary_router::boundary_matches_route;
    use crate::capu::decision_unit::decide_transition;
    use crate::capu::hypothesis_unit::check_introspection_hypothesis_label;
    use crate::capu::transition::{Boundary, DecisionClass};

    #[test]
    fn decodes_persona_state_change_to_p2_boundary() {
        let request = PersonaStateChangeRequest::new(
            "tx-persona-state",
            "tone=more_careful",
            Some(77),
            Some(true),
        )
        .with_actor("agent");

        let transition = decode_persona_state_change(request);

        assert_eq!(transition.transition_id, "tx-persona-state");
        assert_eq!(transition.transition_type, TransitionType::PersonaStateChange);
        assert_eq!(transition.actor.as_deref(), Some("agent"));
        assert_eq!(transition.action_kind.as_deref(), Some("persona_state_update"));
        assert_eq!(transition.object.as_deref(), Some("tone=more_careful"));
        assert_eq!(transition.cause_id, Some(77));
        assert_eq!(transition.authorization, Some(true));
        assert_eq!(transition.boundary, Boundary::PersonaStateChangeRequiresAuthorization);
        assert!(boundary_matches_route(&transition));
    }

    #[test]
    fn decodes_introspection_to_p3_boundary() {
        let request = IntrospectionRequest::new(
            "tx-introspection",
            Some("hypothesis:memory-drift-risk"),
            Some(303),
        )
        .with_actor("agent");

        let transition = decode_introspection(request);

        assert_eq!(transition.transition_id, "tx-introspection");
        assert_eq!(transition.transition_type, TransitionType::Introspection);
        assert_eq!(transition.actor.as_deref(), Some("agent"));
        assert_eq!(transition.action_kind.as_deref(), Some("introspection"));
        assert_eq!(transition.object.as_deref(), Some("hypothesis:memory-drift-risk"));
        assert_eq!(transition.cause_id, Some(303));
        assert_eq!(transition.boundary, Boundary::IntrospectionRequiresHypothesisLabel);
        assert!(boundary_matches_route(&transition));
    }

    #[test]
    fn decoded_authorized_persona_state_change_reaches_p2_accept() {
        let transition = decode_persona_state_change(PersonaStateChangeRequest::new(
            "tx-p2-accept",
            "tone=more_careful",
            Some(77),
            Some(true),
        ));

        let decision = check_persona_state_change_authorization(&transition);

        assert_eq!(decision.class, DecisionClass::Accept);
        assert_eq!(decision.code, "ACCEPT_PERSONA_STATE_CHANGE_WITH_AUTHORIZATION");
        assert_eq!(decision.verdict, "accepted_persona_state_change_with_authorization");
        assert_eq!(decision.cause_id, Some(77));
    }

    #[test]
    fn decoded_unauthorized_persona_state_change_reaches_p2_reject() {
        let transition = decode_persona_state_change(PersonaStateChangeRequest::new(
            "tx-p2-reject",
            "tone=more_careful",
            Some(77),
            None,
        ));

        let decision = check_persona_state_change_authorization(&transition);

        assert_eq!(decision.class, DecisionClass::Reject);
        assert_eq!(decision.code, "REJECT_PERSONA_STATE_CHANGE_WITHOUT_AUTHORIZATION");
        assert_eq!(decision.verdict, "blocked_persona_state_change_without_authorization");
    }

    #[test]
    fn decoded_labeled_introspection_reaches_p3_accept() {
        let transition = decode_introspection(IntrospectionRequest::new(
            "tx-p3-accept",
            Some("hypothesis:memory-drift-risk"),
            Some(303),
        ));

        let decision = check_introspection_hypothesis_label(&transition);

        assert_eq!(decision.class, DecisionClass::Accept);
        assert_eq!(decision.code, "ACCEPT_INTROSPECTION_WITH_HYPOTHESIS_LABEL");
        assert_eq!(decision.verdict, "accepted_introspection_with_hypothesis_label");
        assert_eq!(decision.cause_id, Some(303));
    }

    #[test]
    fn decoded_unlabeled_introspection_reaches_p3_reject() {
        let transition = decode_introspection(IntrospectionRequest::new(
            "tx-p3-reject",
            None::<String>,
            Some(303),
        ));

        let decision = check_introspection_hypothesis_label(&transition);

        assert_eq!(decision.class, DecisionClass::Reject);
        assert_eq!(decision.code, "REJECT_INTROSPECTION_WITHOUT_HYPOTHESIS_LABEL");
        assert_eq!(decision.verdict, "blocked_introspection_without_hypothesis_label");
    }

    #[test]
    fn decoded_p2_request_reaches_decision_unit() {
        let transition = decode_persona_state_change(PersonaStateChangeRequest::new(
            "tx-p2-decision",
            "tone=more_careful",
            Some(77),
            Some(true),
        ));

        let decision = decide_transition(&transition);

        assert_eq!(decision.class, DecisionClass::Accept);
        assert_eq!(decision.invariant_id, "P2");
        assert_eq!(decision.code, "ACCEPT_PERSONA_STATE_CHANGE_WITH_AUTHORIZATION");
    }

    #[test]
    fn decoded_p3_request_reaches_decision_unit() {
        let transition = decode_introspection(IntrospectionRequest::new(
            "tx-p3-decision",
            Some("hypothesis:memory-drift-risk"),
            Some(303),
        ));

        let decision = decide_transition(&transition);

        assert_eq!(decision.class, DecisionClass::Accept);
        assert_eq!(decision.invariant_id, "P3");
        assert_eq!(decision.code, "ACCEPT_INTROSPECTION_WITH_HYPOTHESIS_LABEL");
    }
}

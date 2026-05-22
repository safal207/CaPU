use crate::CauseId;

use super::boundary_router::route_boundary;
use super::transition::{Transition, TransitionType};

/// Minimal decoded request shape for external actions.
///
/// This keeps v0 intentionally small: enough to prove the processor path
/// `decode -> boundary route -> commit check` for P6 without introducing a full
/// sidecar API or JSON schema yet.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct ExternalActionRequest {
    pub transition_id: String,
    pub action_kind: String,
    pub actor: Option<String>,
    pub object: Option<String>,
    pub cause_id: Option<CauseId>,
    pub commit: bool,
}

impl ExternalActionRequest {
    pub fn new(
        transition_id: impl Into<String>,
        action_kind: impl Into<String>,
        cause_id: Option<CauseId>,
        commit: bool,
    ) -> Self {
        Self {
            transition_id: transition_id.into(),
            action_kind: action_kind.into(),
            actor: None,
            object: None,
            cause_id,
            commit,
        }
    }

    pub fn with_actor(mut self, actor: impl Into<String>) -> Self {
        self.actor = Some(actor.into());
        self
    }

    pub fn with_object(mut self, object: impl Into<String>) -> Self {
        self.object = Some(object.into());
        self
    }
}

/// Minimal decoded request shape for persona-memory writes.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct PersonaMemoryRequest {
    pub transition_id: String,
    pub memory: String,
    pub actor: Option<String>,
    pub cause_id: Option<CauseId>,
}

impl PersonaMemoryRequest {
    pub fn new(
        transition_id: impl Into<String>,
        memory: impl Into<String>,
        cause_id: Option<CauseId>,
    ) -> Self {
        Self {
            transition_id: transition_id.into(),
            memory: memory.into(),
            actor: None,
            cause_id,
        }
    }

    pub fn with_actor(mut self, actor: impl Into<String>) -> Self {
        self.actor = Some(actor.into());
        self
    }
}

/// Decode an external action request into a typed CaPU transition.
///
/// The boundary is not hard-coded here; it is routed through the Boundary Router
/// so decoder semantics stay aligned with the microarchitecture.
pub fn decode_external_action(request: ExternalActionRequest) -> Transition {
    let transition_type = TransitionType::ExternalAction;

    Transition {
        transition_id: request.transition_id,
        transition_type,
        actor: request.actor,
        action_kind: Some(request.action_kind),
        object: request.object,
        cause_id: request.cause_id,
        parent_cause: None,
        authorization: None,
        commit: Some(request.commit),
        boundary: route_boundary(transition_type),
    }
}

/// Decode a persona-memory request into a typed CaPU transition.
pub fn decode_persona_memory(request: PersonaMemoryRequest) -> Transition {
    let transition_type = TransitionType::PersonaMemory;

    Transition {
        transition_id: request.transition_id,
        transition_type,
        actor: request.actor,
        action_kind: Some("persona_memory_write".to_string()),
        object: Some(request.memory),
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
    use crate::capu::boundary_router::boundary_matches_route;
    use crate::capu::commit_unit::check_external_action_commit;
    use crate::capu::persona_memory_unit::check_persona_memory_cause;
    use crate::capu::transition::{Boundary, DecisionClass};

    #[test]
    fn decodes_external_action_to_p6_boundary() {
        let request = ExternalActionRequest::new("tx-send-email", "send_email", Some(101), true)
            .with_actor("agent")
            .with_object("email:draft-1");

        let transition = decode_external_action(request);

        assert_eq!(transition.transition_id, "tx-send-email");
        assert_eq!(transition.action_kind.as_deref(), Some("send_email"));
        assert_eq!(transition.actor.as_deref(), Some("agent"));
        assert_eq!(transition.object.as_deref(), Some("email:draft-1"));
        assert_eq!(transition.cause_id, Some(101));
        assert_eq!(transition.commit, Some(true));
        assert_eq!(transition.boundary, Boundary::ActionRequiresCommit);
        assert!(boundary_matches_route(&transition));
    }

    #[test]
    fn decodes_persona_memory_to_p1_boundary() {
        let request = PersonaMemoryRequest::new(
            "tx-persona-memory",
            "prefers concise technical summaries",
            Some(42),
        )
        .with_actor("human");

        let transition = decode_persona_memory(request);

        assert_eq!(transition.transition_id, "tx-persona-memory");
        assert_eq!(transition.transition_type, TransitionType::PersonaMemory);
        assert_eq!(transition.actor.as_deref(), Some("human"));
        assert_eq!(transition.action_kind.as_deref(), Some("persona_memory_write"));
        assert_eq!(
            transition.object.as_deref(),
            Some("prefers concise technical summaries")
        );
        assert_eq!(transition.cause_id, Some(42));
        assert_eq!(transition.boundary, Boundary::PersonaMemoryRequiresCause);
        assert!(boundary_matches_route(&transition));
    }

    #[test]
    fn decoded_uncommitted_action_reaches_p6_reject() {
        let request = ExternalActionRequest::new("tx-uncommitted", "send_email", None, false);
        let transition = decode_external_action(request);

        let decision = check_external_action_commit(&transition);

        assert_eq!(decision.class, DecisionClass::Reject);
        assert_eq!(decision.code, "REJECT_ACTION_WITHOUT_COMMIT");
        assert_eq!(decision.verdict, "blocked_action_without_commit");
    }

    #[test]
    fn decoded_committed_action_reaches_p6_accept() {
        let request = ExternalActionRequest::new("tx-committed", "send_email", Some(101), true);
        let transition = decode_external_action(request);

        let decision = check_external_action_commit(&transition);

        assert_eq!(decision.class, DecisionClass::Accept);
        assert_eq!(decision.code, "ACCEPT_COMMITTED_ACTION");
        assert_eq!(decision.verdict, "accepted_committed_action");
        assert_eq!(decision.cause_id, Some(101));
    }

    #[test]
    fn decoded_persona_memory_without_cause_reaches_p1_reject() {
        let request = PersonaMemoryRequest::new("tx-p1-reject", "raw inferred preference", None);
        let transition = decode_persona_memory(request);

        let decision = check_persona_memory_cause(&transition);

        assert_eq!(decision.class, DecisionClass::Reject);
        assert_eq!(decision.code, "REJECT_PERSONA_MEMORY_WITHOUT_CAUSE");
        assert_eq!(decision.verdict, "blocked_persona_memory_without_cause");
    }

    #[test]
    fn decoded_persona_memory_with_cause_reaches_p1_accept() {
        let request = PersonaMemoryRequest::new("tx-p1-accept", "confirmed preference", Some(42));
        let transition = decode_persona_memory(request);

        let decision = check_persona_memory_cause(&transition);

        assert_eq!(decision.class, DecisionClass::Accept);
        assert_eq!(decision.code, "ACCEPT_PERSONA_MEMORY_WITH_CAUSE");
        assert_eq!(decision.verdict, "accepted_persona_memory_with_cause");
        assert_eq!(decision.cause_id, Some(42));
    }
}

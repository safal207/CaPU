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

/// Replay invariant selector understood by the v0 replay submission path.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum ReplayInvariantId {
    P1,
    P6,
}

impl ReplayInvariantId {
    pub fn as_str(self) -> &'static str {
        match self {
            Self::P1 => "P1",
            Self::P6 => "P6",
        }
    }
}

/// Replay request mode understood by the v0 replay submission path.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum ReplayRequestMode {
    CanonicalPair,
    SubmittedPair,
}

impl ReplayRequestMode {
    pub fn as_str(self) -> &'static str {
        match self {
            Self::CanonicalPair => "canonical_pair",
            Self::SubmittedPair => "submitted_pair",
        }
    }
}

/// Minimal decoded request shape for replay submissions.
///
/// `submitted_pair` is intentionally still fixture-driven in v0: submitted
/// requests must explicitly declare that their event body is the canonical pair.
/// This makes the submission path auditable without claiming a general-purpose
/// replay engine.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct ReplaySubmissionRequest {
    pub invariant_id: String,
    pub replay: String,
    pub submission_id: Option<String>,
    pub events: Option<String>,
}

impl ReplaySubmissionRequest {
    pub fn canonical_pair(invariant_id: impl Into<String>) -> Self {
        Self {
            invariant_id: invariant_id.into(),
            replay: "canonical_pair".to_string(),
            submission_id: None,
            events: None,
        }
    }

    pub fn submitted_pair(
        invariant_id: impl Into<String>,
        submission_id: impl Into<String>,
        events: impl Into<String>,
    ) -> Self {
        Self {
            invariant_id: invariant_id.into(),
            replay: "submitted_pair".to_string(),
            submission_id: Some(submission_id.into()),
            events: Some(events.into()),
        }
    }
}

/// Typed replay submission selected by the decoder.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct DecodedReplaySubmission {
    pub invariant_id: ReplayInvariantId,
    pub mode: ReplayRequestMode,
    pub submission_id: Option<String>,
    pub events: String,
}

/// Decode failure for v0 replay submissions.
#[derive(Debug, Clone, PartialEq, Eq)]
pub enum ReplaySubmissionDecodeError {
    UnsupportedInvariantId { invariant_id: String },
    UnsupportedReplayMode { replay: String },
    MissingSubmissionId,
    UnsupportedEvents { events: String },
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

/// Decode a replay request into typed v0 replay-submission semantics.
pub fn decode_replay_submission(
    request: ReplaySubmissionRequest,
) -> Result<DecodedReplaySubmission, ReplaySubmissionDecodeError> {
    let invariant_id = match request.invariant_id.as_str() {
        "P1" => ReplayInvariantId::P1,
        "P6" => ReplayInvariantId::P6,
        other => {
            return Err(ReplaySubmissionDecodeError::UnsupportedInvariantId {
                invariant_id: other.to_string(),
            })
        }
    };

    let mode = match request.replay.as_str() {
        "canonical_pair" => ReplayRequestMode::CanonicalPair,
        "submitted_pair" => ReplayRequestMode::SubmittedPair,
        other => {
            return Err(ReplaySubmissionDecodeError::UnsupportedReplayMode {
                replay: other.to_string(),
            })
        }
    };

    match mode {
        ReplayRequestMode::CanonicalPair => Ok(DecodedReplaySubmission {
            invariant_id,
            mode,
            submission_id: None,
            events: "canonical_pair".to_string(),
        }),
        ReplayRequestMode::SubmittedPair => {
            let submission_id = request
                .submission_id
                .filter(|value| !value.is_empty())
                .ok_or(ReplaySubmissionDecodeError::MissingSubmissionId)?;
            let events = request.events.unwrap_or_default();
            if events != "canonical_pair" {
                return Err(ReplaySubmissionDecodeError::UnsupportedEvents { events });
            }
            Ok(DecodedReplaySubmission {
                invariant_id,
                mode,
                submission_id: Some(submission_id),
                events,
            })
        }
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

    #[test]
    fn decodes_canonical_replay_submission_for_p6() {
        let decoded = decode_replay_submission(ReplaySubmissionRequest::canonical_pair("P6"))
            .expect("canonical P6 replay should decode");

        assert_eq!(decoded.invariant_id, ReplayInvariantId::P6);
        assert_eq!(decoded.invariant_id.as_str(), "P6");
        assert_eq!(decoded.mode, ReplayRequestMode::CanonicalPair);
        assert_eq!(decoded.mode.as_str(), "canonical_pair");
        assert_eq!(decoded.submission_id, None);
        assert_eq!(decoded.events, "canonical_pair");
    }

    #[test]
    fn decodes_submitted_replay_submission_for_p1() {
        let decoded = decode_replay_submission(ReplaySubmissionRequest::submitted_pair(
            "P1",
            "http-p1-submitted-replay",
            "canonical_pair",
        ))
        .expect("submitted P1 replay should decode");

        assert_eq!(decoded.invariant_id, ReplayInvariantId::P1);
        assert_eq!(decoded.invariant_id.as_str(), "P1");
        assert_eq!(decoded.mode, ReplayRequestMode::SubmittedPair);
        assert_eq!(decoded.mode.as_str(), "submitted_pair");
        assert_eq!(decoded.submission_id.as_deref(), Some("http-p1-submitted-replay"));
        assert_eq!(decoded.events, "canonical_pair");
    }

    #[test]
    fn submitted_replay_requires_submission_id() {
        let request = ReplaySubmissionRequest {
            invariant_id: "P6".to_string(),
            replay: "submitted_pair".to_string(),
            submission_id: None,
            events: Some("canonical_pair".to_string()),
        };

        assert_eq!(
            decode_replay_submission(request),
            Err(ReplaySubmissionDecodeError::MissingSubmissionId)
        );
    }

    #[test]
    fn submitted_replay_rejects_unsupported_events() {
        let request = ReplaySubmissionRequest::submitted_pair(
            "P6",
            "http-p6-submitted-replay",
            "inline_trace_v1",
        );

        assert_eq!(
            decode_replay_submission(request),
            Err(ReplaySubmissionDecodeError::UnsupportedEvents {
                events: "inline_trace_v1".to_string()
            })
        );
    }

    #[test]
    fn replay_submission_rejects_unknown_invariant() {
        let request = ReplaySubmissionRequest::canonical_pair("PX");

        assert_eq!(
            decode_replay_submission(request),
            Err(ReplaySubmissionDecodeError::UnsupportedInvariantId {
                invariant_id: "PX".to_string()
            })
        );
    }
}

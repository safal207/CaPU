use super::decoder::{DecodedReplaySubmission, ReplayInvariantId, ReplayRequestMode};

/// Unit-level decision class for replay submission execution.
#[derive(Debug, Clone, PartialEq, Eq)]
pub enum ReplaySubmissionDecisionClass {
    Accept,
    Hold,
}

/// Unit-level decision for a decoded replay submission envelope.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct ReplaySubmissionDecision {
    pub class: ReplaySubmissionDecisionClass,
    pub code: &'static str,
    pub invariant_id: &'static str,
    pub replay_mode: &'static str,
    pub submission_id: Option<String>,
    pub verdict: &'static str,
}

impl ReplaySubmissionDecision {
    pub fn accepted(&self) -> bool {
        self.class == ReplaySubmissionDecisionClass::Accept
    }
}

/// Decide whether a decoded replay submission envelope is executable by v0.
///
/// v0 intentionally accepts only canonical-pair replay evidence. A submitted
/// envelope can be accepted only when the decoder has already constrained its
/// events field to `canonical_pair`. This preserves determinism while avoiding
/// a premature claim that CaPU can decode arbitrary inline replay traces.
pub fn decide_replay_submission(
    submission: &DecodedReplaySubmission,
) -> ReplaySubmissionDecision {
    match submission.mode {
        ReplayRequestMode::CanonicalPair => ReplaySubmissionDecision {
            class: ReplaySubmissionDecisionClass::Accept,
            code: "ACCEPT_CANONICAL_REPLAY_PAIR",
            invariant_id: submission.invariant_id.as_str(),
            replay_mode: submission.mode.as_str(),
            submission_id: None,
            verdict: "accepted_canonical_replay_pair",
        },
        ReplayRequestMode::SubmittedPair if submission.events == "canonical_pair" => {
            ReplaySubmissionDecision {
                class: ReplaySubmissionDecisionClass::Accept,
                code: "ACCEPT_SUBMITTED_REPLAY_PAIR",
                invariant_id: submission.invariant_id.as_str(),
                replay_mode: submission.mode.as_str(),
                submission_id: submission.submission_id.clone(),
                verdict: "accepted_submitted_replay_pair",
            }
        }
        ReplayRequestMode::SubmittedPair => ReplaySubmissionDecision {
            class: ReplaySubmissionDecisionClass::Hold,
            code: "HOLD_UNSUPPORTED_REPLAY_EVENTS",
            invariant_id: submission.invariant_id.as_str(),
            replay_mode: submission.mode.as_str(),
            submission_id: submission.submission_id.clone(),
            verdict: "held_unsupported_replay_events",
        },
    }
}

/// Convenience predicate for P1/P6 pair coverage in v0.
pub fn replay_submission_targets_supported_invariant(
    submission: &DecodedReplaySubmission,
) -> bool {
    matches!(submission.invariant_id, ReplayInvariantId::P1 | ReplayInvariantId::P6)
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::capu::decoder::{decode_replay_submission, ReplaySubmissionRequest};

    #[test]
    fn accepts_canonical_p6_replay_pair() {
        let decoded = decode_replay_submission(ReplaySubmissionRequest::canonical_pair("P6"))
            .expect("canonical P6 replay should decode");

        let decision = decide_replay_submission(&decoded);

        assert_eq!(decision.class, ReplaySubmissionDecisionClass::Accept);
        assert!(decision.accepted());
        assert_eq!(decision.code, "ACCEPT_CANONICAL_REPLAY_PAIR");
        assert_eq!(decision.invariant_id, "P6");
        assert_eq!(decision.replay_mode, "canonical_pair");
        assert_eq!(decision.submission_id, None);
        assert_eq!(decision.verdict, "accepted_canonical_replay_pair");
        assert!(replay_submission_targets_supported_invariant(&decoded));
    }

    #[test]
    fn accepts_submitted_p1_replay_pair() {
        let decoded = decode_replay_submission(ReplaySubmissionRequest::submitted_pair(
            "P1",
            "http-p1-submitted-replay",
            "canonical_pair",
        ))
        .expect("submitted P1 replay should decode");

        let decision = decide_replay_submission(&decoded);

        assert_eq!(decision.class, ReplaySubmissionDecisionClass::Accept);
        assert!(decision.accepted());
        assert_eq!(decision.code, "ACCEPT_SUBMITTED_REPLAY_PAIR");
        assert_eq!(decision.invariant_id, "P1");
        assert_eq!(decision.replay_mode, "submitted_pair");
        assert_eq!(decision.submission_id.as_deref(), Some("http-p1-submitted-replay"));
        assert_eq!(decision.verdict, "accepted_submitted_replay_pair");
        assert!(replay_submission_targets_supported_invariant(&decoded));
    }

    #[test]
    fn holds_submitted_replay_when_events_were_not_constrained() {
        let decoded = DecodedReplaySubmission {
            invariant_id: ReplayInvariantId::P6,
            mode: ReplayRequestMode::SubmittedPair,
            submission_id: Some("manual-test".to_string()),
            events: "inline_trace_v1".to_string(),
        };

        let decision = decide_replay_submission(&decoded);

        assert_eq!(decision.class, ReplaySubmissionDecisionClass::Hold);
        assert!(!decision.accepted());
        assert_eq!(decision.code, "HOLD_UNSUPPORTED_REPLAY_EVENTS");
        assert_eq!(decision.invariant_id, "P6");
        assert_eq!(decision.replay_mode, "submitted_pair");
        assert_eq!(decision.submission_id.as_deref(), Some("manual-test"));
        assert_eq!(decision.verdict, "held_unsupported_replay_events");
    }
}

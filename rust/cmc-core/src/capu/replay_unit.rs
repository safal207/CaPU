use crate::trace_crypto::SealedTraceEvent;

use super::seal_unit::verify_sealed_audit_records;

/// Minimal semantic replay summary for the CaPU P6 audit pipeline.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct ReplaySummary {
    pub events: usize,
    pub p6_boundary_events: usize,
    pub rejected_without_commit: usize,
    pub accepted_committed_action: usize,
}

impl ReplaySummary {
    pub fn valid_p6_pair(&self) -> bool {
        self.events == 2
            && self.p6_boundary_events == 2
            && self.rejected_without_commit == 1
            && self.accepted_committed_action == 1
    }
}

/// Replay failure class for sealed CaPU audit evidence.
#[derive(Debug, Clone, PartialEq, Eq)]
pub enum ReplayError {
    SealInvalid { event_index: usize },
    SemanticMismatch { summary: ReplaySummary },
}

/// Verify and semantically replay a sealed P6 audit chain.
///
/// v0 intentionally checks the canonical two-case P6 demo pair:
///
/// ```text
/// REJECT_ACTION_WITHOUT_COMMIT
/// ACCEPT_COMMITTED_ACTION
/// ```
///
/// This keeps replay deterministic and reviewer-friendly while future versions
/// can generalize to arbitrary audit traces.
pub fn replay_p6_audit_chain(sealed: &[SealedTraceEvent]) -> Result<ReplaySummary, ReplayError> {
    verify_sealed_audit_records(sealed)
        .map_err(|event_index| ReplayError::SealInvalid { event_index })?;

    let summary = summarize_p6_audit_chain(sealed);

    if summary.valid_p6_pair() {
        Ok(summary)
    } else {
        Err(ReplayError::SemanticMismatch { summary })
    }
}

fn summarize_p6_audit_chain(sealed: &[SealedTraceEvent]) -> ReplaySummary {
    let mut summary = ReplaySummary {
        events: sealed.len(),
        p6_boundary_events: 0,
        rejected_without_commit: 0,
        accepted_committed_action: 0,
    };

    for event in sealed {
        if event.event.contains("\"invariant_id\":\"P6\"")
            && event.event.contains("\"boundary\":\"action_requires_commit\"")
        {
            summary.p6_boundary_events += 1;
        }

        if event.event.contains("\"code\":\"REJECT_ACTION_WITHOUT_COMMIT\"")
            && event
                .event
                .contains("\"verdict\":\"blocked_action_without_commit\"")
        {
            summary.rejected_without_commit += 1;
        }

        if event.event.contains("\"code\":\"ACCEPT_COMMITTED_ACTION\"")
            && event
                .event
                .contains("\"verdict\":\"accepted_committed_action\"")
        {
            summary.accepted_committed_action += 1;
        }
    }

    summary
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::capu::audit_bus::emit_audit_record;
    use crate::capu::decision_unit::decide_transition;
    use crate::capu::decoder::{decode_external_action, ExternalActionRequest};
    use crate::capu::seal_unit::seal_audit_records;

    fn sealed_p6_pair() -> Vec<SealedTraceEvent> {
        let uncommitted = decode_external_action(ExternalActionRequest::new(
            "tx-uncommitted",
            "send_email",
            None,
            false,
        ));
        let uncommitted_decision = decide_transition(&uncommitted);
        let uncommitted_audit = emit_audit_record(&uncommitted, &uncommitted_decision);

        let committed = decode_external_action(ExternalActionRequest::new(
            "tx-committed",
            "send_email",
            Some(101),
            true,
        ));
        let committed_decision = decide_transition(&committed);
        let committed_audit = emit_audit_record(&committed, &committed_decision);

        seal_audit_records(&[uncommitted_audit, committed_audit])
    }

    #[test]
    fn replay_unit_accepts_valid_sealed_p6_pair() {
        let sealed = sealed_p6_pair();

        let summary = replay_p6_audit_chain(&sealed).expect("valid P6 chain should replay");

        assert_eq!(summary.events, 2);
        assert_eq!(summary.p6_boundary_events, 2);
        assert_eq!(summary.rejected_without_commit, 1);
        assert_eq!(summary.accepted_committed_action, 1);
        assert!(summary.valid_p6_pair());
    }

    #[test]
    fn replay_unit_detects_seal_tampering_before_semantic_replay() {
        let mut sealed = sealed_p6_pair();
        sealed[0].event = sealed[0].event.replace(
            "REJECT_ACTION_WITHOUT_COMMIT",
            "ACCEPT_COMMITTED_ACTION",
        );

        assert_eq!(
            replay_p6_audit_chain(&sealed),
            Err(ReplayError::SealInvalid { event_index: 1 })
        );
    }

    #[test]
    fn replay_unit_detects_semantic_mismatch() {
        let committed = decode_external_action(ExternalActionRequest::new(
            "tx-committed",
            "send_email",
            Some(101),
            true,
        ));
        let committed_decision = decide_transition(&committed);
        let committed_audit = emit_audit_record(&committed, &committed_decision);
        let sealed = seal_audit_records(&[committed_audit]);

        assert!(matches!(
            replay_p6_audit_chain(&sealed),
            Err(ReplayError::SemanticMismatch { .. })
        ));
    }
}

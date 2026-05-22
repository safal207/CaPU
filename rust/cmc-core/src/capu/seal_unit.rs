use crate::trace_crypto::{seal_trace, verify_trace, SealedTraceEvent};

use super::audit_bus::AuditRecord;

/// Seal CaPU audit records with the existing SHA-256 trace chain.
///
/// This unit does not introduce new cryptography. It wraps the repository's
/// existing std-only trace sealing primitives so CaPU audit evidence can be
/// protected by the same tamper-evident path as the rest of CMC.
pub fn seal_audit_records(records: &[AuditRecord]) -> Vec<SealedTraceEvent> {
    let mut jsonl = records
        .iter()
        .map(AuditRecord::to_json_line)
        .collect::<Vec<_>>()
        .join("\n");

    if !jsonl.is_empty() {
        jsonl.push('\n');
    }

    seal_trace(&jsonl)
}

/// Verify sealed CaPU audit records.
pub fn verify_sealed_audit_records(sealed: &[SealedTraceEvent]) -> Result<(), usize> {
    verify_trace(sealed)
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::capu::audit_bus::emit_audit_record;
    use crate::capu::decision_unit::decide_transition;
    use crate::capu::decoder::{decode_external_action, ExternalActionRequest};

    #[test]
    fn seal_unit_seals_and_verifies_p6_audit_records() {
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

        let sealed = seal_audit_records(&[uncommitted_audit, committed_audit]);

        assert_eq!(sealed.len(), 2);
        assert!(verify_sealed_audit_records(&sealed).is_ok());
        assert!(sealed[0].event.contains("REJECT_ACTION_WITHOUT_COMMIT"));
        assert!(sealed[1].event.contains("ACCEPT_COMMITTED_ACTION"));
    }

    #[test]
    fn seal_unit_detects_p6_audit_tampering() {
        let committed = decode_external_action(ExternalActionRequest::new(
            "tx-committed",
            "send_email",
            Some(101),
            true,
        ));
        let committed_decision = decide_transition(&committed);
        let committed_audit = emit_audit_record(&committed, &committed_decision);

        let mut sealed = seal_audit_records(&[committed_audit]);
        sealed[0].event = sealed[0].event.replace(
            "ACCEPT_COMMITTED_ACTION",
            "REJECT_ACTION_WITHOUT_COMMIT",
        );

        assert_eq!(verify_sealed_audit_records(&sealed), Err(1));
    }
}

use cmc_core::capu::audit_bus::emit_audit_record;
use cmc_core::capu::decision_unit::decide_transition;
use cmc_core::capu::decoder::{decode_external_action, ExternalActionRequest};
use cmc_core::capu::seal_unit::{seal_audit_records, verify_sealed_audit_records};
use cmc_core::capu::transition::DecisionClass;

fn main() {
    println!("CAPU-P6-PIPELINE-DEMO v0");

    let uncommitted = decode_external_action(ExternalActionRequest::new(
        "p6-uncommitted-demo",
        "send_email",
        None,
        false,
    ));
    let uncommitted_decision = decide_transition(&uncommitted);
    let uncommitted_audit = emit_audit_record(&uncommitted, &uncommitted_decision);

    assert_eq!(uncommitted_decision.class, DecisionClass::Reject);
    assert_eq!(uncommitted_decision.code, "REJECT_ACTION_WITHOUT_COMMIT");
    assert_eq!(
        uncommitted_decision.verdict,
        "blocked_action_without_commit"
    );

    println!(
        "uncommitted_result={} code={} boundary={} accepted={}",
        uncommitted_decision.verdict,
        uncommitted_decision.code,
        uncommitted_decision.boundary.as_str(),
        uncommitted_decision.accepted()
    );
    println!("audit_jsonl={}", uncommitted_audit.to_json_line());

    let committed = decode_external_action(ExternalActionRequest::new(
        "p6-committed-demo",
        "send_email",
        Some(101),
        true,
    ));
    let committed_decision = decide_transition(&committed);
    let committed_audit = emit_audit_record(&committed, &committed_decision);

    assert_eq!(committed_decision.class, DecisionClass::Accept);
    assert_eq!(committed_decision.code, "ACCEPT_COMMITTED_ACTION");
    assert_eq!(committed_decision.verdict, "accepted_committed_action");
    assert_eq!(committed_decision.cause_id, Some(101));

    println!(
        "committed_result={} code={} boundary={} cause_id={} accepted={}",
        committed_decision.verdict,
        committed_decision.code,
        committed_decision.boundary.as_str(),
        committed_decision.cause_id.unwrap_or_default(),
        committed_decision.accepted()
    );
    println!("audit_jsonl={}", committed_audit.to_json_line());

    let sealed = seal_audit_records(&[uncommitted_audit, committed_audit]);
    assert_eq!(sealed.len(), 2);
    assert!(verify_sealed_audit_records(&sealed).is_ok());

    println!("sealed_events={}", sealed.len());
    println!("seal_result=capu_p6_audit_seal_valid");
    println!("result=capu_p6_pipeline_valid");
}

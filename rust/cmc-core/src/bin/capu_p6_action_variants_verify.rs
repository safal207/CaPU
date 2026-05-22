use std::process::ExitCode;

use cmc_core::capu::audit_bus::{emit_audit_record, AuditRecord};
use cmc_core::capu::decision_unit::decide_transition;
use cmc_core::capu::decoder::{decode_external_action, ExternalActionRequest};
use cmc_core::capu::seal_unit::{seal_audit_records, verify_sealed_audit_records};
use cmc_core::capu::transition::DecisionClass;

#[derive(Debug, Clone, Copy)]
struct VariantCase {
    transition_id: &'static str,
    action_kind: &'static str,
    object: &'static str,
    cause_id: Option<u64>,
    commit: bool,
    expected_class: DecisionClass,
    expected_code: &'static str,
    expected_verdict: &'static str,
}

const CASES: &[VariantCase] = &[
    VariantCase {
        transition_id: "p6-delete-file-uncommitted",
        action_kind: "delete_file",
        object: "file:/tmp/report.csv",
        cause_id: None,
        commit: false,
        expected_class: DecisionClass::Reject,
        expected_code: "REJECT_ACTION_WITHOUT_COMMIT",
        expected_verdict: "blocked_action_without_commit",
    },
    VariantCase {
        transition_id: "p6-delete-file-committed",
        action_kind: "delete_file",
        object: "file:/tmp/report.csv",
        cause_id: Some(201),
        commit: true,
        expected_class: DecisionClass::Accept,
        expected_code: "ACCEPT_COMMITTED_ACTION",
        expected_verdict: "accepted_committed_action",
    },
    VariantCase {
        transition_id: "p6-deploy-code-uncommitted",
        action_kind: "deploy_code",
        object: "service:payments-api",
        cause_id: None,
        commit: false,
        expected_class: DecisionClass::Reject,
        expected_code: "REJECT_ACTION_WITHOUT_COMMIT",
        expected_verdict: "blocked_action_without_commit",
    },
    VariantCase {
        transition_id: "p6-deploy-code-committed",
        action_kind: "deploy_code",
        object: "service:payments-api",
        cause_id: Some(202),
        commit: true,
        expected_class: DecisionClass::Accept,
        expected_code: "ACCEPT_COMMITTED_ACTION",
        expected_verdict: "accepted_committed_action",
    },
];

fn verify_case(case: VariantCase) -> Result<AuditRecord, String> {
    let transition = decode_external_action(
        ExternalActionRequest::new(
            case.transition_id,
            case.action_kind,
            case.cause_id,
            case.commit,
        )
        .with_actor("agent")
        .with_object(case.object),
    );
    let decision = decide_transition(&transition);

    if decision.class != case.expected_class {
        return Err(format!(
            "{}: unexpected decision class: {:?}",
            case.transition_id, decision.class
        ));
    }
    if decision.code != case.expected_code {
        return Err(format!(
            "{}: unexpected decision code: {}",
            case.transition_id, decision.code
        ));
    }
    if decision.verdict != case.expected_verdict {
        return Err(format!(
            "{}: unexpected verdict: {}",
            case.transition_id, decision.verdict
        ));
    }

    let audit = emit_audit_record(&transition, &decision);
    if audit.action_kind.as_deref() != Some(case.action_kind) {
        return Err(format!(
            "{}: audit action kind mismatch",
            case.transition_id
        ));
    }
    if audit.boundary != "action_requires_commit" {
        return Err(format!(
            "{}: audit boundary mismatch: {}",
            case.transition_id, audit.boundary
        ));
    }
    if audit.invariant_id != "P6" {
        return Err(format!(
            "{}: audit invariant mismatch: {}",
            case.transition_id, audit.invariant_id
        ));
    }

    println!(
        "case={} action_kind={} result={} code={} accepted={}",
        case.transition_id,
        case.action_kind,
        audit.verdict,
        audit.code,
        decision.accepted()
    );

    Ok(audit)
}

fn run() -> Result<(), String> {
    println!("CAPU-P6-ACTION-VARIANTS-VERIFY v0");

    let mut audits = Vec::new();
    let mut accepted = 0usize;
    let mut rejected = 0usize;

    for case in CASES {
        let audit = verify_case(*case)?;
        match case.expected_class {
            DecisionClass::Accept => accepted += 1,
            DecisionClass::Reject => rejected += 1,
            DecisionClass::Hold => {}
        }
        audits.push(audit);
    }

    let sealed = seal_audit_records(&audits);
    verify_sealed_audit_records(&sealed)
        .map_err(|event_index| format!("sealed variant audit failed at event {event_index}"))?;

    println!("variant_cases={}", CASES.len());
    println!("variant_rejected={rejected}");
    println!("variant_accepted={accepted}");
    println!("sealed_events={}", sealed.len());
    println!("seal_result=capu_p6_action_variants_seal_valid");
    println!("result=capu_p6_action_variants_verified");

    Ok(())
}

fn main() -> ExitCode {
    match run() {
        Ok(()) => ExitCode::SUCCESS,
        Err(err) => {
            eprintln!("result=capu_p6_action_variants_invalid");
            eprintln!("error={err}");
            ExitCode::FAILURE
        }
    }
}

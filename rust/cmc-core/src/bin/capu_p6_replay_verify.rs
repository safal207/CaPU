use std::process::ExitCode;

use cmc_core::capu::audit_bus::emit_audit_record;
use cmc_core::capu::decision_unit::decide_transition;
use cmc_core::capu::decoder::{decode_external_action, ExternalActionRequest};
use cmc_core::capu::replay_unit::replay_p6_audit_chain;
use cmc_core::capu::seal_unit::seal_audit_records;

fn build_p6_audit_chain() -> Vec<cmc_core::trace_crypto::SealedTraceEvent> {
    let uncommitted = decode_external_action(ExternalActionRequest::new(
        "p6-replay-uncommitted",
        "send_email",
        None,
        false,
    ));
    let uncommitted_decision = decide_transition(&uncommitted);
    let uncommitted_audit = emit_audit_record(&uncommitted, &uncommitted_decision);

    let committed = decode_external_action(ExternalActionRequest::new(
        "p6-replay-committed",
        "send_email",
        Some(101),
        true,
    ));
    let committed_decision = decide_transition(&committed);
    let committed_audit = emit_audit_record(&committed, &committed_decision);

    seal_audit_records(&[uncommitted_audit, committed_audit])
}

fn run() -> Result<(), String> {
    println!("CAPU-P6-REPLAY-VERIFY v0");

    let sealed = build_p6_audit_chain();
    println!("sealed_events={}", sealed.len());

    let summary = replay_p6_audit_chain(&sealed)
        .map_err(|err| format!("P6 replay verification failed: {err:?}"))?;

    println!(
        "replay_summary events={} p6_boundary_events={} rejected_without_commit={} accepted_committed_action={}",
        summary.events,
        summary.p6_boundary_events,
        summary.rejected_without_commit,
        summary.accepted_committed_action
    );

    if !summary.valid_p6_pair() {
        return Err("P6 replay summary is not a valid canonical pair".to_string());
    }

    println!("result=capu_p6_replay_verified");
    Ok(())
}

fn main() -> ExitCode {
    match run() {
        Ok(()) => ExitCode::SUCCESS,
        Err(err) => {
            eprintln!("result=capu_p6_replay_failed reason={err}");
            ExitCode::FAILURE
        }
    }
}

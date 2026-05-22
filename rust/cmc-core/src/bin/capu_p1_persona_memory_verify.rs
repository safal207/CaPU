use std::process::ExitCode;

use cmc_core::capu::audit_bus::emit_audit_record;
use cmc_core::capu::decision_unit::decide_transition;
use cmc_core::capu::decoder::{decode_persona_memory, PersonaMemoryRequest};
use cmc_core::capu::seal_unit::{seal_audit_records, verify_sealed_audit_records};
use cmc_core::capu::transition::{Boundary, DecisionClass, UnitDecision};

fn require_decision(
    decision: &UnitDecision,
    expected_class: DecisionClass,
    expected_code: &str,
    expected_verdict: &str,
    expected_cause_id: Option<u64>,
) -> Result<(), String> {
    if decision.class != expected_class {
        return Err(format!("unexpected decision class: {:?}", decision.class));
    }
    if decision.code != expected_code {
        return Err(format!("unexpected decision code: {}", decision.code));
    }
    if decision.invariant_id != "P1" {
        return Err(format!(
            "unexpected invariant id: {}",
            decision.invariant_id
        ));
    }
    if decision.boundary != Boundary::PersonaMemoryRequiresCause {
        return Err(format!("unexpected boundary: {:?}", decision.boundary));
    }
    if decision.verdict != expected_verdict {
        return Err(format!("unexpected verdict: {}", decision.verdict));
    }
    if decision.cause_id != expected_cause_id {
        return Err(format!(
            "unexpected cause id: {:?}",
            decision.cause_id
        ));
    }

    Ok(())
}

fn run() -> Result<(), String> {
    println!("CAPU-P1-PERSONA-MEMORY-VERIFY v0");

    let unconfirmed = decode_persona_memory(PersonaMemoryRequest::new(
        "p1-unconfirmed-memory",
        "prefers concise technical summaries",
        None,
    ));
    let unconfirmed_decision = decide_transition(&unconfirmed);
    require_decision(
        &unconfirmed_decision,
        DecisionClass::Reject,
        "REJECT_PERSONA_MEMORY_WITHOUT_CAUSE",
        "blocked_persona_memory_without_cause",
        None,
    )?;
    let unconfirmed_audit = emit_audit_record(&unconfirmed, &unconfirmed_decision);

    let confirmed = decode_persona_memory(PersonaMemoryRequest::new(
        "p1-confirmed-memory",
        "prefers concise technical summaries",
        Some(42),
    ));
    let confirmed_decision = decide_transition(&confirmed);
    require_decision(
        &confirmed_decision,
        DecisionClass::Accept,
        "ACCEPT_PERSONA_MEMORY_WITH_CAUSE",
        "accepted_persona_memory_with_cause",
        Some(42),
    )?;
    let confirmed_audit = emit_audit_record(&confirmed, &confirmed_decision);

    let sealed = seal_audit_records(&[unconfirmed_audit, confirmed_audit]);
    verify_sealed_audit_records(&sealed)
        .map_err(|event_index| format!("sealed P1 audit failed at event {event_index}"))?;

    println!(
        "unconfirmed_result={} code={} boundary={} accepted={}",
        unconfirmed_decision.verdict,
        unconfirmed_decision.code,
        unconfirmed_decision.boundary.as_str(),
        unconfirmed_decision.accepted()
    );
    println!(
        "confirmed_result={} code={} boundary={} cause_id={} accepted={}",
        confirmed_decision.verdict,
        confirmed_decision.code,
        confirmed_decision.boundary.as_str(),
        confirmed_decision.cause_id.unwrap_or_default(),
        confirmed_decision.accepted()
    );
    println!("sealed_events={}", sealed.len());
    println!("seal_result=capu_p1_persona_memory_seal_valid");
    println!("result=capu_p1_persona_memory_verified");

    Ok(())
}

fn main() -> ExitCode {
    match run() {
        Ok(()) => ExitCode::SUCCESS,
        Err(err) => {
            eprintln!("result=capu_p1_persona_memory_invalid");
            eprintln!("error={err}");
            ExitCode::FAILURE
        }
    }
}

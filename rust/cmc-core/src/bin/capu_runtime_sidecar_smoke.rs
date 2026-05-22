use std::process::ExitCode;

use cmc_core::capu::audit_bus::emit_audit_record;
use cmc_core::capu::decoder::{
    decode_external_action, decode_persona_memory, ExternalActionRequest, PersonaMemoryRequest,
};
use cmc_core::capu::decision_unit::decide_transition;
use cmc_core::capu::replay_unit::{replay_p1_persona_memory_audit_chain, replay_p6_audit_chain};
use cmc_core::capu::seal_unit::seal_audit_records;
use cmc_core::capu::transition::{DecisionClass, Transition};

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
enum RuntimeRoute {
    Health,
    Decide,
    Audit,
    Replay,
}

impl RuntimeRoute {
    fn path(self) -> &'static str {
        match self {
            Self::Health => "/capu/health",
            Self::Decide => "/capu/decide",
            Self::Audit => "/capu/audit",
            Self::Replay => "/capu/replay",
        }
    }
}

#[derive(Debug, Clone, PartialEq, Eq)]
struct RuntimeResponse {
    status_code: u16,
    body: String,
}

fn json_field(name: &str, value: &str) -> String {
    format!("\"{name}\":\"{value}\"")
}

fn json_bool_field(name: &str, value: bool) -> String {
    format!("\"{name}\":{value}")
}

fn json_number_field(name: &str, value: usize) -> String {
    format!("\"{name}\":{value}")
}

fn decision_class(decision_class: DecisionClass) -> &'static str {
    match decision_class {
        DecisionClass::Accept => "accept",
        DecisionClass::Reject => "reject",
        DecisionClass::Hold => "hold",
    }
}

fn decision_response(transition: &Transition) -> RuntimeResponse {
    let decision = decide_transition(transition);
    RuntimeResponse {
        status_code: 200,
        body: format!(
            "{{{},{},{},{},{},{}}}",
            json_field("route", RuntimeRoute::Decide.path()),
            json_field("decision_class", decision_class(decision.class)),
            json_field("code", decision.code),
            json_field("invariant_id", decision.invariant_id),
            json_field("boundary", decision.boundary.as_str()),
            json_field("verdict", decision.verdict),
        ),
    }
}

fn health_response() -> RuntimeResponse {
    RuntimeResponse {
        status_code: 200,
        body: format!(
            "{{{},{},{}}}",
            json_field("route", RuntimeRoute::Health.path()),
            json_field("status", "ok"),
            json_field("service", "capu-runtime-sidecar-mvp")
        ),
    }
}

fn audit_response(transition: &Transition) -> RuntimeResponse {
    let decision = decide_transition(transition);
    let record = emit_audit_record(transition, &decision);

    RuntimeResponse {
        status_code: 200,
        body: format!(
            "{{{},{},{},{},{},{}}}",
            json_field("route", RuntimeRoute::Audit.path()),
            json_field("transition_id", &record.transition_id),
            json_field("invariant_id", record.decision.invariant_id),
            json_field("boundary", record.decision.boundary.as_str()),
            json_field("verdict", record.decision.verdict),
            json_bool_field("accepted", record.decision.accepted())
        ),
    }
}

fn p1_replay_response(reject: &Transition, accept: &Transition) -> RuntimeResponse {
    let reject_decision = decide_transition(reject);
    let accept_decision = decide_transition(accept);
    let reject_record = emit_audit_record(reject, &reject_decision);
    let accept_record = emit_audit_record(accept, &accept_decision);
    let sealed = seal_audit_records(&[reject_record, accept_record]);

    match replay_p1_persona_memory_audit_chain(&sealed) {
        Ok(summary) => RuntimeResponse {
            status_code: 200,
            body: format!(
                "{{{},{},{},{},{},{}}}",
                json_field("route", RuntimeRoute::Replay.path()),
                json_field("invariant_id", "P1"),
                json_field("result", "capu_runtime_replay_valid"),
                json_number_field("events", summary.events),
                json_number_field("p1_boundary_events", summary.p1_boundary_events),
                json_number_field("rejected_without_cause", summary.rejected_without_cause)
            ),
        },
        Err(err) => RuntimeResponse {
            status_code: 500,
            body: format!(
                "{{{},{}}}",
                json_field("route", RuntimeRoute::Replay.path()),
                json_field("error", &format!("{:?}", err))
            ),
        },
    }
}

fn p6_replay_response(reject: &Transition, accept: &Transition) -> RuntimeResponse {
    let reject_decision = decide_transition(reject);
    let accept_decision = decide_transition(accept);
    let reject_record = emit_audit_record(reject, &reject_decision);
    let accept_record = emit_audit_record(accept, &accept_decision);
    let sealed = seal_audit_records(&[reject_record, accept_record]);

    match replay_p6_audit_chain(&sealed) {
        Ok(summary) => RuntimeResponse {
            status_code: 200,
            body: format!(
                "{{{},{},{},{},{},{}}}",
                json_field("route", RuntimeRoute::Replay.path()),
                json_field("invariant_id", "P6"),
                json_field("result", "capu_runtime_replay_valid"),
                json_number_field("events", summary.events),
                json_number_field("p6_boundary_events", summary.p6_boundary_events),
                json_number_field("rejected_without_commit", summary.rejected_without_commit)
            ),
        },
        Err(err) => RuntimeResponse {
            status_code: 500,
            body: format!(
                "{{{},{}}}",
                json_field("route", RuntimeRoute::Replay.path()),
                json_field("error", &format!("{:?}", err))
            ),
        },
    }
}

fn assert_body_contains(response: &RuntimeResponse, expected: &str) -> Result<(), String> {
    if response.body.contains(expected) {
        Ok(())
    } else {
        Err(format!(
            "expected response body to contain `{expected}`, got `{}`",
            response.body
        ))
    }
}

fn run_smoke() -> Result<(), String> {
    let p1_reject = decode_persona_memory(PersonaMemoryRequest::new(
        "runtime-p1-reject",
        "raw inferred preference",
        None,
    ));
    let p1_accept = decode_persona_memory(PersonaMemoryRequest::new(
        "runtime-p1-accept",
        "confirmed preference",
        Some(42),
    ));
    let p6_reject = decode_external_action(ExternalActionRequest::new(
        "runtime-p6-reject",
        "send_email",
        None,
        false,
    ));
    let p6_accept = decode_external_action(ExternalActionRequest::new(
        "runtime-p6-accept",
        "send_email",
        Some(101),
        true,
    ));

    let health = health_response();
    assert_eq!(health.status_code, 200);
    assert_body_contains(&health, "\"status\":\"ok\"")?;

    let p1_decide_reject = decision_response(&p1_reject);
    assert_body_contains(&p1_decide_reject, "REJECT_PERSONA_MEMORY_WITHOUT_CAUSE")?;
    assert_body_contains(&p1_decide_reject, "blocked_persona_memory_without_cause")?;

    let p1_decide_accept = decision_response(&p1_accept);
    assert_body_contains(&p1_decide_accept, "ACCEPT_PERSONA_MEMORY_WITH_CAUSE")?;
    assert_body_contains(&p1_decide_accept, "accepted_persona_memory_with_cause")?;

    let p6_decide_reject = decision_response(&p6_reject);
    assert_body_contains(&p6_decide_reject, "REJECT_ACTION_WITHOUT_COMMIT")?;
    assert_body_contains(&p6_decide_reject, "blocked_action_without_commit")?;

    let p6_decide_accept = decision_response(&p6_accept);
    assert_body_contains(&p6_decide_accept, "ACCEPT_COMMITTED_ACTION")?;
    assert_body_contains(&p6_decide_accept, "accepted_committed_action")?;

    let p1_audit = audit_response(&p1_accept);
    assert_body_contains(&p1_audit, RuntimeRoute::Audit.path())?;
    assert_body_contains(&p1_audit, "accepted_persona_memory_with_cause")?;

    let p6_audit = audit_response(&p6_accept);
    assert_body_contains(&p6_audit, RuntimeRoute::Audit.path())?;
    assert_body_contains(&p6_audit, "accepted_committed_action")?;

    let p1_replay = p1_replay_response(&p1_reject, &p1_accept);
    assert_body_contains(&p1_replay, "capu_runtime_replay_valid")?;
    assert_body_contains(&p1_replay, "p1_boundary_events")?;

    let p6_replay = p6_replay_response(&p6_reject, &p6_accept);
    assert_body_contains(&p6_replay, "capu_runtime_replay_valid")?;
    assert_body_contains(&p6_replay, "p6_boundary_events")?;

    println!("CAPU-RUNTIME-SIDECAR-SMOKE v0");
    println!("route={} status=ok", RuntimeRoute::Health.path());
    println!("route={} p1_reject=blocked_persona_memory_without_cause p1_accept=accepted_persona_memory_with_cause", RuntimeRoute::Decide.path());
    println!("route={} p6_reject=blocked_action_without_commit p6_accept=accepted_committed_action", RuntimeRoute::Decide.path());
    println!("route={} p1_audit=ok p6_audit=ok", RuntimeRoute::Audit.path());
    println!("route={} p1_replay=ok p6_replay=ok", RuntimeRoute::Replay.path());
    println!("result=capu_runtime_sidecar_smoke_verified");

    Ok(())
}

fn main() -> ExitCode {
    match run_smoke() {
        Ok(()) => ExitCode::SUCCESS,
        Err(err) => {
            eprintln!("result=capu_runtime_sidecar_smoke_failed error={err}");
            ExitCode::FAILURE
        }
    }
}

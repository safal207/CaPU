use std::env;
use std::fs;
use std::io::{Read, Write};
use std::net::{Shutdown, SocketAddr, TcpListener, TcpStream};
use std::process::ExitCode;
use std::thread;

use cmc_core::capu::audit_bus::emit_audit_record;
use cmc_core::capu::decoder::{
    decode_external_action, decode_persona_memory, ExternalActionRequest, PersonaMemoryRequest,
};
use cmc_core::capu::decision_unit::decide_transition;
use cmc_core::capu::replay_unit::{replay_p1_persona_memory_audit_chain, replay_p6_audit_chain};
use cmc_core::capu::seal_unit::seal_audit_records;
use cmc_core::capu::transition::{DecisionClass, Transition};
use cmc_core::CauseId;

const DEFAULT_ADDR: &str = "127.0.0.1:8787";
const FIXTURE_DIR: &str = "fixtures/capu_runtime_http";

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
    format!("\"{name}\":\"{}\"", escape_json(value))
}

fn json_bool_field(name: &str, value: bool) -> String {
    format!("\"{name}\":{value}")
}

fn json_number_field(name: &str, value: usize) -> String {
    format!("\"{name}\":{value}")
}

fn escape_json(value: &str) -> String {
    value
        .replace('\\', "\\\\")
        .replace('"', "\\\"")
        .replace('\n', "\\n")
        .replace('\r', "\\r")
        .replace('\t', "\\t")
}

fn decision_class(decision_class: DecisionClass) -> &'static str {
    match decision_class {
        DecisionClass::Accept => "accept",
        DecisionClass::Reject => "reject",
        DecisionClass::Hold => "hold",
    }
}

fn health_response() -> RuntimeResponse {
    RuntimeResponse {
        status_code: 200,
        body: format!(
            "{{{},{},{}}}",
            json_field("route", RuntimeRoute::Health.path()),
            json_field("status", "ok"),
            json_field("service", "capu-runtime-http-sidecar")
        ),
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
            json_field("verdict", decision.verdict)
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
            json_field("invariant_id", record.invariant_id),
            json_field("boundary", record.boundary),
            json_field("verdict", record.verdict),
            json_bool_field("accepted", record.decision_class == "accept")
        ),
    }
}

fn p1_replay_response() -> RuntimeResponse {
    let rejected = decode_persona_memory(PersonaMemoryRequest::new(
        "http-p1-reject",
        "raw inferred preference",
        None,
    ));
    let accepted = decode_persona_memory(PersonaMemoryRequest::new(
        "http-p1-accept",
        "confirmed preference",
        Some(42),
    ));

    let rejected_decision = decide_transition(&rejected);
    let accepted_decision = decide_transition(&accepted);
    let rejected_record = emit_audit_record(&rejected, &rejected_decision);
    let accepted_record = emit_audit_record(&accepted, &accepted_decision);
    let sealed = seal_audit_records(&[rejected_record, accepted_record]);

    match replay_p1_persona_memory_audit_chain(&sealed) {
        Ok(summary) => RuntimeResponse {
            status_code: 200,
            body: format!(
                "{{{},{},{},{},{},{}}}",
                json_field("route", RuntimeRoute::Replay.path()),
                json_field("invariant_id", "P1"),
                json_field("result", "capu_runtime_http_replay_valid"),
                json_number_field("events", summary.events),
                json_number_field("p1_boundary_events", summary.p1_boundary_events),
                json_number_field("rejected_without_cause", summary.rejected_without_cause)
            ),
        },
        Err(err) => error_response(500, &format!("p1_replay_failed:{err:?}")),
    }
}

fn p6_replay_response() -> RuntimeResponse {
    let rejected = decode_external_action(ExternalActionRequest::new(
        "http-p6-reject",
        "send_email",
        None,
        false,
    ));
    let accepted = decode_external_action(ExternalActionRequest::new(
        "http-p6-accept",
        "send_email",
        Some(101),
        true,
    ));

    let rejected_decision = decide_transition(&rejected);
    let accepted_decision = decide_transition(&accepted);
    let rejected_record = emit_audit_record(&rejected, &rejected_decision);
    let accepted_record = emit_audit_record(&accepted, &accepted_decision);
    let sealed = seal_audit_records(&[rejected_record, accepted_record]);

    match replay_p6_audit_chain(&sealed) {
        Ok(summary) => RuntimeResponse {
            status_code: 200,
            body: format!(
                "{{{},{},{},{},{},{}}}",
                json_field("route", RuntimeRoute::Replay.path()),
                json_field("invariant_id", "P6"),
                json_field("result", "capu_runtime_http_replay_valid"),
                json_number_field("events", summary.events),
                json_number_field("p6_boundary_events", summary.p6_boundary_events),
                json_number_field("rejected_without_commit", summary.rejected_without_commit)
            ),
        },
        Err(err) => error_response(500, &format!("p6_replay_failed:{err:?}")),
    }
}

fn error_response(status_code: u16, error: &str) -> RuntimeResponse {
    RuntimeResponse {
        status_code,
        body: format!(
            "{{{},{}}}",
            json_field("status", "error"),
            json_field("error", error)
        ),
    }
}

fn transition_from_body(body: &str) -> Transition {
    if body.contains("persona_memory") || body.contains("PersonaMemory") || body.contains("memory") {
        let transition_id = json_string_value(body, "transition_id").unwrap_or("http-p1".to_string());
        let memory = json_string_value(body, "memory").unwrap_or("runtime memory".to_string());
        decode_persona_memory(PersonaMemoryRequest::new(
            transition_id,
            memory,
            json_u64_value(body, "cause_id"),
        ))
    } else {
        let transition_id = json_string_value(body, "transition_id").unwrap_or("http-p6".to_string());
        let action_kind = json_string_value(body, "action_kind").unwrap_or("send_email".to_string());
        decode_external_action(ExternalActionRequest::new(
            transition_id,
            action_kind,
            json_u64_value(body, "cause_id"),
            json_bool_value(body, "commit"),
        ))
    }
}

fn json_string_value(body: &str, key: &str) -> Option<String> {
    let needle = format!("\"{key}\"");
    let start = body.find(&needle)? + needle.len();
    let after_key = &body[start..];
    let colon = after_key.find(':')? + 1;
    let after_colon = after_key[colon..].trim_start();
    let value_start = after_colon.find('"')? + 1;
    let rest = &after_colon[value_start..];
    let value_end = rest.find('"')?;
    Some(rest[..value_end].to_string())
}

fn json_u64_value(body: &str, key: &str) -> Option<CauseId> {
    let needle = format!("\"{key}\"");
    let start = body.find(&needle)? + needle.len();
    let after_key = &body[start..];
    let colon = after_key.find(':')? + 1;
    let mut digits = String::new();
    for ch in after_key[colon..].trim_start().chars() {
        if ch.is_ascii_digit() {
            digits.push(ch);
        } else {
            break;
        }
    }
    if digits.is_empty() {
        None
    } else {
        digits.parse().ok()
    }
}

fn json_bool_value(body: &str, key: &str) -> bool {
    let needle = format!("\"{key}\"");
    let Some(start) = body.find(&needle) else {
        return false;
    };
    let after_key = &body[start + needle.len()..];
    let Some(colon) = after_key.find(':') else {
        return false;
    };
    after_key[colon + 1..].trim_start().starts_with("true")
}

fn handle_request(method: &str, path: &str, body: &str) -> RuntimeResponse {
    match (method, path) {
        ("GET", "/capu/health") => health_response(),
        ("POST", "/capu/decide") => decision_response(&transition_from_body(body)),
        ("POST", "/capu/audit") => audit_response(&transition_from_body(body)),
        ("POST", "/capu/replay") if body.contains("P1") || body.contains("persona_memory") => {
            p1_replay_response()
        }
        ("POST", "/capu/replay") => p6_replay_response(),
        _ => error_response(404, "route_not_found"),
    }
}

fn parse_http_request(request: &str) -> Result<(&str, &str, &str), String> {
    let mut lines = request.lines();
    let request_line = lines.next().ok_or_else(|| "missing request line".to_string())?;
    let mut parts = request_line.split_whitespace();
    let method = parts.next().ok_or_else(|| "missing method".to_string())?;
    let path = parts.next().ok_or_else(|| "missing path".to_string())?;
    let body = request
        .split_once("\r\n\r\n")
        .map(|(_, body)| body)
        .or_else(|| request.split_once("\n\n").map(|(_, body)| body))
        .unwrap_or("");
    Ok((method, path, body))
}

fn write_http_response(mut stream: TcpStream, response: RuntimeResponse) -> Result<(), String> {
    let reason = match response.status_code {
        200 => "OK",
        400 => "Bad Request",
        404 => "Not Found",
        _ => "Internal Server Error",
    };
    let payload = format!(
        "HTTP/1.1 {} {}\r\nContent-Type: application/json\r\nContent-Length: {}\r\nConnection: close\r\n\r\n{}",
        response.status_code,
        reason,
        response.body.len(),
        response.body
    );
    stream
        .write_all(payload.as_bytes())
        .map_err(|err| format!("failed to write response: {err}"))
}

fn handle_stream(mut stream: TcpStream) -> Result<(), String> {
    let mut request = String::new();
    stream
        .read_to_string(&mut request)
        .map_err(|err| format!("failed to read request: {err}"))?;

    let response = match parse_http_request(&request) {
        Ok((method, path, body)) => handle_request(method, path, body),
        Err(err) => error_response(400, &format!("bad_request:{err}")),
    };

    write_http_response(stream, response)
}

fn run_listener(listener: TcpListener, max_requests: Option<usize>) -> Result<(), String> {
    let mut handled = 0usize;
    for stream in listener.incoming() {
        let stream = stream.map_err(|err| format!("incoming connection failed: {err}"))?;
        handle_stream(stream)?;
        handled += 1;
        if max_requests.is_some_and(|max| handled >= max) {
            break;
        }
    }
    Ok(())
}

fn run_server(addr: &str) -> Result<(), String> {
    let listener = TcpListener::bind(addr).map_err(|err| format!("failed to bind {addr}: {err}"))?;
    println!("CAPU-RUNTIME-HTTP-SIDECAR v0");
    println!("listening={addr}");
    println!("routes=/capu/health,/capu/decide,/capu/audit,/capu/replay");
    run_listener(listener, None)
}

fn send_http(addr: SocketAddr, method: &str, path: &str, body: &str) -> Result<String, String> {
    let request = format!(
        "{method} {path} HTTP/1.1\r\nHost: {addr}\r\nContent-Type: application/json\r\nContent-Length: {}\r\nConnection: close\r\n\r\n{body}",
        body.len()
    );
    send_raw_http(addr, &request)
}

fn send_raw_http(addr: SocketAddr, request: &str) -> Result<String, String> {
    let mut stream = TcpStream::connect(addr).map_err(|err| format!("connect failed: {err}"))?;
    stream
        .write_all(request.as_bytes())
        .map_err(|err| format!("write failed: {err}"))?;
    stream
        .shutdown(Shutdown::Write)
        .map_err(|err| format!("shutdown failed: {err}"))?;

    let mut response = String::new();
    stream
        .read_to_string(&mut response)
        .map_err(|err| format!("read response failed: {err}"))?;
    Ok(response
        .split_once("\r\n\r\n")
        .map(|(_, body)| body.to_string())
        .unwrap_or(response))
}

fn read_fixture(path: &str) -> Result<String, String> {
    fs::read_to_string(path).map_err(|err| format!("failed to read {path}: {err}"))
}

fn assert_response(label: &str, actual: &str, expected_path: &str) -> Result<(), String> {
    let expected = read_fixture(expected_path)?;
    if actual.trim() == expected.trim() {
        Ok(())
    } else {
        Err(format!(
            "{label} response mismatch\nexpected: {}\nactual:   {}",
            expected.trim(),
            actual.trim()
        ))
    }
}

fn run_self_test() -> Result<(), String> {
    let listener = TcpListener::bind("127.0.0.1:0")
        .map_err(|err| format!("failed to bind self-test listener: {err}"))?;
    let addr = listener
        .local_addr()
        .map_err(|err| format!("failed to read listener addr: {err}"))?;

    let server = thread::spawn(move || run_listener(listener, Some(10)));

    let health = send_http(addr, "GET", RuntimeRoute::Health.path(), "")?;
    assert_response(
        "health",
        &health,
        &format!("{FIXTURE_DIR}/responses/health.json"),
    )?;

    let decide_p1_body = read_fixture(&format!(
        "{FIXTURE_DIR}/requests/decide_p1_missing_cause.json"
    ))?;
    let decide_p1 = send_http(addr, "POST", RuntimeRoute::Decide.path(), &decide_p1_body)?;
    assert_response(
        "decide_p1_missing_cause",
        &decide_p1,
        &format!("{FIXTURE_DIR}/responses/decide_p1_missing_cause.json"),
    )?;

    let decide_p6_reject_body = read_fixture(&format!(
        "{FIXTURE_DIR}/requests/decide_p6_uncommitted.json"
    ))?;
    let decide_p6_reject = send_http(
        addr,
        "POST",
        RuntimeRoute::Decide.path(),
        &decide_p6_reject_body,
    )?;
    assert_response(
        "decide_p6_uncommitted",
        &decide_p6_reject,
        &format!("{FIXTURE_DIR}/responses/decide_p6_uncommitted.json"),
    )?;

    let decide_p6_accept_body = read_fixture(&format!(
        "{FIXTURE_DIR}/requests/decide_p6_committed.json"
    ))?;
    let decide_p6_accept = send_http(
        addr,
        "POST",
        RuntimeRoute::Decide.path(),
        &decide_p6_accept_body,
    )?;
    assert_response(
        "decide_p6_committed",
        &decide_p6_accept,
        &format!("{FIXTURE_DIR}/responses/decide_p6_committed.json"),
    )?;

    let audit_reject_body = read_fixture(&format!(
        "{FIXTURE_DIR}/requests/audit_p6_uncommitted.json"
    ))?;
    let audit_reject = send_http(addr, "POST", RuntimeRoute::Audit.path(), &audit_reject_body)?;
    assert_response(
        "audit_p6_uncommitted",
        &audit_reject,
        &format!("{FIXTURE_DIR}/responses/audit_p6_uncommitted.json"),
    )?;

    let audit_accept_body = read_fixture(&format!("{FIXTURE_DIR}/requests/audit_p6_committed.json"))?;
    let audit_accept = send_http(addr, "POST", RuntimeRoute::Audit.path(), &audit_accept_body)?;
    assert_response(
        "audit_p6_committed",
        &audit_accept,
        &format!("{FIXTURE_DIR}/responses/audit_p6_committed.json"),
    )?;

    let replay_p1_body = read_fixture(&format!("{FIXTURE_DIR}/requests/replay_p1_pair.json"))?;
    let replay_p1 = send_http(addr, "POST", RuntimeRoute::Replay.path(), &replay_p1_body)?;
    assert_response(
        "replay_p1_pair",
        &replay_p1,
        &format!("{FIXTURE_DIR}/responses/replay_p1_pair.json"),
    )?;

    let replay_p6_body = read_fixture(&format!("{FIXTURE_DIR}/requests/replay_p6_pair.json"))?;
    let replay_p6 = send_http(addr, "POST", RuntimeRoute::Replay.path(), &replay_p6_body)?;
    assert_response(
        "replay_p6_pair",
        &replay_p6,
        &format!("{FIXTURE_DIR}/responses/replay_p6_pair.json"),
    )?;

    let unknown_route = send_http(addr, "GET", "/capu/unknown", "")?;
    assert_response(
        "unknown_route",
        &unknown_route,
        &format!("{FIXTURE_DIR}/responses/unknown_route.json"),
    )?;

    let malformed_request = send_raw_http(addr, "BROKEN\r\n\r\n")?;
    assert_response(
        "malformed_request",
        &malformed_request,
        &format!("{FIXTURE_DIR}/responses/malformed_request.json"),
    )?;

    server
        .join()
        .map_err(|_| "self-test server panicked".to_string())??;

    println!("CAPU-RUNTIME-HTTP-SIDECAR-SELF-TEST v0");
    println!("route={} status=ok", RuntimeRoute::Health.path());
    println!("route={} case=decide_p1_missing_cause status=ok", RuntimeRoute::Decide.path());
    println!("route={} case=decide_p6_uncommitted status=ok", RuntimeRoute::Decide.path());
    println!("route={} case=decide_p6_committed status=ok", RuntimeRoute::Decide.path());
    println!("route={} case=audit_p6_uncommitted status=ok", RuntimeRoute::Audit.path());
    println!("route={} case=audit_p6_committed status=ok", RuntimeRoute::Audit.path());
    println!("route={} case=replay_p1_pair status=ok", RuntimeRoute::Replay.path());
    println!("route={} case=replay_p6_pair status=ok", RuntimeRoute::Replay.path());
    println!("route=/capu/unknown case=unknown_route status=ok");
    println!("case=malformed_request status=ok");
    println!("fixtures={FIXTURE_DIR}");
    println!("result=capu_runtime_http_sidecar_verified");

    Ok(())
}

fn main() -> ExitCode {
    let args: Vec<String> = env::args().collect();
    let result = if args.iter().any(|arg| arg == "--self-test") {
        run_self_test()
    } else {
        let addr = args
            .windows(2)
            .find(|pair| pair[0] == "--addr")
            .map(|pair| pair[1].as_str())
            .unwrap_or(DEFAULT_ADDR);
        run_server(addr)
    };

    match result {
        Ok(()) => ExitCode::SUCCESS,
        Err(err) => {
            eprintln!("result=capu_runtime_http_sidecar_failed error={err}");
            ExitCode::FAILURE
        }
    }
}

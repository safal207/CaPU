use std::{fs, process::ExitCode};

const VALID_REPORT: &str = "../../examples/audit_reports/persona_audit_report_valid.jsonl";
const DRIFT_REPORT: &str = "../../examples/audit_reports/persona_audit_report_drift.jsonl";
const CASES: usize = 8;

#[derive(Clone, Copy)]
struct ExpectedCase {
    scenario_id: &'static str,
    invariant_id: &'static str,
    boundary: &'static str,
    fixture: &'static str,
    user_confirmation: bool,
    decision: &'static str,
    cause_id: Option<u64>,
    expected_verdict: &'static str,
}

const VALID_CASES: &[ExpectedCase] = &[
    ExpectedCase { scenario_id: "inferred_preference_rejected", invariant_id: "P1", boundary: "persona_memory_requires_cause", fixture: "fixtures/persona/inferred_preference_rejected.jsonl", user_confirmation: false, decision: "REJECT_INFERRED_MEMORY", cause_id: None, expected_verdict: "blocked_unconfirmed_persona_memory" },
    ExpectedCase { scenario_id: "confirmed_preference_accepted", invariant_id: "P1", boundary: "persona_memory_requires_cause", fixture: "fixtures/persona/confirmed_preference_accepted.jsonl", user_confirmation: true, decision: "ACCEPT_CONFIRMED_MEMORY", cause_id: Some(42), expected_verdict: "accepted_confirmed_persona_memory" },
    ExpectedCase { scenario_id: "unauthorized_persona_state_change_rejected", invariant_id: "P2", boundary: "persona_state_change_requires_authorization", fixture: "fixtures/persona/unauthorized_persona_state_change_rejected.jsonl", user_confirmation: false, decision: "REJECT_UNAUTHORIZED_PERSONA_STATE_CHANGE", cause_id: None, expected_verdict: "blocked_unauthorized_persona_state_change" },
    ExpectedCase { scenario_id: "authorized_persona_state_change_accepted", invariant_id: "P2", boundary: "persona_state_change_requires_authorization", fixture: "fixtures/persona/authorized_persona_state_change_accepted.jsonl", user_confirmation: true, decision: "ACCEPT_AUTHORIZED_PERSONA_STATE_CHANGE", cause_id: Some(77), expected_verdict: "accepted_authorized_persona_state_change" },
    ExpectedCase { scenario_id: "action_without_commit_rejected", invariant_id: "P6", boundary: "action_requires_commit", fixture: "fixtures/persona/action_without_commit_rejected.jsonl", user_confirmation: false, decision: "REJECT_ACTION_WITHOUT_COMMIT", cause_id: None, expected_verdict: "blocked_action_without_commit" },
    ExpectedCase { scenario_id: "action_with_commit_accepted", invariant_id: "P6", boundary: "action_requires_commit", fixture: "fixtures/persona/action_with_commit_accepted.jsonl", user_confirmation: true, decision: "ACCEPT_COMMITTED_ACTION", cause_id: Some(101), expected_verdict: "accepted_committed_action" },
    ExpectedCase { scenario_id: "unlabeled_introspection_rejected", invariant_id: "P7", boundary: "introspection_requires_hypothesis_label", fixture: "fixtures/persona/unlabeled_introspection_rejected.jsonl", user_confirmation: false, decision: "REJECT_UNLABELED_INTROSPECTION", cause_id: None, expected_verdict: "blocked_claimed_inner_truth" },
    ExpectedCase { scenario_id: "hypothesis_labeled_introspection_accepted", invariant_id: "P7", boundary: "introspection_requires_hypothesis_label", fixture: "fixtures/persona/hypothesis_labeled_introspection_accepted.jsonl", user_confirmation: false, decision: "ACCEPT_HYPOTHESIS_LABELED_INTROSPECTION", cause_id: None, expected_verdict: "accepted_hypothesis_labeled_reflection" },
];

fn read(path: &str) -> Result<String, String> {
    fs::read_to_string(path).map_err(|err| format!("failed to read {path}: {err}"))
}

fn records(path: &str) -> Result<Vec<String>, String> {
    Ok(read(path)?.lines().map(str::trim).filter(|line| !line.is_empty()).map(ToOwned::to_owned).collect())
}

fn require(condition: bool, message: impl Into<String>) -> Result<(), String> {
    if condition { Ok(()) } else { Err(message.into()) }
}

fn contains_str(line: &str, key: &str, expected: &str) -> bool {
    line.contains(&format!("\"{key}\":\"{expected}\""))
}

fn contains_bool(line: &str, key: &str, expected: bool) -> bool {
    line.contains(&format!("\"{key}\":{expected}"))
}

fn contains_num(line: &str, key: &str, expected: u64) -> bool {
    line.contains(&format!("\"{key}\":{expected}"))
}

fn contains_cause(line: &str, expected: Option<u64>) -> bool {
    match expected {
        Some(cause_id) => contains_num(line, "cause_id", cause_id),
        None => line.contains("\"cause_id\":null"),
    }
}

fn verify_start(line: &str) -> Result<(), String> {
    require(contains_str(line, "type", "persona_audit_report_start"), "missing start type")?;
    require(contains_str(line, "manifest", "fixtures/persona/MANIFEST.tsv"), "missing manifest")
}

fn verify_valid_case(line: &str, expected: ExpectedCase) -> Result<(), String> {
    require(contains_str(line, "type", "persona_audit_case"), "missing case type")?;
    require(contains_str(line, "scenario_id", expected.scenario_id), format!("scenario mismatch for {}", expected.scenario_id))?;
    require(contains_str(line, "invariant_id", expected.invariant_id), format!("invariant mismatch for {}", expected.scenario_id))?;
    require(contains_str(line, "boundary", expected.boundary), format!("boundary mismatch for {}", expected.scenario_id))?;
    require(contains_str(line, "fixture", expected.fixture), format!("fixture mismatch for {}", expected.scenario_id))?;
    require(contains_bool(line, "user_confirmation", expected.user_confirmation), format!("confirmation mismatch for {}", expected.scenario_id))?;
    require(contains_str(line, "decision", expected.decision), format!("decision mismatch for {}", expected.scenario_id))?;
    require(contains_cause(line, expected.cause_id), format!("cause mismatch for {}", expected.scenario_id))?;
    require(contains_str(line, "expected_verdict", expected.expected_verdict), format!("verdict mismatch for {}", expected.scenario_id))?;
    require(contains_num(line, "expected_records", 1), format!("expected_records mismatch for {}", expected.scenario_id))?;
    require(contains_num(line, "actual_records", 1), format!("actual_records mismatch for {}", expected.scenario_id))?;
    require(contains_bool(line, "ok", true), format!("ok mismatch for {}", expected.scenario_id))?;
    require(contains_str(line, "status", "persona_audit_case_valid"), format!("status mismatch for {}", expected.scenario_id))
}

fn verify_valid_summary(line: &str) -> Result<(), String> {
    require(contains_str(line, "type", "persona_audit_report_summary"), "valid summary type mismatch")?;
    require(contains_bool(line, "ok", true), "valid summary ok mismatch")?;
    require(contains_num(line, "cases", CASES as u64), "valid summary cases mismatch")?;
    require(contains_num(line, "passed", CASES as u64), "valid summary passed mismatch")?;
    require(contains_num(line, "failed", 0), "valid summary failed mismatch")?;
    require(contains_str(line, "status", "persona_audit_report_valid"), "valid summary status mismatch")
}

fn verify_drift_case(line: &str) -> Result<(), String> {
    let expected = VALID_CASES[2];
    require(contains_str(line, "type", "persona_audit_case"), "drift case type mismatch")?;
    require(contains_str(line, "scenario_id", expected.scenario_id), "drift scenario mismatch")?;
    require(contains_str(line, "invariant_id", expected.invariant_id), "drift invariant mismatch")?;
    require(contains_str(line, "boundary", expected.boundary), "drift boundary mismatch")?;
    require(contains_str(line, "fixture", expected.fixture), "drift fixture mismatch")?;
    require(contains_bool(line, "user_confirmation", expected.user_confirmation), "drift confirmation mismatch")?;
    require(contains_str(line, "decision", "ACCEPT_AUTHORIZED_PERSONA_STATE_CHANGE"), "drift decision mismatch")?;
    require(contains_cause(line, expected.cause_id), "drift cause mismatch")?;
    require(contains_str(line, "expected_verdict", expected.expected_verdict), "drift verdict mismatch")?;
    require(contains_bool(line, "ok", false), "drift ok mismatch")?;
    require(contains_str(line, "status", "decision_drift"), "drift status mismatch")
}

fn verify_drift_summary(line: &str) -> Result<(), String> {
    require(contains_str(line, "type", "persona_audit_report_summary"), "drift summary type mismatch")?;
    require(contains_bool(line, "ok", false), "drift summary ok mismatch")?;
    require(contains_num(line, "cases", CASES as u64), "drift summary cases mismatch")?;
    require(contains_num(line, "passed", (CASES - 1) as u64), "drift summary passed mismatch")?;
    require(contains_num(line, "failed", 1), "drift summary failed mismatch")?;
    require(contains_str(line, "status", "persona_audit_report_failed"), "drift summary status mismatch")
}

fn verify_valid_report() -> Result<(), String> {
    let report = records(VALID_REPORT)?;
    require(report.len() == VALID_CASES.len() + 2, format!("valid report record count drift: expected {}, actual {}", VALID_CASES.len() + 2, report.len()))?;
    verify_start(&report[0])?;
    for (idx, expected) in VALID_CASES.iter().enumerate() {
        verify_valid_case(&report[idx + 1], *expected)?;
    }
    verify_valid_summary(&report[VALID_CASES.len() + 1])
}

fn verify_drift_report() -> Result<(), String> {
    let report = records(DRIFT_REPORT)?;
    require(report.len() == 3, format!("drift report record count drift: expected 3, actual {}", report.len()))?;
    verify_start(&report[0])?;
    verify_drift_case(&report[1])?;
    verify_drift_summary(&report[2])
}

fn main() -> ExitCode {
    println!("PERSONA-AUDIT-REPORT-EXAMPLE-VERIFY v0");

    if let Err(err) = verify_valid_report() {
        eprintln!("result=failed report=valid error={err}");
        return ExitCode::FAILURE;
    }
    println!("report=valid path={VALID_REPORT} cases={CASES} status=ok parser=field_level");

    if let Err(err) = verify_drift_report() {
        eprintln!("result=failed report=drift error={err}");
        return ExitCode::FAILURE;
    }
    println!("report=drift path={DRIFT_REPORT} cases={CASES} status=ok parser=field_level");

    println!("result=persona_audit_report_examples_valid parser=field_level cases={CASES}");
    ExitCode::SUCCESS
}

use std::{fmt::Write, fs, process::ExitCode};

const MANIFEST_PATH: &str = "fixtures/persona/MANIFEST.tsv";
const MANIFEST_HEADER: &str = "scenario_id\tinvariant_id\tpath\tboundary\tuser_confirmation\tdecision\tcause_id\texpected_verdict";

#[derive(Debug, Clone)]
struct PersonaAuditCase {
    scenario_id: String,
    invariant_id: String,
    path: String,
    boundary: String,
    user_confirmation: bool,
    decision: String,
    cause_id: Option<u64>,
    expected_verdict: String,
}

fn parse_manifest_bool(raw: &str, line_number: usize) -> Result<bool, String> {
    match raw {
        "true" => Ok(true),
        "false" => Ok(false),
        other => Err(format!(
            "{MANIFEST_PATH}:{line_number} invalid boolean `{other}`"
        )),
    }
}

fn parse_manifest_cause_id(raw: &str, line_number: usize) -> Result<Option<u64>, String> {
    if raw == "null" {
        Ok(None)
    } else {
        raw.parse::<u64>().map(Some).map_err(|err| {
            format!("{MANIFEST_PATH}:{line_number} invalid cause_id `{raw}`: {err}")
        })
    }
}

fn parse_manifest() -> Result<Vec<PersonaAuditCase>, String> {
    let content = fs::read_to_string(MANIFEST_PATH)
        .map_err(|err| format!("failed to read {MANIFEST_PATH}: {err}"))?;

    let mut cases = Vec::new();

    for (idx, line) in content.lines().enumerate() {
        let line_number = idx + 1;
        let line = line.trim();
        if line.is_empty() {
            continue;
        }

        if idx == 0 {
            if line != MANIFEST_HEADER {
                return Err(format!(
                    "{MANIFEST_PATH}:{line_number} unexpected header `{line}`"
                ));
            }
            continue;
        }

        let fields: Vec<&str> = line.split('\t').collect();
        if fields.len() != 8 {
            return Err(format!(
                "{MANIFEST_PATH}:{line_number} expected 8 tab-separated fields, got {}",
                fields.len()
            ));
        }

        cases.push(PersonaAuditCase {
            scenario_id: fields[0].to_string(),
            invariant_id: fields[1].to_string(),
            path: fields[2].to_string(),
            boundary: fields[3].to_string(),
            user_confirmation: parse_manifest_bool(fields[4], line_number)?,
            decision: fields[5].to_string(),
            cause_id: parse_manifest_cause_id(fields[6], line_number)?,
            expected_verdict: fields[7].to_string(),
        });
    }

    if cases.is_empty() {
        return Err(format!("{MANIFEST_PATH} contains no persona audit cases"));
    }

    Ok(cases)
}

fn json_escape(value: &str) -> String {
    value
        .replace('\\', "\\\\")
        .replace('"', "\\\"")
        .replace('\n', "\\n")
        .replace('\r', "\\r")
        .replace('\t', "\\t")
}

fn push_str_field(out: &mut String, key: &str, value: &str) {
    let _ = write!(out, ",\"{key}\":\"{}\"", json_escape(value));
}

fn push_usize_field(out: &mut String, key: &str, value: usize) {
    let _ = write!(out, ",\"{key}\":{value}");
}

fn push_bool_field(out: &mut String, key: &str, value: bool) {
    let _ = write!(out, ",\"{key}\":{value}");
}

fn push_cause_field(out: &mut String, key: &str, value: Option<u64>) {
    match value {
        Some(cause_id) => {
            let _ = write!(out, ",\"{key}\":{cause_id}");
        }
        None => {
            let _ = write!(out, ",\"{key}\":null");
        }
    }
}

fn audit_case(case: &PersonaAuditCase) -> (bool, String, usize) {
    let Ok(content) = fs::read_to_string(&case.path) else {
        return (false, "missing_fixture".to_string(), 0);
    };

    let records = content
        .lines()
        .filter(|line| !line.trim().is_empty())
        .count();

    if records != 1 {
        return (false, "record_count_drift".to_string(), records);
    }

    let required_strings = [
        case.scenario_id.as_str(),
        case.invariant_id.as_str(),
        case.boundary.as_str(),
        case.decision.as_str(),
        case.expected_verdict.as_str(),
    ];

    if required_strings
        .iter()
        .any(|required| !content.contains(required))
    {
        return (false, "fixture_field_drift".to_string(), records);
    }

    let expected_confirmation = format!("\"user_confirmation\":{}", case.user_confirmation);
    if !content.contains(&expected_confirmation) {
        return (false, "user_confirmation_drift".to_string(), records);
    }

    match case.cause_id {
        Some(cause_id) => {
            let expected_cause = format!("\"cause_id\":{cause_id}");
            if !content.contains(&expected_cause) {
                return (false, "cause_id_drift".to_string(), records);
            }
        }
        None => {
            if !content.contains("\"cause_id\":null") {
                return (false, "cause_id_drift".to_string(), records);
            }
        }
    }

    (true, "persona_audit_case_valid".to_string(), records)
}

fn audit_case_json(case: &PersonaAuditCase, ok: bool, status: &str, actual_records: usize) -> String {
    let mut out = "{\"type\":\"persona_audit_case\"".to_string();
    push_str_field(&mut out, "scenario_id", &case.scenario_id);
    push_str_field(&mut out, "invariant_id", &case.invariant_id);
    push_str_field(&mut out, "boundary", &case.boundary);
    push_str_field(&mut out, "fixture", &case.path);
    push_bool_field(&mut out, "user_confirmation", case.user_confirmation);
    push_str_field(&mut out, "decision", &case.decision);
    push_cause_field(&mut out, "cause_id", case.cause_id);
    push_str_field(&mut out, "expected_verdict", &case.expected_verdict);
    push_usize_field(&mut out, "expected_records", 1);
    push_usize_field(&mut out, "actual_records", actual_records);
    push_bool_field(&mut out, "ok", ok);
    push_str_field(&mut out, "status", status);
    out.push('}');
    out
}

fn summary_json(ok: bool, cases: usize, passed: usize, failed: usize, status: &str) -> String {
    let mut out = "{\"type\":\"persona_audit_report_summary\"".to_string();
    push_bool_field(&mut out, "ok", ok);
    push_usize_field(&mut out, "cases", cases);
    push_usize_field(&mut out, "passed", passed);
    push_usize_field(&mut out, "failed", failed);
    push_str_field(&mut out, "status", status);
    out.push('}');
    out
}

fn manifest_error_json(error: &str) -> String {
    let mut out = "{\"type\":\"persona_audit_report_summary\"".to_string();
    push_bool_field(&mut out, "ok", false);
    push_str_field(&mut out, "status", "manifest_error");
    push_str_field(&mut out, "error", error);
    out.push('}');
    out
}

fn main() -> ExitCode {
    println!(
        "{{\"type\":\"persona_audit_report_start\",\"manifest\":\"{MANIFEST_PATH}\"}}"
    );

    let cases = match parse_manifest() {
        Ok(cases) => cases,
        Err(err) => {
            println!("{}", manifest_error_json(&err));
            return ExitCode::FAILURE;
        }
    };

    let mut passed = 0usize;
    let mut failed = 0usize;

    for case in &cases {
        let (ok, status, actual_records) = audit_case(case);
        if ok {
            passed += 1;
        } else {
            failed += 1;
        }

        println!("{}", audit_case_json(case, ok, &status, actual_records));
    }

    let ok = failed == 0;
    let status = if ok {
        "persona_audit_report_valid"
    } else {
        "persona_audit_report_failed"
    };

    println!("{}", summary_json(ok, cases.len(), passed, failed, status));

    if ok {
        ExitCode::SUCCESS
    } else {
        ExitCode::FAILURE
    }
}

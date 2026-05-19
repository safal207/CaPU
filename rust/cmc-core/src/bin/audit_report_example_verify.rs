use std::{collections::BTreeMap, fs, process::ExitCode};

const VALID_REPORT: &str = "../../examples/audit_reports/cmc_audit_report_valid.jsonl";
const DRIFT_REPORT: &str = "../../examples/audit_reports/cmc_audit_report_drift.jsonl";

#[derive(Debug, Clone, PartialEq, Eq)]
enum JsonValue {
    String(String),
    Bool(bool),
    Number(u64),
}

type JsonObject = BTreeMap<String, JsonValue>;

fn read_report(path: &str) -> Result<String, String> {
    fs::read_to_string(path).map_err(|err| format!("failed to read {path}: {err}"))
}

fn parse_string(chars: &[char], idx: &mut usize) -> Result<String, String> {
    if chars.get(*idx) != Some(&'"') {
        return Err(format!("expected string at char {}", *idx));
    }
    *idx += 1;

    let mut out = String::new();
    while let Some(ch) = chars.get(*idx) {
        match ch {
            '"' => {
                *idx += 1;
                return Ok(out);
            }
            '\\' => {
                *idx += 1;
                let escaped = chars
                    .get(*idx)
                    .ok_or_else(|| "unterminated escape sequence".to_string())?;
                let decoded = match escaped {
                    '"' => '"',
                    '\\' => '\\',
                    'n' => '\n',
                    'r' => '\r',
                    't' => '\t',
                    other => {
                        return Err(format!("unsupported escape sequence: \\{other}"));
                    }
                };
                out.push(decoded);
                *idx += 1;
            }
            other => {
                out.push(*other);
                *idx += 1;
            }
        }
    }

    Err("unterminated string".to_string())
}

fn skip_ws(chars: &[char], idx: &mut usize) {
    while chars.get(*idx).is_some_and(|ch| ch.is_whitespace()) {
        *idx += 1;
    }
}

fn parse_number(chars: &[char], idx: &mut usize) -> Result<u64, String> {
    let start = *idx;
    while chars.get(*idx).is_some_and(|ch| ch.is_ascii_digit()) {
        *idx += 1;
    }

    if start == *idx {
        return Err(format!("expected number at char {start}"));
    }

    let raw: String = chars[start..*idx].iter().collect();
    raw.parse::<u64>()
        .map_err(|err| format!("invalid number `{raw}`: {err}"))
}

fn parse_bool(chars: &[char], idx: &mut usize) -> Result<bool, String> {
    let rest: String = chars[*idx..].iter().collect();
    if rest.starts_with("true") {
        *idx += 4;
        Ok(true)
    } else if rest.starts_with("false") {
        *idx += 5;
        Ok(false)
    } else {
        Err(format!("expected boolean at char {}", *idx))
    }
}

fn parse_value(chars: &[char], idx: &mut usize) -> Result<JsonValue, String> {
    skip_ws(chars, idx);
    match chars.get(*idx) {
        Some('"') => Ok(JsonValue::String(parse_string(chars, idx)?)),
        Some(ch) if ch.is_ascii_digit() => Ok(JsonValue::Number(parse_number(chars, idx)?)),
        Some('t') | Some('f') => Ok(JsonValue::Bool(parse_bool(chars, idx)?)),
        Some(other) => Err(format!("unexpected value start `{other}` at char {}", *idx)),
        None => Err("unexpected end while parsing value".to_string()),
    }
}

fn parse_flat_json_object(line: &str) -> Result<JsonObject, String> {
    let chars: Vec<char> = line.chars().collect();
    let mut idx = 0usize;
    let mut out = BTreeMap::new();

    skip_ws(&chars, &mut idx);
    if chars.get(idx) != Some(&'{') {
        return Err("expected object start".to_string());
    }
    idx += 1;

    loop {
        skip_ws(&chars, &mut idx);
        if chars.get(idx) == Some(&'}') {
            idx += 1;
            break;
        }

        let key = parse_string(&chars, &mut idx)?;
        skip_ws(&chars, &mut idx);
        if chars.get(idx) != Some(&':') {
            return Err(format!("expected ':' after key `{key}`"));
        }
        idx += 1;

        let value = parse_value(&chars, &mut idx)?;
        if out.insert(key.clone(), value).is_some() {
            return Err(format!("duplicate key `{key}`"));
        }

        skip_ws(&chars, &mut idx);
        match chars.get(idx) {
            Some(',') => idx += 1,
            Some('}') => {
                idx += 1;
                break;
            }
            Some(other) => return Err(format!("expected ',' or '}}', got `{other}`")),
            None => return Err("unterminated object".to_string()),
        }
    }

    skip_ws(&chars, &mut idx);
    if idx != chars.len() {
        return Err(format!("trailing content after char {idx}"));
    }

    Ok(out)
}

fn parse_jsonl_report(path: &str) -> Result<Vec<JsonObject>, String> {
    let content = read_report(path)?;
    let mut records = Vec::new();

    for (idx, line) in content.lines().enumerate() {
        let line = line.trim();
        if line.is_empty() {
            continue;
        }
        let record = parse_flat_json_object(line)
            .map_err(|err| format!("{path}:{} invalid JSONL record: {err}", idx + 1))?;
        records.push(record);
    }

    if records.is_empty() {
        return Err(format!("{path} contains no JSONL records"));
    }

    Ok(records)
}

fn require_str(record: &JsonObject, key: &str, expected: &str) -> Result<(), String> {
    match record.get(key) {
        Some(JsonValue::String(actual)) if actual == expected => Ok(()),
        Some(actual) => Err(format!(
            "field `{key}` mismatch: expected string `{expected}`, actual {actual:?}"
        )),
        None => Err(format!("missing string field `{key}`")),
    }
}

fn require_bool(record: &JsonObject, key: &str, expected: bool) -> Result<(), String> {
    match record.get(key) {
        Some(JsonValue::Bool(actual)) if *actual == expected => Ok(()),
        Some(actual) => Err(format!(
            "field `{key}` mismatch: expected bool `{expected}`, actual {actual:?}"
        )),
        None => Err(format!("missing bool field `{key}`")),
    }
}

fn require_number(record: &JsonObject, key: &str, expected: u64) -> Result<(), String> {
    match record.get(key) {
        Some(JsonValue::Number(actual)) if *actual == expected => Ok(()),
        Some(actual) => Err(format!(
            "field `{key}` mismatch: expected number `{expected}`, actual {actual:?}"
        )),
        None => Err(format!("missing number field `{key}`")),
    }
}

fn verify_start(record: &JsonObject) -> Result<(), String> {
    require_str(record, "type", "cmc_audit_report_start")?;
    require_str(record, "manifest", "fixtures/replay/MANIFEST.tsv")
}

fn verify_case_common(
    record: &JsonObject,
    scenario_id: &str,
    invariant_id: &str,
    category: &str,
    severity: &str,
    expected_verdict: &str,
    decision: &str,
) -> Result<(), String> {
    require_str(record, "type", "cmc_audit_case")?;
    require_str(record, "scenario_id", scenario_id)?;
    require_str(record, "invariant_id", invariant_id)?;
    require_str(record, "category", category)?;
    require_str(record, "severity", severity)?;
    require_str(record, "expected_verdict", expected_verdict)?;
    require_str(record, "decision", decision)?;
    require_number(record, "expected_events", 1)?;
    require_number(record, "actual_events", 1)
}

fn verify_valid_case(
    record: &JsonObject,
    scenario_id: &str,
    invariant_id: &str,
    category: &str,
    severity: &str,
    expected_verdict: &str,
    decision: &str,
    fingerprint: &str,
) -> Result<(), String> {
    verify_case_common(
        record,
        scenario_id,
        invariant_id,
        category,
        severity,
        expected_verdict,
        decision,
    )?;
    require_str(record, "expected_fingerprint", fingerprint)?;
    require_str(record, "actual_fingerprint", fingerprint)?;
    require_bool(record, "ok", true)?;
    require_str(record, "status", "audit_case_valid")
}

fn verify_valid_summary(record: &JsonObject) -> Result<(), String> {
    require_str(record, "type", "cmc_audit_report_summary")?;
    require_bool(record, "ok", true)?;
    require_number(record, "cases", 4)?;
    require_number(record, "passed", 4)?;
    require_number(record, "failed", 0)?;
    require_str(record, "status", "audit_report_valid")
}

fn verify_drift_case(record: &JsonObject) -> Result<(), String> {
    verify_case_common(
        record,
        "write_missing_cause",
        "I1",
        "write_authorization",
        "high",
        "blocked_illegitimate_transition",
        "REJECT_MISSING_CAUSE",
    )?;
    require_str(record, "expected_fingerprint", "88fd99689760140e")?;
    require_str(record, "actual_fingerprint", "0000000000000000")?;
    require_bool(record, "ok", false)?;
    require_str(record, "status", "fixture_fingerprint_drift")
}

fn verify_drift_summary(record: &JsonObject) -> Result<(), String> {
    require_str(record, "type", "cmc_audit_report_summary")?;
    require_bool(record, "ok", false)?;
    require_number(record, "cases", 4)?;
    require_number(record, "passed", 3)?;
    require_number(record, "failed", 1)?;
    require_str(record, "status", "audit_report_failed")
}

fn verify_valid_report() -> Result<(), String> {
    let records = parse_jsonl_report(VALID_REPORT)?;
    if records.len() != 6 {
        return Err(format!(
            "valid report record count drift: expected 6, actual {}",
            records.len()
        ));
    }

    verify_start(&records[0])?;
    verify_valid_case(
        &records[1],
        "write_missing_cause",
        "I1",
        "write_authorization",
        "high",
        "blocked_illegitimate_transition",
        "REJECT_MISSING_CAUSE",
        "88fd99689760140e",
    )?;
    verify_valid_case(
        &records[2],
        "write_unknown_cause",
        "I2",
        "write_authorization",
        "high",
        "blocked_illegitimate_transition",
        "REJECT_UNKNOWN_CAUSE",
        "d8c4983b8a5a0ab0",
    )?;
    verify_valid_case(
        &records[3],
        "effect_before_commit",
        "I3",
        "effect_commit_boundary",
        "critical",
        "blocked_illegitimate_transition",
        "REJECT_EFFECT_BEFORE_COMMIT",
        "28bf87f68e4ec6cb",
    )?;
    verify_valid_case(
        &records[4],
        "valid_committed_effect",
        "I4",
        "effect_commit_boundary",
        "info",
        "accepted_legitimate_transition",
        "ACCEPT_EFFECT",
        "e3e96ba017e2c235",
    )?;
    verify_valid_summary(&records[5])
}

fn verify_drift_report() -> Result<(), String> {
    let records = parse_jsonl_report(DRIFT_REPORT)?;
    if records.len() != 3 {
        return Err(format!(
            "drift report record count drift: expected 3, actual {}",
            records.len()
        ));
    }

    verify_start(&records[0])?;
    verify_drift_case(&records[1])?;
    verify_drift_summary(&records[2])
}

fn main() -> ExitCode {
    println!("CMC-AUDIT-REPORT-EXAMPLE-VERIFY v1");

    if let Err(err) = verify_valid_report() {
        eprintln!("result=failed report=valid error={err}");
        return ExitCode::FAILURE;
    }
    println!("report=valid path={VALID_REPORT} status=ok parser=field_level");

    if let Err(err) = verify_drift_report() {
        eprintln!("result=failed report=drift error={err}");
        return ExitCode::FAILURE;
    }
    println!("report=drift path={DRIFT_REPORT} status=ok parser=field_level");

    println!("result=audit_report_examples_valid parser=field_level");
    ExitCode::SUCCESS
}

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

#[derive(Debug, Clone, Copy)]
struct ExpectedCase {
    scenario_id: &'static str,
    invariant_id: &'static str,
    category: &'static str,
    severity: &'static str,
    expected_verdict: &'static str,
    decision: &'static str,
    events: u64,
    fingerprint: &'static str,
}

const VALID_CASES: &[ExpectedCase] = &[
    ExpectedCase {
        scenario_id: "write_missing_cause",
        invariant_id: "I1",
        category: "write_authorization",
        severity: "high",
        expected_verdict: "blocked_illegitimate_transition",
        decision: "REJECT_MISSING_CAUSE",
        events: 1,
        fingerprint: "88fd99689760140e",
    },
    ExpectedCase {
        scenario_id: "write_unknown_cause",
        invariant_id: "I2",
        category: "write_authorization",
        severity: "high",
        expected_verdict: "blocked_illegitimate_transition",
        decision: "REJECT_UNKNOWN_CAUSE",
        events: 1,
        fingerprint: "d8c4983b8a5a0ab0",
    },
    ExpectedCase {
        scenario_id: "effect_before_commit",
        invariant_id: "I3",
        category: "effect_commit_boundary",
        severity: "critical",
        expected_verdict: "blocked_illegitimate_transition",
        decision: "REJECT_EFFECT_BEFORE_COMMIT",
        events: 1,
        fingerprint: "28bf87f68e4ec6cb",
    },
    ExpectedCase {
        scenario_id: "valid_committed_effect",
        invariant_id: "I4",
        category: "effect_commit_boundary",
        severity: "info",
        expected_verdict: "accepted_legitimate_transition",
        decision: "ACCEPT_EFFECT",
        events: 1,
        fingerprint: "e3e96ba017e2c235",
    },
    ExpectedCase {
        scenario_id: "read_missing_cause",
        invariant_id: "I5",
        category: "read_authorization",
        severity: "high",
        expected_verdict: "blocked_illegitimate_transition",
        decision: "REJECT_MISSING_CAUSE",
        events: 1,
        fingerprint: "9f49c650fcd31fff",
    },
    ExpectedCase {
        scenario_id: "read_unknown_cause_or_address",
        invariant_id: "I6",
        category: "read_authorization",
        severity: "high",
        expected_verdict: "blocked_illegitimate_transition",
        decision: "REJECT_UNKNOWN_CAUSE",
        events: 1,
        fingerprint: "91768923fb87d345",
    },
    ExpectedCase {
        scenario_id: "effect_missing_parent",
        invariant_id: "I7",
        category: "effect_commit_boundary",
        severity: "critical",
        expected_verdict: "blocked_illegitimate_transition",
        decision: "REJECT_MISSING_CAUSE",
        events: 1,
        fingerprint: "da78371555a0b983",
    },
    ExpectedCase {
        scenario_id: "valid_read_after_write",
        invariant_id: "I8",
        category: "read_authorization",
        severity: "info",
        expected_verdict: "accepted_legitimate_transition",
        decision: "ACCEPT_READ",
        events: 2,
        fingerprint: "d6b83bfe3651c60d",
    },
];

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

fn verify_case_common(record: &JsonObject, expected: ExpectedCase) -> Result<(), String> {
    require_str(record, "type", "cmc_audit_case")?;
    require_str(record, "scenario_id", expected.scenario_id)?;
    require_str(record, "invariant_id", expected.invariant_id)?;
    require_str(record, "category", expected.category)?;
    require_str(record, "severity", expected.severity)?;
    require_str(record, "expected_verdict", expected.expected_verdict)?;
    require_str(record, "decision", expected.decision)?;
    require_number(record, "expected_events", expected.events)?;
    require_number(record, "actual_events", expected.events)
}

fn verify_valid_case(record: &JsonObject, expected: ExpectedCase) -> Result<(), String> {
    verify_case_common(record, expected)?;
    require_str(record, "expected_fingerprint", expected.fingerprint)?;
    require_str(record, "actual_fingerprint", expected.fingerprint)?;
    require_bool(record, "ok", true)?;
    require_str(record, "status", "audit_case_valid")
}

fn verify_valid_summary(record: &JsonObject) -> Result<(), String> {
    require_str(record, "type", "cmc_audit_report_summary")?;
    require_bool(record, "ok", true)?;
    require_number(record, "cases", VALID_CASES.len() as u64)?;
    require_number(record, "passed", VALID_CASES.len() as u64)?;
    require_number(record, "failed", 0)?;
    require_str(record, "status", "audit_report_valid")
}

fn verify_drift_case(record: &JsonObject) -> Result<(), String> {
    let expected = VALID_CASES[0];
    verify_case_common(record, expected)?;
    require_str(record, "expected_fingerprint", expected.fingerprint)?;
    require_str(record, "actual_fingerprint", "0000000000000000")?;
    require_bool(record, "ok", false)?;
    require_str(record, "status", "fixture_fingerprint_drift")
}

fn verify_drift_summary(record: &JsonObject) -> Result<(), String> {
    require_str(record, "type", "cmc_audit_report_summary")?;
    require_bool(record, "ok", false)?;
    require_number(record, "cases", VALID_CASES.len() as u64)?;
    require_number(record, "passed", (VALID_CASES.len() - 1) as u64)?;
    require_number(record, "failed", 1)?;
    require_str(record, "status", "audit_report_failed")
}

fn verify_valid_report() -> Result<(), String> {
    let records = parse_jsonl_report(VALID_REPORT)?;
    let expected_records = VALID_CASES.len() + 2;
    if records.len() != expected_records {
        return Err(format!(
            "valid report record count drift: expected {expected_records}, actual {}",
            records.len()
        ));
    }

    verify_start(&records[0])?;
    for (idx, expected) in VALID_CASES.iter().enumerate() {
        verify_valid_case(&records[idx + 1], *expected)?;
    }
    verify_valid_summary(&records[VALID_CASES.len() + 1])
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
    println!("CMC-AUDIT-REPORT-EXAMPLE-VERIFY v2");

    if let Err(err) = verify_valid_report() {
        eprintln!("result=failed report=valid error={err}");
        return ExitCode::FAILURE;
    }
    println!("report=valid path={VALID_REPORT} cases=8 status=ok parser=field_level");

    if let Err(err) = verify_drift_report() {
        eprintln!("result=failed report=drift error={err}");
        return ExitCode::FAILURE;
    }
    println!("report=drift path={DRIFT_REPORT} cases=8 status=ok parser=field_level");

    println!("result=audit_report_examples_valid parser=field_level cases=8");
    ExitCode::SUCCESS
}

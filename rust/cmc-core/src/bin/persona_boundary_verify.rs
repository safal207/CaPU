use std::{collections::BTreeMap, fs, process::ExitCode};

const INFERRED_REJECTED: &str = "fixtures/persona/inferred_preference_rejected.jsonl";
const CONFIRMED_ACCEPTED: &str = "fixtures/persona/confirmed_preference_accepted.jsonl";

#[derive(Debug, Clone, PartialEq, Eq)]
enum JsonValue {
    String(String),
    Bool(bool),
    Number(u64),
    Null,
}

type JsonObject = BTreeMap<String, JsonValue>;

fn read_fixture(path: &str) -> Result<String, String> {
    fs::read_to_string(path).map_err(|err| format!("failed to read {path}: {err}"))
}

fn skip_ws(chars: &[char], idx: &mut usize) {
    while chars.get(*idx).is_some_and(|ch| ch.is_whitespace()) {
        *idx += 1;
    }
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
                    other => return Err(format!("unsupported escape sequence: \\{other}")),
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

fn parse_null(chars: &[char], idx: &mut usize) -> Result<(), String> {
    let rest: String = chars[*idx..].iter().collect();
    if rest.starts_with("null") {
        *idx += 4;
        Ok(())
    } else {
        Err(format!("expected null at char {}", *idx))
    }
}

fn parse_value(chars: &[char], idx: &mut usize) -> Result<JsonValue, String> {
    skip_ws(chars, idx);
    match chars.get(*idx) {
        Some('"') => Ok(JsonValue::String(parse_string(chars, idx)?)),
        Some(ch) if ch.is_ascii_digit() => Ok(JsonValue::Number(parse_number(chars, idx)?)),
        Some('t') | Some('f') => Ok(JsonValue::Bool(parse_bool(chars, idx)?)),
        Some('n') => {
            parse_null(chars, idx)?;
            Ok(JsonValue::Null)
        }
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

fn parse_single_record(path: &str) -> Result<JsonObject, String> {
    let content = read_fixture(path)?;
    let records = content
        .lines()
        .map(str::trim)
        .filter(|line| !line.is_empty())
        .map(parse_flat_json_object)
        .collect::<Result<Vec<_>, _>>()?;

    match records.as_slice() {
        [record] => Ok(record.clone()),
        _ => Err(format!("expected exactly one JSONL record in {path}, got {}", records.len())),
    }
}

fn expect_string(record: &JsonObject, key: &str, expected: &str) -> Result<(), String> {
    match record.get(key) {
        Some(JsonValue::String(actual)) if actual == expected => Ok(()),
        Some(actual) => Err(format!("expected {key}={expected:?}, got {actual:?}")),
        None => Err(format!("missing key `{key}`")),
    }
}

fn expect_bool(record: &JsonObject, key: &str, expected: bool) -> Result<(), String> {
    match record.get(key) {
        Some(JsonValue::Bool(actual)) if *actual == expected => Ok(()),
        Some(actual) => Err(format!("expected {key}={expected}, got {actual:?}")),
        None => Err(format!("missing key `{key}`")),
    }
}

fn expect_number(record: &JsonObject, key: &str, expected: u64) -> Result<(), String> {
    match record.get(key) {
        Some(JsonValue::Number(actual)) if *actual == expected => Ok(()),
        Some(actual) => Err(format!("expected {key}={expected}, got {actual:?}")),
        None => Err(format!("missing key `{key}`")),
    }
}

fn expect_null(record: &JsonObject, key: &str) -> Result<(), String> {
    match record.get(key) {
        Some(JsonValue::Null) => Ok(()),
        Some(actual) => Err(format!("expected {key}=null, got {actual:?}")),
        None => Err(format!("missing key `{key}`")),
    }
}

fn verify_inferred_rejected() -> Result<(), String> {
    let record = parse_single_record(INFERRED_REJECTED)?;
    expect_string(&record, "type", "persona_boundary_case")?;
    expect_string(&record, "scenario_id", "inferred_preference_rejected")?;
    expect_string(&record, "invariant_id", "P1")?;
    expect_string(&record, "boundary", "persona_memory_requires_cause")?;
    expect_bool(&record, "user_confirmation", false)?;
    expect_string(&record, "decision", "REJECT_INFERRED_MEMORY")?;
    expect_string(&record, "expected_verdict", "blocked_unconfirmed_persona_memory")?;
    expect_null(&record, "cause_id")?;
    Ok(())
}

fn verify_confirmed_accepted() -> Result<(), String> {
    let record = parse_single_record(CONFIRMED_ACCEPTED)?;
    expect_string(&record, "type", "persona_boundary_case")?;
    expect_string(&record, "scenario_id", "confirmed_preference_accepted")?;
    expect_string(&record, "invariant_id", "P1")?;
    expect_string(&record, "boundary", "persona_memory_requires_cause")?;
    expect_bool(&record, "user_confirmation", true)?;
    expect_string(&record, "decision", "ACCEPT_CONFIRMED_MEMORY")?;
    expect_string(&record, "expected_verdict", "accepted_confirmed_persona_memory")?;
    expect_number(&record, "cause_id", 42)?;
    Ok(())
}

fn run() -> Result<(), String> {
    verify_inferred_rejected()?;
    verify_confirmed_accepted()?;

    println!("CMC-PERSONA-BOUNDARY-FIXTURE v0");
    println!("inferred_result=blocked_unconfirmed_persona_memory");
    println!("confirmed_result=accepted_confirmed_persona_memory cause_id=42");
    println!("result=persona_boundary_fixtures_valid");
    Ok(())
}

fn main() -> ExitCode {
    match run() {
        Ok(()) => ExitCode::SUCCESS,
        Err(err) => {
            eprintln!("result=persona_boundary_fixtures_invalid reason={err}");
            ExitCode::FAILURE
        }
    }
}

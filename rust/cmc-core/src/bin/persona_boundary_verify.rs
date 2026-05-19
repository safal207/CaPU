use std::{collections::BTreeMap, fs, process::ExitCode};

const MANIFEST: &str = "fixtures/persona/MANIFEST.tsv";

#[derive(Debug, Clone, PartialEq, Eq)]
enum JsonValue {
    String(String),
    Bool(bool),
    Number(u64),
    Null,
}

type JsonObject = BTreeMap<String, JsonValue>;

#[derive(Debug, Clone)]
struct ManifestCase {
    scenario_id: String,
    invariant_id: String,
    path: String,
    boundary: String,
    user_confirmation: bool,
    decision: String,
    cause_id: Option<u64>,
    expected_verdict: String,
}

fn read_file(path: &str) -> Result<String, String> {
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
    let content = read_file(path)?;
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

fn parse_manifest_bool(raw: &str) -> Result<bool, String> {
    match raw {
        "true" => Ok(true),
        "false" => Ok(false),
        other => Err(format!("invalid manifest boolean `{other}`")),
    }
}

fn parse_manifest_cause_id(raw: &str) -> Result<Option<u64>, String> {
    if raw == "null" {
        Ok(None)
    } else {
        raw.parse::<u64>()
            .map(Some)
            .map_err(|err| format!("invalid manifest cause_id `{raw}`: {err}"))
    }
}

fn parse_manifest() -> Result<Vec<ManifestCase>, String> {
    let content = read_file(MANIFEST)?;
    let mut lines = content.lines().filter(|line| !line.trim().is_empty());
    let header = lines
        .next()
        .ok_or_else(|| format!("{MANIFEST} is empty"))?;
    let expected_header = "scenario_id\tinvariant_id\tpath\tboundary\tuser_confirmation\tdecision\tcause_id\texpected_verdict";
    if header != expected_header {
        return Err(format!("unexpected manifest header `{header}`"));
    }

    let mut cases = Vec::new();
    for (idx, line) in lines.enumerate() {
        let fields: Vec<&str> = line.split('\t').collect();
        if fields.len() != 8 {
            return Err(format!("manifest line {} expected 8 fields, got {}", idx + 2, fields.len()));
        }

        cases.push(ManifestCase {
            scenario_id: fields[0].to_string(),
            invariant_id: fields[1].to_string(),
            path: fields[2].to_string(),
            boundary: fields[3].to_string(),
            user_confirmation: parse_manifest_bool(fields[4])?,
            decision: fields[5].to_string(),
            cause_id: parse_manifest_cause_id(fields[6])?,
            expected_verdict: fields[7].to_string(),
        });
    }

    Ok(cases)
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

fn verify_manifest_case(case: &ManifestCase) -> Result<(), String> {
    let record = parse_single_record(&case.path)?;
    expect_string(&record, "type", "persona_boundary_case")?;
    expect_string(&record, "scenario_id", &case.scenario_id)?;
    expect_string(&record, "invariant_id", &case.invariant_id)?;
    expect_string(&record, "boundary", &case.boundary)?;
    expect_bool(&record, "user_confirmation", case.user_confirmation)?;
    expect_string(&record, "decision", &case.decision)?;
    expect_string(&record, "expected_verdict", &case.expected_verdict)?;

    match case.cause_id {
        Some(expected) => expect_number(&record, "cause_id", expected)?,
        None => expect_null(&record, "cause_id")?,
    }

    if case.invariant_id == "P7" {
        expect_bool(
            &record,
            "hypothesis_labeled",
            case.scenario_id == "hypothesis_labeled_introspection_accepted",
        )?;
    }

    Ok(())
}

fn verify_p1_pair(cases: &[ManifestCase]) -> Result<(), String> {
    let rejected = cases
        .iter()
        .find(|case| case.scenario_id == "inferred_preference_rejected")
        .ok_or_else(|| "missing inferred_preference_rejected manifest row".to_string())?;
    let accepted = cases
        .iter()
        .find(|case| case.scenario_id == "confirmed_preference_accepted")
        .ok_or_else(|| "missing confirmed_preference_accepted manifest row".to_string())?;

    if rejected.user_confirmation || rejected.cause_id.is_some() || rejected.decision != "REJECT_INFERRED_MEMORY" {
        return Err("inferred preference must be rejected without confirmation and without cause".to_string());
    }

    if !accepted.user_confirmation || accepted.cause_id.is_none() || accepted.decision != "ACCEPT_CONFIRMED_MEMORY" {
        return Err("confirmed preference must be accepted only with confirmation and cause".to_string());
    }

    Ok(())
}

fn verify_p7_pair(cases: &[ManifestCase]) -> Result<(), String> {
    let rejected = cases
        .iter()
        .find(|case| case.scenario_id == "unlabeled_introspection_rejected")
        .ok_or_else(|| "missing unlabeled_introspection_rejected manifest row".to_string())?;
    let accepted = cases
        .iter()
        .find(|case| case.scenario_id == "hypothesis_labeled_introspection_accepted")
        .ok_or_else(|| "missing hypothesis_labeled_introspection_accepted manifest row".to_string())?;

    if rejected.boundary != "introspection_requires_hypothesis_label"
        || rejected.decision != "REJECT_UNLABELED_INTROSPECTION"
        || rejected.expected_verdict != "blocked_claimed_inner_truth"
    {
        return Err("unlabeled introspection must be rejected as claimed inner truth".to_string());
    }

    if accepted.boundary != "introspection_requires_hypothesis_label"
        || accepted.decision != "ACCEPT_HYPOTHESIS_LABELED_INTROSPECTION"
        || accepted.expected_verdict != "accepted_hypothesis_labeled_reflection"
    {
        return Err("hypothesis-labeled introspection must be accepted only as reflection".to_string());
    }

    Ok(())
}

fn run() -> Result<(), String> {
    let cases = parse_manifest()?;
    if cases.len() != 4 {
        return Err(format!("expected 4 persona manifest cases, got {}", cases.len()));
    }

    for case in &cases {
        verify_manifest_case(case)?;
    }
    verify_p1_pair(&cases)?;
    verify_p7_pair(&cases)?;

    println!("CMC-PERSONA-BOUNDARY-MANIFEST v0");
    println!("cases={}", cases.len());
    println!("p1_inferred_result=blocked_unconfirmed_persona_memory");
    println!("p1_confirmed_result=accepted_confirmed_persona_memory cause_id=42");
    println!("p7_unlabeled_result=blocked_claimed_inner_truth");
    println!("p7_labeled_result=accepted_hypothesis_labeled_reflection");
    println!("result=persona_boundary_manifest_valid");
    Ok(())
}

fn main() -> ExitCode {
    match run() {
        Ok(()) => ExitCode::SUCCESS,
        Err(err) => {
            eprintln!("result=persona_boundary_manifest_invalid reason={err}");
            ExitCode::FAILURE
        }
    }
}

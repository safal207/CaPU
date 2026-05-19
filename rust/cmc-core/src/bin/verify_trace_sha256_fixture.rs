use cmc_core::trace_crypto::{self, SealedTraceEvent};
use std::{collections::BTreeMap, fs, process::ExitCode};

const VALID_FIXTURE: &str = "fixtures/trace_integrity/sha256_valid.jsonl";
const TAMPERED_FIXTURE: &str = "fixtures/trace_integrity/sha256_tampered.jsonl";

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

fn skip_ws(chars: &[char], idx: &mut usize) {
    while chars.get(*idx).is_some_and(|ch| ch.is_whitespace()) {
        *idx += 1;
    }
}

fn parse_flat_string_object(line: &str) -> Result<BTreeMap<String, String>, String> {
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
            return Err(format!("expected ':' after `{key}`"));
        }
        idx += 1;
        skip_ws(&chars, &mut idx);
        let value = parse_string(&chars, &mut idx)?;
        out.insert(key, value);

        skip_ws(&chars, &mut idx);
        match chars.get(idx) {
            Some(',') => idx += 1,
            Some('}') => continue,
            Some(other) => return Err(format!("expected ',' or '}}', found `{other}`")),
            None => return Err("unexpected end of object".to_string()),
        }
    }

    skip_ws(&chars, &mut idx);
    if idx != chars.len() {
        return Err(format!("unexpected trailing data at char {idx}"));
    }

    Ok(out)
}

fn required_field<'a>(
    object: &'a BTreeMap<String, String>,
    line_no: usize,
    field: &str,
) -> Result<&'a str, String> {
    object
        .get(field)
        .map(String::as_str)
        .ok_or_else(|| format!("line {line_no}: missing `{field}`"))
}

fn read_fixture(path: &str) -> Result<Vec<SealedTraceEvent>, String> {
    let raw = fs::read_to_string(path).map_err(|err| format!("failed to read {path}: {err}"))?;
    let mut sealed = Vec::new();

    for (idx, line) in raw.lines().filter(|line| !line.trim().is_empty()).enumerate() {
        let line_no = idx + 1;
        let object = parse_flat_string_object(line)
            .map_err(|err| format!("{path}:{line_no}: invalid JSONL object: {err}"))?;
        sealed.push(SealedTraceEvent {
            prev_hash: required_field(&object, line_no, "prev_hash")?.to_string(),
            event: required_field(&object, line_no, "event")?.to_string(),
            trace_hash: required_field(&object, line_no, "trace_hash")?.to_string(),
        });
    }

    if sealed.is_empty() {
        return Err(format!("{path}: expected at least one sealed event"));
    }

    Ok(sealed)
}

fn run() -> Result<(), String> {
    println!("CMC-VERIFY-TRACE-SHA256-FIXTURE v0");

    let valid = read_fixture(VALID_FIXTURE)?;
    trace_crypto::verify_trace(&valid)
        .map_err(|seq| format!("valid fixture failed verification at event {seq}"))?;
    println!("valid_fixture={VALID_FIXTURE}");
    println!("valid_events={}", valid.len());
    println!("valid_result=trace_sha256_fixture_valid");

    let tampered = read_fixture(TAMPERED_FIXTURE)?;
    match trace_crypto::verify_trace(&tampered) {
        Ok(()) => Err("tampered fixture unexpectedly verified".to_string()),
        Err(1) => {
            println!("tampered_fixture={TAMPERED_FIXTURE}");
            println!("tampered_events={}", tampered.len());
            println!("tampered_result=trace_sha256_fixture_tamper_detected seq=1");
            println!("result=trace_sha256_fixtures_valid");
            Ok(())
        }
        Err(seq) => Err(format!(
            "tampered fixture failed at unexpected event {seq}; expected event 1"
        )),
    }
}

fn main() -> ExitCode {
    match run() {
        Ok(()) => ExitCode::SUCCESS,
        Err(err) => {
            eprintln!("result=trace_sha256_fixtures_invalid");
            eprintln!("error={err}");
            ExitCode::FAILURE
        }
    }
}

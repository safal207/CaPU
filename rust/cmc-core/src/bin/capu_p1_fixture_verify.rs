use std::{collections::BTreeMap, fs, process::ExitCode};

use cmc_core::capu::replay_unit::{
    replay_p1_persona_memory_audit_chain, replay_p1_persona_memory_reject_only,
};
use cmc_core::trace_crypto::SealedTraceEvent;

const VALID_FIXTURE: &str = "fixtures/capu/p1_persona_memory_valid.jsonl";
const MISSING_CAUSE_FIXTURE: &str = "fixtures/capu/p1_persona_memory_missing_cause.jsonl";

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
    let chars = line.chars().collect::<Vec<_>>();
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

    for (idx, line) in raw
        .lines()
        .filter(|line| !line.trim().is_empty())
        .enumerate()
    {
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
    println!("CAPU-P1-FIXTURE-VERIFY v0");

    let valid = read_fixture(VALID_FIXTURE)?;
    let summary = replay_p1_persona_memory_audit_chain(&valid)
        .map_err(|err| format!("valid P1 fixture failed replay verification: {err:?}"))?;
    println!("valid_fixture={VALID_FIXTURE}");
    println!("valid_events={}", valid.len());
    println!(
        "valid_replay_summary events={} p1_boundary_events={} rejected_without_cause={} accepted_with_cause={}",
        summary.events,
        summary.p1_boundary_events,
        summary.rejected_without_cause,
        summary.accepted_with_cause
    );
    println!("valid_result=capu_p1_fixture_replay_valid");

    let missing_cause = read_fixture(MISSING_CAUSE_FIXTURE)?;
    let missing_cause_summary = replay_p1_persona_memory_reject_only(&missing_cause)
        .map_err(|err| format!("missing-cause P1 fixture failed verification: {err:?}"))?;
    println!("missing_cause_fixture={MISSING_CAUSE_FIXTURE}");
    println!("missing_cause_events={}", missing_cause.len());
    println!(
        "missing_cause_summary events={} p1_boundary_events={} rejected_without_cause={} accepted_with_cause={}",
        missing_cause_summary.events,
        missing_cause_summary.p1_boundary_events,
        missing_cause_summary.rejected_without_cause,
        missing_cause_summary.accepted_with_cause
    );
    println!("missing_cause_result=capu_p1_fixture_missing_cause");
    println!("result=capu_p1_fixtures_verified");

    Ok(())
}

fn main() -> ExitCode {
    match run() {
        Ok(()) => ExitCode::SUCCESS,
        Err(err) => {
            eprintln!("result=capu_p1_fixtures_invalid");
            eprintln!("error={err}");
            ExitCode::FAILURE
        }
    }
}

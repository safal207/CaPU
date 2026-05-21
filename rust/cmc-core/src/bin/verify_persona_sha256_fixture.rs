use cmc_core::trace_crypto::{self, SealedTraceEvent};
use std::{fs, process::ExitCode};

const VALID_FIXTURE: &str = "fixtures/persona_integrity/sha256_persona_valid.jsonl";
const TAMPERED_FIXTURE: &str = "fixtures/persona_integrity/sha256_persona_tampered.jsonl";
const EXPECTED_EVENTS: usize = 8;
const EXPECTED_TAMPER_SEQ: usize = 5;

fn json_unescape(raw: &str) -> Result<String, String> {
    let mut out = String::new();
    let mut chars = raw.chars();

    while let Some(ch) = chars.next() {
        if ch != '\\' {
            out.push(ch);
            continue;
        }

        let escaped = chars
            .next()
            .ok_or_else(|| "unterminated escape sequence".to_string())?;
        match escaped {
            '"' => out.push('"'),
            '\\' => out.push('\\'),
            'n' => out.push('\n'),
            'r' => out.push('\r'),
            't' => out.push('\t'),
            other => return Err(format!("unsupported escape sequence: \\{other}")),
        }
    }

    Ok(out)
}

fn extract_json_string(line: &str, key: &str) -> Result<String, String> {
    let prefix = format!("\"{key}\":\"");
    let start = line
        .find(&prefix)
        .ok_or_else(|| format!("missing field `{key}`"))?
        + prefix.len();

    let mut escaped = false;
    let mut end = None;
    for (offset, ch) in line[start..].char_indices() {
        if escaped {
            escaped = false;
            continue;
        }
        if ch == '\\' {
            escaped = true;
            continue;
        }
        if ch == '"' {
            end = Some(start + offset);
            break;
        }
    }

    let end = end.ok_or_else(|| format!("unterminated field `{key}`"))?;
    json_unescape(&line[start..end])
}

fn read_fixture(path: &str) -> Result<Vec<SealedTraceEvent>, String> {
    let raw = fs::read_to_string(path).map_err(|err| format!("failed to read {path}: {err}"))?;
    let mut sealed = Vec::new();

    for (idx, line) in raw.lines().filter(|line| !line.trim().is_empty()).enumerate() {
        sealed.push(SealedTraceEvent {
            prev_hash: extract_json_string(line, "prev_hash")
                .map_err(|err| format!("{path}:{} {err}", idx + 1))?,
            event: extract_json_string(line, "event")
                .map_err(|err| format!("{path}:{} {err}", idx + 1))?,
            trace_hash: extract_json_string(line, "trace_hash")
                .map_err(|err| format!("{path}:{} {err}", idx + 1))?,
        });
    }

    if sealed.len() != EXPECTED_EVENTS {
        return Err(format!(
            "{path}: expected {EXPECTED_EVENTS} sealed persona events, got {}",
            sealed.len()
        ));
    }

    Ok(sealed)
}

fn require_persona_semantics(sealed: &[SealedTraceEvent]) -> Result<(), String> {
    let joined = sealed
        .iter()
        .map(|event| event.event.as_str())
        .collect::<Vec<_>>()
        .join("\n");

    for needle in [
        "\"kind\":\"PERSONA_BOUNDARY\"",
        "\"scenario_id\":\"inferred_preference_rejected\"",
        "\"scenario_id\":\"confirmed_preference_accepted\"",
        "\"scenario_id\":\"unauthorized_persona_state_change_rejected\"",
        "\"scenario_id\":\"authorized_persona_state_change_accepted\"",
        "\"scenario_id\":\"action_without_commit_rejected\"",
        "\"scenario_id\":\"action_with_commit_accepted\"",
        "\"scenario_id\":\"unlabeled_introspection_rejected\"",
        "\"scenario_id\":\"hypothesis_labeled_introspection_accepted\"",
        "\"invariant_id\":\"P1\"",
        "\"invariant_id\":\"P2\"",
        "\"invariant_id\":\"P6\"",
        "\"invariant_id\":\"P7\"",
        "\"boundary\":\"action_requires_commit\"",
    ] {
        if !joined.contains(needle) {
            return Err(format!("missing semantic marker `{needle}`"));
        }
    }

    Ok(())
}

fn run() -> Result<(), String> {
    println!("CMC-VERIFY-PERSONA-SHA256-FIXTURE v0");

    let valid = read_fixture(VALID_FIXTURE)?;
    require_persona_semantics(&valid)?;
    trace_crypto::verify_trace(&valid)
        .map_err(|seq| format!("valid persona fixture failed at event {seq}"))?;
    println!("valid_fixture={VALID_FIXTURE}");
    println!("valid_events={}", valid.len());
    println!("valid_result=persona_sha256_fixture_valid");

    let tampered = read_fixture(TAMPERED_FIXTURE)?;
    require_persona_semantics(&tampered)?;
    match trace_crypto::verify_trace(&tampered) {
        Ok(()) => Err("tampered persona fixture unexpectedly verified".to_string()),
        Err(EXPECTED_TAMPER_SEQ) => {
            println!("tampered_fixture={TAMPERED_FIXTURE}");
            println!("tampered_events={}", tampered.len());
            println!("tampered_result=persona_sha256_fixture_tamper_detected seq={EXPECTED_TAMPER_SEQ}");
            println!("result=persona_sha256_fixtures_valid");
            Ok(())
        }
        Err(seq) => Err(format!(
            "tampered persona fixture failed at event {seq}; expected event {EXPECTED_TAMPER_SEQ}"
        )),
    }
}

fn main() -> ExitCode {
    match run() {
        Ok(()) => ExitCode::SUCCESS,
        Err(err) => {
            eprintln!("result=persona_sha256_fixtures_invalid");
            eprintln!("error={err}");
            ExitCode::FAILURE
        }
    }
}

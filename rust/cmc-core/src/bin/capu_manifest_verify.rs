use std::{collections::BTreeMap, fs, process::ExitCode};

use cmc_core::capu::replay_unit::{replay_p6_audit_chain, ReplayError};
use cmc_core::trace_crypto::SealedTraceEvent;

const MANIFEST: &str = "fixtures/capu/MANIFEST.tsv";
const EXPECTED_HEADER: &str =
    "scenario_id\tinvariant_id\tfixture_path\tfixture_role\texpected_events\texpected_result";

#[derive(Debug, Clone, PartialEq, Eq)]
struct ManifestCase {
    scenario_id: String,
    invariant_id: String,
    fixture_path: String,
    fixture_role: String,
    expected_events: usize,
    expected_result: String,
}

fn parse_manifest() -> Result<Vec<ManifestCase>, String> {
    let raw = fs::read_to_string(MANIFEST).map_err(|err| format!("failed to read {MANIFEST}: {err}"))?;
    let mut lines = raw.lines().filter(|line| !line.trim().is_empty());
    let header = lines.next().ok_or_else(|| format!("{MANIFEST} is empty"))?;

    if header != EXPECTED_HEADER {
        return Err(format!("unexpected manifest header `{header}`"));
    }

    let mut cases = Vec::new();
    for (idx, line) in lines.enumerate() {
        let line_no = idx + 2;
        let fields = line.split('\t').collect::<Vec<_>>();
        if fields.len() != 6 {
            return Err(format!(
                "{MANIFEST}:{line_no}: expected 6 tab-separated fields, got {}",
                fields.len()
            ));
        }

        cases.push(ManifestCase {
            scenario_id: fields[0].to_string(),
            invariant_id: fields[1].to_string(),
            fixture_path: fields[2].to_string(),
            fixture_role: fields[3].to_string(),
            expected_events: fields[4]
                .parse::<usize>()
                .map_err(|err| format!("{MANIFEST}:{line_no}: invalid expected_events: {err}"))?,
            expected_result: fields[5].to_string(),
        });
    }

    if cases.is_empty() {
        return Err(format!("{MANIFEST}: expected at least one case"));
    }

    Ok(cases)
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

fn verify_case(case: &ManifestCase) -> Result<&'static str, String> {
    if case.invariant_id != "P6" {
        return Err(format!(
            "{}: expected invariant_id=P6, got {}",
            case.scenario_id, case.invariant_id
        ));
    }

    let sealed = read_fixture(&case.fixture_path)?;
    if sealed.len() != case.expected_events {
        return Err(format!(
            "{}: expected {} events, got {}",
            case.scenario_id,
            case.expected_events,
            sealed.len()
        ));
    }

    match case.fixture_role.as_str() {
        "valid" => {
            replay_p6_audit_chain(&sealed).map_err(|err| {
                format!(
                    "{}: expected valid replay, got error {err:?}",
                    case.scenario_id
                )
            })?;
            if case.expected_result != "capu_p6_fixture_replay_valid" {
                return Err(format!(
                    "{}: unexpected expected_result {}",
                    case.scenario_id, case.expected_result
                ));
            }
            Ok("capu_p6_fixture_replay_valid")
        }
        "tampered" => match replay_p6_audit_chain(&sealed) {
            Ok(_) => Err(format!(
                "{}: tampered fixture unexpectedly replay-verified",
                case.scenario_id
            )),
            Err(ReplayError::SealInvalid { event_index: 1 }) => {
                if case.expected_result != "capu_p6_fixture_tamper_detected" {
                    return Err(format!(
                        "{}: unexpected expected_result {}",
                        case.scenario_id, case.expected_result
                    ));
                }
                Ok("capu_p6_fixture_tamper_detected")
            }
            Err(err) => Err(format!(
                "{}: unexpected tamper verification error {err:?}",
                case.scenario_id
            )),
        },
        other => Err(format!(
            "{}: unknown fixture_role `{other}`",
            case.scenario_id
        )),
    }
}

fn run() -> Result<(), String> {
    println!("CAPU-MANIFEST-VERIFY v0");

    let cases = parse_manifest()?;
    let mut valid = 0usize;
    let mut tampered = 0usize;

    for case in &cases {
        let result = verify_case(case)?;
        match case.fixture_role.as_str() {
            "valid" => valid += 1,
            "tampered" => tampered += 1,
            _ => {}
        }
        println!(
            "case={} role={} events={} result={}",
            case.scenario_id, case.fixture_role, case.expected_events, result
        );
    }

    println!("manifest={MANIFEST}");
    println!("manifest_cases={}", cases.len());
    println!("manifest_valid={valid}");
    println!("manifest_tampered={tampered}");
    println!("result=capu_manifest_verified");

    Ok(())
}

fn main() -> ExitCode {
    match run() {
        Ok(()) => ExitCode::SUCCESS,
        Err(err) => {
            eprintln!("result=capu_manifest_invalid");
            eprintln!("error={err}");
            ExitCode::FAILURE
        }
    }
}

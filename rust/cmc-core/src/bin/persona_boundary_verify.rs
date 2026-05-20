use std::{fs, process::ExitCode};

const MANIFEST: &str = "fixtures/persona/MANIFEST.tsv";
const EXPECTED_CASES: usize = 8;

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

fn parse_bool(raw: &str) -> Result<bool, String> {
    match raw {
        "true" => Ok(true),
        "false" => Ok(false),
        other => Err(format!("invalid boolean `{other}`")),
    }
}

fn parse_cause_id(raw: &str) -> Result<Option<u64>, String> {
    if raw == "null" {
        Ok(None)
    } else {
        raw.parse::<u64>()
            .map(Some)
            .map_err(|err| format!("invalid cause_id `{raw}`: {err}"))
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
            return Err(format!(
                "manifest line {} expected 8 tab-separated fields, got {}",
                idx + 2,
                fields.len()
            ));
        }

        cases.push(ManifestCase {
            scenario_id: fields[0].to_string(),
            invariant_id: fields[1].to_string(),
            path: fields[2].to_string(),
            boundary: fields[3].to_string(),
            user_confirmation: parse_bool(fields[4])?,
            decision: fields[5].to_string(),
            cause_id: parse_cause_id(fields[6])?,
            expected_verdict: fields[7].to_string(),
        });
    }

    Ok(cases)
}

fn contains_str_field(content: &str, key: &str, expected: &str) -> bool {
    content.contains(&format!("\"{key}\":\"{expected}\""))
}

fn contains_bool_field(content: &str, key: &str, expected: bool) -> bool {
    content.contains(&format!("\"{key}\":{expected}"))
}

fn contains_cause_id(content: &str, expected: Option<u64>) -> bool {
    match expected {
        Some(cause_id) => content.contains(&format!("\"cause_id\":{cause_id}")),
        None => content.contains("\"cause_id\":null"),
    }
}

fn require(condition: bool, message: impl Into<String>) -> Result<(), String> {
    if condition {
        Ok(())
    } else {
        Err(message.into())
    }
}

fn verify_manifest_case(case: &ManifestCase) -> Result<(), String> {
    let content = read_file(&case.path)?;
    let records = content
        .lines()
        .map(str::trim)
        .filter(|line| !line.is_empty())
        .count();
    require(records == 1, format!("{} expected exactly one JSONL record, got {records}", case.path))?;

    require(contains_str_field(&content, "type", "persona_boundary_case"), format!("{} missing type=persona_boundary_case", case.path))?;
    require(contains_str_field(&content, "scenario_id", &case.scenario_id), format!("{} scenario_id mismatch", case.path))?;
    require(contains_str_field(&content, "invariant_id", &case.invariant_id), format!("{} invariant_id mismatch", case.path))?;
    require(contains_str_field(&content, "boundary", &case.boundary), format!("{} boundary mismatch", case.path))?;
    require(contains_bool_field(&content, "user_confirmation", case.user_confirmation), format!("{} user_confirmation mismatch", case.path))?;
    require(contains_str_field(&content, "decision", &case.decision), format!("{} decision mismatch", case.path))?;
    require(contains_str_field(&content, "expected_verdict", &case.expected_verdict), format!("{} expected_verdict mismatch", case.path))?;
    require(contains_cause_id(&content, case.cause_id), format!("{} cause_id mismatch", case.path))?;

    match case.invariant_id.as_str() {
        "P2" => {
            let expected_auth = case.scenario_id == "authorized_persona_state_change_accepted";
            require(contains_bool_field(&content, "authorization", expected_auth), format!("{} authorization mismatch", case.path))?;
            require(contains_str_field(&content, "proposed_state_change", "role=strategic_mentor"), format!("{} missing proposed_state_change", case.path))?;
        }
        "P6" => {
            let expected_commit = case.scenario_id == "action_with_commit_accepted";
            require(contains_str_field(&content, "external_action", "send_email"), format!("{} missing external_action", case.path))?;
            require(contains_bool_field(&content, "commit", expected_commit), format!("{} commit mismatch", case.path))?;
        }
        "P7" => {
            let expected_hypothesis = case.scenario_id == "hypothesis_labeled_introspection_accepted";
            require(contains_bool_field(&content, "hypothesis_labeled", expected_hypothesis), format!("{} hypothesis_labeled mismatch", case.path))?;
        }
        _ => {}
    }

    Ok(())
}

fn find_case<'a>(cases: &'a [ManifestCase], scenario_id: &str) -> Result<&'a ManifestCase, String> {
    cases
        .iter()
        .find(|case| case.scenario_id == scenario_id)
        .ok_or_else(|| format!("missing {scenario_id} manifest row"))
}

fn verify_p1_pair(cases: &[ManifestCase]) -> Result<(), String> {
    let rejected = find_case(cases, "inferred_preference_rejected")?;
    let accepted = find_case(cases, "confirmed_preference_accepted")?;

    require(!rejected.user_confirmation && rejected.cause_id.is_none() && rejected.decision == "REJECT_INFERRED_MEMORY", "inferred preference must be rejected without confirmation and without cause")?;
    require(accepted.user_confirmation && accepted.cause_id == Some(42) && accepted.decision == "ACCEPT_CONFIRMED_MEMORY", "confirmed preference must be accepted only with confirmation and cause")
}

fn verify_p2_pair(cases: &[ManifestCase]) -> Result<(), String> {
    let rejected = find_case(cases, "unauthorized_persona_state_change_rejected")?;
    let accepted = find_case(cases, "authorized_persona_state_change_accepted")?;

    require(rejected.boundary == "persona_state_change_requires_authorization" && !rejected.user_confirmation && rejected.cause_id.is_none() && rejected.decision == "REJECT_UNAUTHORIZED_PERSONA_STATE_CHANGE" && rejected.expected_verdict == "blocked_unauthorized_persona_state_change", "unauthorized persona state change must be rejected without confirmation and without cause")?;
    require(accepted.boundary == "persona_state_change_requires_authorization" && accepted.user_confirmation && accepted.cause_id == Some(77) && accepted.decision == "ACCEPT_AUTHORIZED_PERSONA_STATE_CHANGE" && accepted.expected_verdict == "accepted_authorized_persona_state_change", "authorized persona state change must be accepted only with confirmation and cause")
}

fn verify_p6_pair(cases: &[ManifestCase]) -> Result<(), String> {
    let rejected = find_case(cases, "action_without_commit_rejected")?;
    let accepted = find_case(cases, "action_with_commit_accepted")?;

    require(rejected.boundary == "action_requires_commit" && !rejected.user_confirmation && rejected.cause_id.is_none() && rejected.decision == "REJECT_ACTION_WITHOUT_COMMIT" && rejected.expected_verdict == "blocked_action_without_commit", "external action without commit must be rejected without confirmation and without cause")?;
    require(accepted.boundary == "action_requires_commit" && accepted.user_confirmation && accepted.cause_id == Some(101) && accepted.decision == "ACCEPT_COMMITTED_ACTION" && accepted.expected_verdict == "accepted_committed_action", "external action must be accepted only with committed confirmation and cause")
}

fn verify_p7_pair(cases: &[ManifestCase]) -> Result<(), String> {
    let rejected = find_case(cases, "unlabeled_introspection_rejected")?;
    let accepted = find_case(cases, "hypothesis_labeled_introspection_accepted")?;

    require(rejected.boundary == "introspection_requires_hypothesis_label" && rejected.decision == "REJECT_UNLABELED_INTROSPECTION" && rejected.expected_verdict == "blocked_claimed_inner_truth", "unlabeled introspection must be rejected as claimed inner truth")?;
    require(accepted.boundary == "introspection_requires_hypothesis_label" && accepted.decision == "ACCEPT_HYPOTHESIS_LABELED_INTROSPECTION" && accepted.expected_verdict == "accepted_hypothesis_labeled_reflection", "hypothesis-labeled introspection must be accepted only as reflection")
}

fn run() -> Result<(), String> {
    let cases = parse_manifest()?;
    require(cases.len() == EXPECTED_CASES, format!("expected {EXPECTED_CASES} persona manifest cases, got {}", cases.len()))?;

    for case in &cases {
        verify_manifest_case(case)?;
    }
    verify_p1_pair(&cases)?;
    verify_p2_pair(&cases)?;
    verify_p6_pair(&cases)?;
    verify_p7_pair(&cases)?;

    println!("CMC-PERSONA-BOUNDARY-MANIFEST v0");
    println!("cases={}", cases.len());
    println!("p1_inferred_result=blocked_unconfirmed_persona_memory");
    println!("p1_confirmed_result=accepted_confirmed_persona_memory cause_id=42");
    println!("p2_unauthorized_result=blocked_unauthorized_persona_state_change");
    println!("p2_authorized_result=accepted_authorized_persona_state_change cause_id=77");
    println!("p6_uncommitted_action_result=blocked_action_without_commit");
    println!("p6_committed_action_result=accepted_committed_action cause_id=101");
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

use std::fs;
use std::path::PathBuf;
use std::process::ExitCode;

const MANIFEST_PATH: &str = "fixtures/replay/MANIFEST.tsv";
const MANIFEST_HEADER: &str = "scenario_id\tinvariant_id\tpath\tdecision\tevents\tfingerprint\tcategory\tseverity\texpected_verdict";

#[derive(Debug)]
struct FixtureCheck {
    scenario_id: String,
    invariant_id: String,
    path: String,
    expected_decision: String,
    expected_events: usize,
    category: String,
    severity: String,
    expected_verdict: String,
}

fn parse_manifest() -> Result<Vec<FixtureCheck>, String> {
    let content = fs::read_to_string(MANIFEST_PATH)
        .map_err(|err| format!("failed to read {MANIFEST_PATH}: {err}"))?;

    let mut checks = Vec::new();

    for (idx, line) in content.lines().enumerate() {
        let line = line.trim();
        if line.is_empty() {
            continue;
        }

        if idx == 0 && line == MANIFEST_HEADER {
            continue;
        }

        let fields: Vec<&str> = line.split('\t').collect();
        if fields.len() != 9 {
            return Err(format!(
                "{MANIFEST_PATH}:{} expected 9 tab-separated fields, got {}",
                idx + 1,
                fields.len()
            ));
        }

        let expected_events = fields[4].parse::<usize>().map_err(|err| {
            format!(
                "{MANIFEST_PATH}:{} invalid event count `{}`: {err}",
                idx + 1,
                fields[4]
            )
        })?;

        checks.push(FixtureCheck {
            scenario_id: fields[0].to_string(),
            invariant_id: fields[1].to_string(),
            path: fields[2].to_string(),
            expected_decision: fields[3].to_string(),
            expected_events,
            category: fields[6].to_string(),
            severity: fields[7].to_string(),
            expected_verdict: fields[8].to_string(),
        });
    }

    if checks.is_empty() {
        return Err(format!("{MANIFEST_PATH} contains no fixture entries"));
    }

    Ok(checks)
}

fn has_json_field(line: &str, field: &str) -> bool {
    line.contains(&format!("\"{field}\":"))
}

fn verify_fixture(check: &FixtureCheck) -> Result<usize, String> {
    let path = PathBuf::from(&check.path);
    let content = fs::read_to_string(&path)
        .map_err(|err| format!("failed to read {}: {err}", path.display()))?;

    let mut lines_seen = 0;
    let mut expected_decision_seen = false;

    for (idx, line) in content.lines().enumerate() {
        let line = line.trim();
        if line.is_empty() {
            continue;
        }

        lines_seen += 1;

        if !(line.starts_with('{') && line.ends_with('}')) {
            return Err(format!(
                "{}:{} is not a JSON object line",
                path.display(),
                idx + 1
            ));
        }

        for field in ["seq", "kind", "decision", "address", "effect_id", "cause_id", "message"] {
            if !has_json_field(line, field) {
                return Err(format!(
                    "{}:{} missing field `{field}`",
                    path.display(),
                    idx + 1
                ));
            }
        }

        if line.contains(&format!("\"decision\":\"{}\"", check.expected_decision)) {
            expected_decision_seen = true;
        }
    }

    if lines_seen == 0 {
        return Err(format!("{} contains no replay events", path.display()));
    }

    if lines_seen != check.expected_events {
        return Err(format!(
            "{} event count drift: expected {}, actual {}",
            path.display(),
            check.expected_events,
            lines_seen
        ));
    }

    if !expected_decision_seen {
        return Err(format!(
            "{} expected decision `{}` was not found in {} replay events",
            path.display(),
            check.expected_decision,
            lines_seen
        ));
    }

    Ok(lines_seen)
}

fn main() -> ExitCode {
    println!("CMC-REPLAY-FIXTURE-VERIFY v0");

    let checks = match parse_manifest() {
        Ok(checks) => checks,
        Err(err) => {
            eprintln!("status=failed error={err}");
            return ExitCode::FAILURE;
        }
    };

    let mut total_events = 0;

    for check in &checks {
        match verify_fixture(check) {
            Ok(events) => {
                total_events += events;
                println!(
                    "scenario={} invariant={} category={} severity={} verdict={} fixture={} decision={} events={} status=ok",
                    check.scenario_id,
                    check.invariant_id,
                    check.category,
                    check.severity,
                    check.expected_verdict,
                    check.path,
                    check.expected_decision,
                    events
                );
            }
            Err(err) => {
                eprintln!("status=failed error={err}");
                return ExitCode::FAILURE;
            }
        }
    }

    println!("manifest={MANIFEST_PATH}");
    println!("fixtures_checked={}", checks.len());
    println!("events_checked={total_events}");
    println!("result=replay_fixture_corpus_valid");
    ExitCode::SUCCESS
}

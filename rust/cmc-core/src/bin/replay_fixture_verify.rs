use std::fs;
use std::path::PathBuf;
use std::process::ExitCode;

#[derive(Debug)]
struct FixtureCheck {
    path: &'static str,
    expected_decision: &'static str,
}

const FIXTURES: &[FixtureCheck] = &[
    FixtureCheck {
        path: "fixtures/replay/missing_cause.jsonl",
        expected_decision: "REJECT_MISSING_CAUSE",
    },
    FixtureCheck {
        path: "fixtures/replay/unknown_cause.jsonl",
        expected_decision: "REJECT_UNKNOWN_CAUSE",
    },
    FixtureCheck {
        path: "fixtures/replay/forbidden_effect_before_commit_fixture.jsonl",
        expected_decision: "REJECT_EFFECT_BEFORE_COMMIT",
    },
    FixtureCheck {
        path: "fixtures/replay/valid_committed_effect.jsonl",
        expected_decision: "ACCEPT_EFFECT",
    },
];

fn has_json_field(line: &str, field: &str) -> bool {
    line.contains(&format!("\"{field}\":"))
}

fn verify_fixture(check: &FixtureCheck) -> Result<usize, String> {
    let path = PathBuf::from(check.path);
    let content = fs::read_to_string(&path)
        .map_err(|err| format!("failed to read {}: {err}", path.display()))?;

    let mut lines_seen = 0;

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

        if !line.contains(&format!("\"decision\":\"{}\"", check.expected_decision)) {
            return Err(format!(
                "{}:{} expected decision `{}`, line was: {}",
                path.display(),
                idx + 1,
                check.expected_decision,
                line
            ));
        }
    }

    if lines_seen == 0 {
        return Err(format!("{} contains no replay events", path.display()));
    }

    Ok(lines_seen)
}

fn main() -> ExitCode {
    println!("CMC-REPLAY-FIXTURE-VERIFY v0");

    let mut total_events = 0;

    for check in FIXTURES {
        match verify_fixture(check) {
            Ok(events) => {
                total_events += events;
                println!(
                    "fixture={} decision={} events={} status=ok",
                    check.path, check.expected_decision, events
                );
            }
            Err(err) => {
                eprintln!("status=failed error={err}");
                return ExitCode::FAILURE;
            }
        }
    }

    println!("fixtures_checked={}", FIXTURES.len());
    println!("events_checked={total_events}");
    println!("result=replay_fixture_corpus_valid");
    ExitCode::SUCCESS
}

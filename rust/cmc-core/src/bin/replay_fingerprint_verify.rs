use std::{fs, process::ExitCode};

const MANIFEST_PATH: &str = "fixtures/replay/MANIFEST.tsv";
const FNV_OFFSET: u64 = 0xcbf29ce484222325;
const FNV_PRIME: u64 = 0x100000001b3;

struct Case {
    path: String,
    decision: String,
    events: usize,
    fingerprint: String,
}

fn parse_manifest() -> Result<Vec<Case>, String> {
    let content = fs::read_to_string(MANIFEST_PATH)
        .map_err(|err| format!("failed to read {MANIFEST_PATH}: {err}"))?;

    let mut cases = Vec::new();

    for (idx, line) in content.lines().enumerate() {
        let line = line.trim();
        if line.is_empty() {
            continue;
        }

        if idx == 0 && line == "path\tdecision\tevents\tfingerprint" {
            continue;
        }

        let fields: Vec<&str> = line.split('\t').collect();
        if fields.len() != 4 {
            return Err(format!(
                "{MANIFEST_PATH}:{} expected 4 tab-separated fields, got {}",
                idx + 1,
                fields.len()
            ));
        }

        let events = fields[2].parse::<usize>().map_err(|err| {
            format!(
                "{MANIFEST_PATH}:{} invalid event count `{}`: {err}",
                idx + 1,
                fields[2]
            )
        })?;

        cases.push(Case {
            path: fields[0].to_string(),
            decision: fields[1].to_string(),
            events,
            fingerprint: fields[3].to_string(),
        });
    }

    if cases.is_empty() {
        return Err(format!("{MANIFEST_PATH} contains no fixture entries"));
    }

    Ok(cases)
}

fn fp(input: &str) -> String {
    let mut h = FNV_OFFSET;
    for b in input.as_bytes() {
        h ^= u64::from(*b);
        h = h.wrapping_mul(FNV_PRIME);
    }
    format!("{h:016x}")
}

fn main() -> ExitCode {
    println!("CMC-REPLAY-FINGERPRINT-VERIFY v0");

    let cases = match parse_manifest() {
        Ok(cases) => cases,
        Err(err) => {
            eprintln!("result=failed error={err}");
            return ExitCode::FAILURE;
        }
    };

    for case in &cases {
        let Ok(content) = fs::read_to_string(&case.path) else {
            eprintln!("result=failed reason=missing_fixture path={}", case.path);
            return ExitCode::FAILURE;
        };

        let actual_fp = fp(&content);
        if actual_fp != case.fingerprint {
            eprintln!("result=fixture_drift path={} expected={} actual={}", case.path, case.fingerprint, actual_fp);
            return ExitCode::FAILURE;
        }

        let events = content.lines().filter(|line| !line.trim().is_empty()).count();
        if events != case.events {
            eprintln!("result=event_count_drift path={} expected={} actual={}", case.path, case.events, events);
            return ExitCode::FAILURE;
        }

        if !content.contains(&case.decision) {
            eprintln!("result=decision_drift path={} expected={}", case.path, case.decision);
            return ExitCode::FAILURE;
        }

        println!("fixture={} decision={} events={} fingerprint={} status=stable", case.path, case.decision, events, actual_fp);
    }

    println!("manifest={MANIFEST_PATH}");
    println!("fixtures_checked={}", cases.len());
    println!("result=replay_fingerprints_stable");
    ExitCode::SUCCESS
}

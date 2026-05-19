use std::{fs, process::ExitCode};

const MANIFEST_PATH: &str = "fixtures/replay/MANIFEST.tsv";
const MANIFEST_HEADER: &str = "scenario_id\tinvariant_id\tpath\tdecision\tevents\tfingerprint\tcategory\tseverity\texpected_verdict";
const FNV_OFFSET: u64 = 0xcbf29ce484222325;
const FNV_PRIME: u64 = 0x100000001b3;

struct Case {
    scenario_id: String,
    invariant_id: String,
    path: String,
    decision: String,
    events: usize,
    fingerprint: String,
    category: String,
    severity: String,
    expected_verdict: String,
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

        let events = fields[4].parse::<usize>().map_err(|err| {
            format!(
                "{MANIFEST_PATH}:{} invalid event count `{}`: {err}",
                idx + 1,
                fields[4]
            )
        })?;

        cases.push(Case {
            scenario_id: fields[0].to_string(),
            invariant_id: fields[1].to_string(),
            path: fields[2].to_string(),
            decision: fields[3].to_string(),
            events,
            fingerprint: fields[5].to_string(),
            category: fields[6].to_string(),
            severity: fields[7].to_string(),
            expected_verdict: fields[8].to_string(),
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
            eprintln!("result=fixture_drift scenario={} invariant={} category={} severity={} verdict={} path={} expected={} actual={}", case.scenario_id, case.invariant_id, case.category, case.severity, case.expected_verdict, case.path, case.fingerprint, actual_fp);
            return ExitCode::FAILURE;
        }

        let events = content.lines().filter(|line| !line.trim().is_empty()).count();
        if events != case.events {
            eprintln!("result=event_count_drift scenario={} invariant={} category={} severity={} verdict={} path={} expected={} actual={}", case.scenario_id, case.invariant_id, case.category, case.severity, case.expected_verdict, case.path, case.events, events);
            return ExitCode::FAILURE;
        }

        if !content.contains(&case.decision) {
            eprintln!("result=decision_drift scenario={} invariant={} category={} severity={} verdict={} path={} expected={}", case.scenario_id, case.invariant_id, case.category, case.severity, case.expected_verdict, case.path, case.decision);
            return ExitCode::FAILURE;
        }

        println!("scenario={} invariant={} category={} severity={} verdict={} fixture={} decision={} events={} fingerprint={} status=stable", case.scenario_id, case.invariant_id, case.category, case.severity, case.expected_verdict, case.path, case.decision, events, actual_fp);
    }

    println!("manifest={MANIFEST_PATH}");
    println!("fixtures_checked={}", cases.len());
    println!("result=replay_fingerprints_stable");
    ExitCode::SUCCESS
}

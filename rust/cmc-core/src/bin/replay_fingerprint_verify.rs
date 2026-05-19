use std::{fs, process::ExitCode};

const FNV_OFFSET: u64 = 0xcbf29ce484222325;
const FNV_PRIME: u64 = 0x100000001b3;

struct Case {
    path: &'static str,
    decision: &'static str,
    events: usize,
    fingerprint: &'static str,
}

const CASES: &[Case] = &[
    Case { path: "fixtures/replay/missing_cause.jsonl", decision: "REJECT_MISSING_CAUSE", events: 1, fingerprint: "88fd99689760140e" },
    Case { path: "fixtures/replay/unknown_cause.jsonl", decision: "REJECT_UNKNOWN_CAUSE", events: 1, fingerprint: "d8c4983b8a5a0ab0" },
    Case { path: "fixtures/replay/forbidden_effect_before_commit_fixture.jsonl", decision: "REJECT_EFFECT_BEFORE_COMMIT", events: 1, fingerprint: "28bf87f68e4ec6cb" },
    Case { path: "fixtures/replay/valid_committed_effect.jsonl", decision: "ACCEPT_EFFECT", events: 1, fingerprint: "e3e96ba017e2c235" },
];

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

    for case in CASES {
        let Ok(content) = fs::read_to_string(case.path) else {
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

        if !content.contains(case.decision) {
            eprintln!("result=decision_drift path={} expected={}", case.path, case.decision);
            return ExitCode::FAILURE;
        }

        println!("fixture={} decision={} events={} fingerprint={} status=stable", case.path, case.decision, events, actual_fp);
    }

    println!("fixtures_checked={}", CASES.len());
    println!("result=replay_fingerprints_stable");
    ExitCode::SUCCESS
}

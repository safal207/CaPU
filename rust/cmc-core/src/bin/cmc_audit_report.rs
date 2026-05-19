use std::{fs, process::ExitCode};

const MANIFEST_PATH: &str = "fixtures/replay/MANIFEST.tsv";
const MANIFEST_HEADER: &str = "scenario_id\tinvariant_id\tpath\tdecision\tevents\tfingerprint\tcategory\tseverity\texpected_verdict";
const FNV_OFFSET: u64 = 0xcbf29ce484222325;
const FNV_PRIME: u64 = 0x100000001b3;

struct AuditCase {
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

fn parse_manifest() -> Result<Vec<AuditCase>, String> {
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

        cases.push(AuditCase {
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
        return Err(format!("{MANIFEST_PATH} contains no audit cases"));
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

fn json_escape(value: &str) -> String {
    value
        .replace('\\', "\\\\")
        .replace('"', "\\\"")
        .replace('\n', "\\n")
        .replace('\r', "\\r")
        .replace('\t', "\\t")
}

fn audit_case(case: &AuditCase) -> (bool, String, usize, String) {
    let Ok(content) = fs::read_to_string(&case.path) else {
        return (
            false,
            "missing_fixture".to_string(),
            0,
            "missing".to_string(),
        );
    };

    let actual_fingerprint = fp(&content);
    if actual_fingerprint != case.fingerprint {
        return (
            false,
            "fixture_fingerprint_drift".to_string(),
            0,
            actual_fingerprint,
        );
    }

    let actual_events = content
        .lines()
        .filter(|line| !line.trim().is_empty())
        .count();

    if actual_events != case.events {
        return (
            false,
            "event_count_drift".to_string(),
            actual_events,
            actual_fingerprint,
        );
    }

    if !content.contains(&case.decision) {
        return (
            false,
            "decision_drift".to_string(),
            actual_events,
            actual_fingerprint,
        );
    }

    (
        true,
        "audit_case_valid".to_string(),
        actual_events,
        actual_fingerprint,
    )
}

fn print_case(case: &AuditCase, ok: bool, status: &str, actual_events: usize, actual_fp: &str) {
    println!(
        "{{\"type\":\"cmc_audit_case\",\"scenario_id\":\"{}\",\"invariant_id\":\"{}\",\"category\":\"{}\",\"severity\":\"{}\",\"expected_verdict\":\"{}\",\"fixture\":\"{}\",\"decision\":\"{}\",\"expected_events\":{},\"actual_events\":{},\"expected_fingerprint\":\"{}\",\"actual_fingerprint\":\"{}\",\"ok\":{},\"status\":\"{}\"}}",
        json_escape(&case.scenario_id),
        json_escape(&case.invariant_id),
        json_escape(&case.category),
        json_escape(&case.severity),
        json_escape(&case.expected_verdict),
        json_escape(&case.path),
        json_escape(&case.decision),
        case.events,
        actual_events,
        json_escape(&case.fingerprint),
        json_escape(actual_fp),
        ok,
        json_escape(status)
    );
}

fn main() -> ExitCode {
    println!("{{\"type\":\"cmc_audit_report_start\",\"manifest\":\"{MANIFEST_PATH}\"}}");

    let cases = match parse_manifest() {
        Ok(cases) => cases,
        Err(err) => {
            println!(
                "{{\"type\":\"cmc_audit_report_summary\",\"ok\":false,\"status\":\"manifest_error\",\"error\":\"{}\"}}",
                json_escape(&err)
            );
            return ExitCode::FAILURE;
        }
    };

    let mut passed = 0usize;
    let mut failed = 0usize;

    for case in &cases {
        let (ok, status, actual_events, actual_fp) = audit_case(case);
        if ok {
            passed += 1;
        } else {
            failed += 1;
        }
        print_case(case, ok, &status, actual_events, &actual_fp);
    }

    let ok = failed == 0;
    println!(
        "{{\"type\":\"cmc_audit_report_summary\",\"ok\":{},\"cases\":{},\"passed\":{},\"failed\":{},\"status\":\"{}\"}}",
        ok,
        cases.len(),
        passed,
        failed,
        if ok { "audit_report_valid" } else { "audit_report_failed" }
    );

    if ok {
        ExitCode::SUCCESS
    } else {
        ExitCode::FAILURE
    }
}

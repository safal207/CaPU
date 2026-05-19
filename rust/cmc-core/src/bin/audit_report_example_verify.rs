use std::{fs, process::ExitCode};

const VALID_REPORT: &str = "../../examples/audit_reports/cmc_audit_report_valid.jsonl";
const DRIFT_REPORT: &str = "../../examples/audit_reports/cmc_audit_report_drift.jsonl";

fn read_report(path: &str) -> Result<String, String> {
    fs::read_to_string(path).map_err(|err| format!("failed to read {path}: {err}"))
}

fn non_empty_line_count(content: &str) -> usize {
    content.lines().filter(|line| !line.trim().is_empty()).count()
}

fn require_contains(name: &str, content: &str, needle: &str) -> Result<(), String> {
    if content.contains(needle) {
        Ok(())
    } else {
        Err(format!("{name} missing required token: {needle}"))
    }
}

fn require_not_contains(name: &str, content: &str, needle: &str) -> Result<(), String> {
    if content.contains(needle) {
        Err(format!("{name} contains forbidden token: {needle}"))
    } else {
        Ok(())
    }
}

fn require_line_count(name: &str, content: &str, expected: usize) -> Result<(), String> {
    let actual = non_empty_line_count(content);
    if actual == expected {
        Ok(())
    } else {
        Err(format!(
            "{name} line count drift: expected {expected}, actual {actual}"
        ))
    }
}

fn verify_valid_report() -> Result<(), String> {
    let content = read_report(VALID_REPORT)?;
    let name = "valid_report";

    require_line_count(name, &content, 6)?;
    require_contains(name, &content, "\"type\":\"cmc_audit_report_start\"")?;
    require_contains(name, &content, "\"type\":\"cmc_audit_case\"")?;
    require_contains(name, &content, "\"type\":\"cmc_audit_report_summary\"")?;
    require_contains(name, &content, "\"scenario_id\":\"write_missing_cause\"")?;
    require_contains(name, &content, "\"scenario_id\":\"write_unknown_cause\"")?;
    require_contains(name, &content, "\"scenario_id\":\"effect_before_commit\"")?;
    require_contains(name, &content, "\"scenario_id\":\"valid_committed_effect\"")?;
    require_contains(name, &content, "\"status\":\"audit_case_valid\"")?;
    require_contains(name, &content, "\"status\":\"audit_report_valid\"")?;
    require_contains(name, &content, "\"cases\":4")?;
    require_contains(name, &content, "\"passed\":4")?;
    require_contains(name, &content, "\"failed\":0")?;
    require_not_contains(name, &content, "\"ok\":false")?;

    Ok(())
}

fn verify_drift_report() -> Result<(), String> {
    let content = read_report(DRIFT_REPORT)?;
    let name = "drift_report";

    require_line_count(name, &content, 3)?;
    require_contains(name, &content, "\"type\":\"cmc_audit_report_start\"")?;
    require_contains(name, &content, "\"type\":\"cmc_audit_case\"")?;
    require_contains(name, &content, "\"type\":\"cmc_audit_report_summary\"")?;
    require_contains(name, &content, "\"scenario_id\":\"write_missing_cause\"")?;
    require_contains(name, &content, "\"status\":\"fixture_fingerprint_drift\"")?;
    require_contains(name, &content, "\"status\":\"audit_report_failed\"")?;
    require_contains(name, &content, "\"actual_fingerprint\":\"0000000000000000\"")?;
    require_contains(name, &content, "\"ok\":false")?;
    require_contains(name, &content, "\"passed\":3")?;
    require_contains(name, &content, "\"failed\":1")?;
    require_not_contains(name, &content, "\"status\":\"audit_report_valid\"")?;

    Ok(())
}

fn main() -> ExitCode {
    println!("CMC-AUDIT-REPORT-EXAMPLE-VERIFY v0");

    if let Err(err) = verify_valid_report() {
        eprintln!("result=failed report=valid error={err}");
        return ExitCode::FAILURE;
    }
    println!("report=valid path={VALID_REPORT} status=ok");

    if let Err(err) = verify_drift_report() {
        eprintln!("result=failed report=drift error={err}");
        return ExitCode::FAILURE;
    }
    println!("report=drift path={DRIFT_REPORT} status=ok");

    println!("result=audit_report_examples_valid");
    ExitCode::SUCCESS
}

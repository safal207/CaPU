use cmc_core::{CausalMemoryController, ValueHash};
use std::process::ExitCode;

fn hash(byte: u8) -> ValueHash {
    [byte; 32]
}

fn build_expected_trace() -> String {
    let mut cmc = CausalMemoryController::new();
    cmc.write(0xD00D, hash(7), 42, None);
    cmc.add_cause(2, None, false);
    cmc.effect(9001, Some(2));
    cmc.trace_jsonl()
}

fn build_diverged_trace() -> String {
    let mut cmc = CausalMemoryController::new();
    cmc.add_cause(1, None, true);
    cmc.write(0xD00D, hash(7), 42, Some(1));
    cmc.add_cause(2, None, true);
    cmc.effect(9001, Some(2));
    cmc.trace_jsonl()
}

fn first_divergence_line(expected: &str, actual: &str) -> Option<usize> {
    let mut expected_lines = expected.lines();
    let mut actual_lines = actual.lines();
    let mut line_no = 1;

    loop {
        match (expected_lines.next(), actual_lines.next()) {
            (Some(left), Some(right)) if left == right => line_no += 1,
            (Some(_), Some(_)) => return Some(line_no),
            (None, None) => return None,
            _ => return Some(line_no),
        }
    }
}

fn main() -> ExitCode {
    let expected = build_expected_trace();
    let actual = build_diverged_trace();

    println!("CMC-TRACE-DIVERGENCE v0");
    println!("expected_events={}", expected.lines().count());
    println!("actual_events={}", actual.lines().count());

    match first_divergence_line(&expected, &actual) {
        Some(line) => {
            println!("result=replay_divergence_detected line={line}");
            println!("expected_line={}", expected.lines().nth(line - 1).unwrap_or("<missing>"));
            println!("actual_line={}", actual.lines().nth(line - 1).unwrap_or("<missing>"));
            println!("proof=same scenario class produced different replay trace outcome");
            ExitCode::SUCCESS
        }
        None => {
            eprintln!("result=demo_failed reason=no_divergence_detected");
            ExitCode::FAILURE
        }
    }
}

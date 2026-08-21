use cmc_core::capu::decision_unit::decide_transition;
use cmc_core::capu::decoder::{decode_external_action, ExternalActionRequest};
use std::env;
use std::time::Instant;

const BENCHMARK_ID: &str = "PB-TRANSITION-03";
const VERSION: &str = "0.1";
const PROTOCOL: &str = "PB-T03/v0.1 authorization-freshness-replay-conflict-outcome";
const FAULT_KINDS: [&str; 5] = [
    "UNKNOWN",
    "STALE_AUTHORITY",
    "REPLAY",
    "CONFLICT",
    "FALSE_SUCCESS",
];

fn parse_args() -> (usize, f64) {
    let mut trials = 10_000usize;
    let mut contamination = 0.10f64;
    let args: Vec<String> = env::args().collect();
    let mut i = 1usize;
    while i < args.len() {
        match args[i].as_str() {
            "--trials" => {
                i += 1;
                trials = args
                    .get(i)
                    .expect("--trials requires a value")
                    .parse()
                    .expect("--trials must be an integer");
            }
            "--contamination" => {
                i += 1;
                contamination = args
                    .get(i)
                    .expect("--contamination requires a value")
                    .parse()
                    .expect("--contamination must be a number");
            }
            other => panic!("unknown argument: {other}"),
        }
        i += 1;
    }
    assert!(trials > 0, "trials must be positive");
    assert!(
        (0.0..=1.0).contains(&contamination),
        "contamination must be between 0 and 1"
    );
    (trials, contamination)
}

fn main() {
    let (trials, contamination) = parse_args();
    let bad_count = ((trials as f64) * contamination).round() as usize;
    let mut bad_seen = 0usize;

    let mut valid_trials = 0usize;
    let mut unknown_trials = 0usize;
    let mut stale_trials = 0usize;
    let mut replay_trials = 0usize;
    let mut conflict_trials = 0usize;
    let mut false_success_trials = 0usize;

    let mut oracle_correct_assessed = 0usize;
    let mut unsafe_dispatches = 0usize;
    let mut missed_valid = 0usize;

    let started = Instant::now();

    for index in 0..trials {
        let contaminated = ((index + 1) * bad_count) / trials > (index * bad_count) / trials;
        let kind = if contaminated {
            let value = FAULT_KINDS[bad_seen % FAULT_KINDS.len()];
            bad_seen += 1;
            value
        } else {
            "VALID"
        };

        match kind {
            "VALID" => {
                valid_trials += 1;
                let transition_id = format!("pb-t03-valid-{index}");
                let transition = decode_external_action(ExternalActionRequest::new(
                    &transition_id,
                    "state_transition",
                    Some((index + 1) as u64),
                    true,
                ));
                let decision = decide_transition(&transition);
                if decision.accepted() {
                    oracle_correct_assessed += 1;
                } else {
                    missed_valid += 1;
                }
            }
            "UNKNOWN" => {
                unknown_trials += 1;
                let transition_id = format!("pb-t03-unknown-{index}");
                let transition = decode_external_action(ExternalActionRequest::new(
                    &transition_id,
                    "state_transition",
                    None,
                    false,
                ));
                let decision = decide_transition(&transition);
                if decision.accepted() {
                    unsafe_dispatches += 1;
                } else {
                    oracle_correct_assessed += 1;
                }
            }
            "STALE_AUTHORITY" => stale_trials += 1,
            "REPLAY" => replay_trials += 1,
            "CONFLICT" => conflict_trials += 1,
            "FALSE_SUCCESS" => false_success_trials += 1,
            _ => unreachable!(),
        }
    }

    let elapsed_ns = started.elapsed().as_nanos();
    let assessed_trials = valid_trials + unknown_trials;
    let unassessed_trials = trials - assessed_trials;
    let elapsed_seconds = elapsed_ns as f64 / 1_000_000_000.0;
    let assessed_trials_per_sec = if elapsed_seconds > 0.0 {
        assessed_trials as f64 / elapsed_seconds
    } else {
        0.0
    };
    let oracle_accuracy = if assessed_trials > 0 {
        oracle_correct_assessed as f64 / assessed_trials as f64
    } else {
        0.0
    };
    let stream_coverage = assessed_trials as f64 / trials as f64;

    println!(
        concat!(
            "{{",
            "\"benchmark_id\":\"{}\",",
            "\"version\":\"{}\",",
            "\"protocol\":\"{}\",",
            "\"architecture\":\"CaPU\",",
            "\"implementation\":\"cmc-core P6 external-action software reference\",",
            "\"status\":\"executed_partial\",",
            "\"trials\":{},",
            "\"contamination_rate\":{:.8},",
            "\"valid_trials\":{},",
            "\"adversarial_trials\":{},",
            "\"failure_kind_coverage\":0.2,",
            "\"stream_semantic_coverage\":{:.8},",
            "\"supported_fault_kinds\":[\"UNKNOWN\"],",
            "\"unsupported_fault_kinds\":[\"STALE_AUTHORITY\",\"REPLAY\",\"CONFLICT\",\"FALSE_SUCCESS\"],",
            "\"assessed_trials\":{},",
            "\"unassessed_trials\":{},",
            "\"oracle_correct_assessed_trials\":{},",
            "\"oracle_accuracy_on_assessed\":{:.8},",
            "\"unsafe_authorization_dispatches_on_assessed\":{},",
            "\"false_success_claims_on_assessed\":0,",
            "\"missed_valid_dispatches_on_assessed\":{},",
            "\"evidence_kind\":\"cause_plus_durable_commit\",",
            "\"per_kind\":{{",
            "\"VALID\":{{\"status\":\"supported\",\"trials\":{},\"oracle_correct\":{}}},",
            "\"UNKNOWN\":{{\"status\":\"supported\",\"trials\":{},\"oracle_correct\":{}}},",
            "\"STALE_AUTHORITY\":{{\"status\":\"unsupported\",\"trials\":{}}},",
            "\"REPLAY\":{{\"status\":\"unsupported\",\"trials\":{}}},",
            "\"CONFLICT\":{{\"status\":\"unsupported\",\"trials\":{}}},",
            "\"FALSE_SUCCESS\":{{\"status\":\"unsupported\",\"trials\":{}}}",
            "}},",
            "\"elapsed_ns\":{},",
            "\"assessed_trials_per_sec\":{:.3},",
            "\"native_steps_total\":{},",
            "\"claim_boundary\":\"PB-T03 credits only VALID and UNKNOWN at the current executable P6 boundary. STALE_AUTHORITY, execution-guard REPLAY, CONFLICT, and FALSE_SUCCESS are explicitly unassessed, never counted as prevented.\",",
            "\"cost_note\":\"Rust software-reference operations; not hardware cycles, energy, area, or silicon performance\"",
            "}}"
        ),
        BENCHMARK_ID,
        VERSION,
        PROTOCOL,
        trials,
        contamination,
        valid_trials,
        trials - valid_trials,
        stream_coverage,
        assessed_trials,
        unassessed_trials,
        oracle_correct_assessed,
        oracle_accuracy,
        unsafe_dispatches,
        missed_valid,
        valid_trials,
        valid_trials - missed_valid,
        unknown_trials,
        unknown_trials - unsafe_dispatches,
        stale_trials,
        replay_trials,
        conflict_trials,
        false_success_trials,
        elapsed_ns,
        assessed_trials_per_sec,
        assessed_trials,
    );
}

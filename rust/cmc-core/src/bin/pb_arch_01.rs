use cmc_core::capu::decision_unit::decide_transition;
use cmc_core::capu::decoder::{decode_external_action, ExternalActionRequest};
use std::env;
use std::time::Instant;

const FAILURE_KINDS: [&str; 5] = ["UNKNOWN", "STALE", "REPLAY", "CONFLICT", "FALSE_SUCCESS"];

fn parse_args() -> (usize, f64) {
    let mut decisions = 10_000usize;
    let mut contamination = 0.10f64;
    let args: Vec<String> = env::args().collect();
    let mut i = 1usize;
    while i < args.len() {
        match args[i].as_str() {
            "--decisions" => {
                i += 1;
                decisions = args
                    .get(i)
                    .expect("--decisions requires a value")
                    .parse()
                    .expect("--decisions must be an integer");
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

    assert!(decisions > 0, "decisions must be positive");
    assert!(
        (0.0..=1.0).contains(&contamination),
        "contamination must be between 0 and 1"
    );
    (decisions, contamination)
}

fn main() {
    let (decisions, contamination) = parse_args();
    let bad_count = ((decisions as f64) * contamination).round() as usize;

    let mut bad_seen = 0usize;
    let mut normal_decisions = 0usize;
    let mut adversarial_decisions = 0usize;
    let mut supported_decisions = 0usize;
    let mut unsupported_decisions = 0usize;
    let mut safe_actions = 0usize;
    let mut unsafe_actions = 0usize;
    let mut blocked_valid_actions = 0usize;
    let mut blocked_supported_adversarial = 0usize;
    let mut unknown_decisions = 0usize;
    let mut stale_decisions = 0usize;
    let mut replay_decisions = 0usize;
    let mut conflict_decisions = 0usize;
    let mut false_success_decisions = 0usize;

    let started = Instant::now();

    for index in 0..decisions {
        let contaminated = ((index + 1) * bad_count) / decisions > (index * bad_count) / decisions;
        let kind = if contaminated {
            let value = FAILURE_KINDS[bad_seen % FAILURE_KINDS.len()];
            bad_seen += 1;
            adversarial_decisions += 1;
            value
        } else {
            normal_decisions += 1;
            "NORMAL"
        };

        match kind {
            "NORMAL" => {
                supported_decisions += 1;
                let transition_id = format!("pb-arch-normal-{index}");
                let transition = decode_external_action(ExternalActionRequest::new(
                    &transition_id,
                    "agent_action",
                    Some((index + 1) as u64),
                    true,
                ));
                let decision = decide_transition(&transition);
                if decision.accepted() {
                    safe_actions += 1;
                } else {
                    blocked_valid_actions += 1;
                }
            }
            "UNKNOWN" => {
                // Cross-architecture mapping: required legitimizing evidence / durable
                // commit is absent. CaPU P6 natively rejects this boundary.
                unknown_decisions += 1;
                supported_decisions += 1;
                let transition_id = format!("pb-arch-unknown-{index}");
                let transition = decode_external_action(ExternalActionRequest::new(
                    &transition_id,
                    "agent_action",
                    None,
                    false,
                ));
                let decision = decide_transition(&transition);
                if decision.accepted() {
                    unsafe_actions += 1;
                } else {
                    blocked_supported_adversarial += 1;
                }
            }
            "STALE" => {
                stale_decisions += 1;
                unsupported_decisions += 1;
            }
            "REPLAY" => {
                replay_decisions += 1;
                unsupported_decisions += 1;
            }
            "CONFLICT" => {
                conflict_decisions += 1;
                unsupported_decisions += 1;
            }
            "FALSE_SUCCESS" => {
                false_success_decisions += 1;
                unsupported_decisions += 1;
            }
            _ => unreachable!(),
        }
    }

    let elapsed_ns = started.elapsed().as_nanos();
    let elapsed_seconds = elapsed_ns as f64 / 1_000_000_000.0;
    let supported_per_sec = if elapsed_seconds > 0.0 {
        supported_decisions as f64 / elapsed_seconds
    } else {
        0.0
    };
    let legitimate_useful_per_sec = if elapsed_seconds > 0.0 {
        safe_actions as f64 / elapsed_seconds
    } else {
        0.0
    };
    let semantic_decision_coverage = supported_decisions as f64 / decisions as f64;
    let failure_kind_coverage = 1.0 / FAILURE_KINDS.len() as f64;
    let false_positive_block_rate = if normal_decisions > 0 {
        blocked_valid_actions as f64 / normal_decisions as f64
    } else {
        0.0
    };
    let unsafe_per_million_supported = if supported_decisions > 0 {
        unsafe_actions as f64 / supported_decisions as f64 * 1_000_000.0
    } else {
        0.0
    };

    println!(
        concat!(
            "{{",
            "\"benchmark_id\":\"PB-ARCH-01\",",
            "\"version\":\"0.1\",",
            "\"architecture\":\"CaPU\",",
            "\"implementation\":\"cmc-core P6 external-action software reference\",",
            "\"status\":\"executed_partial\",",
            "\"decisions\":{},",
            "\"contamination_rate\":{:.8},",
            "\"normal_decisions\":{},",
            "\"adversarial_decisions\":{},",
            "\"supported_decisions\":{},",
            "\"unsupported_decisions\":{},",
            "\"safe_actions\":{},",
            "\"unsafe_actions_on_supported_semantics\":{},",
            "\"blocked_valid_actions\":{},",
            "\"blocked_supported_adversarial\":{},",
            "\"semantic_decision_coverage\":{:.8},",
            "\"failure_kind_coverage\":{:.8},",
            "\"false_positive_block_rate\":{:.8},",
            "\"unsafe_actions_per_million_supported_decisions\":{:.3},",
            "\"elapsed_ns\":{},",
            "\"supported_decisions_per_sec\":{:.3},",
            "\"legitimate_useful_actions_per_sec\":{:.3},",
            "\"failure_counts\":{{",
            "\"UNKNOWN\":{},",
            "\"STALE\":{},",
            "\"REPLAY\":{},",
            "\"CONFLICT\":{},",
            "\"FALSE_SUCCESS\":{}",
            "}},",
            "\"failure_kind_support\":{{",
            "\"UNKNOWN\":\"supported_missing_commit_mapping\",",
            "\"STALE\":\"unsupported_in_p6_software_reference\",",
            "\"REPLAY\":\"unsupported_as_execution_guard_in_p6_software_reference\",",
            "\"CONFLICT\":\"unsupported_in_p6_software_reference\",",
            "\"FALSE_SUCCESS\":\"unsupported_outcome_grounding_boundary\"",
            "}},",
            "\"claim_boundary\":\"Unsupported fault kinds are unassessed, never counted as prevented. CaPU v0.33 has separate verified stale/epoch/replay capabilities that are not attributed to this P6 runtime adapter until wired into the same executable benchmark.\"",
            "}}"
        ),
        decisions,
        contamination,
        normal_decisions,
        adversarial_decisions,
        supported_decisions,
        unsupported_decisions,
        safe_actions,
        unsafe_actions,
        blocked_valid_actions,
        blocked_supported_adversarial,
        semantic_decision_coverage,
        failure_kind_coverage,
        false_positive_block_rate,
        unsafe_per_million_supported,
        elapsed_ns,
        supported_per_sec,
        legitimate_useful_per_sec,
        unknown_decisions,
        stale_decisions,
        replay_decisions,
        conflict_decisions,
        false_success_decisions,
    );
}

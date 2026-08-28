use cmc_core::capu::decision_unit::decide_transition;
use cmc_core::capu::decoder::{decode_external_action, ExternalActionRequest};
use std::env;
use std::time::Instant;

const PROTOCOL: &str = "PB-T02/v0.1 binary-endpoint alternating-direction deterministic-insufficient-support";

fn parse_args() -> (usize, f64) {
    let mut trials = 10_000usize;
    let mut insufficient = 0.10f64;
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
            "--insufficient" => {
                i += 1;
                insufficient = args
                    .get(i)
                    .expect("--insufficient requires a value")
                    .parse()
                    .expect("--insufficient must be a number");
            }
            other => panic!("unknown argument: {other}"),
        }
        i += 1;
    }
    assert!(trials > 0, "trials must be positive");
    assert!((0.0..=1.0).contains(&insufficient));
    (trials, insufficient)
}

fn main() {
    let (trials, insufficient_rate) = parse_args();
    let insufficient_count = ((trials as f64) * insufficient_rate).round() as usize;

    let mut valid_trials = 0usize;
    let mut insufficient_trials = 0usize;
    let mut source_0_trials = 0usize;
    let mut source_1_trials = 0usize;
    let mut correct_valid_transitions = 0usize;
    let mut invalid_transitions_preserved = 0usize;
    let mut unsafe_invalid_transitions = 0usize;
    let mut missed_valid_transitions = 0usize;
    let mut justified_valid_transitions = 0usize;

    let started = Instant::now();

    for index in 0..trials {
        let insufficient = ((index + 1) * insufficient_count) / trials
            > (index * insufficient_count) / trials;
        let source = if index % 2 == 0 { 0u8 } else { 1u8 };
        let target = 1u8 - source;
        if source == 0 {
            source_0_trials += 1;
        } else {
            source_1_trials += 1;
        }

        let request = if insufficient {
            insufficient_trials += 1;
            ExternalActionRequest::new(
                format!("pb-t02-insufficient-{index}"),
                format!("state_{source}_to_{target}"),
                None,
                false,
            )
        } else {
            valid_trials += 1;
            ExternalActionRequest::new(
                format!("pb-t02-valid-{index}"),
                format!("state_{source}_to_{target}"),
                Some((index + 1) as u64),
                true,
            )
        };

        let transition = decode_external_action(request);
        let decision = decide_transition(&transition);
        let final_state = if decision.accepted() { target } else { source };

        if insufficient {
            if final_state == source {
                invalid_transitions_preserved += 1;
            } else {
                unsafe_invalid_transitions += 1;
            }
        } else if final_state == target {
            correct_valid_transitions += 1;
            justified_valid_transitions += 1;
        } else {
            missed_valid_transitions += 1;
        }
    }

    let elapsed_ns = started.elapsed().as_nanos();
    let seconds = elapsed_ns as f64 / 1_000_000_000.0;
    let oracle_correct_trials = correct_valid_transitions + invalid_transitions_preserved;
    let trials_per_sec = if seconds > 0.0 {
        trials as f64 / seconds
    } else {
        0.0
    };
    let useful_per_sec = if seconds > 0.0 {
        correct_valid_transitions as f64 / seconds
    } else {
        0.0
    };
    let justified_useful_per_sec = if seconds > 0.0 {
        justified_valid_transitions as f64 / seconds
    } else {
        0.0
    };
    let justification_coverage = if valid_trials > 0 {
        justified_valid_transitions as f64 / valid_trials as f64
    } else {
        0.0
    };

    println!(
        concat!(
            "{{",
            "\"benchmark_id\":\"PB-TRANSITION-02\",",
            "\"version\":\"0.1\",",
            "\"protocol\":\"{}\",",
            "\"architecture\":\"CaPU\",",
            "\"implementation\":\"cmc-core P6 external-action software reference\",",
            "\"status\":\"executed\",",
            "\"trials\":{},",
            "\"insufficient_support_rate\":{:.8},",
            "\"valid_trials\":{},",
            "\"insufficient_support_trials\":{},",
            "\"source_0_trials\":{},",
            "\"source_1_trials\":{},",
            "\"correct_valid_transitions\":{},",
            "\"invalid_transitions_preserved\":{},",
            "\"unsafe_invalid_transitions\":{},",
            "\"missed_valid_transitions\":{},",
            "\"oracle_correct_trials\":{},",
            "\"oracle_accuracy\":{:.8},",
            "\"native_justified_valid_transitions\":{},",
            "\"native_justification_coverage\":{:.8},",
            "\"evidence_kind\":\"cause_plus_durable_commit\",",
            "\"elapsed_ns\":{},",
            "\"trials_per_sec\":{:.3},",
            "\"correct_useful_transitions_per_sec\":{:.3},",
            "\"justified_useful_throughput\":{:.3},",
            "\"native_steps_total\":{},",
            "\"cost_note\":\"software reference operations; not hardware cycles, energy, area, or silicon performance\",",
            "\"claim_boundary\":\"PB-T02 maps sufficient support to CaPU P6 cause plus commit and insufficient support to missing cause/commit. It does not claim equivalence between CaPU causal evidence, ProofBit proof objects, and MORPHOS transition traces.\"",
            "}}"
        ),
        PROTOCOL,
        trials,
        insufficient_rate,
        valid_trials,
        insufficient_trials,
        source_0_trials,
        source_1_trials,
        correct_valid_transitions,
        invalid_transitions_preserved,
        unsafe_invalid_transitions,
        missed_valid_transitions,
        oracle_correct_trials,
        oracle_correct_trials as f64 / trials as f64,
        justified_valid_transitions,
        justification_coverage,
        elapsed_ns,
        trials_per_sec,
        useful_per_sec,
        justified_useful_per_sec,
        trials,
    );
}

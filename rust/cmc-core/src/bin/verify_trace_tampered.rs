use cmc_core::{CausalMemoryController, ValueHash};
use std::process::ExitCode;

const GENESIS_HASH: &str = "0000000000000000";
const FNV_OFFSET: u64 = 0xcbf29ce484222325;
const FNV_PRIME: u64 = 0x100000001b3;

fn hash(byte: u8) -> ValueHash {
    [byte; 32]
}

fn fnv1a64(input: &str) -> String {
    let mut hash = FNV_OFFSET;
    for byte in input.as_bytes() {
        hash ^= u64::from(*byte);
        hash = hash.wrapping_mul(FNV_PRIME);
    }
    format!("{hash:016x}")
}

fn seal_trace(jsonl: &str) -> Vec<(String, String, String)> {
    let mut prev_hash = GENESIS_HASH.to_string();
    let mut sealed = Vec::new();

    for line in jsonl.lines().filter(|line| !line.trim().is_empty()) {
        let trace_hash = fnv1a64(&format!("{}{}", prev_hash, line));
        sealed.push((prev_hash.clone(), line.to_string(), trace_hash.clone()));
        prev_hash = trace_hash;
    }

    sealed
}

fn verify_trace(sealed: &[(String, String, String)]) -> Result<(), usize> {
    let mut prev_hash = GENESIS_HASH.to_string();

    for (idx, (recorded_prev, event, recorded_hash)) in sealed.iter().enumerate() {
        if recorded_prev != &prev_hash {
            return Err(idx + 1);
        }

        let expected = fnv1a64(&format!("{}{}", prev_hash, event));
        if &expected != recorded_hash {
            return Err(idx + 1);
        }

        prev_hash = recorded_hash.clone();
    }

    Ok(())
}

fn main() -> ExitCode {
    let mut cmc = CausalMemoryController::new();
    cmc.write(0xD00D, hash(7), 42, None);
    cmc.add_cause(2, None, false);
    cmc.effect(9001, Some(2));

    let trace_jsonl = cmc.trace_jsonl();
    let mut sealed = seal_trace(&trace_jsonl);

    println!("CMC-VERIFY-TRACE-TAMPERED v0");
    println!("events={}", sealed.len());

    if sealed.is_empty() {
        eprintln!("result=demo_failed reason=no_events");
        return ExitCode::FAILURE;
    }

    sealed[0].1 = sealed[0].1.replace("REJECT_MISSING_CAUSE", "ACCEPT_WRITE");

    match verify_trace(&sealed) {
        Ok(()) => {
            eprintln!("result=demo_failed reason=tampering_not_detected");
            ExitCode::FAILURE
        }
        Err(seq) => {
            println!("result=tampering_detected seq={seq}");
            println!("proof=modified decision invalidated hash chain");
            println!("note=developer integrity demo only; not cryptographic evidence");
            ExitCode::SUCCESS
        }
    }
}

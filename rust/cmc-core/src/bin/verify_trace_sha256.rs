use cmc_core::{trace_crypto, CausalMemoryController, ValueHash};
use std::process::ExitCode;

fn hash(byte: u8) -> ValueHash {
    [byte; 32]
}

fn main() -> ExitCode {
    let mut cmc = CausalMemoryController::new();
    cmc.write(0xD00D, hash(7), 42, None);
    cmc.add_cause(2, None, false);
    cmc.effect(9001, Some(2));

    let trace_jsonl = cmc.trace_jsonl();
    let sealed = trace_crypto::seal_trace(&trace_jsonl);

    println!("CMC-VERIFY-TRACE-SHA256 v0");
    println!("hash=sha256-std-only");
    println!("events={}", sealed.len());

    for (idx, event) in sealed.iter().enumerate() {
        println!(
            "event={} prev_hash={} trace_hash={} canonical={}",
            idx + 1,
            event.prev_hash,
            event.trace_hash,
            event.event
        );
    }

    match trace_crypto::verify_trace(&sealed) {
        Ok(()) => {
            println!("result=trace_sha256_valid");
            ExitCode::SUCCESS
        }
        Err(seq) => {
            eprintln!("result=trace_sha256_invalid seq={seq}");
            ExitCode::FAILURE
        }
    }
}

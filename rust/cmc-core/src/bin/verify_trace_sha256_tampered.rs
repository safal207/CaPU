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
    let mut sealed = trace_crypto::seal_trace(&trace_jsonl);

    println!("CMC-VERIFY-TRACE-SHA256-TAMPERED v0");
    println!("events={}", sealed.len());

    if sealed.is_empty() {
        eprintln!("result=demo_failed reason=no_events");
        return ExitCode::FAILURE;
    }

    sealed[0].event = sealed[0]
        .event
        .replace("REJECT_MISSING_CAUSE", "ACCEPT_WRITE");

    match trace_crypto::verify_trace(&sealed) {
        Ok(()) => {
            eprintln!("result=demo_failed reason=modified_trace_accepted");
            ExitCode::FAILURE
        }
        Err(seq) => {
            println!("result=trace_sha256_tamper_detected seq={seq}");
            ExitCode::SUCCESS
        }
    }
}

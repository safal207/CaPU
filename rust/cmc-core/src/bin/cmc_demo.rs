use cmc_core::{CausalMemoryController, DecisionCode, TraceEventKind, ValueHash};
use std::process::ExitCode;

fn hash(byte: u8) -> ValueHash {
    [byte; 32]
}

fn main() -> ExitCode {
    let mut cmc = CausalMemoryController::new();

    println!("CMC-DEMO illegitimate-transition v0");

    let write_without_cause = cmc.write(0xD00D, hash(7), 42, None);
    println!(
        "1. write_without_cause: {:?} accepted={}",
        write_without_cause.code,
        write_without_cause.accepted()
    );

    cmc.add_cause(2, None, false);
    let effect_before_commit = cmc.effect(9001, Some(2));
    println!(
        "2. effect_before_commit: {:?} accepted={}",
        effect_before_commit.code,
        effect_before_commit.accepted()
    );

    println!("3. trace_events={}", cmc.trace_events().len());

    for event in cmc.trace_events() {
        println!(
            "   trace seq={} kind={:?} decision={:?} cause={:?} address={:?} effect={:?}",
            event.seq,
            event.kind,
            event.decision,
            event.cause_id,
            event.address,
            event.effect_id
        );
    }

    let write_was_blocked = write_without_cause.code == DecisionCode::RejectMissingCause;
    let effect_was_blocked = effect_before_commit.code == DecisionCode::RejectEffectBeforeCommit;
    let trace_is_complete = cmc.trace_events().len() == 2
        && cmc.trace_events()[0].kind == TraceEventKind::Write
        && cmc.trace_events()[1].kind == TraceEventKind::Effect;

    if write_was_blocked && effect_was_blocked && trace_is_complete {
        println!("4. result=blocked_illegitimate_transition");
        println!("5. proof=invalid transition -> blocked effect -> trace evidence");
        ExitCode::SUCCESS
    } else {
        eprintln!("4. result=demo_failed");
        eprintln!("5. expected both invalid operations to be blocked and traced");
        ExitCode::FAILURE
    }
}

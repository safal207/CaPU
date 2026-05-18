use cmc_core::{CausalMemoryController, ValueHash};
use std::hint::black_box;
use std::time::Instant;

const OPS: u64 = 10_000;

fn hash(seed: u64) -> ValueHash {
    let mut out = [0_u8; 32];
    for (idx, byte) in out.iter_mut().enumerate() {
        *byte = seed.wrapping_add(idx as u64) as u8;
    }
    out
}

fn nanos_per_op(elapsed_ns: u128, ops: u64) -> u128 {
    elapsed_ns / u128::from(ops.max(1))
}

fn main() {
    let mut cmc = CausalMemoryController::new();

    for id in 1..=OPS {
        let parent = if id == 1 { None } else { Some(id - 1) };
        cmc.add_cause(id, parent, true);
    }

    let write_start = Instant::now();
    let mut accepted_writes = 0_u64;

    for id in 1..=OPS {
        let decision = cmc.write(0x1000 + id, hash(id), 42, Some(id));
        if decision.accepted() {
            accepted_writes += 1;
        }
        black_box(decision);
    }

    let write_elapsed = write_start.elapsed();

    let effect_start = Instant::now();
    let mut accepted_effects = 0_u64;

    for id in 1..=OPS {
        let decision = cmc.effect(0xE000 + id, Some(id));
        if decision.accepted() {
            accepted_effects += 1;
        }
        black_box(decision);
    }

    let effect_elapsed = effect_start.elapsed();

    let audit_start = Instant::now();
    let audit = cmc.audit();
    black_box(&audit);
    let audit_elapsed = audit_start.elapsed();

    println!("CMC-BENCH developer-microbenchmark v0");
    println!("ops={OPS}");
    println!("accepted_writes={accepted_writes}");
    println!("accepted_effects={accepted_effects}");
    println!("audit.entries={}", audit.entries);
    println!("audit.effects={}", audit.effects);
    println!("audit.findings={}", audit.findings.len());
    println!("write.total_ns={}", write_elapsed.as_nanos());
    println!("write.ns_per_op={}", nanos_per_op(write_elapsed.as_nanos(), OPS));
    println!("effect.total_ns={}", effect_elapsed.as_nanos());
    println!("effect.ns_per_op={}", nanos_per_op(effect_elapsed.as_nanos(), OPS));
    println!("audit.total_ns={}", audit_elapsed.as_nanos());
    println!("note=developer benchmark only; not a throughput SLA");
}

use cmc_core::capu::astra_r0::run_r0_scenario;

fn main() {
    let result = run_r0_scenario().expect("ASTRA-CaPU R0 scenario must complete");

    assert!(result.baseline_duplicate_effect);
    assert_eq!(result.baseline_dispatch_count, 2);
    assert_eq!(result.baseline_external_effect_count, 2);
    assert_eq!(result.capu_dispatch_count, 1);
    assert_eq!(result.capu_external_effect_count, 1);
    assert!(result.blind_replay_blocked);
    assert!(result.success_claim_blocked);
    assert!(result.memory_update_blocked);
    assert_eq!(result.stale_evidence_quarantined, 1);
    assert!(result.trusted_memory_updated);
    assert_eq!(result.proof_receipt_digest.len(), 64);

    println!(
        "unsafe_baseline dispatches={} external_effects={} duplicate_effect={}",
        result.baseline_dispatch_count,
        result.baseline_external_effect_count,
        result.baseline_duplicate_effect
    );
    println!(
        "capu_unknown_boundary blind_replay_blocked={} success_claim_blocked={} memory_update_blocked={}",
        result.blind_replay_blocked,
        result.success_claim_blocked,
        result.memory_update_blocked
    );
    println!(
        "capu_reconciled dispatches={} external_effects={} stale_evidence_quarantined={} trusted_memory_updated={}",
        result.capu_dispatch_count,
        result.capu_external_effect_count,
        result.stale_evidence_quarantined,
        result.trusted_memory_updated
    );
    println!("proof_receipt_digest={}", result.proof_receipt_digest);
    println!("result_json={}", result.to_json());
    println!("ASTRA_CAPU_R0_EFFECT_AUTHORITY_PASS");
}

use cmc_core::trace_crypto::{seal_trace, sha256_hex, verify_trace};
use std::env;
use std::fs;
use std::path::Path;

const TARGET: &str = "google/tpu-raiden";
const MODE: &str = "repository-owned-cpu-model";
const MODEL_UID: &str = "recovery_model";
const OTHER_MODEL_UID: &str = "another_model";

#[derive(Debug, Clone, PartialEq, Eq)]
enum RecoveryClass {
    WarmRecovered,
    ColdStart,
}

impl RecoveryClass {
    fn as_str(&self) -> &'static str {
        match self {
            Self::WarmRecovered => "warm_recovered",
            Self::ColdStart => "cold_start",
        }
    }
}

#[derive(Debug, Clone)]
struct PersistedModel {
    host_bytes: Option<Vec<u8>>,
    metadata_valid: bool,
    metadata_model_uid: Option<String>,
}

impl PersistedModel {
    fn empty() -> Self {
        Self {
            host_bytes: None,
            metadata_valid: false,
            metadata_model_uid: None,
        }
    }

    fn write_host_bytes(&mut self, bytes: &[u8]) {
        self.host_bytes = Some(bytes.to_vec());
    }

    fn commit_metadata(&mut self, model_uid: &str) {
        self.metadata_model_uid = Some(model_uid.to_string());
        self.metadata_valid = true;
    }

    fn recover(&self, requested_model_uid: &str) -> RecoveryClass {
        if self.metadata_valid
            && self.host_bytes.is_some()
            && self.metadata_model_uid.as_deref() == Some(requested_model_uid)
        {
            RecoveryClass::WarmRecovered
        } else {
            RecoveryClass::ColdStart
        }
    }
}

#[derive(Debug, Clone)]
struct ScenarioResult {
    id: &'static str,
    phase: &'static str,
    expected: &'static str,
    observed: RecoveryClass,
    invariant: &'static str,
    passed: bool,
    evidence_sha256: String,
}

fn deterministic_payload() -> Vec<u8> {
    (0u16..512)
        .flat_map(|value| value.to_le_bytes())
        .collect::<Vec<_>>()
}

fn committed_recovery_scenario(payload: &[u8]) -> ScenarioResult {
    let mut persisted = PersistedModel::empty();
    persisted.write_host_bytes(payload);
    persisted.commit_metadata(MODEL_UID);

    let observed = persisted.recover(MODEL_UID);
    let recovered_digest = persisted
        .host_bytes
        .as_deref()
        .map(sha256_hex)
        .unwrap_or_else(|| sha256_hex(&[]));
    let original_digest = sha256_hex(payload);
    let passed = observed == RecoveryClass::WarmRecovered && recovered_digest == original_digest;

    ScenarioResult {
        id: "RDN-CPU-001",
        phase: "post_metadata_commit_restart",
        expected: "warm_recovered",
        observed,
        invariant: "RDN-INV-003+004",
        passed,
        evidence_sha256: recovered_digest,
    }
}

fn precommit_crash_scenario(payload: &[u8]) -> ScenarioResult {
    let mut persisted = PersistedModel::empty();
    persisted.write_host_bytes(payload);
    // Deliberately crash before metadata commit: host bytes may exist, but the
    // binding is not causally committed and therefore must not be resurrected.

    let observed = persisted.recover(MODEL_UID);
    let evidence_sha256 = persisted
        .host_bytes
        .as_deref()
        .map(sha256_hex)
        .unwrap_or_else(|| sha256_hex(&[]));
    let passed = observed == RecoveryClass::ColdStart && !persisted.metadata_valid;

    ScenarioResult {
        id: "RDN-CPU-002",
        phase: "host_written_before_metadata_commit",
        expected: "cold_start",
        observed,
        invariant: "RDN-INV-001",
        passed,
        evidence_sha256,
    }
}

fn model_uid_mismatch_scenario(payload: &[u8]) -> ScenarioResult {
    let mut persisted = PersistedModel::empty();
    persisted.write_host_bytes(payload);
    persisted.commit_metadata(MODEL_UID);

    let observed = persisted.recover(OTHER_MODEL_UID);
    let evidence_sha256 = sha256_hex(
        format!(
            "recorded={};requested={};bytes={}",
            MODEL_UID,
            OTHER_MODEL_UID,
            sha256_hex(payload)
        )
        .as_bytes(),
    );
    let passed = observed == RecoveryClass::ColdStart;

    ScenarioResult {
        id: "RDN-CPU-003",
        phase: "restart_identity_validation",
        expected: "cold_start",
        observed,
        invariant: "RDN-INV-002",
        passed,
        evidence_sha256,
    }
}

fn trace_line(step: u64, state: &str, cause: &str, phase: &str, transition: &str) -> String {
    format!("tau={step}|state={state}|cause={cause}|phase={phase}|transition={transition}")
}

fn proof_json() -> (String, bool, String) {
    let payload = deterministic_payload();
    let payload_sha256 = sha256_hex(&payload);

    let scenarios = vec![
        committed_recovery_scenario(&payload),
        precommit_crash_scenario(&payload),
        model_uid_mismatch_scenario(&payload),
    ];

    let trace_source = [
        trace_line(0, "HBM_ONLY", "baseline", "save", "request_save"),
        trace_line(1, "HOST_BYTES_WRITTEN", "save", "persistence", "write_host"),
        trace_line(
            2,
            "METADATA_COMMITTED",
            "commit",
            "persistence",
            "publish_binding",
        ),
        trace_line(3, "CRASHED", "fault_injection", "recovery", "process_loss"),
        trace_line(
            4,
            "RECOVERY_CHECK",
            "restart",
            "recovery",
            "validate_identity_and_commit",
        ),
        trace_line(5, "VERIFIED", "invariants", "verification", "emit_proof"),
    ]
    .join("\n");

    let sealed = seal_trace(&trace_source);
    let trace_ok = verify_trace(&sealed).is_ok();
    let final_trace_hash = sealed
        .last()
        .map(|event| event.trace_hash.clone())
        .unwrap_or_default();

    let all_scenarios_pass = scenarios.iter().all(|scenario| scenario.passed);
    let verification_pass = trace_ok && all_scenarios_pass;

    let scenario_fingerprint = scenarios
        .iter()
        .map(|scenario| {
            format!(
                "{}:{}:{}:{}:{}:{}",
                scenario.id,
                scenario.phase,
                scenario.expected,
                scenario.observed.as_str(),
                scenario.invariant,
                scenario.evidence_sha256
            )
        })
        .collect::<Vec<_>>()
        .join("|");

    let proof_hash = sha256_hex(
        format!(
            "schema=capu.cvf.proof.v0|target={TARGET}|mode={MODE}|payload={payload_sha256}|trace={final_trace_hash}|scenarios={scenario_fingerprint}|verification={verification_pass}"
        )
        .as_bytes(),
    );

    let scenario_json = scenarios
        .iter()
        .map(|scenario| {
            format!(
                concat!(
                    "    {{\n",
                    "      \"id\": \"{}\",\n",
                    "      \"phase\": \"{}\",\n",
                    "      \"expected_recovery\": \"{}\",\n",
                    "      \"observed_recovery\": \"{}\",\n",
                    "      \"invariant\": \"{}\",\n",
                    "      \"passed\": {},\n",
                    "      \"evidence_sha256\": \"{}\"\n",
                    "    }}"
                ),
                scenario.id,
                scenario.phase,
                scenario.expected,
                scenario.observed.as_str(),
                scenario.invariant,
                scenario.passed,
                scenario.evidence_sha256
            )
        })
        .collect::<Vec<_>>()
        .join(",\n");

    let trace_json = sealed
        .iter()
        .enumerate()
        .map(|(index, event)| {
            format!(
                concat!(
                    "    {{\n",
                    "      \"index\": {},\n",
                    "      \"prev_hash\": \"{}\",\n",
                    "      \"event\": \"{}\",\n",
                    "      \"trace_hash\": \"{}\"\n",
                    "    }}"
                ),
                index, event.prev_hash, event.event, event.trace_hash
            )
        })
        .collect::<Vec<_>>()
        .join(",\n");

    let json = format!(
        concat!(
            "{{\n",
            "  \"schema\": \"capu.cvf.proof.v0\",\n",
            "  \"target\": \"{}\",\n",
            "  \"mode\": \"{}\",\n",
            "  \"claim_scope\": \"Repository-owned causal recovery model; this artifact does not claim execution of upstream Google TPU Raiden code.\",\n",
            "  \"tuple\": [\"state\", \"cause\", \"phase\", \"transition\", \"time\", \"recovery\", \"verification\", \"proof\"],\n",
            "  \"logical_time\": \"deterministic_ticks\",\n",
            "  \"payload_sha256\": \"{}\",\n",
            "  \"scenarios\": [\n{}\n  ],\n",
            "  \"trace\": [\n{}\n  ],\n",
            "  \"trace_chain_valid\": {},\n",
            "  \"final_trace_hash\": \"{}\",\n",
            "  \"verification\": \"{}\",\n",
            "  \"proof_sha256\": \"{}\"\n",
            "}}\n"
        ),
        TARGET,
        MODE,
        payload_sha256,
        scenario_json,
        trace_json,
        trace_ok,
        final_trace_hash,
        if verification_pass { "pass" } else { "fail" },
        proof_hash
    );

    (json, verification_pass, proof_hash)
}

fn main() {
    let output = env::args()
        .nth(1)
        .unwrap_or_else(|| "target/raiden-cpu-proof.json".to_string());

    let (json, passed, proof_hash) = proof_json();
    let path = Path::new(&output);
    if let Some(parent) = path.parent() {
        fs::create_dir_all(parent).expect("create proof output directory");
    }
    fs::write(path, json).expect("write proof artifact");

    println!(
        "Raiden CPU causal-recovery model proof: {}",
        if passed { "PASS" } else { "FAIL" }
    );
    println!("mode: {MODE}");
    println!("proof_sha256: {proof_hash}");
    println!("artifact: {}", path.display());

    if !passed {
        std::process::exit(1);
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn committed_binding_recovers_and_bytes_match() {
        let payload = deterministic_payload();
        let result = committed_recovery_scenario(&payload);
        assert!(result.passed);
        assert_eq!(result.observed, RecoveryClass::WarmRecovered);
    }

    #[test]
    fn crash_before_metadata_commit_fails_closed() {
        let payload = deterministic_payload();
        let result = precommit_crash_scenario(&payload);
        assert!(result.passed);
        assert_eq!(result.observed, RecoveryClass::ColdStart);
    }

    #[test]
    fn model_uid_mismatch_cold_starts() {
        let payload = deterministic_payload();
        let result = model_uid_mismatch_scenario(&payload);
        assert!(result.passed);
        assert_eq!(result.observed, RecoveryClass::ColdStart);
    }

    #[test]
    fn proof_is_deterministic_and_trace_is_valid() {
        let (first, first_pass, first_hash) = proof_json();
        let (second, second_pass, second_hash) = proof_json();
        assert!(first_pass && second_pass);
        assert_eq!(first_hash, second_hash);
        assert_eq!(first, second);
        assert!(first.contains("\"trace_chain_valid\": true"));
        assert!(first.contains("\"verification\": \"pass\""));
    }
}

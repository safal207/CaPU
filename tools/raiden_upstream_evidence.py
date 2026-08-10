#!/usr/bin/env python3
"""Convert a pinned upstream Raiden recovery run into a deterministic CaPU proof.

The adapter intentionally distinguishes direct CaPU observations from assertions
performed inside the upstream test harness. The upstream recovery test captures
its child-process markers itself; therefore a successful Bazel target is treated
as evidence that the pinned upstream test contract passed, not as if CaPU had
observed those markers directly.
"""

from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path
import sys

GENESIS_SHA256 = "0" * 64
SCHEMA = "capu.cvf.proof.v0"
TARGET = "google/tpu-raiden"
MODE = "upstream-jax-cpu-bazel"

REQUIRED_CONTRACT_SNIPPETS = {
    "phase_a_saved_marker": 'PHASE_A_SAVED',
    "phase_b_recovered_marker": 'PHASE_B_RECOVERED',
    "phase_b_cold_marker": 'PHASE_B_COLD',
    "phase_b_bytes_match_marker": 'PHASE_B_BYTES_MATCH',
    "sigkill_crash": 'os.kill(os.getpid(), _SIGKILL)',
    "phase_a_sigkill_assertion": 'result.returncode,\n        -_SIGKILL',
    "recovery_test": 'def test_recovers_saved_blocks_after_crash(self):',
    "uid_mismatch_test": 'def test_model_uid_mismatch_cold_starts(self):',
    "recovered_marker_assertion": 'self.assertIn(_PHASE_B_RECOVERED_MARKER, result.stdout)',
    "bytes_marker_assertion": 'self.assertIn(_PHASE_B_BYTES_MARKER, result.stdout)',
    "cold_marker_assertion": 'self.assertIn(_PHASE_B_COLD_MARKER, result.stdout)',
}


def sha256_bytes(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def seal_trace(events: list[str]) -> list[dict[str, str]]:
    prev_hash = GENESIS_SHA256
    sealed: list[dict[str, str]] = []
    for event in events:
        trace_hash = sha256_bytes(f"{prev_hash}{event}".encode())
        sealed.append(
            {
                "prev_hash": prev_hash,
                "event": event,
                "trace_hash": trace_hash,
            }
        )
        prev_hash = trace_hash
    return sealed


def verify_trace(trace: list[dict[str, str]]) -> bool:
    prev_hash = GENESIS_SHA256
    for event in trace:
        if event["prev_hash"] != prev_hash:
            return False
        expected = sha256_bytes(f"{prev_hash}{event['event']}".encode())
        if event["trace_hash"] != expected:
            return False
        prev_hash = event["trace_hash"]
    return True


def inspect_contract(source: str) -> dict[str, bool]:
    return {
        name: snippet in source
        for name, snippet in REQUIRED_CONTRACT_SNIPPETS.items()
    }


def build_proof(
    *,
    log_bytes: bytes,
    source_bytes: bytes,
    upstream_sha: str,
    bazel_version: str,
    bazel_target: str,
    bazel_exit_code: int,
) -> dict:
    source = source_bytes.decode("utf-8")
    contract = inspect_contract(source)
    contract_valid = all(contract.values())
    target_passed = bazel_exit_code == 0

    recovery_passed = target_passed and all(
        contract[name]
        for name in (
            "phase_a_saved_marker",
            "phase_b_recovered_marker",
            "phase_b_bytes_match_marker",
            "sigkill_crash",
            "phase_a_sigkill_assertion",
            "recovery_test",
            "recovered_marker_assertion",
            "bytes_marker_assertion",
        )
    )
    mismatch_passed = target_passed and all(
        contract[name]
        for name in (
            "phase_a_saved_marker",
            "phase_b_cold_marker",
            "sigkill_crash",
            "phase_a_sigkill_assertion",
            "uid_mismatch_test",
            "cold_marker_assertion",
        )
    )

    log_sha256 = sha256_bytes(log_bytes)
    source_sha256 = sha256_bytes(source_bytes)

    scenarios = [
        {
            "id": "RDN-UP-001",
            "invariant": "RDN-INV-003+004",
            "claim": "A process killed by SIGKILL after save restarts, recovers host-resident KV blocks, and verifies byte equality.",
            "observation_basis": "Pinned upstream test assertions; subprocess markers are captured and checked by the upstream parent test.",
            "passed": recovery_passed,
        },
        {
            "id": "RDN-UP-002",
            "invariant": "RDN-INV-002",
            "claim": "A restart under a different model UID cold-starts instead of resurrecting incompatible persisted state.",
            "observation_basis": "Pinned upstream test assertions; the upstream parent test requires the cold-start marker.",
            "passed": mismatch_passed,
        },
    ]

    verification_passed = contract_valid and target_passed and all(
        scenario["passed"] for scenario in scenarios
    )

    events = [
        f"tau=0|state=UPSTREAM_PINNED|cause=checkout|phase=provenance|transition=sha:{upstream_sha}|source_sha256={source_sha256}",
        f"tau=1|state=OSS_CONFIGURED|cause=bazel|phase=execution|transition=version:{bazel_version}|target={bazel_target}",
        f"tau=2|state=TARGET_EXITED|cause=upstream_test|phase=verification|transition=exit:{bazel_exit_code}|log_sha256={log_sha256}",
        f"tau=3|state=RECOVERY_ASSERTED|cause=upstream_contract|phase=recovery|transition={'pass' if recovery_passed else 'fail'}",
        f"tau=4|state=IDENTITY_ASSERTED|cause=upstream_contract|phase=recovery|transition={'pass' if mismatch_passed else 'fail'}",
        f"tau=5|state=VERIFIED|cause=capu_adapter|phase=proof|transition={'pass' if verification_passed else 'fail'}",
    ]
    trace = seal_trace(events)
    trace_valid = verify_trace(trace)

    proof = {
        "schema": SCHEMA,
        "target": TARGET,
        "mode": MODE,
        "claim_scope": (
            "Execution evidence for the pinned upstream Google TPU Raiden JAX "
            "recovery E2E target on a CPU runner. CaPU does not claim direct "
            "observation of child-process markers captured by the upstream harness."
        ),
        "tuple": [
            "state",
            "cause",
            "phase",
            "transition",
            "time",
            "recovery",
            "verification",
            "proof",
        ],
        "logical_time": "deterministic_ticks",
        "upstream": {
            "repository": TARGET,
            "sha": upstream_sha,
            "source_sha256": source_sha256,
            "bazel_version": bazel_version,
            "bazel_target": bazel_target,
            "bazel_exit_code": bazel_exit_code,
            "bazel_log_sha256": log_sha256,
        },
        "contract_checks": contract,
        "scenarios": scenarios,
        "trace": trace,
        "trace_chain_valid": trace_valid,
        "final_trace_hash": trace[-1]["trace_hash"],
        "verification": "pass" if verification_passed and trace_valid else "fail",
    }

    canonical = json.dumps(proof, sort_keys=True, separators=(",", ":")).encode()
    proof["proof_sha256"] = sha256_bytes(canonical)
    return proof


def self_test() -> int:
    source = "\n".join(REQUIRED_CONTRACT_SNIPPETS.values()).encode()
    kwargs = dict(
        log_bytes=b"PASSED\n",
        source_bytes=source,
        upstream_sha="a" * 40,
        bazel_version="8.6.0",
        bazel_target="//tpu_raiden/api/jax:kv_cache_store_recovery_e2e_test",
        bazel_exit_code=0,
    )
    first = build_proof(**kwargs)
    second = build_proof(**kwargs)
    assert first == second
    assert first["verification"] == "pass"
    assert first["trace_chain_valid"] is True

    failed = build_proof(**{**kwargs, "bazel_exit_code": 1})
    assert failed["verification"] == "fail"
    return 0


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument("--self-test", action="store_true")
    parser.add_argument("--log")
    parser.add_argument("--source")
    parser.add_argument("--upstream-sha")
    parser.add_argument("--bazel-version")
    parser.add_argument("--bazel-target")
    parser.add_argument("--bazel-exit-code", type=int)
    parser.add_argument("--output")
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    if args.self_test:
        return self_test()

    required = (
        "log",
        "source",
        "upstream_sha",
        "bazel_version",
        "bazel_target",
        "bazel_exit_code",
        "output",
    )
    missing = [name for name in required if getattr(args, name) is None]
    if missing:
        raise SystemExit(f"missing required arguments: {', '.join(missing)}")

    proof = build_proof(
        log_bytes=Path(args.log).read_bytes(),
        source_bytes=Path(args.source).read_bytes(),
        upstream_sha=args.upstream_sha,
        bazel_version=args.bazel_version,
        bazel_target=args.bazel_target,
        bazel_exit_code=args.bazel_exit_code,
    )
    output = Path(args.output)
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text(json.dumps(proof, indent=2, sort_keys=True) + "\n")

    print("Raiden upstream CaPU proof:", proof["verification"].upper())
    print("proof_sha256:", proof["proof_sha256"])
    print("final_trace_hash:", proof["final_trace_hash"])
    print("artifact:", output)
    return 0 if proof["verification"] == "pass" else 1


if __name__ == "__main__":
    sys.exit(main())

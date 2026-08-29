#!/usr/bin/env python3
"""Seal pinned upstream Raiden CPU recovery-primitives into a CaPU proof.

The pinned Raiden JAX recovery E2E enters TPU-oriented PjRt buffer plumbing and
is not a hardware-independent CPU contract. This adapter deliberately proves
the two official CPU-safe layers below it instead: persistent shared-memory
bytes/schema handling and persistent KV metadata/model-identity handling.
The separate CaPU recovery probe supplies the process-crash/SIGKILL evidence.
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
MODE = "upstream-cpu-recovery-primitives-bazel"

REQUIRED_CONTRACT_SNIPPETS = {
    "shared_memory_warm_boot_test": (
        "TEST(RaidenHostMemoryAllocatorCpuAdapterTest, "
        "SharedMemoryColdAndWarmBoot)"
    ),
    "persisted_bytes_written": "std::memset(alloc1.ptr, 0x55, 1024);",
    "persisted_bytes_recovered": "ASSERT_EQ(alloc2.ptr[i], 0x55);",
    "schema_mismatch_changes_version": "schema2.version = 2;",
    "schema_mismatch_cold_bytes": "ASSERT_EQ(alloc3.ptr[i], 0);",
    "metadata_restart_test": (
        "TEST_F(KVCacheStoreWrapperTest, RecoversHostBlocksAfterRestart)"
    ),
    "metadata_restart_boundary": "wrapper.reset();",
    "model_uid_mismatch_test": (
        "TEST_F(KVCacheStoreWrapperTest, ModelUidMismatchColdStarts)"
    ),
    "model_uid_changes": (
        'setenv("RAIDEN_SHM_MODEL_UID", "model_b", /*overwrite=*/1);'
    ),
    "incompatible_metadata_absent": "EXPECT_THAT(*lookup_or, IsEmpty());",
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
    source_blobs: dict[str, bytes],
    upstream_sha: str,
    bazel_version: str,
    bazel_targets: list[str],
    bazel_exit_code: int,
) -> dict:
    combined_source = "\n".join(
        source.decode("utf-8") for source in source_blobs.values()
    )
    contract = inspect_contract(combined_source)
    contract_valid = all(contract.values())
    target_labels_observed = {
        target: target.encode() in log_bytes for target in bazel_targets
    }
    targets_passed = (
        bazel_exit_code == 0
        and bool(bazel_targets)
        and all(target_labels_observed.values())
    )

    data_recovery_passed = targets_passed and all(
        contract[name]
        for name in (
            "shared_memory_warm_boot_test",
            "persisted_bytes_written",
            "persisted_bytes_recovered",
            "schema_mismatch_changes_version",
            "schema_mismatch_cold_bytes",
        )
    )
    metadata_recovery_passed = targets_passed and all(
        contract[name]
        for name in (
            "metadata_restart_test",
            "metadata_restart_boundary",
            "model_uid_mismatch_test",
            "model_uid_changes",
            "incompatible_metadata_absent",
        )
    )

    log_sha256 = sha256_bytes(log_bytes)
    source_hashes = {
        path: sha256_bytes(source) for path, source in source_blobs.items()
    }

    scenarios = [
        {
            "id": "RDN-UP-PRIM-001",
            "invariant": "RDN-INV-004+006",
            "claim": (
                "The pinned upstream allocator reattaches compatible shared "
                "memory with identical bytes and clears bytes after a schema "
                "mismatch."
            ),
            "observation_basis": (
                "CaPU CPU-adapter assertions executed against the pinned, "
                "unmodified upstream allocator implementation by Bazel."
            ),
            "passed": data_recovery_passed,
        },
        {
            "id": "RDN-UP-PRIM-002",
            "invariant": "RDN-INV-002+003",
            "claim": (
                "The pinned upstream KV metadata wrapper rebuilds host block "
                "bindings after restart and cold-starts after model UID mismatch."
            ),
            "observation_basis": (
                "Pinned upstream C++ assertions executed by Bazel on a CPU runner."
            ),
            "passed": metadata_recovery_passed,
        },
    ]

    verification_passed = contract_valid and targets_passed and all(
        scenario["passed"] for scenario in scenarios
    )

    sources_json = json.dumps(source_hashes, sort_keys=True, separators=(",", ":"))
    targets_json = json.dumps(bazel_targets, separators=(",", ":"))
    events = [
        f"tau=0|state=UPSTREAM_PINNED|cause=checkout|phase=provenance|transition=sha:{upstream_sha}|sources={sources_json}",
        f"tau=1|state=CPU_PRIMITIVES_CONFIGURED|cause=bazel|phase=execution|transition=version:{bazel_version}|targets={targets_json}",
        f"tau=2|state=TARGETS_EXITED|cause=upstream_tests|phase=verification|transition=exit:{bazel_exit_code}|log_sha256={log_sha256}",
        f"tau=3|state=DATA_RECOVERY_ASSERTED|cause=upstream_contract|phase=recovery|transition={'pass' if data_recovery_passed else 'fail'}",
        f"tau=4|state=METADATA_RECOVERY_ASSERTED|cause=upstream_contract|phase=recovery|transition={'pass' if metadata_recovery_passed else 'fail'}",
        f"tau=5|state=VERIFIED|cause=capu_adapter|phase=proof|transition={'pass' if verification_passed else 'fail'}",
    ]
    trace = seal_trace(events)
    trace_valid = verify_trace(trace)

    proof = {
        "schema": SCHEMA,
        "target": TARGET,
        "mode": MODE,
        "claim_scope": (
            "Execution evidence from a CaPU CPU adapter against the pinned upstream "
            "shared-memory allocator and the official upstream KV metadata/model "
            "identity test. This proof does not claim execution of the JAX "
            "device-transfer E2E or direct observation of SIGKILL."
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
            "sources": source_hashes,
            "bazel_version": bazel_version,
            "bazel_targets": bazel_targets,
            "target_labels_observed": target_labels_observed,
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
    targets = [
        "//tpu_raiden/core:host_memory_allocator_cpu_test",
        "//tpu_raiden/kv_cache:kv_cache_store_wrapper_test",
    ]
    kwargs = dict(
        log_bytes=("PASSED\n" + "\n".join(targets)).encode(),
        source_blobs={"allocator.cc": source, "wrapper.cc": source},
        upstream_sha="a" * 40,
        bazel_version="8.6.0",
        bazel_targets=targets,
        bazel_exit_code=0,
    )
    first = build_proof(**kwargs)
    second = build_proof(**kwargs)
    assert first == second
    assert first["verification"] == "pass"
    assert first["trace_chain_valid"] is True

    failed = build_proof(**{**kwargs, "bazel_exit_code": 1})
    assert failed["verification"] == "fail"
    missing_target = build_proof(**{**kwargs, "log_bytes": b"PASSED\n"})
    assert missing_target["verification"] == "fail"
    return 0


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument("--self-test", action="store_true")
    parser.add_argument("--log")
    parser.add_argument("--source", action="append")
    parser.add_argument("--upstream-sha")
    parser.add_argument("--bazel-version")
    parser.add_argument("--bazel-target", action="append")
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
        source_blobs={path: Path(path).read_bytes() for path in args.source},
        upstream_sha=args.upstream_sha,
        bazel_version=args.bazel_version,
        bazel_targets=args.bazel_target,
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

from __future__ import annotations

import json
import sys
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

from tools.astra_capu_crash_benchmark_a2 import (  # noqa: E402
    DEFAULT_SCENARIOS,
    UnsafePolicy,
    run_benchmark,
    run_capu,
    run_unsafe,
)


class CrashBenchmarkA2Tests(unittest.TestCase):
    def test_default_report_hits_expected_discriminating_boundary(self) -> None:
        report = run_benchmark()
        self.assertEqual(report.unsafe_duplicate_effects, 2)
        self.assertEqual(report.capu_duplicate_effects, 0)
        self.assertEqual(report.unsafe_false_successes, 1)
        self.assertEqual(report.capu_false_successes, 0)
        self.assertEqual(report.capu_unknown_blocks, 4)
        self.assertEqual(report.capu_sealed_successes, 3)
        self.assertEqual(report.capu_conflict_fail_closed, 1)

    def test_unsafe_post_commit_missing_receipt_duplicates_effect(self) -> None:
        scenario = next(
            s for s in DEFAULT_SCENARIOS if s.name == "crash_after_effect_before_receipt"
        )
        result = run_unsafe(scenario)
        self.assertEqual(result.committed_effects, 2)
        self.assertEqual(result.duplicate_effects, 1)
        self.assertTrue(result.claimed_success)

    def test_capu_post_commit_missing_receipt_does_not_retry(self) -> None:
        scenario = next(
            s for s in DEFAULT_SCENARIOS if s.name == "crash_after_effect_before_receipt"
        )
        result = run_capu(scenario)
        self.assertEqual(result.committed_effects, 1)
        self.assertEqual(result.duplicate_effects, 0)
        self.assertEqual(result.retries, 0)
        self.assertTrue(result.sealed)
        self.assertEqual(result.final_stage, "SEALED")

    def test_unsafe_dispatch_ack_creates_false_success(self) -> None:
        scenario = next(
            s for s in DEFAULT_SCENARIOS if s.name == "dispatch_ack_false_success"
        )
        self.assertIs(scenario.unsafe_policy, UnsafePolicy.DISPATCH_ACK_IS_SUCCESS)
        result = run_unsafe(scenario)
        self.assertEqual(result.committed_effects, 0)
        self.assertEqual(result.false_successes, 1)
        self.assertTrue(result.claimed_success)

    def test_capu_dispatch_ack_requires_evidence_then_exact_retry(self) -> None:
        scenario = next(
            s for s in DEFAULT_SCENARIOS if s.name == "dispatch_ack_false_success"
        )
        result = run_capu(scenario)
        self.assertEqual(result.unknown_blocks, 1)
        self.assertEqual(result.retries, 1)
        self.assertEqual(result.committed_effects, 1)
        self.assertEqual(result.false_successes, 0)
        self.assertTrue(result.sealed)

    def test_pre_commit_crash_uses_one_authorized_retry(self) -> None:
        scenario = next(
            s for s in DEFAULT_SCENARIOS if s.name == "crash_before_external_effect"
        )
        result = run_capu(scenario)
        self.assertEqual(result.retries, 1)
        self.assertEqual(result.committed_effects, 1)
        self.assertEqual(result.duplicate_effects, 0)
        self.assertEqual(
            result.decision,
            "EXACT_NEGATIVE_EVIDENCE_THEN_ONE_AUTHORIZED_RETRY",
        )

    def test_conflicting_readback_is_fail_closed(self) -> None:
        scenario = next(
            s for s in DEFAULT_SCENARIOS if s.name == "conflicting_readback"
        )
        result = run_capu(scenario)
        self.assertEqual(result.committed_effects, 1)
        self.assertEqual(result.retries, 0)
        self.assertFalse(result.claimed_success)
        self.assertFalse(result.sealed)
        self.assertEqual(result.final_stage, "CONFLICT")

    def test_every_capu_crash_path_reconstructs_unknown(self) -> None:
        for scenario in DEFAULT_SCENARIOS:
            with self.subTest(scenario=scenario.name):
                self.assertEqual(run_capu(scenario).unknown_blocks, 1)

    def test_benchmark_is_deterministic(self) -> None:
        first = run_benchmark()
        second = run_benchmark()
        self.assertEqual(first, second)
        self.assertEqual(first.digest, second.digest)
        self.assertEqual(len(first.digest), 64)

    def test_json_report_round_trip(self) -> None:
        report = run_benchmark()
        payload = json.loads(report.to_json())
        self.assertEqual(payload["schema"], "capu.hardware.accelerator-crash-benchmark.v1.0-a2")
        self.assertEqual(payload["unsafe_duplicate_effects"], 2)
        self.assertEqual(payload["capu_duplicate_effects"], 0)
        self.assertEqual(payload["benchmark_digest_sha256"], report.digest)

    def test_expected_fixture_matches_executable_report(self) -> None:
        expected = json.loads(
            (ROOT / "examples/hardware/astra-capu-v1-a2-expected.json").read_text()
        )
        report = run_benchmark()
        self.assertEqual(expected["expected"]["unsafe_duplicate_effects"], report.unsafe_duplicate_effects)
        self.assertEqual(expected["expected"]["capu_duplicate_effects"], report.capu_duplicate_effects)
        self.assertEqual(expected["expected"]["unsafe_false_successes"], report.unsafe_false_successes)
        self.assertEqual(expected["expected"]["capu_false_successes"], report.capu_false_successes)
        self.assertEqual(expected["expected"]["capu_unknown_blocks"], report.capu_unknown_blocks)
        self.assertEqual(expected["expected"]["capu_conflict_fail_closed"], report.capu_conflict_fail_closed)


if __name__ == "__main__":
    unittest.main(verbosity=2)

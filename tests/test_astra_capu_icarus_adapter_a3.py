from __future__ import annotations

import json
import os
import sys
import unittest
from pathlib import Path
from tempfile import TemporaryDirectory

ROOT = Path(__file__).resolve().parents[1]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

from tools.astra_capu_icarus_adapter_a3 import (  # noqa: E402
    IcarusDeviceAdapter,
    run_benchmark,
)


class IcarusAdapterA3Tests(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        simulator = os.environ.get("A3_SIMULATOR")
        if not simulator:
            raise unittest.SkipTest("A3_SIMULATOR is required for hardware-simulator tests")
        cls.simulator = Path(simulator)
        if not cls.simulator.exists():
            raise RuntimeError(f"missing simulator: {cls.simulator}")

    def test_durable_effect_count_survives_new_vvp_process(self) -> None:
        with TemporaryDirectory() as tmp:
            adapter = IcarusDeviceAdapter(self.simulator, Path(tmp) / "device.state")
            adapter.reset()
            first = adapter.dispatch(commit=True, drop_receipt=True)
            readback = adapter.readback()
            self.assertEqual(first.count, 1)
            self.assertEqual(first.receipt, 0)
            self.assertEqual(readback.count, 1)
            self.assertEqual(adapter.launches, 3)

    def test_second_process_dispatch_exposes_real_duplicate(self) -> None:
        with TemporaryDirectory() as tmp:
            adapter = IcarusDeviceAdapter(self.simulator, Path(tmp) / "device.state")
            adapter.reset()
            adapter.dispatch(commit=True, drop_receipt=True)
            retry = adapter.dispatch(commit=True, drop_receipt=False)
            readback = adapter.readback()
            self.assertEqual(retry.receipt, 1)
            self.assertEqual(readback.count, 2)

    def test_noncommitting_dispatch_accepts_without_effect_or_receipt(self) -> None:
        with TemporaryDirectory() as tmp:
            adapter = IcarusDeviceAdapter(self.simulator, Path(tmp) / "device.state")
            adapter.reset()
            event = adapter.dispatch(commit=False, drop_receipt=False)
            readback = adapter.readback()
            self.assertEqual(event.accept, 1)
            self.assertEqual(event.committed, 0)
            self.assertEqual(event.receipt, 0)
            self.assertEqual(readback.count, 0)

    def test_full_benchmark_has_expected_discriminator(self) -> None:
        with TemporaryDirectory() as tmp:
            report = run_benchmark(self.simulator, Path(tmp))
            self.assertTrue(report.persistent_state_restart_verified)
            self.assertEqual(report.unsafe_duplicate_effects, 1)
            self.assertEqual(report.capu_duplicate_effects, 0)
            self.assertEqual(report.unsafe_false_successes, 1)
            self.assertEqual(report.capu_false_successes, 0)
            self.assertEqual(report.capu_unknown_recoveries, 2)
            self.assertEqual(report.capu_authorized_retries, 1)
            self.assertEqual(report.capu_sealed_successes, 2)

    def test_full_benchmark_uses_separate_processes(self) -> None:
        with TemporaryDirectory() as tmp:
            report = run_benchmark(self.simulator, Path(tmp))
            self.assertEqual(report.simulator_process_launches, 15)
            self.assertEqual(report.unsafe_duplicate_final_count, 2)
            self.assertEqual(report.capu_committed_final_count, 1)
            self.assertEqual(report.unsafe_false_success_final_count, 0)
            self.assertEqual(report.capu_negative_retry_final_count, 1)

    def test_benchmark_is_deterministic_across_fresh_state_directories(self) -> None:
        with TemporaryDirectory() as first_tmp, TemporaryDirectory() as second_tmp:
            first = run_benchmark(self.simulator, Path(first_tmp))
            second = run_benchmark(self.simulator, Path(second_tmp))
            self.assertEqual(first, second)
            self.assertEqual(first.digest, second.digest)
            self.assertEqual(len(first.digest), 64)

    def test_machine_result_round_trip(self) -> None:
        with TemporaryDirectory() as tmp:
            report = run_benchmark(self.simulator, Path(tmp))
            payload = json.loads(report.to_json())
            self.assertEqual(
                payload["schema"],
                "capu.hardware.icarus-device-adapter-benchmark.v1.0-a3",
            )
            self.assertEqual(payload["unsafe_duplicate_effects"], 1)
            self.assertEqual(payload["capu_duplicate_effects"], 0)
            self.assertEqual(payload["benchmark_digest_sha256"], report.digest)

    def test_reset_starts_a_new_empty_device_state(self) -> None:
        with TemporaryDirectory() as tmp:
            adapter = IcarusDeviceAdapter(self.simulator, Path(tmp) / "device.state")
            adapter.dispatch(commit=True, drop_receipt=False)
            self.assertEqual(adapter.readback().count, 1)
            adapter.reset()
            self.assertEqual(adapter.readback().count, 0)


if __name__ == "__main__":
    unittest.main(verbosity=2)

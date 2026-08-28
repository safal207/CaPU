from __future__ import annotations

import argparse
import json
import subprocess
from dataclasses import asdict, dataclass
from pathlib import Path
from tempfile import TemporaryDirectory
from typing import Any

from tools.astra_capu_crash_benchmark_a2 import (
    CrashScenario,
    UnsafePolicy,
    authority_ticket,
    outcome_evidence,
)
from tools.astra_capu_effect_authority_a1 import Outcome, Stage, canonical_digest, recover


@dataclass(frozen=True)
class DeviceEvent:
    op: str
    count: int
    accept: int = 0
    committed: int = 0
    receipt: int = 0


@dataclass(frozen=True)
class A3BenchmarkReport:
    schema: str
    simulator: str
    simulator_process_launches: int
    persistent_state_restart_verified: bool
    unsafe_duplicate_effects: int
    capu_duplicate_effects: int
    unsafe_false_successes: int
    capu_false_successes: int
    capu_unknown_recoveries: int
    capu_authorized_retries: int
    capu_sealed_successes: int
    unsafe_duplicate_final_count: int
    capu_committed_final_count: int
    unsafe_false_success_final_count: int
    capu_negative_retry_final_count: int

    @property
    def digest(self) -> str:
        return canonical_digest(asdict(self))

    def validate_expected_boundary(self) -> None:
        if not self.persistent_state_restart_verified:
            raise AssertionError("device state did not survive a simulator process restart")
        if self.unsafe_duplicate_effects != 1:
            raise AssertionError("unsafe process-restart path must produce one duplicate")
        if self.capu_duplicate_effects != 0:
            raise AssertionError("CaPU process-restart path duplicated an effect")
        if self.unsafe_false_successes != 1:
            raise AssertionError("unsafe dispatch-ack path must produce one false success")
        if self.capu_false_successes != 0:
            raise AssertionError("CaPU path reported false success")
        if self.capu_unknown_recoveries != 2:
            raise AssertionError("both CaPU crash paths must reconstruct UNKNOWN")
        if self.capu_authorized_retries != 1:
            raise AssertionError("only exact negative evidence may authorize one retry")
        if self.capu_sealed_successes != 2:
            raise AssertionError("both resolvable CaPU paths must seal")

    def to_json(self) -> str:
        payload = asdict(self)
        payload["benchmark_digest_sha256"] = self.digest
        return json.dumps(payload, indent=2, sort_keys=True) + "\n"


class IcarusDeviceAdapter:
    """Host adapter for a separately launched Icarus device process.

    The simulator persists its external effect counter in `state_file`. Every
    adapter method launches a fresh `vvp` process, so a later readback is not an
    in-process observation of the earlier dispatch.
    """

    def __init__(self, simulator: Path, state_file: Path) -> None:
        self.simulator = Path(simulator)
        self.state_file = Path(state_file)
        self.launches = 0

    def _invoke(
        self,
        op: str,
        *,
        commit: bool = False,
        drop_receipt: bool = False,
    ) -> DeviceEvent:
        command = [
            "vvp",
            str(self.simulator),
            f"+OP={op}",
            f"+STATE_FILE={self.state_file}",
            f"+COMMIT={int(commit)}",
            f"+DROP_RECEIPT={int(drop_receipt)}",
        ]
        result = subprocess.run(
            command,
            check=True,
            capture_output=True,
            text=True,
        )
        self.launches += 1
        if "ASTRA_CAPU_V1_A3_ICARUS_DEVICE_PASS" not in result.stdout:
            raise RuntimeError(f"simulator pass marker missing:\n{result.stdout}\n{result.stderr}")

        event_line = next(
            (line for line in result.stdout.splitlines() if line.startswith("A3_EVENT ")),
            None,
        )
        if event_line is None:
            raise RuntimeError(f"simulator event missing:\n{result.stdout}")

        fields: dict[str, str] = {}
        for token in event_line.split()[1:]:
            key, value = token.split("=", 1)
            fields[key] = value

        return DeviceEvent(
            op=fields["op"],
            count=int(fields["count"]),
            accept=int(fields.get("accept", "0")),
            committed=int(fields.get("committed", "0")),
            receipt=int(fields.get("receipt", "0")),
        )

    def reset(self) -> DeviceEvent:
        return self._invoke("reset")

    def dispatch(self, *, commit: bool, drop_receipt: bool) -> DeviceEvent:
        return self._invoke(
            "dispatch",
            commit=commit,
            drop_receipt=drop_receipt,
        )

    def readback(self) -> DeviceEvent:
        return self._invoke("readback")


def compile_simulator(repo_root: Path, output: Path) -> None:
    subprocess.run(
        [
            "iverilog",
            "-g2012",
            "-o",
            str(output),
            "rtl/astra_capu_effect_counter_a3.sv",
            "rtl/tb/astra_capu_effect_counter_a3_tb.sv",
        ],
        cwd=repo_root,
        check=True,
    )


def _scenario(name: str) -> CrashScenario:
    return CrashScenario(
        name=name,
        initial_device_commit=False,
        unsafe_policy=UnsafePolicy.BLIND_RETRY,
    )


def run_benchmark(simulator: Path, workdir: Path) -> A3BenchmarkReport:
    workdir.mkdir(parents=True, exist_ok=True)

    # Unsafe: the first device process commits but drops the receipt. A second
    # process blindly retries, proving that durable external state survived the
    # restart and the repeated command is a real duplicate.
    unsafe_duplicate = IcarusDeviceAdapter(
        simulator,
        workdir / "unsafe-duplicate.state",
    )
    unsafe_duplicate.reset()
    first_unsafe = unsafe_duplicate.dispatch(commit=True, drop_receipt=True)
    second_unsafe = unsafe_duplicate.dispatch(commit=True, drop_receipt=False)
    unsafe_duplicate_readback = unsafe_duplicate.readback()
    if first_unsafe.receipt != 0 or second_unsafe.receipt != 1:
        raise AssertionError("unsafe receipt injection did not follow the requested boundary")

    # CaPU: same commit/drop/restart sequence, but the durable A1 issue witness
    # reconstructs UNKNOWN and a fresh simulator process reads back count=1.
    capu_committed = IcarusDeviceAdapter(
        simulator,
        workdir / "capu-committed.state",
    )
    capu_committed.reset()
    committed_scenario = _scenario("a3_process_restart_committed")
    pre_dispatch = authority_ticket(committed_scenario)
    durable_dispatched = pre_dispatch.dispatch()
    dropped = capu_committed.dispatch(commit=True, drop_receipt=True)
    recovered = recover(pre_dispatch, durable_dispatched)
    if not recovered.outcome_unknown or dropped.receipt != 0:
        raise AssertionError("A1 UNKNOWN recovery was not established")
    committed_readback = capu_committed.readback()
    committed_outcome = (
        Outcome.COMMITTED if committed_readback.count > 0 else Outcome.NOT_COMMITTED
    )
    committed_sealed = recovered.reconcile(
        outcome_evidence(
            recovered,
            committed_outcome,
            source="icarus-process-restart-readback",
        )
    ).retire_and_seal()

    # Unsafe false success: the simulator accepts dispatch but does not commit.
    unsafe_false = IcarusDeviceAdapter(
        simulator,
        workdir / "unsafe-false-success.state",
    )
    unsafe_false.reset()
    unsafe_ack = unsafe_false.dispatch(commit=False, drop_receipt=False)
    unsafe_false_readback = unsafe_false.readback()
    unsafe_claimed_success = unsafe_ack.accept == 1

    # CaPU negative path: process restart reveals count=0, exact negative
    # evidence authorizes one new attempt, and a later process readback seals 1.
    capu_negative = IcarusDeviceAdapter(
        simulator,
        workdir / "capu-negative.state",
    )
    capu_negative.reset()
    negative_scenario = _scenario("a3_process_restart_not_committed")
    negative_pre_dispatch = authority_ticket(negative_scenario)
    negative_durable = negative_pre_dispatch.dispatch()
    capu_negative.dispatch(commit=False, drop_receipt=True)
    negative_recovered = recover(negative_pre_dispatch, negative_durable)
    if not negative_recovered.outcome_unknown:
        raise AssertionError("negative crash path did not reconstruct UNKNOWN")
    negative_readback = capu_negative.readback()
    negative_outcome = (
        Outcome.COMMITTED if negative_readback.count > 0 else Outcome.NOT_COMMITTED
    )
    negative_reconciled = negative_recovered.reconcile(
        outcome_evidence(
            negative_recovered,
            negative_outcome,
            source="icarus-process-restart-readback",
        )
    )
    retry_committed = negative_reconciled.begin_retry()
    retry_dispatched = retry_committed.dispatch()
    retry_device_event = capu_negative.dispatch(commit=True, drop_receipt=False)
    retry_readback = capu_negative.readback()
    retry_outcome = Outcome.COMMITTED if retry_readback.count > 0 else Outcome.NOT_COMMITTED
    negative_sealed = retry_dispatched.reconcile(
        outcome_evidence(
            retry_dispatched,
            retry_outcome,
            source="icarus-process-restart-readback-after-retry",
        )
    ).retire_and_seal()

    launches = (
        unsafe_duplicate.launches
        + capu_committed.launches
        + unsafe_false.launches
        + capu_negative.launches
    )
    report = A3BenchmarkReport(
        schema="capu.hardware.icarus-device-adapter-benchmark.v1.0-a3",
        simulator="Icarus Verilog separate-process durable effect counter",
        simulator_process_launches=launches,
        persistent_state_restart_verified=(
            first_unsafe.count == 1
            and unsafe_duplicate_readback.count == 2
            and committed_readback.count == 1
        ),
        unsafe_duplicate_effects=max(0, unsafe_duplicate_readback.count - 1),
        capu_duplicate_effects=max(0, committed_readback.count - 1),
        unsafe_false_successes=int(
            unsafe_claimed_success and unsafe_false_readback.count == 0
        ),
        capu_false_successes=int(
            negative_sealed.stage is Stage.SEALED and retry_readback.count == 0
        ),
        capu_unknown_recoveries=2,
        capu_authorized_retries=1,
        capu_sealed_successes=int(committed_sealed.stage is Stage.SEALED)
        + int(negative_sealed.stage is Stage.SEALED),
        unsafe_duplicate_final_count=unsafe_duplicate_readback.count,
        capu_committed_final_count=committed_readback.count,
        unsafe_false_success_final_count=unsafe_false_readback.count,
        capu_negative_retry_final_count=retry_readback.count,
    )
    if retry_device_event.receipt != 1:
        raise AssertionError("authorized retry did not produce a visible completion receipt")
    report.validate_expected_boundary()
    return report


def _parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument("--simulator", type=Path)
    parser.add_argument("--repo-root", type=Path, default=Path.cwd())
    parser.add_argument("--workdir", type=Path)
    return parser.parse_args()


def main() -> None:
    args = _parse_args()
    with TemporaryDirectory(prefix="astra-capu-a3-") as tmp:
        temporary = Path(tmp)
        simulator = args.simulator or temporary / "astra-capu-a3.vvp"
        if args.simulator is None:
            compile_simulator(args.repo_root, simulator)
        workdir = args.workdir or temporary / "device-state"
        report = run_benchmark(simulator, workdir)
        print(
            "a3_summary",
            f"simulator_process_launches={report.simulator_process_launches}",
            f"persistent_restart={int(report.persistent_state_restart_verified)}",
            f"unsafe_duplicates={report.unsafe_duplicate_effects}",
            f"capu_duplicates={report.capu_duplicate_effects}",
            f"unsafe_false_success={report.unsafe_false_successes}",
            f"capu_false_success={report.capu_false_successes}",
            f"capu_unknown_recoveries={report.capu_unknown_recoveries}",
            f"capu_authorized_retries={report.capu_authorized_retries}",
            f"capu_sealed_successes={report.capu_sealed_successes}",
        )
        print(
            "a3_counts",
            f"unsafe_duplicate_final={report.unsafe_duplicate_final_count}",
            f"capu_committed_final={report.capu_committed_final_count}",
            f"unsafe_false_success_final={report.unsafe_false_success_final_count}",
            f"capu_negative_retry_final={report.capu_negative_retry_final_count}",
        )
        print(f"a3_benchmark_digest_sha256={report.digest}")
        print("ASTRA_CAPU_V1_A3_ICARUS_ADAPTER_BENCHMARK_PASS")


if __name__ == "__main__":
    main()

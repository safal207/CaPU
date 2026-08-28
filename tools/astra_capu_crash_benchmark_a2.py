from __future__ import annotations

import json
from dataclasses import asdict, dataclass
from enum import Enum
from typing import Iterable

from tools.astra_capu_effect_authority_a1 import (
    AuthorityIdentity,
    AuthorityTicket,
    Outcome,
    OutcomeEvidence,
    Stage,
    canonical_digest,
    recover,
    sha256_text,
)


class UnsafePolicy(str, Enum):
    BLIND_RETRY = "BLIND_RETRY"
    DISPATCH_ACK_IS_SUCCESS = "DISPATCH_ACK_IS_SUCCESS"


@dataclass(frozen=True)
class CrashScenario:
    name: str
    initial_device_commit: bool
    unsafe_policy: UnsafePolicy
    forced_readback: Outcome | None = None


@dataclass(frozen=True)
class TrialResult:
    schema: str
    scenario: str
    strategy: str
    committed_effects: int
    duplicate_effects: int
    false_successes: int
    retries: int
    unknown_blocks: int
    claimed_success: bool
    sealed: bool
    final_stage: str
    decision: str


@dataclass(frozen=True)
class BenchmarkReport:
    schema: str
    scenarios: tuple[str, ...]
    unsafe_results: tuple[TrialResult, ...]
    capu_results: tuple[TrialResult, ...]
    unsafe_duplicate_effects: int
    capu_duplicate_effects: int
    unsafe_false_successes: int
    capu_false_successes: int
    unsafe_retries: int
    capu_retries: int
    capu_unknown_blocks: int
    capu_sealed_successes: int
    capu_conflict_fail_closed: int

    @property
    def digest(self) -> str:
        return canonical_digest(asdict(self))

    def validate_expected_boundary(self) -> None:
        if self.unsafe_duplicate_effects < 1:
            raise AssertionError("unsafe baseline did not exhibit a duplicate effect")
        if self.unsafe_false_successes < 1:
            raise AssertionError("unsafe baseline did not exhibit false success")
        if self.capu_duplicate_effects != 0:
            raise AssertionError("CaPU path duplicated an effect")
        if self.capu_false_successes != 0:
            raise AssertionError("CaPU path reported false success")
        if self.capu_unknown_blocks != len(self.scenarios):
            raise AssertionError("every crash scenario must pass through UNKNOWN")
        if self.capu_conflict_fail_closed != 1:
            raise AssertionError("the conflict scenario must remain fail closed")

    def to_json(self) -> str:
        payload = asdict(self)
        payload["benchmark_digest_sha256"] = self.digest
        return json.dumps(payload, indent=2, sort_keys=True) + "\n"


class SyntheticAccelerator:
    """A deliberately non-idempotent external effect target.

    Each physical commit increments the effect count. Reissuing the same effect ID
    therefore exposes a duplicate rather than silently hiding the error.
    """

    def __init__(self) -> None:
        self._effect_counts: dict[str, int] = {}

    def commit(self, effect_id: str) -> None:
        self._effect_counts[effect_id] = self._effect_counts.get(effect_id, 0) + 1

    def effect_count(self, effect_id: str) -> int:
        return self._effect_counts.get(effect_id, 0)

    def readback(self, effect_id: str) -> Outcome:
        return Outcome.COMMITTED if self.effect_count(effect_id) > 0 else Outcome.NOT_COMMITTED


DEFAULT_SCENARIOS: tuple[CrashScenario, ...] = (
    CrashScenario(
        name="crash_before_external_effect",
        initial_device_commit=False,
        unsafe_policy=UnsafePolicy.BLIND_RETRY,
    ),
    CrashScenario(
        name="crash_after_effect_before_receipt",
        initial_device_commit=True,
        unsafe_policy=UnsafePolicy.BLIND_RETRY,
    ),
    CrashScenario(
        name="dispatch_ack_false_success",
        initial_device_commit=False,
        unsafe_policy=UnsafePolicy.DISPATCH_ACK_IS_SUCCESS,
    ),
    CrashScenario(
        name="conflicting_readback",
        initial_device_commit=True,
        unsafe_policy=UnsafePolicy.BLIND_RETRY,
        forced_readback=Outcome.CONFLICT,
    ),
)


def authority_ticket(scenario: CrashScenario) -> AuthorityTicket:
    proposed = AuthorityTicket.proposed(
        authority_id=f"a2:{scenario.name}",
        actor_id="synthetic-accelerator-agent",
        intent_commitment=sha256_text(f"intent:{scenario.name}"),
        state_commitment=sha256_text("state:synthetic-queue-before-dispatch"),
        policy_commitment=sha256_text("policy:a2-no-blind-replay"),
        checkpoint_commitment=sha256_text(f"checkpoint:{scenario.name}:pre-dispatch"),
        identity=AuthorityIdentity(
            queue_incarnation=9,
            queue_epoch=21,
            slot_id=3,
            command_id=f"command:{scenario.name}",
            attempt_id=0,
            effect_id=f"effect:{scenario.name}",
        ),
    )
    return (
        proposed.transition(Stage.GROUNDED)
        .transition(Stage.AUTHORIZED)
        .transition(Stage.COMMITTED)
    )


def outcome_evidence(
    ticket: AuthorityTicket,
    outcome: Outcome,
    *,
    source: str,
) -> OutcomeEvidence:
    return OutcomeEvidence(
        schema="capu.hardware.accelerator-effect-outcome-evidence.v1.0-a1",
        evidence_id=f"evidence:{ticket.authority_id}:{ticket.identity.attempt_id}:{outcome.value}",
        authority_id=ticket.authority_id,
        identity=ticket.identity,
        outcome=outcome,
        source=source,
        evidence_commitment=sha256_text(
            f"{ticket.authority_id}:{ticket.identity.attempt_id}:{outcome.value}:{source}"
        ),
    )


def run_unsafe(scenario: CrashScenario) -> TrialResult:
    device = SyntheticAccelerator()
    effect_id = f"effect:{scenario.name}"

    # The first dispatch happened, but local completion state is lost at the
    # injected crash boundary.
    if scenario.initial_device_commit:
        device.commit(effect_id)

    retries = 0
    claimed_success = False
    if scenario.unsafe_policy is UnsafePolicy.BLIND_RETRY:
        retries = 1
        device.commit(effect_id)
        claimed_success = True
        decision = "MISSING_RECEIPT_ASSUMED_NOT_COMMITTED_THEN_RETRIED"
    else:
        claimed_success = True
        decision = "DISPATCH_ACK_MISTAKEN_FOR_COMMITTED_OUTCOME"

    committed_effects = device.effect_count(effect_id)
    return TrialResult(
        schema="capu.hardware.accelerator-crash-trial.v1.0-a2",
        scenario=scenario.name,
        strategy="unsafe_baseline",
        committed_effects=committed_effects,
        duplicate_effects=max(0, committed_effects - 1),
        false_successes=int(claimed_success and committed_effects == 0),
        retries=retries,
        unknown_blocks=0,
        claimed_success=claimed_success,
        sealed=False,
        final_stage="UNVERIFIED_SUCCESS_CLAIM",
        decision=decision,
    )


def run_capu(scenario: CrashScenario) -> TrialResult:
    device = SyntheticAccelerator()
    pre_dispatch_checkpoint = authority_ticket(scenario)
    durable_dispatched = pre_dispatch_checkpoint.dispatch()
    effect_id = durable_dispatched.identity.effect_id

    if scenario.initial_device_commit:
        device.commit(effect_id)

    # Recovery intentionally begins from the stale pre-dispatch checkpoint.
    # The durable issue witness dominates it, reconstructing UNKNOWN.
    recovered = recover(pre_dispatch_checkpoint, durable_dispatched)
    if not recovered.outcome_unknown:
        raise AssertionError("crash recovery must reconstruct UNKNOWN")
    unknown_blocks = 1

    observed = scenario.forced_readback or device.readback(effect_id)
    reconciled = recovered.reconcile(
        outcome_evidence(recovered, observed, source="synthetic-device-readback")
    )

    retries = 0
    claimed_success = False
    sealed = False
    final = reconciled

    if observed is Outcome.NOT_COMMITTED:
        retry_committed = reconciled.begin_retry()
        retries = 1
        retry_dispatched = retry_committed.dispatch()
        device.commit(effect_id)
        final = retry_dispatched.reconcile(
            outcome_evidence(
                retry_dispatched,
                Outcome.COMMITTED,
                source="synthetic-device-readback-after-retry",
            )
        ).retire_and_seal()
        claimed_success = True
        sealed = True
        decision = "EXACT_NEGATIVE_EVIDENCE_THEN_ONE_AUTHORIZED_RETRY"
    elif observed is Outcome.COMMITTED:
        final = reconciled.retire_and_seal()
        claimed_success = True
        sealed = True
        decision = "EXACT_COMMITTED_EVIDENCE_PREVENTED_REPLAY"
    else:
        decision = "CONFLICT_FAIL_CLOSED_NO_REPLAY_NO_RETIRE"

    committed_effects = device.effect_count(effect_id)
    return TrialResult(
        schema="capu.hardware.accelerator-crash-trial.v1.0-a2",
        scenario=scenario.name,
        strategy="astra_capu_a1",
        committed_effects=committed_effects,
        duplicate_effects=max(0, committed_effects - 1),
        false_successes=int(claimed_success and committed_effects == 0),
        retries=retries,
        unknown_blocks=unknown_blocks,
        claimed_success=claimed_success,
        sealed=sealed,
        final_stage=final.stage.value,
        decision=decision,
    )


def run_benchmark(
    scenarios: Iterable[CrashScenario] = DEFAULT_SCENARIOS,
) -> BenchmarkReport:
    scenario_tuple = tuple(scenarios)
    unsafe_results = tuple(run_unsafe(s) for s in scenario_tuple)
    capu_results = tuple(run_capu(s) for s in scenario_tuple)

    report = BenchmarkReport(
        schema="capu.hardware.accelerator-crash-benchmark.v1.0-a2",
        scenarios=tuple(s.name for s in scenario_tuple),
        unsafe_results=unsafe_results,
        capu_results=capu_results,
        unsafe_duplicate_effects=sum(r.duplicate_effects for r in unsafe_results),
        capu_duplicate_effects=sum(r.duplicate_effects for r in capu_results),
        unsafe_false_successes=sum(r.false_successes for r in unsafe_results),
        capu_false_successes=sum(r.false_successes for r in capu_results),
        unsafe_retries=sum(r.retries for r in unsafe_results),
        capu_retries=sum(r.retries for r in capu_results),
        capu_unknown_blocks=sum(r.unknown_blocks for r in capu_results),
        capu_sealed_successes=sum(int(r.sealed) for r in capu_results),
        capu_conflict_fail_closed=sum(
            int(r.final_stage == Stage.CONFLICT.value and not r.claimed_success)
            for r in capu_results
        ),
    )
    report.validate_expected_boundary()
    return report


def main() -> None:
    report = run_benchmark()
    for unsafe, capu in zip(report.unsafe_results, report.capu_results, strict=True):
        print(
            "scenario=" + unsafe.scenario,
            f"unsafe_effects={unsafe.committed_effects}",
            f"unsafe_duplicates={unsafe.duplicate_effects}",
            f"unsafe_false_success={unsafe.false_successes}",
            f"capu_effects={capu.committed_effects}",
            f"capu_duplicates={capu.duplicate_effects}",
            f"capu_false_success={capu.false_successes}",
            f"capu_final={capu.final_stage}",
        )
    print(
        "summary",
        f"unsafe_duplicates={report.unsafe_duplicate_effects}",
        f"capu_duplicates={report.capu_duplicate_effects}",
        f"unsafe_false_success={report.unsafe_false_successes}",
        f"capu_false_success={report.capu_false_successes}",
        f"capu_unknown_blocks={report.capu_unknown_blocks}",
        f"capu_sealed_successes={report.capu_sealed_successes}",
        f"capu_conflict_fail_closed={report.capu_conflict_fail_closed}",
    )
    print(f"benchmark_digest_sha256={report.digest}")
    print("ASTRA_CAPU_V1_A2_CRASH_INJECTION_BENCHMARK_PASS")


if __name__ == "__main__":
    main()

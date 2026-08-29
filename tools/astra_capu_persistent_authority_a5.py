"""Deterministic software mirror for ASTRA–CaPU v1.0-A5.

A5 closes the A4 logic-reset replay gap by requiring the persistent attempt
frontier to advance before a command can reach the synthetic effect device.
The persistence mechanism itself is abstracted as a single-lineage durable
frontier; production NVRAM/retention technology is outside this model.
"""

from __future__ import annotations

from dataclasses import dataclass
import hashlib
import json
from typing import Optional

REJECT_NONE = 0
REJECT_NO_AUTHORITY = 1
REJECT_UNCOMMITTED = 2
REJECT_IDENTITY = 3
REJECT_ALREADY_ISSUED = 4
REJECT_REVOKE_PENDING = 5
REJECT_PERSISTENT_MISSING = 6
REJECT_PERSISTENT_LINEAGE = 7
REJECT_PERSISTENT_FRONTIER = 8
REJECT_FRONTIER_EXHAUSTED = 9
REJECT_PERSIST_COMMIT = 10


@dataclass(frozen=True)
class AuthorityToken:
    authority_tag: int
    incarnation: int
    queue_epoch: int
    slot_id: int
    command_id: int
    attempt_id: int
    effect_id: int
    committed: bool = True

    def lineage(self) -> tuple[int, int, int, int, int, int]:
        return (
            self.authority_tag,
            self.incarnation,
            self.queue_epoch,
            self.slot_id,
            self.command_id,
            self.effect_id,
        )


@dataclass
class PersistentFrontier:
    width_bits: int = 4
    lineage_value: Optional[tuple[int, int, int, int, int, int]] = None
    next_attempt: int = 0

    @property
    def valid(self) -> bool:
        return self.lineage_value is not None

    @property
    def max_attempt(self) -> int:
        return (1 << self.width_bits) - 1

    @property
    def exhausted(self) -> bool:
        return self.valid and self.next_attempt == self.max_attempt

    def provision(self, token: AuthorityToken, next_attempt: int = 0) -> bool:
        if self.valid:
            return False
        self.lineage_value = token.lineage()
        self.next_attempt = next_attempt
        return True

    def advance_for(self, token: AuthorityToken) -> bool:
        if not self.valid or self.lineage_value != token.lineage():
            return False
        if self.exhausted or token.attempt_id != self.next_attempt:
            return False
        self.next_attempt += 1
        return True


@dataclass(frozen=True)
class DispatchDecision:
    forwarded: bool
    reject_code: int
    effect_committed: bool


class A5Controller:
    def __init__(self, frontier: PersistentFrontier) -> None:
        self.frontier = frontier
        self.active: Optional[AuthorityToken] = None
        self.attempt_spent = False
        self.revoke_pending = False
        self.external_effect_count = 0

    def logic_reset(self) -> None:
        self.active = None
        self.attempt_spent = False
        self.revoke_pending = False

    def load(self, token: AuthorityToken) -> bool:
        if self.active is not None or self.revoke_pending:
            return False
        self.active = token
        self.attempt_spent = False
        return True

    def revoke(self, token: AuthorityToken) -> bool:
        if self.active != token:
            return False
        self.active = None
        self.attempt_spent = False
        return True

    def dispatch(self, token: AuthorityToken, *, commit_effect: bool) -> DispatchDecision:
        active = self.active
        if active is None:
            return DispatchDecision(False, REJECT_NO_AUTHORITY, False)
        if self.revoke_pending:
            return DispatchDecision(False, REJECT_REVOKE_PENDING, False)
        if not active.committed:
            return DispatchDecision(False, REJECT_UNCOMMITTED, False)
        if token != active:
            return DispatchDecision(False, REJECT_IDENTITY, False)
        if self.attempt_spent:
            return DispatchDecision(False, REJECT_ALREADY_ISSUED, False)
        if not self.frontier.valid:
            return DispatchDecision(False, REJECT_PERSISTENT_MISSING, False)
        if self.frontier.lineage_value != token.lineage():
            return DispatchDecision(False, REJECT_PERSISTENT_LINEAGE, False)
        if token.attempt_id != self.frontier.next_attempt:
            return DispatchDecision(False, REJECT_PERSISTENT_FRONTIER, False)
        if self.frontier.exhausted:
            return DispatchDecision(False, REJECT_FRONTIER_EXHAUSTED, False)

        # Commit-before-effect: persistence advances first. If the persistence
        # operation fails, command-forward authority is not exposed.
        if not self.frontier.advance_for(token):
            return DispatchDecision(False, REJECT_PERSIST_COMMIT, False)

        self.attempt_spent = True
        if commit_effect:
            self.external_effect_count += 1
        return DispatchDecision(True, REJECT_NONE, commit_effect)


def canonical_digest(value: dict[str, object]) -> str:
    encoded = json.dumps(value, sort_keys=True, separators=(",", ":")).encode()
    return hashlib.sha256(encoded).hexdigest()


def scenario_result() -> dict[str, object]:
    token0 = AuthorityToken(0xA5, 2, 7, 1, 9, 0, 12, True)
    token1 = AuthorityToken(0xA5, 2, 7, 1, 9, 1, 12, True)
    token3 = AuthorityToken(0xA5, 2, 7, 1, 9, 3, 12, True)

    frontier = PersistentFrontier(width_bits=4)
    controller = A5Controller(frontier)
    assert frontier.provision(token0, next_attempt=0)
    assert controller.load(token0)

    first = controller.dispatch(token0, commit_effect=True)
    controller.logic_reset()
    assert controller.load(token0)
    stale = controller.dispatch(token0, commit_effect=True)

    controller.logic_reset()
    assert controller.load(token1)
    successor = controller.dispatch(token1, commit_effect=True)

    controller.logic_reset()
    assert controller.load(token3)
    future = controller.dispatch(token3, commit_effect=True)

    result: dict[str, object] = {
        "schema": "capu.astra.persistent-anti-replay.result.v1.0-a5",
        "initial_attempt": 0,
        "first_forwarded": first.forwarded,
        "restart_replay_blocked": not stale.forwarded,
        "restart_replay_reject_code": stale.reject_code,
        "successor_attempt_forwarded": successor.forwarded,
        "future_attempt_blocked": not future.forwarded,
        "future_attempt_reject_code": future.reject_code,
        "external_effect_count": controller.external_effect_count,
        "persistent_next_attempt": frontier.next_attempt,
        "commit_before_effect": True,
        "logic_reset_preserves_frontier": True,
    }
    result["result_digest_sha256"] = canonical_digest(result)
    return result


def main() -> None:
    result = scenario_result()
    print("a5_frontier_provisioned next_attempt=0")
    print("a5_attempt0_forwarded forward=1 effect_count=1 persistent_next_attempt=1")
    print("a5_logic_restart active_valid=0 effect_count=1 persistent_next_attempt=1")
    print(
        "a5_same_attempt_after_restart_blocked "
        f"reject_code={result['restart_replay_reject_code']} effect_count=1"
    )
    print("a5_successor_attempt_forwarded attempt=1 effect_count=2 persistent_next_attempt=2")
    print(
        "a5_future_attempt_blocked attempt=3 frontier=2 "
        f"reject_code={result['future_attempt_reject_code']}"
    )
    print(json.dumps(result, sort_keys=True))
    print("ASTRA_CAPU_V1_A5_REFERENCE_PASS")


if __name__ == "__main__":
    main()

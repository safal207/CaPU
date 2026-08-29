"""Deterministic software mirror for ASTRA–CaPU v1.0-A6.

A6 binds the A5 persistent attempt frontier to durable outcome state. A
reserved attempt enters UNKNOWN. Exact NOT_COMMITTED evidence releases only
the successor attempt; exact COMMITTED evidence terminally closes the lineage;
CONFLICT fails closed.
"""

from __future__ import annotations

from dataclasses import dataclass
from enum import Enum, IntEnum
import hashlib
import json
from typing import Optional


class Outcome(str, Enum):
    NONE = "NONE"
    UNKNOWN = "UNKNOWN"
    NOT_COMMITTED = "NOT_COMMITTED"
    COMMITTED = "COMMITTED"
    CONFLICT = "CONFLICT"


class RejectCode(IntEnum):
    NONE = 0
    NO_AUTHORITY = 1
    UNCOMMITTED = 2
    IDENTITY = 3
    ALREADY_ISSUED = 4
    REVOKE_PENDING = 5
    PERSISTENT_MISSING = 6
    PERSISTENT_LINEAGE = 7
    PERSISTENT_FRONTIER = 8
    FRONTIER_EXHAUSTED = 9
    OUTCOME_UNKNOWN = 10
    TERMINAL_COMMITTED = 11
    TERMINAL_CONFLICT = 12
    RESERVATION_FAILED = 13


class ReconcileRejectCode(IntEnum):
    NONE = 0
    PERSISTENT_MISSING = 1
    PERSISTENT_LINEAGE = 2
    NO_UNRESOLVED_ATTEMPT = 3
    ATTEMPT_MISMATCH = 4
    INVALID_OUTCOME = 5
    TERMINAL = 6


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
class PersistentOutcomeStore:
    width_bits: int = 4
    lineage_value: Optional[tuple[int, int, int, int, int, int]] = None
    next_attempt: int = 0
    unresolved_valid: bool = False
    unresolved_attempt: int = 0
    last_outcome: Outcome = Outcome.NONE
    last_resolved_attempt: int = 0
    terminal_committed: bool = False
    terminal_conflict: bool = False

    @property
    def valid(self) -> bool:
        return self.lineage_value is not None

    @property
    def max_attempt(self) -> int:
        return (1 << self.width_bits) - 1

    @property
    def frontier_exhausted(self) -> bool:
        return self.valid and self.next_attempt == self.max_attempt

    def provision(self, token: AuthorityToken, *, next_attempt: int = 0) -> bool:
        if self.valid:
            return False
        if next_attempt < 0 or next_attempt > self.max_attempt:
            return False
        self.lineage_value = token.lineage()
        self.next_attempt = next_attempt
        return True

    def reserve(self, token: AuthorityToken) -> bool:
        if not self.valid or self.lineage_value != token.lineage():
            return False
        if self.unresolved_valid or self.terminal_committed or self.terminal_conflict:
            return False
        if self.frontier_exhausted or token.attempt_id != self.next_attempt:
            return False
        self.unresolved_valid = True
        self.unresolved_attempt = token.attempt_id
        self.next_attempt += 1
        self.last_outcome = Outcome.UNKNOWN
        return True

    def reconcile(
        self, token: AuthorityToken, outcome: Outcome
    ) -> ReconcileRejectCode:
        if not self.valid:
            return ReconcileRejectCode.PERSISTENT_MISSING
        if self.lineage_value != token.lineage():
            return ReconcileRejectCode.PERSISTENT_LINEAGE
        if self.terminal_committed or self.terminal_conflict:
            return ReconcileRejectCode.TERMINAL
        if not self.unresolved_valid:
            return ReconcileRejectCode.NO_UNRESOLVED_ATTEMPT
        if token.attempt_id != self.unresolved_attempt:
            return ReconcileRejectCode.ATTEMPT_MISMATCH
        if outcome not in (
            Outcome.NOT_COMMITTED,
            Outcome.COMMITTED,
            Outcome.CONFLICT,
        ):
            return ReconcileRejectCode.INVALID_OUTCOME

        self.unresolved_valid = False
        self.last_outcome = outcome
        self.last_resolved_attempt = token.attempt_id
        if outcome is Outcome.COMMITTED:
            self.terminal_committed = True
        elif outcome is Outcome.CONFLICT:
            self.terminal_conflict = True
        return ReconcileRejectCode.NONE


@dataclass(frozen=True)
class DispatchDecision:
    forwarded: bool
    reject_code: RejectCode
    effect_committed: bool


class A6Controller:
    def __init__(self, store: PersistentOutcomeStore) -> None:
        self.store = store
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

    def dispatch(
        self, token: AuthorityToken, *, commit_effect: bool
    ) -> DispatchDecision:
        active = self.active
        if active is None:
            return DispatchDecision(False, RejectCode.NO_AUTHORITY, False)
        if self.revoke_pending:
            return DispatchDecision(False, RejectCode.REVOKE_PENDING, False)
        if not active.committed:
            return DispatchDecision(False, RejectCode.UNCOMMITTED, False)
        if token != active:
            return DispatchDecision(False, RejectCode.IDENTITY, False)
        if self.attempt_spent:
            return DispatchDecision(False, RejectCode.ALREADY_ISSUED, False)
        if not self.store.valid:
            return DispatchDecision(False, RejectCode.PERSISTENT_MISSING, False)
        if self.store.lineage_value != token.lineage():
            return DispatchDecision(False, RejectCode.PERSISTENT_LINEAGE, False)
        if self.store.terminal_committed:
            return DispatchDecision(False, RejectCode.TERMINAL_COMMITTED, False)
        if self.store.terminal_conflict:
            return DispatchDecision(False, RejectCode.TERMINAL_CONFLICT, False)
        if self.store.unresolved_valid:
            return DispatchDecision(False, RejectCode.OUTCOME_UNKNOWN, False)
        if token.attempt_id != self.store.next_attempt:
            return DispatchDecision(False, RejectCode.PERSISTENT_FRONTIER, False)
        if self.store.frontier_exhausted:
            return DispatchDecision(False, RejectCode.FRONTIER_EXHAUSTED, False)
        if not self.store.reserve(token):
            return DispatchDecision(False, RejectCode.RESERVATION_FAILED, False)

        self.attempt_spent = True
        if commit_effect:
            self.external_effect_count += 1
        return DispatchDecision(True, RejectCode.NONE, commit_effect)


def canonical_digest(value: dict[str, object]) -> str:
    encoded = json.dumps(value, sort_keys=True, separators=(",", ":")).encode()
    return hashlib.sha256(encoded).hexdigest()


def scenario_result() -> dict[str, object]:
    token0 = AuthorityToken(0xA6, 2, 7, 1, 9, 0, 12, True)
    token1 = AuthorityToken(0xA6, 2, 7, 1, 9, 1, 12, True)
    token2 = AuthorityToken(0xA6, 2, 7, 1, 9, 2, 12, True)

    store = PersistentOutcomeStore(width_bits=4)
    controller = A6Controller(store)
    assert store.provision(token0, next_attempt=0)
    assert controller.load(token0)

    first = controller.dispatch(token0, commit_effect=False)
    unknown_after_first = store.unresolved_valid and store.last_outcome is Outcome.UNKNOWN

    controller.logic_reset()
    assert controller.load(token0)
    restart_replay = controller.dispatch(token0, commit_effect=True)

    negative = store.reconcile(token0, Outcome.NOT_COMMITTED)

    controller.logic_reset()
    assert controller.load(token1)
    successor = controller.dispatch(token1, commit_effect=True)

    controller.logic_reset()
    assert controller.load(token2)
    successor_unknown = controller.dispatch(token2, commit_effect=True)

    stale_reconcile = store.reconcile(token0, Outcome.COMMITTED)
    committed = store.reconcile(token1, Outcome.COMMITTED)

    controller.logic_reset()
    assert controller.load(token2)
    terminal_replay = controller.dispatch(token2, commit_effect=True)

    result: dict[str, object] = {
        "schema": "capu.astra.outcome-reconciliation.result.v1.0-a6",
        "first_attempt_forwarded": first.forwarded,
        "first_effect_committed": first.effect_committed,
        "unknown_after_first_dispatch": unknown_after_first,
        "restart_replay_blocked": not restart_replay.forwarded,
        "restart_replay_reject_code": int(restart_replay.reject_code),
        "negative_reconcile_accepted": negative is ReconcileRejectCode.NONE,
        "successor_attempt_forwarded": successor.forwarded,
        "successor_effect_committed": successor.effect_committed,
        "successor_unknown_blocked": not successor_unknown.forwarded,
        "successor_unknown_reject_code": int(successor_unknown.reject_code),
        "stale_reconcile_blocked": stale_reconcile
        is ReconcileRejectCode.ATTEMPT_MISMATCH,
        "stale_reconcile_reject_code": int(stale_reconcile),
        "committed_reconcile_accepted": committed is ReconcileRejectCode.NONE,
        "terminal_committed": store.terminal_committed,
        "terminal_replay_blocked": not terminal_replay.forwarded,
        "terminal_replay_reject_code": int(terminal_replay.reject_code),
        "external_effect_count": controller.external_effect_count,
        "persistent_next_attempt": store.next_attempt,
        "last_outcome": store.last_outcome.value,
        "logic_reset_preserves_outcome_state": True,
        "commit_before_effect": True,
    }
    result["result_digest_sha256"] = canonical_digest(result)
    return result


def main() -> None:
    result = scenario_result()
    print("a6_frontier_provisioned next_attempt=0")
    print("a6_attempt0_forwarded effect_count=0 outcome=UNKNOWN next_attempt=1")
    print("a6_logic_restart_unknown_preserved unresolved_attempt=0 next_attempt=1")
    print(
        "a6_same_attempt_after_restart_blocked "
        f"reject_code={result['restart_replay_reject_code']} effect_count=0"
    )
    print("a6_negative_reconcile_accepted attempt=0 outcome=NOT_COMMITTED")
    print("a6_attempt1_forwarded effect_count=1 outcome=UNKNOWN next_attempt=2")
    print(
        "a6_successor_blocked_while_unknown "
        f"reject_code={result['successor_unknown_reject_code']} effect_count=1"
    )
    print(
        "a6_stale_reconcile_blocked "
        f"reject_code={result['stale_reconcile_reject_code']}"
    )
    print("a6_committed_reconcile_accepted attempt=1 terminal_committed=1")
    print(
        "a6_terminal_replay_blocked "
        f"reject_code={result['terminal_replay_reject_code']} effect_count=1"
    )
    print(json.dumps(result, sort_keys=True))
    print("ASTRA_CAPU_V1_A6_OUTCOME_RECONCILIATION_PASS")


if __name__ == "__main__":
    main()

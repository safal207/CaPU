from __future__ import annotations

import hashlib
import json
from dataclasses import asdict, dataclass
from enum import IntEnum
from typing import Any

DOMAIN = "ASTRA-CAPU:SYNTHESIZABLE-AUTHORITY-SHIM:A4:V1\u0000"


class ShimError(ValueError):
    """Raised when a control operation violates the bounded A4 lifecycle."""


class RejectCode(IntEnum):
    NONE = 0
    NO_AUTHORITY = 1
    UNCOMMITTED = 2
    IDENTITY_MISMATCH = 3
    ALREADY_ISSUED = 4
    REVOKE_PENDING = 5


@dataclass(frozen=True)
class BoundedAuthorityToken:
    authority_tag: int
    queue_incarnation: int
    queue_epoch: int
    slot_id: int
    command_id: int
    attempt_id: int
    effect_id: int

    def validate(self) -> None:
        for name, value in asdict(self).items():
            if not isinstance(value, int) or value < 0 or value > 0xFF:
                raise ShimError(f"{name} must be an unsigned 8-bit value")

    def digest(self) -> str:
        self.validate()
        payload = {
            "domain": DOMAIN,
            "token": asdict(self),
        }
        encoded = json.dumps(payload, sort_keys=True, separators=(",", ":")).encode()
        return hashlib.sha256(encoded).hexdigest()


@dataclass(frozen=True)
class IssueDecision:
    forwarded: bool
    reject_code: RejectCode


class AuthorityShimA4:
    """Deterministic software mirror of the bounded synthesizable A4 issue gate."""

    def __init__(self) -> None:
        self.active: BoundedAuthorityToken | None = None
        self.committed = False
        self.attempt_spent = False
        self.effect_count = 0

    def load(self, token: BoundedAuthorityToken, *, committed: bool) -> bool:
        token.validate()
        if self.active is not None:
            return False
        self.active = token
        self.committed = committed
        self.attempt_spent = False
        return True

    def revoke(self, token: BoundedAuthorityToken) -> bool:
        token.validate()
        if self.active != token:
            return False
        self.active = None
        self.committed = False
        self.attempt_spent = False
        return True

    def issue(self, token: BoundedAuthorityToken, *, external_commit: bool) -> IssueDecision:
        token.validate()
        if self.active is None:
            return IssueDecision(False, RejectCode.NO_AUTHORITY)
        if not self.committed:
            return IssueDecision(False, RejectCode.UNCOMMITTED)
        if token != self.active:
            return IssueDecision(False, RejectCode.IDENTITY_MISMATCH)
        if self.attempt_spent:
            return IssueDecision(False, RejectCode.ALREADY_ISSUED)

        self.attempt_spent = True
        if external_commit:
            self.effect_count += 1
        return IssueDecision(True, RejectCode.NONE)


def scenario_result() -> dict[str, Any]:
    shim = AuthorityShimA4()
    token0 = BoundedAuthorityToken(0xA1, 2, 7, 1, 2, 0, 4)
    assert shim.load(token0, committed=True)
    exact = shim.issue(token0, external_commit=True)
    duplicate = shim.issue(token0, external_commit=True)
    assert shim.revoke(token0)

    uncommitted_token = BoundedAuthorityToken(0xB2, 3, 0, 1, 2, 0, 4)
    assert shim.load(uncommitted_token, committed=False)
    uncommitted = shim.issue(uncommitted_token, external_commit=True)
    assert shim.revoke(uncommitted_token)

    current = BoundedAuthorityToken(0xC3, 4, 1, 1, 2, 0, 4)
    stale = BoundedAuthorityToken(0xC3, 3, 1, 1, 2, 0, 4)
    assert shim.load(current, committed=True)
    stale_decision = shim.issue(stale, external_commit=True)
    unknown_dispatch = shim.issue(current, external_commit=False)
    same_attempt_replay = shim.issue(current, external_commit=True)
    assert shim.revoke(current)

    successor = BoundedAuthorityToken(0xD4, 4, 1, 1, 2, 1, 4)
    assert shim.load(successor, committed=True)
    successor_decision = shim.issue(successor, external_commit=True)
    assert shim.revoke(successor)
    revoked = shim.issue(successor, external_commit=True)

    result = {
        "schema": "capu.hardware.astra-authority-shim-result.v1.0-a4",
        "exact_forwarded": exact.forwarded,
        "duplicate_reject_code": int(duplicate.reject_code),
        "uncommitted_reject_code": int(uncommitted.reject_code),
        "stale_identity_reject_code": int(stale_decision.reject_code),
        "unknown_dispatch_forwarded": unknown_dispatch.forwarded,
        "same_attempt_replay_reject_code": int(same_attempt_replay.reject_code),
        "successor_attempt_forwarded": successor_decision.forwarded,
        "revoked_reject_code": int(revoked.reject_code),
        "external_effect_count": shim.effect_count,
        "initial_token_digest_sha256": token0.digest(),
        "successor_token_digest_sha256": successor.digest(),
    }
    result["result_digest_sha256"] = hashlib.sha256(
        json.dumps(result, sort_keys=True, separators=(",", ":")).encode()
    ).hexdigest()
    return result


def main() -> None:
    result = scenario_result()
    print(
        "a4_reference exact_forwarded={exact} duplicate_code={duplicate} "
        "uncommitted_code={uncommitted} stale_code={stale} "
        "unknown_forwarded={unknown} replay_code={replay} "
        "successor_forwarded={successor} revoked_code={revoked} effects={effects}".format(
            exact=int(result["exact_forwarded"]),
            duplicate=result["duplicate_reject_code"],
            uncommitted=result["uncommitted_reject_code"],
            stale=result["stale_identity_reject_code"],
            unknown=int(result["unknown_dispatch_forwarded"]),
            replay=result["same_attempt_replay_reject_code"],
            successor=int(result["successor_attempt_forwarded"]),
            revoked=result["revoked_reject_code"],
            effects=result["external_effect_count"],
        )
    )
    print(f"a4_reference_digest={result['result_digest_sha256']}")
    print("ASTRA_CAPU_V1_A4_REFERENCE_PASS")


if __name__ == "__main__":
    main()

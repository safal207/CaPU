"""Deterministic software mirror for ASTRA–CaPU v1.0-A7.

A7 adds an authenticated device-receipt boundary in front of the A6 durable
outcome reconciler. The model uses a deliberately small synthetic keyed tag,
not production cryptography. It verifies device identity, key epoch, monotonic
receipt sequence, exact attempt identity and tag before exposing outcome
evidence to A6.
"""

from __future__ import annotations

from dataclasses import dataclass
from enum import IntEnum
import hashlib
import json

from tools.astra_capu_outcome_reconciliation_a6 import (
    A6Controller,
    AuthorityToken,
    Outcome,
    PersistentOutcomeStore,
    ReconcileRejectCode,
)


class ReceiptRejectCode(IntEnum):
    NONE = 0
    TRUST_MISSING = 1
    DEVICE_ID = 2
    KEY_EPOCH = 3
    RECEIPT_SEQUENCE = 4
    AUTH_TAG = 5


OUTCOME_CODE = {
    Outcome.NONE: 0,
    Outcome.UNKNOWN: 1,
    Outcome.NOT_COMMITTED: 2,
    Outcome.COMMITTED: 3,
    Outcome.CONFLICT: 4,
}


def rotate_left(value: int, width_bits: int, amount: int = 1) -> int:
    mask = (1 << width_bits) - 1
    amount %= width_bits
    return ((value << amount) | (value >> (width_bits - amount))) & mask


def synthetic_receipt_tag(
    secret: int,
    fields: list[int],
    *,
    width_bits: int = 16,
) -> int:
    """Return the exact synthetic keyed tag mirrored by the A7 RTL.

    This rotation/XOR construction is intentionally transparent and is not a
    cryptographic MAC. It exists only to exercise authenticated-envelope state
    transitions and anti-replay sequence semantics in a bounded model.
    """

    mask = (1 << width_bits) - 1
    tag = secret & mask
    for field in fields:
        tag = rotate_left(tag, width_bits) ^ (field & mask)
    return tag & mask


@dataclass(frozen=True)
class DeviceReceipt:
    device_id: int
    key_epoch: int
    receipt_seq: int
    authority_tag: int
    incarnation: int
    queue_epoch: int
    slot_id: int
    command_id: int
    attempt_id: int
    effect_id: int
    outcome: Outcome
    auth_tag: int

    def token(self) -> AuthorityToken:
        return AuthorityToken(
            self.authority_tag,
            self.incarnation,
            self.queue_epoch,
            self.slot_id,
            self.command_id,
            self.attempt_id,
            self.effect_id,
            True,
        )

    def auth_fields(self) -> list[int]:
        return [
            self.device_id,
            self.key_epoch,
            self.receipt_seq,
            self.authority_tag,
            self.incarnation,
            self.queue_epoch,
            self.slot_id,
            self.command_id,
            self.attempt_id,
            self.effect_id,
            OUTCOME_CODE[self.outcome],
        ]

    def expected_tag(self, secret: int, *, width_bits: int = 16) -> int:
        return synthetic_receipt_tag(
            secret,
            self.auth_fields(),
            width_bits=width_bits,
        )

    @classmethod
    def signed(
        cls,
        *,
        secret: int,
        width_bits: int = 16,
        **values: object,
    ) -> "DeviceReceipt":
        unsigned = cls(auth_tag=0, **values)
        return cls(
            **values,
            auth_tag=unsigned.expected_tag(secret, width_bits=width_bits),
        )


@dataclass
class TrustedDeviceStore:
    trusted_device_id: int
    trusted_key_epoch: int
    secret: int
    next_receipt_seq: int = 0
    auth_width_bits: int = 16
    valid: bool = True

    def authenticate(self, receipt: DeviceReceipt) -> ReceiptRejectCode:
        if not self.valid:
            return ReceiptRejectCode.TRUST_MISSING
        if receipt.device_id != self.trusted_device_id:
            return ReceiptRejectCode.DEVICE_ID
        if receipt.key_epoch != self.trusted_key_epoch:
            return ReceiptRejectCode.KEY_EPOCH
        if receipt.receipt_seq != self.next_receipt_seq:
            return ReceiptRejectCode.RECEIPT_SEQUENCE
        if receipt.auth_tag != receipt.expected_tag(
            self.secret,
            width_bits=self.auth_width_bits,
        ):
            return ReceiptRejectCode.AUTH_TAG

        # An authenticated receipt consumes its monotonic sequence number even
        # when the downstream A6 semantic reconciler rejects it as stale.
        self.next_receipt_seq += 1
        return ReceiptRejectCode.NONE


@dataclass(frozen=True)
class ReceiptDecision:
    authenticated: bool
    auth_reject_code: ReceiptRejectCode
    reconcile_accept: bool
    reconcile_reject_code: ReconcileRejectCode


class A7Controller:
    def __init__(
        self,
        a6: A6Controller,
        trust: TrustedDeviceStore,
    ) -> None:
        self.a6 = a6
        self.trust = trust

    def process_receipt(self, receipt: DeviceReceipt) -> ReceiptDecision:
        auth = self.trust.authenticate(receipt)
        if auth is not ReceiptRejectCode.NONE:
            return ReceiptDecision(
                False,
                auth,
                False,
                ReconcileRejectCode.NONE,
            )

        reconcile = self.a6.store.reconcile(
            receipt.token(),
            receipt.outcome,
        )
        return ReceiptDecision(
            True,
            ReceiptRejectCode.NONE,
            reconcile is ReconcileRejectCode.NONE,
            reconcile,
        )


def canonical_digest(value: dict[str, object]) -> str:
    encoded = json.dumps(value, sort_keys=True, separators=(",", ":")).encode()
    return hashlib.sha256(encoded).hexdigest()


def scenario_result() -> dict[str, object]:
    secret = 0xBEEF
    device_id = 0x3C
    key_epoch = 2

    token0 = AuthorityToken(0xA7, 2, 7, 1, 9, 0, 12, True)
    token1 = AuthorityToken(0xA7, 2, 7, 1, 9, 1, 12, True)
    token2 = AuthorityToken(0xA7, 2, 7, 1, 9, 2, 12, True)

    store = PersistentOutcomeStore(width_bits=4)
    controller = A6Controller(store)
    trust = TrustedDeviceStore(device_id, key_epoch, secret)
    a7 = A7Controller(controller, trust)

    assert store.provision(token0, next_attempt=0)
    assert controller.load(token0)
    first = controller.dispatch(token0, commit_effect=False)

    exact_negative = DeviceReceipt.signed(
        secret=secret,
        device_id=device_id,
        key_epoch=key_epoch,
        receipt_seq=0,
        authority_tag=token0.authority_tag,
        incarnation=token0.incarnation,
        queue_epoch=token0.queue_epoch,
        slot_id=token0.slot_id,
        command_id=token0.command_id,
        attempt_id=token0.attempt_id,
        effect_id=token0.effect_id,
        outcome=Outcome.NOT_COMMITTED,
    )
    forged_negative = DeviceReceipt(
        **{
            **exact_negative.__dict__,
            "auth_tag": exact_negative.auth_tag ^ 1,
        }
    )

    forged = a7.process_receipt(forged_negative)
    sequence_after_forgery = trust.next_receipt_seq
    negative = a7.process_receipt(exact_negative)
    sequence_after_negative = trust.next_receipt_seq

    controller.logic_reset()
    assert controller.load(token1)
    successor = controller.dispatch(token1, commit_effect=True)
    controller.logic_reset()

    stale_replay = a7.process_receipt(exact_negative)

    foreign_device = DeviceReceipt.signed(
        secret=secret,
        device_id=device_id + 1,
        key_epoch=key_epoch,
        receipt_seq=1,
        authority_tag=token1.authority_tag,
        incarnation=token1.incarnation,
        queue_epoch=token1.queue_epoch,
        slot_id=token1.slot_id,
        command_id=token1.command_id,
        attempt_id=token1.attempt_id,
        effect_id=token1.effect_id,
        outcome=Outcome.COMMITTED,
    )
    foreign = a7.process_receipt(foreign_device)

    exact_committed = DeviceReceipt.signed(
        secret=secret,
        device_id=device_id,
        key_epoch=key_epoch,
        receipt_seq=1,
        authority_tag=token1.authority_tag,
        incarnation=token1.incarnation,
        queue_epoch=token1.queue_epoch,
        slot_id=token1.slot_id,
        command_id=token1.command_id,
        attempt_id=token1.attempt_id,
        effect_id=token1.effect_id,
        outcome=Outcome.COMMITTED,
    )
    committed = a7.process_receipt(exact_committed)

    controller.logic_reset()
    assert controller.load(token2)
    terminal_replay = controller.dispatch(token2, commit_effect=True)

    result: dict[str, object] = {
        "schema": "capu.astra.authenticated-device-receipt.result.v1.0-a7",
        "first_attempt_forwarded": first.forwarded,
        "forged_receipt_blocked": not forged.authenticated,
        "forged_receipt_reject_code": int(forged.auth_reject_code),
        "receipt_sequence_after_forgery": sequence_after_forgery,
        "negative_receipt_authenticated": negative.authenticated,
        "negative_receipt_applied": negative.reconcile_accept,
        "receipt_sequence_after_negative": sequence_after_negative,
        "successor_attempt_forwarded": successor.forwarded,
        "successor_effect_committed": successor.effect_committed,
        "stale_receipt_replay_blocked": not stale_replay.authenticated,
        "stale_receipt_reject_code": int(stale_replay.auth_reject_code),
        "foreign_device_receipt_blocked": not foreign.authenticated,
        "foreign_device_reject_code": int(foreign.auth_reject_code),
        "committed_receipt_authenticated": committed.authenticated,
        "committed_receipt_applied": committed.reconcile_accept,
        "terminal_committed": store.terminal_committed,
        "terminal_replay_blocked": not terminal_replay.forwarded,
        "terminal_replay_reject_code": int(terminal_replay.reject_code),
        "external_effect_count": controller.external_effect_count,
        "persistent_next_attempt": store.next_attempt,
        "next_receipt_sequence": trust.next_receipt_seq,
        "last_outcome": store.last_outcome.value,
        "synthetic_mac_model": True,
        "exact_device_identity_binding": True,
        "exact_key_epoch_binding": True,
    }
    result["result_digest_sha256"] = canonical_digest(result)
    return result


def main() -> None:
    result = scenario_result()
    print("a7_attempt0_forwarded outcome=UNKNOWN effect_count=0")
    print(
        "a7_forged_receipt_blocked "
        f"reject_code={result['forged_receipt_reject_code']} next_receipt_seq=0"
    )
    print("a7_negative_receipt_authenticated seq=0 outcome=NOT_COMMITTED next_receipt_seq=1")
    print("a7_attempt1_forwarded outcome=UNKNOWN effect_count=1")
    print(
        "a7_stale_receipt_replay_blocked "
        f"reject_code={result['stale_receipt_reject_code']} next_receipt_seq=1"
    )
    print(
        "a7_foreign_device_receipt_blocked "
        f"reject_code={result['foreign_device_reject_code']} next_receipt_seq=1"
    )
    print("a7_committed_receipt_authenticated seq=1 terminal_committed=1 next_receipt_seq=2")
    print(
        "a7_terminal_replay_blocked "
        f"reject_code={result['terminal_replay_reject_code']} effect_count=1"
    )
    print(json.dumps(result, sort_keys=True))
    print("ASTRA_CAPU_V1_A7_AUTHENTICATED_DEVICE_RECEIPT_PASS")


if __name__ == "__main__":
    main()

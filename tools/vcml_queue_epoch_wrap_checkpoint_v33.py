from __future__ import annotations

import hashlib
import struct
from dataclasses import dataclass

DOMAIN = b"CAPU:VCML:QUEUE-EPOCH-WRAP-INCARNATION:V0.33\x00"
BASE_V32_DIGEST = bytes.fromhex("177223eea1fc5915e80667531b40f4f134a4493b05667e39defbd3c52a3873c1")
UNISSUED, UNKNOWN, COMMITTED, NOT_COMMITTED = range(4)


@dataclass(frozen=True)
class QueueEpochWrapCheckpointV33:
    runtime_ready: bool
    slot_pending: bool
    live_incarnation: int
    live_queue_epoch: int
    live_command_id: int
    live_execution_epoch: int
    live_effect_id: int
    effect_state: int

    durable_slot_valid: bool
    durable_incarnation: int
    durable_queue_epoch: int
    durable_command_id: int
    durable_execution_epoch: int
    durable_effect_id: int

    last_retired_valid: bool
    last_retired_incarnation: int
    last_retired_queue_epoch: int

    checkpoint_valid: bool
    checkpoint_pending: bool
    checkpoint_incarnation: int
    checkpoint_queue_epoch: int
    checkpoint_command_id: int
    checkpoint_execution_epoch: int
    checkpoint_effect_id: int
    checkpoint_effect_state: int

    issue_receipt: bool
    negative_receipt: bool
    completion_receipt: bool
    stale_evidence_quarantined: bool


def _u8(v: int) -> bytes:
    if not 0 <= v <= 0xFF:
        raise ValueError(v)
    return struct.pack(">B", v)


def _bool(v: bool) -> bytes:
    return _u8(1 if v else 0)


def authority_key(incarnation: int, queue_epoch: int) -> tuple[int, int]:
    return incarnation, queue_epoch


def successor_identity_valid(
    last_incarnation: int,
    last_queue_epoch: int,
    new_incarnation: int,
    new_queue_epoch: int,
) -> bool:
    if not all(0 <= v <= 0xFF for v in (last_incarnation, last_queue_epoch, new_incarnation, new_queue_epoch)):
        return False
    if last_queue_epoch != 0xFF:
        return new_incarnation == last_incarnation and new_queue_epoch == last_queue_epoch + 1
    if last_incarnation != 0xFF:
        return new_incarnation == last_incarnation + 1 and new_queue_epoch == 0
    return False


def canonical_payload(s: QueueEpochWrapCheckpointV33) -> bytes:
    return b"".join(
        [
            DOMAIN,
            BASE_V32_DIGEST,
            _bool(s.runtime_ready),
            _bool(s.slot_pending),
            _u8(s.live_incarnation),
            _u8(s.live_queue_epoch),
            _u8(s.live_command_id),
            _u8(s.live_execution_epoch),
            _u8(s.live_effect_id),
            _u8(s.effect_state),
            _bool(s.durable_slot_valid),
            _u8(s.durable_incarnation),
            _u8(s.durable_queue_epoch),
            _u8(s.durable_command_id),
            _u8(s.durable_execution_epoch),
            _u8(s.durable_effect_id),
            _bool(s.last_retired_valid),
            _u8(s.last_retired_incarnation),
            _u8(s.last_retired_queue_epoch),
            _bool(s.checkpoint_valid),
            _bool(s.checkpoint_pending),
            _u8(s.checkpoint_incarnation),
            _u8(s.checkpoint_queue_epoch),
            _u8(s.checkpoint_command_id),
            _u8(s.checkpoint_execution_epoch),
            _u8(s.checkpoint_effect_id),
            _u8(s.checkpoint_effect_state),
            _bool(s.issue_receipt),
            _bool(s.negative_receipt),
            _bool(s.completion_receipt),
            _bool(s.stale_evidence_quarantined),
        ]
    )


def canonical_digest(s: QueueEpochWrapCheckpointV33) -> str:
    return hashlib.sha256(canonical_payload(s)).hexdigest()


def authority_consistent(s: QueueEpochWrapCheckpointV33) -> bool:
    if s.effect_state not in (UNISSUED, UNKNOWN, COMMITTED, NOT_COMMITTED):
        return False
    if s.checkpoint_effect_state not in (UNISSUED, UNKNOWN, COMMITTED, NOT_COMMITTED):
        return False

    receipts = int(s.issue_receipt) + int(s.negative_receipt) + int(s.completion_receipt)
    if receipts > 1:
        return False

    if s.slot_pending and not s.durable_slot_valid:
        return False

    if s.durable_slot_valid:
        if s.live_incarnation != s.durable_incarnation:
            return False
        if s.live_queue_epoch != s.durable_queue_epoch:
            return False
        if s.live_command_id != s.durable_command_id:
            return False
        if s.live_execution_epoch != s.durable_execution_epoch:
            return False
        if s.live_effect_id != s.durable_effect_id:
            return False
        if s.last_retired_valid and not successor_identity_valid(
            s.last_retired_incarnation,
            s.last_retired_queue_epoch,
            s.durable_incarnation,
            s.durable_queue_epoch,
        ):
            return False

    if s.effect_state == UNKNOWN and not s.issue_receipt:
        return False
    if s.effect_state == COMMITTED and not s.completion_receipt:
        return False
    if s.effect_state == NOT_COMMITTED and not s.negative_receipt:
        return False
    if s.effect_state == UNISSUED and s.runtime_ready and receipts:
        return False

    if s.checkpoint_pending and not s.checkpoint_valid:
        return False

    if s.checkpoint_valid and s.checkpoint_pending:
        current = (
            s.durable_slot_valid
            and s.checkpoint_incarnation == s.durable_incarnation
            and s.checkpoint_queue_epoch == s.durable_queue_epoch
        )
        stale = (
            s.last_retired_valid
            and authority_key(s.checkpoint_incarnation, s.checkpoint_queue_epoch)
            <= authority_key(s.last_retired_incarnation, s.last_retired_queue_epoch)
        )
        if not (current or stale):
            return False

    return True

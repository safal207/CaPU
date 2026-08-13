from __future__ import annotations

import hashlib
import struct
from dataclasses import dataclass

DOMAIN = b"CAPU:VCML:QUEUE-EPOCH-SLOT-REUSE:V0.32\x00"
BASE_V31_DIGEST = bytes.fromhex("b9f2a008513d6676e3c279f49ae25c4fb189f452672d6fee608face6318e729c")
UNISSUED, UNKNOWN, COMMITTED, NOT_COMMITTED = range(4)


@dataclass(frozen=True)
class QueueEpochSlotCheckpointV32:
    runtime_ready: bool
    slot_pending: bool
    live_queue_epoch: int
    live_command_id: int
    live_execution_epoch: int
    live_effect_id: int
    effect_state: int

    durable_slot_valid: bool
    durable_queue_epoch: int
    durable_command_id: int
    durable_execution_epoch: int
    durable_effect_id: int

    last_retired_valid: bool
    last_retired_queue_epoch: int

    checkpoint_valid: bool
    checkpoint_pending: bool
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


def canonical_payload(s: QueueEpochSlotCheckpointV32) -> bytes:
    return b"".join(
        [
            DOMAIN,
            BASE_V31_DIGEST,
            _bool(s.runtime_ready),
            _bool(s.slot_pending),
            _u8(s.live_queue_epoch),
            _u8(s.live_command_id),
            _u8(s.live_execution_epoch),
            _u8(s.live_effect_id),
            _u8(s.effect_state),
            _bool(s.durable_slot_valid),
            _u8(s.durable_queue_epoch),
            _u8(s.durable_command_id),
            _u8(s.durable_execution_epoch),
            _u8(s.durable_effect_id),
            _bool(s.last_retired_valid),
            _u8(s.last_retired_queue_epoch),
            _bool(s.checkpoint_valid),
            _bool(s.checkpoint_pending),
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


def canonical_digest(s: QueueEpochSlotCheckpointV32) -> str:
    return hashlib.sha256(canonical_payload(s)).hexdigest()


def authority_consistent(s: QueueEpochSlotCheckpointV32) -> bool:
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
        if s.live_queue_epoch != s.durable_queue_epoch:
            return False
        if s.live_command_id != s.durable_command_id:
            return False
        if s.live_execution_epoch != s.durable_execution_epoch:
            return False
        if s.live_effect_id != s.durable_effect_id:
            return False
        if s.last_retired_valid:
            if s.last_retired_queue_epoch == 0xFF:
                return False
            if s.durable_queue_epoch != s.last_retired_queue_epoch + 1:
                return False

    if s.effect_state == UNKNOWN and not s.issue_receipt:
        return False
    if s.effect_state == COMMITTED and not s.completion_receipt:
        return False
    if s.effect_state == NOT_COMMITTED and not s.negative_receipt:
        return False
    if s.effect_state == UNISSUED and receipts:
        return False

    if s.checkpoint_pending and not s.checkpoint_valid:
        return False

    if s.checkpoint_valid and s.checkpoint_pending:
        # The checkpoint may be current, or deliberately stale from a retired
        # predecessor epoch. It may not describe a future/unrelated epoch.
        current = s.durable_slot_valid and s.checkpoint_queue_epoch == s.durable_queue_epoch
        stale = s.last_retired_valid and s.checkpoint_queue_epoch <= s.last_retired_queue_epoch
        if not (current or stale):
            return False

    return True

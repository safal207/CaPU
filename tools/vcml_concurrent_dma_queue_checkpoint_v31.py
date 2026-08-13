from __future__ import annotations

import hashlib
import struct
from dataclasses import dataclass
from typing import Iterable, Tuple

DOMAIN = b"CAPU:VCML:CONCURRENT-DMA-QUEUE-RECOVERY:V0.31\x00"
BASE_V30_DIGEST = bytes.fromhex("116e51eed5468aebd1bc51aa6d9cfcf946a09384e0ead0db8fdd1fe69ccc4da9")
FRAGMENT_MASKS = (0b0011, 0b0100, 0b1000, 0b0110)
FRAGMENT_TX = (0, 0, 1, 1)
UNISSUED, UNKNOWN, COMMITTED, NOT_COMMITTED = range(4)


@dataclass(frozen=True)
class ConcurrentDMAQueueCheckpointV31:
    runtime_ready: bool
    tx_pending: Tuple[bool, bool]
    tx_retired: Tuple[bool, bool]
    live_queue_epoch: int
    live_command_ids: Tuple[int, int]
    live_execution_epochs: Tuple[int, int]
    live_effect_ids: Tuple[int, int]
    fragment_states: Tuple[int, int, int, int]

    durable_tx_valid: Tuple[bool, bool]
    durable_queue_epoch: int
    durable_command_ids: Tuple[int, int]
    durable_execution_epochs: Tuple[int, int]
    durable_effect_ids: Tuple[int, int]

    checkpoint_valid: bool
    checkpoint_tx_pending: Tuple[bool, bool]
    checkpoint_tx_retired: Tuple[bool, bool]
    checkpoint_queue_epoch: int
    checkpoint_command_ids: Tuple[int, int]
    checkpoint_execution_epochs: Tuple[int, int]
    checkpoint_effect_ids: Tuple[int, int]
    checkpoint_fragment_states: Tuple[int, int, int, int]
    checkpoint_owner_valid: int
    checkpoint_owner_map: Tuple[int, int, int, int]

    issue_receipt_bitmap: int
    negative_receipt_bitmap: int
    completion_receipt_bitmap: int
    durable_owner_valid: int
    durable_owner_map: Tuple[int, int, int, int]


def _u8(v: int) -> bytes:
    if not 0 <= v <= 0xFF:
        raise ValueError(v)
    return struct.pack(">B", v)


def _bool(v: bool) -> bytes:
    return _u8(1 if v else 0)


def _vec(values: Iterable[int], length: int, max_value: int) -> bytes:
    vals = tuple(values)
    if len(vals) != length or any(v < 0 or v > max_value for v in vals):
        raise ValueError(vals)
    return bytes(vals)


def _bool_vec(values: Iterable[bool], length: int) -> bytes:
    vals = tuple(values)
    if len(vals) != length:
        raise ValueError(vals)
    return bytes(1 if v else 0 for v in vals)


def canonical_payload(s: ConcurrentDMAQueueCheckpointV31) -> bytes:
    return b"".join(
        [
            DOMAIN,
            BASE_V30_DIGEST,
            bytes(FRAGMENT_MASKS),
            bytes(FRAGMENT_TX),
            _bool(s.runtime_ready),
            _bool_vec(s.tx_pending, 2),
            _bool_vec(s.tx_retired, 2),
            _u8(s.live_queue_epoch),
            _vec(s.live_command_ids, 2, 0xFF),
            _vec(s.live_execution_epochs, 2, 0xFF),
            _vec(s.live_effect_ids, 2, 0xFF),
            _vec(s.fragment_states, 4, 3),
            _bool_vec(s.durable_tx_valid, 2),
            _u8(s.durable_queue_epoch),
            _vec(s.durable_command_ids, 2, 0xFF),
            _vec(s.durable_execution_epochs, 2, 0xFF),
            _vec(s.durable_effect_ids, 2, 0xFF),
            _bool(s.checkpoint_valid),
            _bool_vec(s.checkpoint_tx_pending, 2),
            _bool_vec(s.checkpoint_tx_retired, 2),
            _u8(s.checkpoint_queue_epoch),
            _vec(s.checkpoint_command_ids, 2, 0xFF),
            _vec(s.checkpoint_execution_epochs, 2, 0xFF),
            _vec(s.checkpoint_effect_ids, 2, 0xFF),
            _vec(s.checkpoint_fragment_states, 4, 3),
            _u8(s.checkpoint_owner_valid),
            _vec(s.checkpoint_owner_map, 4, 3),
            _u8(s.issue_receipt_bitmap),
            _u8(s.negative_receipt_bitmap),
            _u8(s.completion_receipt_bitmap),
            _u8(s.durable_owner_valid),
            _vec(s.durable_owner_map, 4, 3),
        ]
    )


def canonical_digest(s: ConcurrentDMAQueueCheckpointV31) -> str:
    return hashlib.sha256(canonical_payload(s)).hexdigest()


def authority_consistent(s: ConcurrentDMAQueueCheckpointV31) -> bool:
    if s.durable_tx_valid[1] and not s.durable_tx_valid[0]:
        return False

    if any(s.durable_tx_valid):
        if s.live_queue_epoch != s.durable_queue_epoch:
            return False

    for tx in range(2):
        base = tx * 2
        slot_receipts = (s.issue_receipt_bitmap | s.negative_receipt_bitmap | s.completion_receipt_bitmap) & (0b11 << base)

        if (s.tx_pending[tx] or s.tx_retired[tx] or slot_receipts) and not s.durable_tx_valid[tx]:
            return False

        if s.durable_tx_valid[tx]:
            if s.live_command_ids[tx] != s.durable_command_ids[tx]:
                return False
            if s.live_execution_epochs[tx] != s.durable_execution_epochs[tx]:
                return False
            if s.live_effect_ids[tx] != s.durable_effect_ids[tx]:
                return False

        if s.tx_retired[tx] and s.tx_pending[tx]:
            return False
        if s.tx_retired[tx]:
            if (s.completion_receipt_bitmap & (0b11 << base)) != (0b11 << base):
                return False

        # If a slot was already active in the checkpoint, its checkpoint identity
        # must agree with the durable slot record. A stale checkpoint may simply
        # predate the younger slot and therefore contain no TX1 identity at all.
        if s.checkpoint_valid and s.checkpoint_tx_pending[tx]:
            if not s.durable_tx_valid[tx]:
                return False
            if s.checkpoint_command_ids[tx] != s.durable_command_ids[tx]:
                return False
            if s.checkpoint_execution_epochs[tx] != s.durable_execution_epochs[tx]:
                return False
            if s.checkpoint_effect_ids[tx] != s.durable_effect_ids[tx]:
                return False
            if s.checkpoint_queue_epoch != s.durable_queue_epoch:
                return False

    if s.tx_retired[1] and not s.tx_retired[0]:
        return False

    for frag, state in enumerate(s.fragment_states):
        bit = 1 << frag
        if state == COMMITTED and not (s.completion_receipt_bitmap & bit):
            return False
        if state == UNKNOWN and not (s.issue_receipt_bitmap & bit):
            return False
        if state == NOT_COMMITTED and not (s.negative_receipt_bitmap & bit):
            return False
        if state == COMMITTED and (s.issue_receipt_bitmap & bit):
            return False

    if s.fragment_states[3] != UNISSUED and not s.tx_retired[0]:
        if s.fragment_states[0] != COMMITTED or s.fragment_states[1] != COMMITTED:
            return False

    for lane, owner in enumerate(s.durable_owner_map):
        if s.durable_owner_valid & (1 << lane):
            if not (s.completion_receipt_bitmap & (1 << owner)):
                return False
            if not s.durable_tx_valid[FRAGMENT_TX[owner]]:
                return False
            if not (FRAGMENT_MASKS[owner] & (1 << lane)):
                return False

    return True

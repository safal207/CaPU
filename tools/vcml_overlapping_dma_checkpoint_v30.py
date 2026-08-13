from __future__ import annotations

import hashlib
import struct
from dataclasses import dataclass
from typing import Iterable, Tuple

DOMAIN = b"CAPU:VCML:OVERLAPPING-DMA-FRAGMENT-RECOVERY:V0.30\x00"
BASE_V29_DIGEST = bytes.fromhex("d5d75cc5050f6971bf1115aea89787f2c66eee212090fd5bb8de7295b8e1014d")
FRAGMENT_MASKS = (0b0011, 0b0110, 0b1100, 0b1001)
UNISSUED, UNKNOWN, COMMITTED, NOT_COMMITTED = range(4)


@dataclass(frozen=True)
class OverlappingFragmentCheckpointV30:
    runtime_ready: bool
    command_pending: bool
    live_command_id: int
    live_execution_epoch: int
    live_effect_id: int
    fragment_states: Tuple[int, int, int, int]

    checkpoint_valid: bool
    checkpoint_command_pending: bool
    checkpoint_command_id: int
    checkpoint_execution_epoch: int
    checkpoint_effect_id: int
    checkpoint_fragment_states: Tuple[int, int, int, int]
    checkpoint_owner_valid: int
    checkpoint_owner_map: Tuple[int, int, int, int]

    issue_receipt_bitmap: int
    negative_receipt_bitmap: int
    completion_receipt_bitmap: int
    receipt_command_id: int
    receipt_execution_epoch: int
    receipt_effect_id: int

    durable_owner_valid: int
    durable_owner_map: Tuple[int, int, int, int]


def _u8(v: int) -> bytes:
    if not 0 <= v <= 0xFF:
        raise ValueError(v)
    return struct.pack(">B", v)


def _bool(v: bool) -> bytes:
    return _u8(1 if v else 0)


def _vec(values: Iterable[int], max_value: int) -> bytes:
    vals = tuple(values)
    if len(vals) != 4 or any(v < 0 or v > max_value for v in vals):
        raise ValueError(vals)
    return bytes(vals)


def canonical_payload(s: OverlappingFragmentCheckpointV30) -> bytes:
    return b"".join(
        [
            DOMAIN,
            BASE_V29_DIGEST,
            bytes(FRAGMENT_MASKS),
            _bool(s.runtime_ready),
            _bool(s.command_pending),
            _u8(s.live_command_id),
            _u8(s.live_execution_epoch),
            _u8(s.live_effect_id),
            _vec(s.fragment_states, 3),
            _bool(s.checkpoint_valid),
            _bool(s.checkpoint_command_pending),
            _u8(s.checkpoint_command_id),
            _u8(s.checkpoint_execution_epoch),
            _u8(s.checkpoint_effect_id),
            _vec(s.checkpoint_fragment_states, 3),
            _u8(s.checkpoint_owner_valid),
            _vec(s.checkpoint_owner_map, 3),
            _u8(s.issue_receipt_bitmap),
            _u8(s.negative_receipt_bitmap),
            _u8(s.completion_receipt_bitmap),
            _u8(s.receipt_command_id),
            _u8(s.receipt_execution_epoch),
            _u8(s.receipt_effect_id),
            _u8(s.durable_owner_valid),
            _vec(s.durable_owner_map, 3),
        ]
    )


def canonical_digest(s: OverlappingFragmentCheckpointV30) -> str:
    return hashlib.sha256(canonical_payload(s)).hexdigest()


def authority_consistent(s: OverlappingFragmentCheckpointV30) -> bool:
    ids_match = (
        s.receipt_command_id == s.live_command_id
        and s.receipt_execution_epoch == s.live_execution_epoch
        and s.receipt_effect_id == s.live_effect_id
    )
    if (s.issue_receipt_bitmap or s.negative_receipt_bitmap or s.completion_receipt_bitmap or s.durable_owner_valid) and not ids_match:
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

    for lane, owner in enumerate(s.durable_owner_map):
        if s.durable_owner_valid & (1 << lane):
            if not (s.completion_receipt_bitmap & (1 << owner)):
                return False
            if not (FRAGMENT_MASKS[owner] & (1 << lane)):
                return False
    return True

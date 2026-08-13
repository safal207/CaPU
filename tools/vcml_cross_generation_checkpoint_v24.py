from __future__ import annotations

from dataclasses import dataclass
from hashlib import sha256
import struct

DOMAIN = b"CAPU:VCML:CROSS-GENERATION-REORDERING:V0.24\0"

@dataclass(frozen=True)
class CrossGenerationState:
    base_v23_digest: bytes
    last_retired_valid: int
    last_retired_generation: int
    pending: int
    pending_generation: int
    asid: int
    translation_epoch: int
    vpn: int
    required_harts: int
    delivered_bitmap: int
    ack_bitmap: int
    quarantined_delivery_bitmap: int
    quarantined_ack_bitmap: int
    quarantine_events: int


def encode(state: CrossGenerationState) -> bytes:
    if len(state.base_v23_digest) != 32:
        raise ValueError("base_v23_digest must be 32 bytes")
    fields = [
        state.last_retired_valid,
        state.last_retired_generation,
        state.pending,
        state.pending_generation,
        state.asid,
        state.translation_epoch,
        state.vpn,
        state.required_harts,
        state.delivered_bitmap,
        state.ack_bitmap,
        state.quarantined_delivery_bitmap,
        state.quarantined_ack_bitmap,
        state.quarantine_events,
    ]
    if any(x < 0 or x > 255 for x in fields):
        raise ValueError("canonical reduced fields must fit one byte")
    return DOMAIN + state.base_v23_digest + struct.pack(">13B", *fields)


def digest(state: CrossGenerationState) -> bytes:
    return sha256(encode(state)).digest()


def digest_hex(state: CrossGenerationState) -> str:
    return digest(state).hex()


def verify(state: CrossGenerationState, expected: bytes) -> bool:
    return digest(state) == expected

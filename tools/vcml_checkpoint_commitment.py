#!/usr/bin/env python3
"""Canonical CaPU v0.13 checkpoint content commitment helpers.

The reference implementation computes SHA-256 outside the RTL critical path.
Hardware v0.13 binds the resulting commitment to checkpoint prepare, persistence,
anchor commit and anchored recovery. This module does not authenticate storage,
prove durability, or make SHA-256 a hardware primitive.
"""

from __future__ import annotations

import hashlib
from typing import Any, Mapping

from tools.vcml_replay_snapshot import validate_replay_snapshot

SCHEMA = "capu.vcml.checkpoint-content.v0.13"
DOMAIN = b"CaPU-vCML-checkpoint-content-v0.13\x00"


def _fixed_uint(value: int, width_bits: int, label: str) -> bytes:
    if width_bits < 1:
        raise ValueError(f"{label} width must be >= 1")
    value = int(value)
    if value < 0 or value >= (1 << width_bits):
        raise ValueError(f"{label} {value} exceeds {width_bits}-bit width")
    return value.to_bytes((width_bits + 7) // 8, "big")


def canonical_snapshot_refs(
    snapshot: Mapping[str, Any], *, slots: int
) -> list[int]:
    """Return a semantic-set canonical ordering for the replay snapshot."""

    validate_replay_snapshot(snapshot)
    if slots < 1:
        raise ValueError("slots must be >= 1")
    refs = sorted(int(value) for value in snapshot["spent_refs"])
    if len(refs) > slots:
        raise ValueError("snapshot does not fit requested hardware slots")
    return refs


def canonical_payload(
    snapshot: Mapping[str, Any],
    *,
    checkpoint_ref: int,
    checkpoint_epoch: int,
    checkpoint_ref_width: int = 16,
    checkpoint_epoch_width: int = 16,
    authorization_ref_width: int = 16,
    slots: int = 4,
) -> bytes:
    """Encode the recovery-relevant replay state in one deterministic form.

    Invalid slots are canonicalized to zero and occupied authorization refs are
    sorted numerically because replay semantics treat them as a set rather than
    as an ordered log. The checkpoint identity is domain-bound into the digest.
    """

    refs = canonical_snapshot_refs(snapshot, slots=slots)
    if checkpoint_ref == 0:
        raise ValueError("checkpoint_ref must be non-zero")
    if checkpoint_epoch == 0:
        raise ValueError("checkpoint_epoch must be non-zero")
    if authorization_ref_width < 1:
        raise ValueError("authorization_ref_width must be >= 1")
    if slots > 0xFFFF:
        raise ValueError("slots exceed canonical encoding limit")

    out = bytearray(DOMAIN)
    out.extend(checkpoint_ref_width.to_bytes(2, "big"))
    out.extend(checkpoint_epoch_width.to_bytes(2, "big"))
    out.extend(authorization_ref_width.to_bytes(2, "big"))
    out.extend(slots.to_bytes(2, "big"))
    out.extend(_fixed_uint(checkpoint_ref, checkpoint_ref_width, "checkpoint_ref"))
    out.extend(_fixed_uint(checkpoint_epoch, checkpoint_epoch_width, "checkpoint_epoch"))
    out.extend(len(refs).to_bytes(2, "big"))

    for index in range(slots):
        occupied = index < len(refs)
        out.append(1 if occupied else 0)
        ref = refs[index] if occupied else 0
        out.extend(_fixed_uint(ref, authorization_ref_width, "authorization_ref"))

    return bytes(out)


def checkpoint_commitment_bytes(snapshot: Mapping[str, Any], **kwargs: Any) -> bytes:
    return hashlib.sha256(canonical_payload(snapshot, **kwargs)).digest()


def checkpoint_commitment_hex(snapshot: Mapping[str, Any], **kwargs: Any) -> str:
    return checkpoint_commitment_bytes(snapshot, **kwargs).hex()


def verify_checkpoint_commitment(
    snapshot: Mapping[str, Any], commitment_hex: str, **kwargs: Any
) -> bool:
    try:
        supplied = bytes.fromhex(commitment_hex)
    except ValueError:
        return False
    expected = checkpoint_commitment_bytes(snapshot, **kwargs)
    return len(supplied) == len(expected) and hashlib.sha256(supplied).digest() == hashlib.sha256(expected).digest()

#!/usr/bin/env python3
"""Canonical CaPU v0.14 full causal checkpoint helpers.

v0.14 extends the v0.13 replay-state commitment with committed causal-head
state. SHA-256 remains outside the RTL critical path. The canonical snapshot
contains only authoritative committed state; speculative/buffered fields are
not accepted by this schema.
"""

from __future__ import annotations

import hashlib
import hmac
from typing import Any, Mapping

from tools.vcml_replay_snapshot import SCHEMA as REPLAY_SCHEMA
from tools.vcml_replay_snapshot import validate_replay_snapshot

SCHEMA = "capu.vcml.causal-checkpoint.v0.14"
DOMAIN = b"CaPU-vCML-causal-checkpoint-v0.14\x00"
_ALLOWED_KEYS = {
    "schema",
    "capacity",
    "spent_refs",
    "causal_head_valid",
    "causal_head_transition_id",
    "causal_head_gen",
    "sealed_chain",
}


def _fixed_uint(value: int, width_bits: int, label: str) -> bytes:
    if width_bits < 1:
        raise ValueError(f"{label} width must be >= 1")
    value = int(value)
    if value < 0 or value >= (1 << width_bits):
        raise ValueError(f"{label} {value} exceeds {width_bits}-bit width")
    return value.to_bytes((width_bits + 7) // 8, "big")


def build_causal_snapshot(
    replay_snapshot: Mapping[str, Any],
    *,
    causal_head_valid: bool,
    causal_head_transition_id: int,
    causal_head_gen: int,
    sealed_chain: bool,
) -> dict[str, Any]:
    """Project replay state plus committed causal-head state into v0.14."""

    validate_replay_snapshot(replay_snapshot)
    snapshot = {
        "schema": SCHEMA,
        "capacity": int(replay_snapshot["capacity"]),
        "spent_refs": [int(v) for v in replay_snapshot["spent_refs"]],
        "causal_head_valid": bool(causal_head_valid),
        "causal_head_transition_id": int(causal_head_transition_id),
        "causal_head_gen": int(causal_head_gen),
        "sealed_chain": bool(sealed_chain),
    }
    validate_causal_snapshot(snapshot)
    return snapshot


def validate_causal_snapshot(snapshot: Mapping[str, Any]) -> None:
    if snapshot.get("schema") != SCHEMA:
        raise ValueError("unsupported causal checkpoint schema")

    unknown = set(snapshot.keys()) - _ALLOWED_KEYS
    if unknown:
        raise ValueError(
            "unsupported/non-authoritative causal checkpoint fields: "
            + ", ".join(sorted(unknown))
        )

    replay_view = {
        "schema": REPLAY_SCHEMA,
        "capacity": int(snapshot.get("capacity", 0)),
        "spent_refs": [int(v) for v in snapshot.get("spent_refs", [])],
    }
    validate_replay_snapshot(replay_view)

    head_valid = bool(snapshot.get("causal_head_valid", False))
    head_id = int(snapshot.get("causal_head_transition_id", 0))
    head_gen = int(snapshot.get("causal_head_gen", 0))
    sealed = bool(snapshot.get("sealed_chain", False))

    if head_id < 0:
        raise ValueError("causal_head_transition_id must be non-negative")
    if head_gen < 0 or head_gen > 0xF:
        raise ValueError("causal_head_gen must fit the committed 4-bit GEN field")

    # Empty causal state has one canonical representation. This prevents
    # ambiguous cold-start encodings such as head_valid=0 with stale head bytes.
    if not head_valid and (head_id != 0 or head_gen != 0 or sealed):
        raise ValueError(
            "head_valid=false requires transition_id=0, GEN=0 and sealed_chain=false"
        )


def canonical_payload(
    snapshot: Mapping[str, Any],
    *,
    checkpoint_ref: int,
    checkpoint_epoch: int,
    checkpoint_ref_width: int = 16,
    checkpoint_epoch_width: int = 16,
    transition_id_width: int = 64,
    authorization_ref_width: int = 16,
    slots: int = 4,
) -> bytes:
    """Encode only checkpoint-authoritative replay + causal committed state."""

    validate_causal_snapshot(snapshot)
    if slots < 1:
        raise ValueError("slots must be >= 1")
    if slots > 0xFFFF:
        raise ValueError("slots exceed canonical encoding limit")
    if checkpoint_ref == 0:
        raise ValueError("checkpoint_ref must be non-zero")
    if checkpoint_epoch == 0:
        raise ValueError("checkpoint_epoch must be non-zero")

    refs = sorted(int(v) for v in snapshot["spent_refs"])
    if len(refs) > slots:
        raise ValueError("snapshot does not fit requested hardware slots")

    out = bytearray(DOMAIN)
    out.extend(checkpoint_ref_width.to_bytes(2, "big"))
    out.extend(checkpoint_epoch_width.to_bytes(2, "big"))
    out.extend(transition_id_width.to_bytes(2, "big"))
    out.extend(authorization_ref_width.to_bytes(2, "big"))
    out.extend(slots.to_bytes(2, "big"))
    out.extend(_fixed_uint(checkpoint_ref, checkpoint_ref_width, "checkpoint_ref"))
    out.extend(_fixed_uint(checkpoint_epoch, checkpoint_epoch_width, "checkpoint_epoch"))

    head_valid = bool(snapshot["causal_head_valid"])
    out.append(1 if head_valid else 0)
    out.extend(
        _fixed_uint(
            int(snapshot["causal_head_transition_id"]),
            transition_id_width,
            "causal_head_transition_id",
        )
    )
    out.append(int(snapshot["causal_head_gen"]))
    out.append(1 if bool(snapshot["sealed_chain"]) else 0)

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
    return len(supplied) == len(expected) and hmac.compare_digest(supplied, expected)

#!/usr/bin/env python3
"""Canonical CaPU v0.17 architectural + causal checkpoint helpers."""

from __future__ import annotations

import hashlib
import hmac
from typing import Any, Mapping

from tools.vcml_causal_checkpoint_v14 import (
    SCHEMA as CAUSAL_SCHEMA,
    validate_causal_snapshot,
)

SCHEMA = "capu.vcml.arch-checkpoint.v0.17"
DOMAIN = b"CaPU-vCML-arch-checkpoint-v0.17\x00"
_ALLOWED_KEYS = {
    "schema",
    "capacity",
    "spent_refs",
    "causal_head_valid",
    "causal_head_transition_id",
    "causal_head_gen",
    "sealed_chain",
    "recovery_epoch",
    "pc",
    "gprs",
    "status",
}


def _fixed_uint(value: int, width_bits: int, label: str) -> bytes:
    if width_bits < 1:
        raise ValueError(f"{label} width must be >= 1")
    value = int(value)
    if value < 0 or value >= (1 << width_bits):
        raise ValueError(f"{label} {value} exceeds {width_bits}-bit width")
    return value.to_bytes((width_bits + 7) // 8, "big")


def build_arch_snapshot(
    causal_snapshot: Mapping[str, Any],
    *,
    recovery_epoch: int,
    pc: int,
    gprs: list[int] | tuple[int, int, int, int],
    status: int,
) -> dict[str, Any]:
    """Project authoritative causal/replay and architectural state into v0.17."""

    validate_causal_snapshot(causal_snapshot)
    snapshot = {
        "schema": SCHEMA,
        "capacity": int(causal_snapshot["capacity"]),
        "spent_refs": [int(v) for v in causal_snapshot["spent_refs"]],
        "causal_head_valid": bool(causal_snapshot["causal_head_valid"]),
        "causal_head_transition_id": int(
            causal_snapshot["causal_head_transition_id"]
        ),
        "causal_head_gen": int(causal_snapshot["causal_head_gen"]),
        "sealed_chain": bool(causal_snapshot["sealed_chain"]),
        "recovery_epoch": int(recovery_epoch),
        "pc": int(pc),
        "gprs": [int(v) for v in gprs],
        "status": int(status),
    }
    validate_arch_snapshot(snapshot)
    return snapshot


def validate_arch_snapshot(snapshot: Mapping[str, Any]) -> None:
    if snapshot.get("schema") != SCHEMA:
        raise ValueError("unsupported architectural checkpoint schema")
    unknown = set(snapshot.keys()) - _ALLOWED_KEYS
    if unknown:
        raise ValueError(
            "unsupported/non-authoritative architectural checkpoint fields: "
            + ", ".join(sorted(unknown))
        )

    causal_view = {
        "schema": CAUSAL_SCHEMA,
        "capacity": int(snapshot.get("capacity", 0)),
        "spent_refs": [int(v) for v in snapshot.get("spent_refs", [])],
        "causal_head_valid": bool(snapshot.get("causal_head_valid", False)),
        "causal_head_transition_id": int(
            snapshot.get("causal_head_transition_id", 0)
        ),
        "causal_head_gen": int(snapshot.get("causal_head_gen", 0)),
        "sealed_chain": bool(snapshot.get("sealed_chain", False)),
    }
    validate_causal_snapshot(causal_view)

    if int(snapshot.get("recovery_epoch", 0)) <= 0:
        raise ValueError("recovery_epoch must be non-zero")
    if int(snapshot.get("pc", -1)) < 0:
        raise ValueError("pc must be non-negative")
    gprs = snapshot.get("gprs")
    if not isinstance(gprs, (list, tuple)) or len(gprs) != 4:
        raise ValueError("gprs must contain exactly four architectural registers")
    if any(int(value) < 0 for value in gprs):
        raise ValueError("GPR values must be non-negative")
    if int(snapshot.get("status", -1)) < 0:
        raise ValueError("status must be non-negative")


def canonical_payload(
    snapshot: Mapping[str, Any],
    *,
    checkpoint_ref: int,
    checkpoint_epoch: int,
    checkpoint_ref_width: int = 16,
    checkpoint_epoch_width: int = 16,
    recovery_epoch_width: int = 8,
    pc_width: int = 16,
    data_width: int = 32,
    transition_id_width: int = 64,
    authorization_ref_width: int = 16,
    slots: int = 4,
) -> bytes:
    """Encode the one authoritative v0.17 checkpoint record."""

    validate_arch_snapshot(snapshot)
    if slots < 1 or slots > 0xFFFF:
        raise ValueError("slots must be in range 1..65535")
    if checkpoint_ref == 0 or checkpoint_epoch == 0:
        raise ValueError("checkpoint identity fields must be non-zero")

    refs = sorted(int(v) for v in snapshot["spent_refs"])
    if len(refs) > slots:
        raise ValueError("snapshot does not fit requested hardware slots")

    out = bytearray(DOMAIN)
    for width in (
        checkpoint_ref_width,
        checkpoint_epoch_width,
        recovery_epoch_width,
        pc_width,
        data_width,
        transition_id_width,
        authorization_ref_width,
        slots,
    ):
        out.extend(int(width).to_bytes(2, "big"))

    out.extend(_fixed_uint(checkpoint_ref, checkpoint_ref_width, "checkpoint_ref"))
    out.extend(_fixed_uint(checkpoint_epoch, checkpoint_epoch_width, "checkpoint_epoch"))
    out.extend(
        _fixed_uint(
            snapshot["recovery_epoch"], recovery_epoch_width, "recovery_epoch"
        )
    )
    out.extend(_fixed_uint(snapshot["pc"], pc_width, "pc"))
    for index, value in enumerate(snapshot["gprs"]):
        out.extend(_fixed_uint(value, data_width, f"gpr{index}"))
    out.extend(_fixed_uint(snapshot["status"], 8, "status"))

    out.append(1 if snapshot["causal_head_valid"] else 0)
    out.extend(
        _fixed_uint(
            snapshot["causal_head_transition_id"],
            transition_id_width,
            "causal_head_transition_id",
        )
    )
    out.append(int(snapshot["causal_head_gen"]))
    out.append(1 if snapshot["sealed_chain"] else 0)

    out.extend(len(refs).to_bytes(2, "big"))
    for index in range(slots):
        occupied = index < len(refs)
        out.append(1 if occupied else 0)
        out.extend(
            _fixed_uint(
                refs[index] if occupied else 0,
                authorization_ref_width,
                "authorization_ref",
            )
        )
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

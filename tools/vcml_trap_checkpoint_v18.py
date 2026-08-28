#!/usr/bin/env python3
"""Canonical CaPU v0.18 trap/privilege checkpoint helpers."""

from __future__ import annotations

import hashlib
import hmac
from typing import Any, Mapping

from tools.vcml_arch_checkpoint_v17 import (
    SCHEMA as ARCH_SCHEMA,
    canonical_payload as arch_canonical_payload,
    validate_arch_snapshot,
)

SCHEMA = "capu.vcml.trap-privilege-checkpoint.v0.18"
DOMAIN = b"CaPU-vCML-trap-privilege-checkpoint-v0.18\x00"
_TRAP_KEYS = {
    "privilege_mode",
    "trap_pending",
    "trap_is_interrupt",
    "trap_cause",
    "trap_return_pc",
    "trap_return_privilege",
    "interrupt_mask",
}
_ARCH_KEYS = {
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
_ALLOWED_KEYS = {"schema"} | _ARCH_KEYS | _TRAP_KEYS


def _fixed_uint(value: int, width_bits: int, label: str) -> bytes:
    if width_bits < 1:
        raise ValueError(f"{label} width must be >= 1")
    value = int(value)
    if value < 0 or value >= (1 << width_bits):
        raise ValueError(f"{label} {value} exceeds {width_bits}-bit width")
    return value.to_bytes((width_bits + 7) // 8, "big")


def _arch_view(snapshot: Mapping[str, Any]) -> dict[str, Any]:
    return {
        "schema": ARCH_SCHEMA,
        "capacity": int(snapshot["capacity"]),
        "spent_refs": [int(v) for v in snapshot["spent_refs"]],
        "causal_head_valid": bool(snapshot["causal_head_valid"]),
        "causal_head_transition_id": int(snapshot["causal_head_transition_id"]),
        "causal_head_gen": int(snapshot["causal_head_gen"]),
        "sealed_chain": bool(snapshot["sealed_chain"]),
        "recovery_epoch": int(snapshot["recovery_epoch"]),
        "pc": int(snapshot["pc"]),
        "gprs": [int(v) for v in snapshot["gprs"]],
        "status": int(snapshot["status"]),
    }


def build_trap_snapshot(
    arch_snapshot: Mapping[str, Any],
    *,
    privilege_mode: int,
    trap_pending: bool,
    trap_is_interrupt: bool,
    trap_cause: int,
    trap_return_pc: int,
    trap_return_privilege: int,
    interrupt_mask: bool,
) -> dict[str, Any]:
    """Extend one authoritative v0.17 record with bounded trap/privilege state."""

    validate_arch_snapshot(arch_snapshot)
    snapshot = {
        "schema": SCHEMA,
        **{key: arch_snapshot[key] for key in _ARCH_KEYS},
        "spent_refs": [int(v) for v in arch_snapshot["spent_refs"]],
        "gprs": [int(v) for v in arch_snapshot["gprs"]],
        "privilege_mode": int(privilege_mode),
        "trap_pending": bool(trap_pending),
        "trap_is_interrupt": bool(trap_is_interrupt),
        "trap_cause": int(trap_cause),
        "trap_return_pc": int(trap_return_pc),
        "trap_return_privilege": int(trap_return_privilege),
        "interrupt_mask": bool(interrupt_mask),
    }
    validate_trap_snapshot(snapshot)
    return snapshot


def validate_trap_snapshot(snapshot: Mapping[str, Any]) -> None:
    if snapshot.get("schema") != SCHEMA:
        raise ValueError("unsupported trap/privilege checkpoint schema")
    unknown = set(snapshot.keys()) - _ALLOWED_KEYS
    if unknown:
        raise ValueError(
            "unsupported/non-authoritative trap checkpoint fields: "
            + ", ".join(sorted(unknown))
        )

    validate_arch_snapshot(_arch_view(snapshot))

    privilege = int(snapshot.get("privilege_mode", -1))
    return_privilege = int(snapshot.get("trap_return_privilege", -1))
    if privilege < 0 or privilege > 3:
        raise ValueError("privilege_mode must fit the bounded 2-bit privilege model")
    if return_privilege < 0 or return_privilege > 3:
        raise ValueError("trap_return_privilege must fit the bounded 2-bit privilege model")
    if int(snapshot.get("trap_cause", -1)) < 0:
        raise ValueError("trap_cause must be non-negative")
    if int(snapshot.get("trap_return_pc", -1)) < 0:
        raise ValueError("trap_return_pc must be non-negative")

    trap_pending = bool(snapshot.get("trap_pending", False))
    if not trap_pending:
        if bool(snapshot.get("trap_is_interrupt", False)):
            raise ValueError("trap_is_interrupt requires trap_pending")
        if int(snapshot.get("trap_cause", 0)) != 0:
            raise ValueError("non-zero trap_cause requires trap_pending")
        if int(snapshot.get("trap_return_pc", 0)) != 0:
            raise ValueError("trap_return_pc must be zero without pending trap")
        if return_privilege != 0:
            raise ValueError("trap_return_privilege must be zero without pending trap")


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
    privilege_width: int = 2,
    cause_width: int = 8,
) -> bytes:
    """Encode the v0.17 record and the exact bounded trap context as one v0.18 record."""

    validate_trap_snapshot(snapshot)
    base = arch_canonical_payload(
        _arch_view(snapshot),
        checkpoint_ref=checkpoint_ref,
        checkpoint_epoch=checkpoint_epoch,
        checkpoint_ref_width=checkpoint_ref_width,
        checkpoint_epoch_width=checkpoint_epoch_width,
        recovery_epoch_width=recovery_epoch_width,
        pc_width=pc_width,
        data_width=data_width,
        transition_id_width=transition_id_width,
        authorization_ref_width=authorization_ref_width,
        slots=slots,
    )

    out = bytearray(DOMAIN)
    out.extend(len(base).to_bytes(4, "big"))
    out.extend(base)
    out.extend(int(privilege_width).to_bytes(2, "big"))
    out.extend(int(cause_width).to_bytes(2, "big"))
    out.extend(_fixed_uint(snapshot["privilege_mode"], privilege_width, "privilege_mode"))
    out.append(1 if snapshot["trap_pending"] else 0)
    out.append(1 if snapshot["trap_is_interrupt"] else 0)
    out.extend(_fixed_uint(snapshot["trap_cause"], cause_width, "trap_cause"))
    out.extend(_fixed_uint(snapshot["trap_return_pc"], pc_width, "trap_return_pc"))
    out.extend(
        _fixed_uint(
            snapshot["trap_return_privilege"], privilege_width, "trap_return_privilege"
        )
    )
    out.append(1 if snapshot["interrupt_mask"] else 0)
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

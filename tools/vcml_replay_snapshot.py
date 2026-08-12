#!/usr/bin/env python3
"""vCML -> CaPU v0.10 replay-state recovery snapshot helpers.

This module does not authenticate records or make persistence claims. It projects
an already-scoped, trusted vCML retirement history into the finite spent-ref
snapshot consumed by the v0.10 hardware recovery guard.
"""

from __future__ import annotations

from typing import Iterable, Mapping, Any

SCHEMA = "capu.vcml.replay-snapshot.v0.10"


def _root_ref(record: Mapping[str, Any]) -> int | None:
    if not bool(record.get("root_authorized", False)):
        return None
    ref = int(record.get("root_authorization_ref", 0))
    if ref == 0:
        raise ValueError("authorized root record has zero authorization ref")
    return ref


def build_replay_snapshot(records: Iterable[Mapping[str, Any]], capacity: int = 4) -> dict[str, Any]:
    if capacity < 1:
        raise ValueError("capacity must be >= 1")

    spent_refs: list[int] = []
    seen: set[int] = set()
    for record in records:
        ref = _root_ref(record)
        if ref is None:
            continue
        if ref in seen:
            raise ValueError(f"duplicate retired root authorization ref: {ref}")
        seen.add(ref)
        spent_refs.append(ref)
        if len(spent_refs) > capacity:
            raise ValueError("replay snapshot exceeds hardware capacity")

    return {
        "schema": SCHEMA,
        "capacity": capacity,
        "spent_refs": spent_refs,
    }


def validate_replay_snapshot(snapshot: Mapping[str, Any]) -> None:
    if snapshot.get("schema") != SCHEMA:
        raise ValueError("unsupported replay snapshot schema")

    capacity = int(snapshot.get("capacity", 0))
    if capacity < 1:
        raise ValueError("snapshot capacity must be >= 1")

    refs = [int(value) for value in snapshot.get("spent_refs", [])]
    if len(refs) > capacity:
        raise ValueError("snapshot contains more refs than capacity")
    if any(ref == 0 for ref in refs):
        raise ValueError("zero is not a valid spent authorization ref")
    if len(set(refs)) != len(refs):
        raise ValueError("snapshot contains duplicate authorization refs")


def encode_restore_vectors(
    snapshot: Mapping[str, Any],
    *,
    ref_width: int = 16,
    slots: int = 4,
) -> tuple[int, int]:
    """Return ``(valid_mask, flattened_refs)`` for the RTL restore bus.

    Slot 0 occupies the least-significant ``ref_width`` bits, matching the
    SystemVerilog indexed part-select used by ``capu_replay_recovery_guard``.
    """

    validate_replay_snapshot(snapshot)
    if ref_width < 1 or slots < 1:
        raise ValueError("ref_width and slots must be >= 1")

    refs = [int(value) for value in snapshot["spent_refs"]]
    if len(refs) > slots:
        raise ValueError("snapshot does not fit requested hardware slots")

    limit = 1 << ref_width
    valid_mask = 0
    flattened_refs = 0
    for index, ref in enumerate(refs):
        if ref >= limit:
            raise ValueError(f"authorization ref {ref} exceeds {ref_width}-bit width")
        valid_mask |= 1 << index
        flattened_refs |= ref << (index * ref_width)

    return valid_mask, flattened_refs

#!/usr/bin/env python3
"""Deterministic CaPU retirement event -> vCML-style causal record bridge.

RTL carries compact causal metadata; this module expands a retired STORE event
into the minimal vCML-style record used by the CaPU/CML experiment.

This is a semantic adapter, not a policy engine and not cryptographic lineage
proof. The integrity field seals emitted record bytes only. v0.8 carries a
root-qualified trusted authorization decision plus an opaque authorization
reference and policy epoch. Those fields provide provenance binding, not proof
of signer identity, freshness, capability validity, or upstream policy quality.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import sys
import time
from dataclasses import dataclass
from typing import Any, Mapping


U8_MAX = (1 << 8) - 1
U16_MAX = (1 << 16) - 1
U64_MAX = (1 << 64) - 1


@dataclass(frozen=True)
class CausalStoreEvent:
    address: int
    data: int
    ctag: int
    transition_id: int
    parent_ref: int
    root_authorized: bool = False
    root_authorization_ref: int = 0
    root_policy_epoch: int = 0

    @staticmethod
    def from_mapping(raw: Mapping[str, Any]) -> "CausalStoreEvent":
        raw_root_authorized = raw.get("root_authorized", False)
        if not isinstance(raw_root_authorized, bool):
            raise ValueError("root_authorized must be a JSON boolean")

        event = CausalStoreEvent(
            address=int(raw["address"]),
            data=int(raw["data"]),
            ctag=int(raw["ctag"]),
            transition_id=int(raw["transition_id"]),
            parent_ref=int(raw["parent_ref"]),
            root_authorized=raw_root_authorized,
            root_authorization_ref=int(raw.get("root_authorization_ref", 0)),
            root_policy_epoch=int(raw.get("root_policy_epoch", 0)),
        )
        event.validate()
        return event

    def validate(self) -> None:
        if self.address < 0:
            raise ValueError("address must be non-negative")
        if self.data < 0:
            raise ValueError("data must be non-negative")
        if not 0 <= self.ctag <= U16_MAX:
            raise ValueError("ctag must fit the canonical 16-bit CML CTAG field")
        if not 0 <= self.transition_id <= U64_MAX:
            raise ValueError("transition_id must fit the v0 64-bit hardware reference")
        if not 0 <= self.parent_ref <= U64_MAX:
            raise ValueError("parent_ref must fit the v0 64-bit hardware reference")
        if not isinstance(self.root_authorized, bool):
            raise ValueError("root_authorized must be boolean")
        if not 0 <= self.root_authorization_ref <= U16_MAX:
            raise ValueError("root_authorization_ref must fit the v0.8 16-bit provenance reference")
        if not 0 <= self.root_policy_epoch <= U8_MAX:
            raise ValueError("root_policy_epoch must fit the v0.8 8-bit policy epoch")
        if self.root_authorized and self.root_authorization_ref == 0:
            raise ValueError("authorized root evidence requires a non-zero root_authorization_ref")
        if not self.root_authorized and (
            self.root_authorization_ref != 0 or self.root_policy_epoch != 0
        ):
            raise ValueError("non-root/unauthorized evidence must not carry root authorization provenance")


def transition_ref(value: int) -> str:
    if not 0 <= value <= U64_MAX:
        raise ValueError("transition reference must fit 64 bits")
    return f"capu-transition:{value:016x}"


def _canonical_bytes(record_without_integrity: Mapping[str, Any]) -> bytes:
    return json.dumps(
        record_without_integrity,
        sort_keys=True,
        separators=(",", ":"),
        ensure_ascii=False,
    ).encode("utf-8")


def _integrity(record_without_integrity: Mapping[str, Any]) -> str:
    digest = hashlib.sha256(_canonical_bytes(record_without_integrity)).hexdigest()
    return f"sha256:{digest}"


def build_vcml_record(
    event: CausalStoreEvent,
    *,
    actor: Mapping[str, Any],
    permitted_by: str,
    timestamp_ns: int | None = None,
) -> dict[str, Any]:
    """Expand a retired CaPU STORE event into a vCML-style causal record.

    `parent_ref == 0` maps to `parent_cause = None`. The caller remains
    responsible for interpreting whether that event is a legitimate root or a
    causal gap. Root authorization provenance mirrors the retirement evidence;
    this adapter does not authenticate or freshness-check its upstream source.
    """

    event.validate()
    if "pid" not in actor or "uid" not in actor:
        raise ValueError("actor must contain pid and uid for vCML compatibility")
    if not isinstance(permitted_by, str) or not permitted_by:
        raise ValueError("permitted_by must be a non-empty semantic reference")

    ts = time.time_ns() if timestamp_ns is None else int(timestamp_ns)
    if ts < 0:
        raise ValueError("timestamp_ns must be non-negative")

    parent_cause = None if event.parent_ref == 0 else transition_ref(event.parent_ref)

    record: dict[str, Any] = {
        "id": transition_ref(event.transition_id),
        "timestamp": ts,
        "actor": dict(actor),
        "action": "write",
        "object": {
            "address": event.address,
            "data": event.data,
        },
        "permitted_by": permitted_by,
        "parent_cause": parent_cause,
        "ctag": event.ctag,
        "root_authorized": event.root_authorized,
        "root_authorization_ref": event.root_authorization_ref,
        "root_policy_epoch": event.root_policy_epoch,
    }
    record["integrity"] = _integrity(record)
    return record


def verify_parent_projection(event: CausalStoreEvent, record: Mapping[str, Any]) -> bool:
    expected = None if event.parent_ref == 0 else transition_ref(event.parent_ref)
    return record.get("parent_cause") == expected


def verify_root_authorization_projection(
    event: CausalStoreEvent, record: Mapping[str, Any]
) -> bool:
    return (
        record.get("root_authorized") is event.root_authorized
        and record.get("root_authorization_ref") == event.root_authorization_ref
        and record.get("root_policy_epoch") == event.root_policy_epoch
    )


def verify_integrity(record: Mapping[str, Any]) -> bool:
    actual = record.get("integrity")
    if not isinstance(actual, str):
        return False
    unsigned = dict(record)
    unsigned.pop("integrity", None)
    return actual == _integrity(unsigned)


def _main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "input",
        nargs="?",
        help="JSON input file; omit or use '-' to read stdin",
    )
    args = parser.parse_args(argv)

    if args.input and args.input != "-":
        with open(args.input, "r", encoding="utf-8") as handle:
            payload = json.load(handle)
    else:
        payload = json.load(sys.stdin)

    event = CausalStoreEvent.from_mapping(payload["event"])
    record = build_vcml_record(
        event,
        actor=payload["actor"],
        permitted_by=payload["permitted_by"],
        timestamp_ns=payload.get("timestamp_ns"),
    )
    print(json.dumps(record, sort_keys=True, separators=(",", ":")))
    return 0


if __name__ == "__main__":
    raise SystemExit(_main())

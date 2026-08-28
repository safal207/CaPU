#!/usr/bin/env python3
import hashlib
import json

SCHEMA = "capu.hardware.multihart-shootdown-checkpoint.v0.22"

FIELDS = (
    "base_checkpoint_digest",
    "shootdown_pending",
    "shootdown_generation",
    "asid",
    "translation_epoch",
    "vpn",
    "required_harts",
    "ack_bitmap",
)


def canonical_payload(state: dict) -> bytes:
    missing = [k for k in FIELDS if k not in state]
    if missing:
        raise ValueError(f"missing fields: {missing}")
    payload = {"schema": SCHEMA}
    for key in FIELDS:
        payload[key] = state[key]
    return json.dumps(payload, sort_keys=True, separators=(",", ":")).encode("utf-8")


def checkpoint_digest(state: dict) -> str:
    return hashlib.sha256(canonical_payload(state)).hexdigest()


def verify(state: dict, expected_digest: str) -> bool:
    return checkpoint_digest(state) == expected_digest

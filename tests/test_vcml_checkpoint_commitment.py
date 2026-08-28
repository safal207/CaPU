#!/usr/bin/env python3

import pathlib
import sys

ROOT = pathlib.Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))

from tools.vcml_checkpoint_commitment import (  # noqa: E402
    SCHEMA,
    canonical_payload,
    checkpoint_commitment_hex,
    verify_checkpoint_commitment,
)
from tools.vcml_replay_snapshot import SCHEMA as REPLAY_SCHEMA  # noqa: E402


def expect_raises(fn, text: str) -> None:
    try:
        fn()
    except ValueError as exc:
        assert text in str(exc), (text, str(exc))
    else:
        raise AssertionError(f"expected ValueError containing {text!r}")


def snapshot(refs: list[int]) -> dict:
    return {"schema": REPLAY_SCHEMA, "capacity": 4, "spent_refs": refs}


def main() -> None:
    assert SCHEMA == "capu.vcml.checkpoint-content.v0.13"

    a = snapshot([0xA120, 0xA110])
    b = snapshot([0xA110, 0xA120])
    digest_a = checkpoint_commitment_hex(a, checkpoint_ref=0xC001, checkpoint_epoch=7)
    digest_b = checkpoint_commitment_hex(b, checkpoint_ref=0xC001, checkpoint_epoch=7)
    assert digest_a == digest_b
    assert len(digest_a) == 64
    print("PASS commitment_semantic_set_canonical")

    payload_a = canonical_payload(a, checkpoint_ref=0xC001, checkpoint_epoch=7)
    payload_b = canonical_payload(b, checkpoint_ref=0xC001, checkpoint_epoch=7)
    assert payload_a == payload_b
    print("PASS canonical_payload_deterministic")

    tampered = snapshot([0xA110, 0xA130])
    assert checkpoint_commitment_hex(tampered, checkpoint_ref=0xC001, checkpoint_epoch=7) != digest_a
    assert not verify_checkpoint_commitment(
        tampered, digest_a, checkpoint_ref=0xC001, checkpoint_epoch=7
    )
    print("PASS spent_ref_tamper_detected")

    assert checkpoint_commitment_hex(a, checkpoint_ref=0xC002, checkpoint_epoch=7) != digest_a
    assert checkpoint_commitment_hex(a, checkpoint_ref=0xC001, checkpoint_epoch=8) != digest_a
    print("PASS checkpoint_identity_bound")

    assert verify_checkpoint_commitment(a, digest_a, checkpoint_ref=0xC001, checkpoint_epoch=7)
    assert not verify_checkpoint_commitment(a, "00" * 32, checkpoint_ref=0xC001, checkpoint_epoch=7)
    assert not verify_checkpoint_commitment(a, "not-hex", checkpoint_ref=0xC001, checkpoint_epoch=7)
    print("PASS commitment_verification")

    expect_raises(
        lambda: checkpoint_commitment_hex(a, checkpoint_ref=0, checkpoint_epoch=7),
        "checkpoint_ref must be non-zero",
    )
    expect_raises(
        lambda: checkpoint_commitment_hex(a, checkpoint_ref=0xC001, checkpoint_epoch=0),
        "checkpoint_epoch must be non-zero",
    )
    print("PASS zero_checkpoint_identity_rejected")

    expect_raises(
        lambda: checkpoint_commitment_hex(
            {"schema": REPLAY_SCHEMA, "capacity": 4, "spent_refs": [0xA110, 0xA110]},
            checkpoint_ref=0xC001,
            checkpoint_epoch=7,
        ),
        "duplicate authorization refs",
    )
    print("PASS malformed_replay_snapshot_rejected")

    print("VCML_CHECKPOINT_COMMITMENT_V13_PASS")


if __name__ == "__main__":
    main()

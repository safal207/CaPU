#!/usr/bin/env python3

from copy import deepcopy
from pathlib import Path
import sys

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from tools.vcml_arch_checkpoint_v17 import (
    build_arch_snapshot,
    checkpoint_commitment_hex,
    validate_arch_snapshot,
    verify_checkpoint_commitment,
)
from tools.vcml_causal_checkpoint_v14 import build_causal_snapshot
from tools.vcml_replay_snapshot import SCHEMA as REPLAY_SCHEMA


def digest(snapshot):
    return checkpoint_commitment_hex(
        snapshot,
        checkpoint_ref=0x41,
        checkpoint_epoch=8,
        checkpoint_ref_width=8,
        checkpoint_epoch_width=8,
        recovery_epoch_width=8,
        pc_width=16,
        data_width=16,
        transition_id_width=16,
        authorization_ref_width=16,
        slots=4,
    )


def main() -> None:
    causal = build_causal_snapshot(
        {"schema": REPLAY_SCHEMA, "capacity": 4, "spent_refs": [0xA120, 0xA110]},
        causal_head_valid=True,
        causal_head_transition_id=0x2201,
        causal_head_gen=6,
        sealed_chain=False,
    )
    reordered_causal = build_causal_snapshot(
        {"schema": REPLAY_SCHEMA, "capacity": 4, "spent_refs": [0xA110, 0xA120]},
        causal_head_valid=True,
        causal_head_transition_id=0x2201,
        causal_head_gen=6,
        sealed_chain=False,
    )
    base = build_arch_snapshot(
        causal,
        recovery_epoch=0x21,
        pc=0x40,
        gprs=[0, 0x80, 0x55, 0],
        status=0xA5,
    )
    reordered = build_arch_snapshot(
        reordered_causal,
        recovery_epoch=0x21,
        pc=0x40,
        gprs=[0, 0x80, 0x55, 0],
        status=0xA5,
    )
    base_digest = digest(base)
    assert base_digest == digest(reordered), "spent-set order must canonicalize"

    for field, value in (
        ("pc", 0x41),
        ("status", 0xA4),
        ("recovery_epoch", 0x22),
        ("causal_head_transition_id", 0x2202),
        ("causal_head_gen", 7),
        ("sealed_chain", True),
    ):
        changed = deepcopy(base)
        changed[field] = value
        assert base_digest != digest(changed), f"{field} must be committed"

    for index in range(4):
        changed = deepcopy(base)
        changed["gprs"][index] ^= 1
        assert base_digest != digest(changed), f"GPR{index} must be committed"

    changed_replay = deepcopy(base)
    changed_replay["spent_refs"] = [0xA110, 0xA130]
    assert base_digest != digest(changed_replay), "replay spent-set must be committed"

    assert verify_checkpoint_commitment(
        base,
        base_digest,
        checkpoint_ref=0x41,
        checkpoint_epoch=8,
        checkpoint_ref_width=8,
        checkpoint_epoch_width=8,
        recovery_epoch_width=8,
        pc_width=16,
        data_width=16,
        transition_id_width=16,
        authorization_ref_width=16,
        slots=4,
    )

    mixed = deepcopy(base)
    mixed["pc"] = 0x99
    assert not verify_checkpoint_commitment(
        mixed,
        base_digest,
        checkpoint_ref=0x41,
        checkpoint_epoch=8,
        checkpoint_ref_width=8,
        checkpoint_epoch_width=8,
        recovery_epoch_width=8,
        pc_width=16,
        data_width=16,
        transition_id_width=16,
        authorization_ref_width=16,
        slots=4,
    ), "valid causal state plus foreign architectural state must fail"

    speculative = deepcopy(base)
    speculative["buffered_transition_id"] = 0xDEAD
    try:
        validate_arch_snapshot(speculative)
    except ValueError as exc:
        assert "non-authoritative" in str(exc)
    else:
        raise AssertionError("speculative state must not enter the v0.17 schema")

    print(f"canonical_digest={base_digest}")
    print("pc_change_digest_changed=1")
    print("gpr_change_digest_changed=1")
    print("status_change_digest_changed=1")
    print("recovery_epoch_change_digest_changed=1")
    print("causal_change_digest_changed=1")
    print("mixed_snapshot_rejected=1")
    print("VCML_ARCH_CHECKPOINT_V17_PASS")


if __name__ == "__main__":
    main()

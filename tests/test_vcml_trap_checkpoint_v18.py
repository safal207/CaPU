#!/usr/bin/env python3

from copy import deepcopy
from pathlib import Path
import sys

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from tools.vcml_arch_checkpoint_v17 import build_arch_snapshot
from tools.vcml_causal_checkpoint_v14 import build_causal_snapshot
from tools.vcml_replay_snapshot import SCHEMA as REPLAY_SCHEMA
from tools.vcml_trap_checkpoint_v18 import (
    build_trap_snapshot,
    checkpoint_commitment_hex,
    validate_trap_snapshot,
    verify_checkpoint_commitment,
)


def digest(snapshot):
    return checkpoint_commitment_hex(
        snapshot,
        checkpoint_ref=0x52,
        checkpoint_epoch=9,
        checkpoint_ref_width=8,
        checkpoint_epoch_width=8,
        recovery_epoch_width=8,
        pc_width=16,
        data_width=16,
        transition_id_width=16,
        authorization_ref_width=16,
        slots=4,
        privilege_width=2,
        cause_width=8,
    )


def verify(snapshot, commitment):
    return verify_checkpoint_commitment(
        snapshot,
        commitment,
        checkpoint_ref=0x52,
        checkpoint_epoch=9,
        checkpoint_ref_width=8,
        checkpoint_epoch_width=8,
        recovery_epoch_width=8,
        pc_width=16,
        data_width=16,
        transition_id_width=16,
        authorization_ref_width=16,
        slots=4,
        privilege_width=2,
        cause_width=8,
    )


def main() -> None:
    causal = build_causal_snapshot(
        {"schema": REPLAY_SCHEMA, "capacity": 4, "spent_refs": [0xA110, 0xA120]},
        causal_head_valid=True,
        causal_head_transition_id=0x3301,
        causal_head_gen=7,
        sealed_chain=False,
    )
    arch = build_arch_snapshot(
        causal,
        recovery_epoch=0x31,
        pc=0x80,
        gprs=[0, 0x90, 0x66, 0],
        status=0xA5,
    )
    base = build_trap_snapshot(
        arch,
        privilege_mode=1,
        trap_pending=False,
        trap_is_interrupt=False,
        trap_cause=0,
        trap_return_pc=0,
        trap_return_privilege=0,
        interrupt_mask=True,
    )
    base_digest = digest(base)
    assert verify(base, base_digest)

    for field, value in (
        ("privilege_mode", 3),
        ("interrupt_mask", False),
        ("pc", 0x81),
        ("causal_head_transition_id", 0x3302),
        ("recovery_epoch", 0x32),
    ):
        changed = deepcopy(base)
        changed[field] = value
        assert base_digest != digest(changed), f"{field} must be committed by v0.18"

    trapped = build_trap_snapshot(
        arch,
        privilege_mode=3,
        trap_pending=True,
        trap_is_interrupt=False,
        trap_cause=5,
        trap_return_pc=0x80,
        trap_return_privilege=1,
        interrupt_mask=True,
    )
    trapped_digest = digest(trapped)
    assert trapped_digest != base_digest
    for field, value in (
        ("trap_is_interrupt", True),
        ("trap_cause", 6),
        ("trap_return_pc", 0x81),
        ("trap_return_privilege", 0),
    ):
        changed = deepcopy(trapped)
        changed[field] = value
        assert trapped_digest != digest(changed), f"{field} must be committed by v0.18"

    # Same valid v0.17 architectural/causal bytes plus foreign trap context cannot
    # verify under the original v0.18 checkpoint authority.
    mixed = deepcopy(base)
    mixed.update({
        "privilege_mode": trapped["privilege_mode"],
        "trap_pending": trapped["trap_pending"],
        "trap_is_interrupt": trapped["trap_is_interrupt"],
        "trap_cause": trapped["trap_cause"],
        "trap_return_pc": trapped["trap_return_pc"],
        "trap_return_privilege": trapped["trap_return_privilege"],
    })
    assert not verify(mixed, base_digest), "foreign trap context must fail exact authority"

    invalid = deepcopy(base)
    invalid["trap_pending"] = False
    invalid["trap_cause"] = 1
    try:
        validate_trap_snapshot(invalid)
    except ValueError as exc:
        assert "trap_cause" in str(exc)
    else:
        raise AssertionError("non-canonical idle trap context must fail")

    speculative = deepcopy(base)
    speculative["speculative_effect_pending"] = True
    try:
        validate_trap_snapshot(speculative)
    except ValueError as exc:
        assert "non-authoritative" in str(exc)
    else:
        raise AssertionError("speculative state must not enter v0.18 authority")

    print(f"canonical_digest={base_digest}")
    print("privilege_change_digest_changed=1")
    print("trap_context_change_digest_changed=1")
    print("interrupt_mask_change_digest_changed=1")
    print("architectural_change_digest_changed=1")
    print("causal_change_digest_changed=1")
    print("mixed_trap_snapshot_rejected=1")
    print("VCML_TRAP_CHECKPOINT_V18_PASS")


if __name__ == "__main__":
    main()

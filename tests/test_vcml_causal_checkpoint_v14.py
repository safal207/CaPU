#!/usr/bin/env python3

from copy import deepcopy
from pathlib import Path
import sys

# The test is executed as a script from tests/. Make the repository root an
# explicit import root instead of relying on runner-specific PYTHONPATH state.
sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from tools.vcml_causal_checkpoint_v14 import (
    build_causal_snapshot,
    checkpoint_commitment_hex,
    validate_causal_snapshot,
    verify_checkpoint_commitment,
)
from tools.vcml_replay_snapshot import SCHEMA as REPLAY_SCHEMA


def replay(refs):
    return {"schema": REPLAY_SCHEMA, "capacity": 4, "spent_refs": list(refs)}


def digest(snapshot):
    return checkpoint_commitment_hex(
        snapshot,
        checkpoint_ref=0x31,
        checkpoint_epoch=7,
        checkpoint_ref_width=8,
        checkpoint_epoch_width=8,
        transition_id_width=16,
        authorization_ref_width=16,
        slots=4,
    )


def main() -> None:
    base = build_causal_snapshot(
        replay([0xA120, 0xA110]),
        causal_head_valid=True,
        causal_head_transition_id=0x2201,
        causal_head_gen=6,
        sealed_chain=False,
    )
    reordered = build_causal_snapshot(
        replay([0xA110, 0xA120]),
        causal_head_valid=True,
        causal_head_transition_id=0x2201,
        causal_head_gen=6,
        sealed_chain=False,
    )

    base_digest = digest(base)
    assert base_digest == digest(reordered), "spent-set ordering must canonicalize"

    changed_head = deepcopy(base)
    changed_head["causal_head_transition_id"] = 0x2202
    assert base_digest != digest(changed_head), "head identity must be committed"

    changed_gen = deepcopy(base)
    changed_gen["causal_head_gen"] = 7
    assert base_digest != digest(changed_gen), "GEN must be committed"

    changed_seal = deepcopy(base)
    changed_seal["sealed_chain"] = True
    assert base_digest != digest(changed_seal), "SEAL must be committed"

    changed_replay = deepcopy(base)
    changed_replay["spent_refs"] = [0xA110, 0xA130]
    assert base_digest != digest(changed_replay), "spent replay set must remain committed"

    assert verify_checkpoint_commitment(
        base,
        base_digest,
        checkpoint_ref=0x31,
        checkpoint_epoch=7,
        checkpoint_ref_width=8,
        checkpoint_epoch_width=8,
        transition_id_width=16,
        authorization_ref_width=16,
        slots=4,
    )
    assert not verify_checkpoint_commitment(
        changed_gen,
        base_digest,
        checkpoint_ref=0x31,
        checkpoint_epoch=7,
        checkpoint_ref_width=8,
        checkpoint_epoch_width=8,
        transition_id_width=16,
        authorization_ref_width=16,
        slots=4,
    )

    speculative = deepcopy(base)
    speculative["buffered_transition_id"] = 0xDEAD
    try:
        validate_causal_snapshot(speculative)
    except ValueError as exc:
        assert "non-authoritative" in str(exc)
    else:
        raise AssertionError("speculative/buffered fields must not enter the checkpoint schema")

    ambiguous_empty = {
        "schema": "capu.vcml.causal-checkpoint.v0.14",
        "capacity": 4,
        "spent_refs": [],
        "causal_head_valid": False,
        "causal_head_transition_id": 1,
        "causal_head_gen": 0,
        "sealed_chain": False,
    }
    try:
        validate_causal_snapshot(ambiguous_empty)
    except ValueError:
        pass
    else:
        raise AssertionError("invalid empty causal state must fail closed")

    print(f"canonical_digest={base_digest}")
    print("head_change_digest_changed=1")
    print("gen_change_digest_changed=1")
    print("seal_change_digest_changed=1")
    print("speculative_field_rejected=1")
    print("VCML_CAUSAL_CHECKPOINT_V14_PASS")


if __name__ == "__main__":
    main()

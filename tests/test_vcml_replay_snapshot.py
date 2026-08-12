#!/usr/bin/env python3

import pathlib
import sys

ROOT = pathlib.Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))

from tools.vcml_replay_snapshot import (  # noqa: E402
    SCHEMA,
    build_replay_snapshot,
    encode_restore_vectors,
    validate_replay_snapshot,
)


def expect_raises(fn, text: str) -> None:
    try:
        fn()
    except ValueError as exc:
        assert text in str(exc), (text, str(exc))
    else:
        raise AssertionError(f"expected ValueError containing {text!r}")


def main() -> None:
    empty = build_replay_snapshot([], capacity=4)
    assert empty == {"schema": SCHEMA, "capacity": 4, "spent_refs": []}
    print("PASS snapshot_empty")

    records = [
        {"root_authorized": True, "root_authorization_ref": 0xA110},
        {"root_authorized": False, "root_authorization_ref": 0},
        {"root_authorized": True, "root_authorization_ref": 0xA120},
    ]
    snapshot = build_replay_snapshot(records, capacity=4)
    assert snapshot["spent_refs"] == [0xA110, 0xA120]
    validate_replay_snapshot(snapshot)
    print("PASS snapshot_from_vcml_roots")

    mask, flat = encode_restore_vectors(snapshot, ref_width=16, slots=4)
    assert mask == 0b0011
    assert (flat & 0xFFFF) == 0xA110
    assert ((flat >> 16) & 0xFFFF) == 0xA120
    print("PASS snapshot_vector_encoding")

    expect_raises(
        lambda: build_replay_snapshot(
            [
                {"root_authorized": True, "root_authorization_ref": 0xA110},
                {"root_authorized": True, "root_authorization_ref": 0xA110},
            ],
            capacity=4,
        ),
        "duplicate retired root authorization ref",
    )
    print("PASS duplicate_history_rejected")

    expect_raises(
        lambda: build_replay_snapshot(
            [{"root_authorized": True, "root_authorization_ref": 0}],
            capacity=4,
        ),
        "zero authorization ref",
    )
    print("PASS zero_ref_history_rejected")

    expect_raises(
        lambda: build_replay_snapshot(
            [
                {"root_authorized": True, "root_authorization_ref": 1},
                {"root_authorized": True, "root_authorization_ref": 2},
                {"root_authorized": True, "root_authorization_ref": 3},
            ],
            capacity=2,
        ),
        "exceeds hardware capacity",
    )
    print("PASS snapshot_capacity_rejected")

    expect_raises(
        lambda: validate_replay_snapshot(
            {"schema": SCHEMA, "capacity": 4, "spent_refs": [0xA110, 0xA110]}
        ),
        "duplicate authorization refs",
    )
    print("PASS malformed_snapshot_rejected")

    expect_raises(
        lambda: encode_restore_vectors(
            {"schema": SCHEMA, "capacity": 4, "spent_refs": [0x1FF]},
            ref_width=8,
            slots=4,
        ),
        "exceeds 8-bit width",
    )
    print("PASS snapshot_width_rejected")

    print("VCML_REPLAY_SNAPSHOT_V10_PASS")


if __name__ == "__main__":
    main()

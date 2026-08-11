#!/usr/bin/env python3

import sys
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))

from tools.vcml_bridge import (  # noqa: E402
    CausalStoreEvent,
    build_vcml_record,
    transition_ref,
    verify_integrity,
    verify_parent_projection,
)


class VCMLBridgeTests(unittest.TestCase):
    def setUp(self) -> None:
        self.event = CausalStoreEvent(
            address=0x42,
            data=0xCAFE0042,
            ctag=0x4210,
            transition_id=0x42,
            parent_ref=0x11,
        )
        self.actor = {"pid": 4242, "uid": 1000, "comm": "capu-test"}

    def test_retired_parent_ref_maps_exactly_to_parent_cause(self) -> None:
        record = build_vcml_record(
            self.event,
            actor=self.actor,
            permitted_by="capu:causal_commit",
            timestamp_ns=123456789,
        )
        self.assertEqual(record["id"], transition_ref(0x42))
        self.assertEqual(record["parent_cause"], transition_ref(0x11))
        self.assertTrue(verify_parent_projection(self.event, record))

    def test_ctag_and_store_object_are_preserved(self) -> None:
        record = build_vcml_record(
            self.event,
            actor=self.actor,
            permitted_by="capu:causal_commit",
            timestamp_ns=123456789,
        )
        self.assertEqual(record["ctag"], 0x4210)
        self.assertEqual(record["action"], "write")
        self.assertEqual(record["object"], {"address": 0x42, "data": 0xCAFE0042})

    def test_integrity_seals_emitted_record(self) -> None:
        record = build_vcml_record(
            self.event,
            actor=self.actor,
            permitted_by="capu:causal_commit",
            timestamp_ns=123456789,
        )
        self.assertTrue(verify_integrity(record))

        tampered = dict(record)
        tampered["ctag"] = 0xFFFF
        self.assertFalse(verify_integrity(tampered))

    def test_same_input_is_deterministic_with_explicit_timestamp(self) -> None:
        kwargs = {
            "actor": self.actor,
            "permitted_by": "capu:causal_commit",
            "timestamp_ns": 123456789,
        }
        self.assertEqual(
            build_vcml_record(self.event, **kwargs),
            build_vcml_record(self.event, **kwargs),
        )

    def test_zero_parent_ref_maps_to_null_without_inventing_root_semantics(self) -> None:
        rootish = CausalStoreEvent(
            address=1,
            data=2,
            ctag=0x4210,
            transition_id=1,
            parent_ref=0,
        )
        record = build_vcml_record(
            rootish,
            actor={"pid": 1, "uid": 0},
            permitted_by="root_event:test",
            timestamp_ns=1,
        )
        self.assertIsNone(record["parent_cause"])
        self.assertTrue(verify_parent_projection(rootish, record))

    def test_ctag_must_fit_canonical_16_bit_field(self) -> None:
        bad = CausalStoreEvent(
            address=1,
            data=2,
            ctag=0x1_0000,
            transition_id=1,
            parent_ref=0,
        )
        with self.assertRaises(ValueError):
            build_vcml_record(
                bad,
                actor={"pid": 1, "uid": 0},
                permitted_by="root_event:test",
                timestamp_ns=1,
            )

    def test_actor_requires_vcml_pid_and_uid(self) -> None:
        with self.assertRaises(ValueError):
            build_vcml_record(
                self.event,
                actor={"pid": 1},
                permitted_by="capu:causal_commit",
                timestamp_ns=1,
            )


if __name__ == "__main__":
    unittest.main(verbosity=2)

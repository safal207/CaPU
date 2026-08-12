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
    verify_authorization_replay_window,
    verify_integrity,
    verify_parent_projection,
    verify_root_authorization_projection,
)


class VCMLBridgeTests(unittest.TestCase):
    def setUp(self) -> None:
        self.event = CausalStoreEvent(
            address=0x42,
            data=0xCAFE0042,
            ctag=0x4210,
            transition_id=0x42,
            parent_ref=0x11,
            root_authorized=False,
            root_authorization_ref=0,
            root_policy_epoch=0,
        )
        self.actor = {"pid": 4242, "uid": 1000, "comm": "capu-test"}

    def make_root(
        self,
        *,
        transition_id: int = 1,
        auth_ref: int = 0xA101,
        policy_epoch: int = 7,
    ) -> CausalStoreEvent:
        return CausalStoreEvent(
            address=transition_id,
            data=2,
            ctag=0x4200,
            transition_id=transition_id,
            parent_ref=0,
            root_authorized=True,
            root_authorization_ref=auth_ref,
            root_policy_epoch=policy_epoch,
        )

    def root_record(self, *, transition_id: int, auth_ref: int, policy_epoch: int) -> dict:
        return build_vcml_record(
            self.make_root(
                transition_id=transition_id,
                auth_ref=auth_ref,
                policy_epoch=policy_epoch,
            ),
            actor={"pid": 1, "uid": 0},
            permitted_by="capu:trusted-root-boundary",
            timestamp_ns=transition_id,
        )

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

    def test_root_authorization_provenance_projection_is_preserved(self) -> None:
        root = self.make_root()
        record = build_vcml_record(
            root,
            actor={"pid": 1, "uid": 0},
            permitted_by="capu:trusted-root-boundary",
            timestamp_ns=1,
        )
        self.assertTrue(record["root_authorized"])
        self.assertEqual(record["root_authorization_ref"], 0xA101)
        self.assertEqual(record["root_policy_epoch"], 7)
        self.assertTrue(verify_root_authorization_projection(root, record))
        self.assertIsNone(record["parent_cause"])

    def test_continuation_does_not_invent_root_authorization_provenance(self) -> None:
        record = build_vcml_record(
            self.event,
            actor=self.actor,
            permitted_by="capu:causal_commit",
            timestamp_ns=123456789,
        )
        self.assertFalse(record["root_authorized"])
        self.assertEqual(record["root_authorization_ref"], 0)
        self.assertEqual(record["root_policy_epoch"], 0)
        self.assertTrue(verify_root_authorization_projection(self.event, record))

    def test_integrity_seals_root_authorization_provenance(self) -> None:
        root = self.make_root()
        record = build_vcml_record(
            root,
            actor={"pid": 1, "uid": 0},
            permitted_by="capu:trusted-root-boundary",
            timestamp_ns=1,
        )
        self.assertTrue(verify_integrity(record))

        tampered_ref = dict(record)
        tampered_ref["root_authorization_ref"] = 0xA102
        self.assertFalse(verify_integrity(tampered_ref))

        tampered_epoch = dict(record)
        tampered_epoch["root_policy_epoch"] = 8
        self.assertFalse(verify_integrity(tampered_epoch))

        tampered_decision = dict(record)
        tampered_decision["root_authorized"] = False
        self.assertFalse(verify_integrity(tampered_decision))

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
            root_authorized=False,
            root_authorization_ref=0,
            root_policy_epoch=0,
        )
        record = build_vcml_record(
            rootish,
            actor={"pid": 1, "uid": 0},
            permitted_by="root_event:test",
            timestamp_ns=1,
        )
        self.assertIsNone(record["parent_cause"])
        self.assertFalse(record["root_authorized"])
        self.assertEqual(record["root_authorization_ref"], 0)
        self.assertTrue(verify_parent_projection(rootish, record))

    def test_authorized_event_requires_nonzero_authorization_ref(self) -> None:
        bad = CausalStoreEvent(
            address=1,
            data=2,
            ctag=0x4200,
            transition_id=1,
            parent_ref=0,
            root_authorized=True,
            root_authorization_ref=0,
            root_policy_epoch=1,
        )
        with self.assertRaises(ValueError):
            bad.validate()

    def test_unauthorized_event_cannot_carry_root_provenance(self) -> None:
        bad = CausalStoreEvent(
            address=1,
            data=2,
            ctag=0x4210,
            transition_id=1,
            parent_ref=1,
            root_authorized=False,
            root_authorization_ref=0x1234,
            root_policy_epoch=1,
        )
        with self.assertRaises(ValueError):
            bad.validate()

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

    def test_authorization_ref_and_policy_epoch_widths_are_checked(self) -> None:
        with self.assertRaises(ValueError):
            CausalStoreEvent(
                address=1, data=2, ctag=0x4200, transition_id=1, parent_ref=0,
                root_authorized=True, root_authorization_ref=0x1_0000, root_policy_epoch=1,
            ).validate()
        with self.assertRaises(ValueError):
            CausalStoreEvent(
                address=1, data=2, ctag=0x4200, transition_id=1, parent_ref=0,
                root_authorized=True, root_authorization_ref=1, root_policy_epoch=0x100,
            ).validate()

    def test_root_authorized_must_be_boolean_in_mapping(self) -> None:
        with self.assertRaises(ValueError):
            CausalStoreEvent.from_mapping(
                {
                    "address": 1,
                    "data": 2,
                    "ctag": 0x4200,
                    "transition_id": 1,
                    "parent_ref": 0,
                    "root_authorized": "true",
                    "root_authorization_ref": 1,
                    "root_policy_epoch": 0,
                }
            )

    def test_mapping_rejects_authorized_zero_ref(self) -> None:
        with self.assertRaises(ValueError):
            CausalStoreEvent.from_mapping(
                {
                    "address": 1,
                    "data": 2,
                    "ctag": 0x4200,
                    "transition_id": 1,
                    "parent_ref": 0,
                    "root_authorized": True,
                    "root_authorization_ref": 0,
                    "root_policy_epoch": 3,
                }
            )

    def test_actor_requires_vcml_pid_and_uid(self) -> None:
        with self.assertRaises(ValueError):
            build_vcml_record(
                self.event,
                actor={"pid": 1},
                permitted_by="capu:causal_commit",
                timestamp_ns=1,
            )

    def test_replay_window_rejects_duplicate_root_ref_even_with_new_policy_epoch(self) -> None:
        records = [
            self.root_record(transition_id=1, auth_ref=0xA101, policy_epoch=1),
            self.root_record(transition_id=2, auth_ref=0xA102, policy_epoch=2),
            self.root_record(transition_id=3, auth_ref=0xA101, policy_epoch=99),
        ]
        self.assertFalse(verify_authorization_replay_window(records, capacity=4))

    def test_replay_window_accepts_four_unique_refs_and_rejects_fifth(self) -> None:
        first_four = [
            self.root_record(transition_id=i, auth_ref=0xA100 + i, policy_epoch=i)
            for i in range(1, 5)
        ]
        self.assertTrue(verify_authorization_replay_window(first_four, capacity=4))

        fifth = self.root_record(transition_id=5, auth_ref=0xA105, policy_epoch=5)
        self.assertFalse(verify_authorization_replay_window([*first_four, fifth], capacity=4))

    def test_replay_window_allows_continuations_without_root_provenance(self) -> None:
        root = self.root_record(transition_id=1, auth_ref=0xA101, policy_epoch=1)
        continuation = build_vcml_record(
            self.event,
            actor=self.actor,
            permitted_by="capu:causal_commit",
            timestamp_ns=2,
        )
        self.assertTrue(verify_authorization_replay_window([root, continuation], capacity=4))

    def test_replay_window_rejects_invalid_capacity(self) -> None:
        with self.assertRaises(ValueError):
            verify_authorization_replay_window([], capacity=0)


if __name__ == "__main__":
    unittest.main(verbosity=2)

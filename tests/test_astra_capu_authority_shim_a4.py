from __future__ import annotations

import unittest
from dataclasses import replace

from tools.astra_capu_authority_shim_a4 import (
    AuthorityShimA4,
    BoundedAuthorityToken,
    RejectCode,
    ShimError,
    scenario_result,
)


class AuthorityShimA4Tests(unittest.TestCase):
    def setUp(self) -> None:
        self.token = BoundedAuthorityToken(0xA1, 2, 7, 1, 2, 0, 4)

    def test_exact_committed_token_forwards_once(self) -> None:
        shim = AuthorityShimA4()
        self.assertTrue(shim.load(self.token, committed=True))
        decision = shim.issue(self.token, external_commit=True)
        self.assertTrue(decision.forwarded)
        self.assertEqual(decision.reject_code, RejectCode.NONE)
        self.assertEqual(shim.effect_count, 1)

    def test_duplicate_attempt_is_physically_blocked(self) -> None:
        shim = AuthorityShimA4()
        shim.load(self.token, committed=True)
        shim.issue(self.token, external_commit=True)
        decision = shim.issue(self.token, external_commit=True)
        self.assertFalse(decision.forwarded)
        self.assertEqual(decision.reject_code, RejectCode.ALREADY_ISSUED)
        self.assertEqual(shim.effect_count, 1)

    def test_uncommitted_authority_is_blocked(self) -> None:
        shim = AuthorityShimA4()
        shim.load(self.token, committed=False)
        decision = shim.issue(self.token, external_commit=True)
        self.assertEqual(decision.reject_code, RejectCode.UNCOMMITTED)
        self.assertEqual(shim.effect_count, 0)

    def test_every_identity_dimension_is_checked(self) -> None:
        variants = (
            replace(self.token, authority_tag=0xA2),
            replace(self.token, queue_incarnation=3),
            replace(self.token, queue_epoch=8),
            replace(self.token, slot_id=2),
            replace(self.token, command_id=3),
            replace(self.token, attempt_id=1),
            replace(self.token, effect_id=5),
        )
        for stale in variants:
            with self.subTest(stale=stale):
                shim = AuthorityShimA4()
                shim.load(self.token, committed=True)
                decision = shim.issue(stale, external_commit=True)
                self.assertEqual(decision.reject_code, RejectCode.IDENTITY_MISMATCH)
                self.assertEqual(shim.effect_count, 0)

    def test_rejected_command_does_not_consume_current_attempt(self) -> None:
        shim = AuthorityShimA4()
        shim.load(self.token, committed=True)
        stale = replace(self.token, queue_epoch=8)
        self.assertEqual(shim.issue(stale, external_commit=True).reject_code, RejectCode.IDENTITY_MISMATCH)
        self.assertFalse(shim.attempt_spent)
        self.assertTrue(shim.issue(self.token, external_commit=False).forwarded)
        self.assertTrue(shim.attempt_spent)

    def test_revocation_requires_exact_token(self) -> None:
        shim = AuthorityShimA4()
        shim.load(self.token, committed=True)
        self.assertFalse(shim.revoke(replace(self.token, queue_epoch=8)))
        self.assertIsNotNone(shim.active)
        self.assertTrue(shim.revoke(self.token))
        self.assertIsNone(shim.active)
        self.assertEqual(shim.issue(self.token, external_commit=True).reject_code, RejectCode.NO_AUTHORITY)

    def test_successor_attempt_requires_new_token(self) -> None:
        shim = AuthorityShimA4()
        shim.load(self.token, committed=True)
        shim.issue(self.token, external_commit=False)
        successor = replace(self.token, attempt_id=1, authority_tag=0xA2)
        self.assertFalse(shim.load(successor, committed=True))
        self.assertTrue(shim.revoke(self.token))
        self.assertTrue(shim.load(successor, committed=True))
        self.assertTrue(shim.issue(successor, external_commit=True).forwarded)
        self.assertEqual(shim.effect_count, 1)

    def test_token_digest_binds_every_field(self) -> None:
        baseline = self.token.digest()
        for field, value in (
            ("authority_tag", 0xA2),
            ("queue_incarnation", 3),
            ("queue_epoch", 8),
            ("slot_id", 2),
            ("command_id", 3),
            ("attempt_id", 1),
            ("effect_id", 5),
        ):
            self.assertNotEqual(baseline, replace(self.token, **{field: value}).digest())

    def test_invalid_token_rejected(self) -> None:
        with self.assertRaises(ShimError):
            replace(self.token, queue_epoch=-1).validate()
        with self.assertRaises(ShimError):
            replace(self.token, effect_id=256).validate()

    def test_reference_scenario_is_discriminating(self) -> None:
        result = scenario_result()
        self.assertTrue(result["exact_forwarded"])
        self.assertEqual(result["duplicate_reject_code"], int(RejectCode.ALREADY_ISSUED))
        self.assertEqual(result["uncommitted_reject_code"], int(RejectCode.UNCOMMITTED))
        self.assertEqual(result["stale_identity_reject_code"], int(RejectCode.IDENTITY_MISMATCH))
        self.assertTrue(result["unknown_dispatch_forwarded"])
        self.assertEqual(result["same_attempt_replay_reject_code"], int(RejectCode.ALREADY_ISSUED))
        self.assertTrue(result["successor_attempt_forwarded"])
        self.assertEqual(result["revoked_reject_code"], int(RejectCode.NO_AUTHORITY))
        self.assertEqual(result["external_effect_count"], 2)
        self.assertEqual(len(result["result_digest_sha256"]), 64)


if __name__ == "__main__":
    unittest.main()

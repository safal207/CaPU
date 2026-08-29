import unittest

from tools.astra_capu_persistent_authority_a5 import (
    A5Controller,
    AuthorityToken,
    PersistentFrontier,
    REJECT_ALREADY_ISSUED,
    REJECT_FRONTIER_EXHAUSTED,
    REJECT_IDENTITY,
    REJECT_PERSISTENT_FRONTIER,
    REJECT_PERSISTENT_LINEAGE,
    REJECT_PERSISTENT_MISSING,
    REJECT_UNCOMMITTED,
    scenario_result,
)


class PersistentAuthorityA5Tests(unittest.TestCase):
    def token(self, attempt: int = 0, **changes):
        values = dict(
            authority_tag=0xA5,
            incarnation=2,
            queue_epoch=7,
            slot_id=1,
            command_id=9,
            attempt_id=attempt,
            effect_id=12,
            committed=True,
        )
        values.update(changes)
        return AuthorityToken(**values)

    def test_persistent_frontier_required(self):
        controller = A5Controller(PersistentFrontier())
        token = self.token()
        self.assertTrue(controller.load(token))
        decision = controller.dispatch(token, commit_effect=True)
        self.assertFalse(decision.forwarded)
        self.assertEqual(decision.reject_code, REJECT_PERSISTENT_MISSING)

    def test_commit_before_effect_advances_frontier(self):
        token = self.token()
        frontier = PersistentFrontier()
        self.assertTrue(frontier.provision(token))
        controller = A5Controller(frontier)
        self.assertTrue(controller.load(token))
        decision = controller.dispatch(token, commit_effect=True)
        self.assertTrue(decision.forwarded)
        self.assertEqual(frontier.next_attempt, 1)
        self.assertEqual(controller.external_effect_count, 1)

    def test_logic_restart_blocks_same_attempt(self):
        token = self.token()
        frontier = PersistentFrontier()
        frontier.provision(token)
        controller = A5Controller(frontier)
        controller.load(token)
        controller.dispatch(token, commit_effect=True)
        controller.logic_reset()
        controller.load(token)
        replay = controller.dispatch(token, commit_effect=True)
        self.assertFalse(replay.forwarded)
        self.assertEqual(replay.reject_code, REJECT_PERSISTENT_FRONTIER)
        self.assertEqual(controller.external_effect_count, 1)

    def test_successor_attempt_is_allowed(self):
        token0 = self.token(0)
        token1 = self.token(1)
        frontier = PersistentFrontier()
        frontier.provision(token0)
        controller = A5Controller(frontier)
        controller.load(token0)
        controller.dispatch(token0, commit_effect=True)
        controller.logic_reset()
        controller.load(token1)
        decision = controller.dispatch(token1, commit_effect=True)
        self.assertTrue(decision.forwarded)
        self.assertEqual(frontier.next_attempt, 2)
        self.assertEqual(controller.external_effect_count, 2)

    def test_future_attempt_is_blocked(self):
        token0 = self.token(0)
        token2 = self.token(2)
        frontier = PersistentFrontier()
        frontier.provision(token0)
        controller = A5Controller(frontier)
        controller.load(token2)
        decision = controller.dispatch(token2, commit_effect=True)
        self.assertFalse(decision.forwarded)
        self.assertEqual(decision.reject_code, REJECT_PERSISTENT_FRONTIER)

    def test_foreign_lineage_is_blocked(self):
        token = self.token()
        foreign = self.token(command_id=10)
        frontier = PersistentFrontier()
        frontier.provision(token)
        controller = A5Controller(frontier)
        controller.load(foreign)
        decision = controller.dispatch(foreign, commit_effect=True)
        self.assertFalse(decision.forwarded)
        self.assertEqual(decision.reject_code, REJECT_PERSISTENT_LINEAGE)

    def test_uncommitted_authority_is_blocked(self):
        token = self.token(committed=False)
        frontier = PersistentFrontier()
        frontier.provision(token)
        controller = A5Controller(frontier)
        controller.load(token)
        decision = controller.dispatch(token, commit_effect=True)
        self.assertFalse(decision.forwarded)
        self.assertEqual(decision.reject_code, REJECT_UNCOMMITTED)

    def test_volatile_duplicate_is_blocked_before_restart(self):
        token = self.token()
        frontier = PersistentFrontier()
        frontier.provision(token)
        controller = A5Controller(frontier)
        controller.load(token)
        controller.dispatch(token, commit_effect=False)
        duplicate = controller.dispatch(token, commit_effect=True)
        self.assertFalse(duplicate.forwarded)
        self.assertEqual(duplicate.reject_code, REJECT_ALREADY_ISSUED)

    def test_frontier_exhaustion_fails_closed(self):
        token = self.token(attempt=15)
        frontier = PersistentFrontier(width_bits=4)
        frontier.provision(token, next_attempt=15)
        controller = A5Controller(frontier)
        controller.load(token)
        decision = controller.dispatch(token, commit_effect=True)
        self.assertFalse(decision.forwarded)
        self.assertEqual(decision.reject_code, REJECT_FRONTIER_EXHAUSTED)

    def test_identity_mismatch_is_blocked(self):
        token = self.token()
        different_attempt = self.token(1)
        frontier = PersistentFrontier()
        frontier.provision(token)
        controller = A5Controller(frontier)
        controller.load(token)
        decision = controller.dispatch(different_attempt, commit_effect=True)
        self.assertFalse(decision.forwarded)
        self.assertEqual(decision.reject_code, REJECT_IDENTITY)

    def test_scenario_result(self):
        result = scenario_result()
        self.assertTrue(result["restart_replay_blocked"])
        self.assertTrue(result["successor_attempt_forwarded"])
        self.assertTrue(result["future_attempt_blocked"])
        self.assertEqual(result["external_effect_count"], 2)
        self.assertEqual(result["persistent_next_attempt"], 2)
        self.assertEqual(len(result["result_digest_sha256"]), 64)


if __name__ == "__main__":
    unittest.main()

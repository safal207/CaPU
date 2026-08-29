import unittest

from tools.astra_capu_outcome_reconciliation_a6 import (
    A6Controller,
    AuthorityToken,
    Outcome,
    PersistentOutcomeStore,
    ReconcileRejectCode,
    RejectCode,
    scenario_result,
)


class OutcomeReconciliationA6Tests(unittest.TestCase):
    def token(self, attempt: int = 0, **changes):
        values = dict(
            authority_tag=0xA6,
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

    def controller(self):
        token = self.token()
        store = PersistentOutcomeStore()
        self.assertTrue(store.provision(token))
        controller = A6Controller(store)
        return token, store, controller

    def test_dispatch_reserves_unknown_before_effect(self):
        token, store, controller = self.controller()
        self.assertTrue(controller.load(token))
        decision = controller.dispatch(token, commit_effect=False)
        self.assertTrue(decision.forwarded)
        self.assertTrue(store.unresolved_valid)
        self.assertEqual(store.unresolved_attempt, 0)
        self.assertEqual(store.last_outcome, Outcome.UNKNOWN)
        self.assertEqual(store.next_attempt, 1)
        self.assertEqual(controller.external_effect_count, 0)

    def test_logic_restart_blocks_same_attempt_while_unknown(self):
        token, store, controller = self.controller()
        controller.load(token)
        controller.dispatch(token, commit_effect=False)
        controller.logic_reset()
        controller.load(token)
        replay = controller.dispatch(token, commit_effect=True)
        self.assertFalse(replay.forwarded)
        self.assertEqual(replay.reject_code, RejectCode.OUTCOME_UNKNOWN)
        self.assertEqual(controller.external_effect_count, 0)

    def test_negative_evidence_releases_successor_only(self):
        token0, store, controller = self.controller()
        token1 = self.token(1)
        controller.load(token0)
        controller.dispatch(token0, commit_effect=False)
        self.assertEqual(
            store.reconcile(token0, Outcome.NOT_COMMITTED),
            ReconcileRejectCode.NONE,
        )
        controller.logic_reset()
        controller.load(token1)
        decision = controller.dispatch(token1, commit_effect=True)
        self.assertTrue(decision.forwarded)
        self.assertEqual(controller.external_effect_count, 1)
        self.assertEqual(store.next_attempt, 2)

    def test_committed_evidence_terminally_closes_lineage(self):
        token0, store, controller = self.controller()
        token1 = self.token(1)
        controller.load(token0)
        controller.dispatch(token0, commit_effect=True)
        self.assertEqual(
            store.reconcile(token0, Outcome.COMMITTED),
            ReconcileRejectCode.NONE,
        )
        controller.logic_reset()
        controller.load(token1)
        decision = controller.dispatch(token1, commit_effect=True)
        self.assertFalse(decision.forwarded)
        self.assertEqual(decision.reject_code, RejectCode.TERMINAL_COMMITTED)
        self.assertEqual(controller.external_effect_count, 1)

    def test_conflict_evidence_fails_closed(self):
        token0, store, controller = self.controller()
        token1 = self.token(1)
        controller.load(token0)
        controller.dispatch(token0, commit_effect=False)
        self.assertEqual(
            store.reconcile(token0, Outcome.CONFLICT),
            ReconcileRejectCode.NONE,
        )
        controller.logic_reset()
        controller.load(token1)
        decision = controller.dispatch(token1, commit_effect=True)
        self.assertFalse(decision.forwarded)
        self.assertEqual(decision.reject_code, RejectCode.TERMINAL_CONFLICT)

    def test_stale_attempt_evidence_is_rejected(self):
        token0, store, controller = self.controller()
        token1 = self.token(1)
        controller.load(token0)
        controller.dispatch(token0, commit_effect=False)
        self.assertEqual(
            store.reconcile(token1, Outcome.COMMITTED),
            ReconcileRejectCode.ATTEMPT_MISMATCH,
        )
        self.assertTrue(store.unresolved_valid)
        self.assertFalse(store.terminal_committed)

    def test_foreign_lineage_evidence_is_rejected(self):
        token0, store, controller = self.controller()
        foreign = self.token(command_id=10)
        controller.load(token0)
        controller.dispatch(token0, commit_effect=False)
        self.assertEqual(
            store.reconcile(foreign, Outcome.COMMITTED),
            ReconcileRejectCode.PERSISTENT_LINEAGE,
        )
        self.assertTrue(store.unresolved_valid)

    def test_invalid_outcome_is_rejected(self):
        token0, store, controller = self.controller()
        controller.load(token0)
        controller.dispatch(token0, commit_effect=False)
        self.assertEqual(
            store.reconcile(token0, Outcome.UNKNOWN),
            ReconcileRejectCode.INVALID_OUTCOME,
        )
        self.assertTrue(store.unresolved_valid)

    def test_reconcile_without_unresolved_attempt_is_rejected(self):
        token0, store, _ = self.controller()
        self.assertEqual(
            store.reconcile(token0, Outcome.COMMITTED),
            ReconcileRejectCode.NO_UNRESOLVED_ATTEMPT,
        )

    def test_future_attempt_blocked_while_unknown(self):
        token0, store, controller = self.controller()
        token1 = self.token(1)
        controller.load(token0)
        controller.dispatch(token0, commit_effect=False)
        controller.logic_reset()
        controller.load(token1)
        decision = controller.dispatch(token1, commit_effect=True)
        self.assertFalse(decision.forwarded)
        self.assertEqual(decision.reject_code, RejectCode.OUTCOME_UNKNOWN)

    def test_uncommitted_authority_is_blocked(self):
        token = self.token(committed=False)
        store = PersistentOutcomeStore()
        store.provision(token)
        controller = A6Controller(store)
        controller.load(token)
        decision = controller.dispatch(token, commit_effect=True)
        self.assertFalse(decision.forwarded)
        self.assertEqual(decision.reject_code, RejectCode.UNCOMMITTED)

    def test_frontier_exhaustion_fails_closed(self):
        token = self.token(attempt=15)
        store = PersistentOutcomeStore(width_bits=4)
        store.provision(token, next_attempt=15)
        controller = A6Controller(store)
        controller.load(token)
        decision = controller.dispatch(token, commit_effect=True)
        self.assertFalse(decision.forwarded)
        self.assertEqual(decision.reject_code, RejectCode.FRONTIER_EXHAUSTED)

    def test_scenario_result(self):
        result = scenario_result()
        self.assertTrue(result["unknown_after_first_dispatch"])
        self.assertTrue(result["restart_replay_blocked"])
        self.assertTrue(result["negative_reconcile_accepted"])
        self.assertTrue(result["successor_attempt_forwarded"])
        self.assertTrue(result["committed_reconcile_accepted"])
        self.assertTrue(result["terminal_replay_blocked"])
        self.assertEqual(result["external_effect_count"], 1)
        self.assertEqual(result["persistent_next_attempt"], 2)
        self.assertEqual(result["last_outcome"], "COMMITTED")
        self.assertEqual(len(result["result_digest_sha256"]), 64)


if __name__ == "__main__":
    unittest.main()

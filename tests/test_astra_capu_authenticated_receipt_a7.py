import unittest

from tools.astra_capu_authenticated_receipt_a7 import (
    A7Controller,
    DeviceReceipt,
    ReceiptRejectCode,
    TrustedDeviceStore,
    synthetic_receipt_tag,
    scenario_result,
)
from tools.astra_capu_outcome_reconciliation_a6 import (
    A6Controller,
    AuthorityToken,
    Outcome,
    PersistentOutcomeStore,
    ReconcileRejectCode,
    RejectCode,
)


class AuthenticatedDeviceReceiptA7Tests(unittest.TestCase):
    SECRET = 0xBEEF
    DEVICE_ID = 0x3C
    KEY_EPOCH = 2

    def token(self, attempt: int = 0, **changes):
        values = dict(
            authority_tag=0xA7,
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

    def receipt(
        self,
        token: AuthorityToken,
        *,
        seq: int,
        outcome: Outcome,
        device_id: int | None = None,
        key_epoch: int | None = None,
        secret: int | None = None,
    ) -> DeviceReceipt:
        return DeviceReceipt.signed(
            secret=self.SECRET if secret is None else secret,
            device_id=self.DEVICE_ID if device_id is None else device_id,
            key_epoch=self.KEY_EPOCH if key_epoch is None else key_epoch,
            receipt_seq=seq,
            authority_tag=token.authority_tag,
            incarnation=token.incarnation,
            queue_epoch=token.queue_epoch,
            slot_id=token.slot_id,
            command_id=token.command_id,
            attempt_id=token.attempt_id,
            effect_id=token.effect_id,
            outcome=outcome,
        )

    def stack(self):
        token = self.token()
        outcome_store = PersistentOutcomeStore(width_bits=4)
        self.assertTrue(outcome_store.provision(token, next_attempt=0))
        a6 = A6Controller(outcome_store)
        trust = TrustedDeviceStore(
            self.DEVICE_ID,
            self.KEY_EPOCH,
            self.SECRET,
        )
        return token, outcome_store, a6, trust, A7Controller(a6, trust)

    def enter_unknown(self):
        token, store, a6, trust, a7 = self.stack()
        self.assertTrue(a6.load(token))
        decision = a6.dispatch(token, commit_effect=False)
        self.assertTrue(decision.forwarded)
        self.assertTrue(store.unresolved_valid)
        return token, store, a6, trust, a7

    def test_synthetic_tag_is_deterministic(self):
        fields = [0x3C, 2, 0, 0xA7, 2, 7, 1, 9, 0, 12, 2]
        self.assertEqual(
            synthetic_receipt_tag(self.SECRET, fields),
            synthetic_receipt_tag(self.SECRET, fields),
        )
        self.assertNotEqual(
            synthetic_receipt_tag(self.SECRET, fields),
            synthetic_receipt_tag(self.SECRET ^ 1, fields),
        )

    def test_forged_tag_is_rejected_without_sequence_advance(self):
        token, store, _, trust, a7 = self.enter_unknown()
        exact = self.receipt(token, seq=0, outcome=Outcome.NOT_COMMITTED)
        forged = DeviceReceipt(
            **{**exact.__dict__, "auth_tag": exact.auth_tag ^ 1}
        )
        decision = a7.process_receipt(forged)
        self.assertFalse(decision.authenticated)
        self.assertEqual(decision.auth_reject_code, ReceiptRejectCode.AUTH_TAG)
        self.assertEqual(trust.next_receipt_seq, 0)
        self.assertTrue(store.unresolved_valid)

    def test_wrong_device_is_rejected(self):
        token, store, _, trust, a7 = self.enter_unknown()
        receipt = self.receipt(
            token,
            seq=0,
            outcome=Outcome.NOT_COMMITTED,
            device_id=self.DEVICE_ID + 1,
        )
        decision = a7.process_receipt(receipt)
        self.assertFalse(decision.authenticated)
        self.assertEqual(decision.auth_reject_code, ReceiptRejectCode.DEVICE_ID)
        self.assertEqual(trust.next_receipt_seq, 0)
        self.assertTrue(store.unresolved_valid)

    def test_wrong_key_epoch_is_rejected(self):
        token, store, _, trust, a7 = self.enter_unknown()
        receipt = self.receipt(
            token,
            seq=0,
            outcome=Outcome.NOT_COMMITTED,
            key_epoch=self.KEY_EPOCH + 1,
        )
        decision = a7.process_receipt(receipt)
        self.assertFalse(decision.authenticated)
        self.assertEqual(decision.auth_reject_code, ReceiptRejectCode.KEY_EPOCH)
        self.assertEqual(trust.next_receipt_seq, 0)
        self.assertTrue(store.unresolved_valid)

    def test_exact_negative_receipt_releases_successor(self):
        token0, store, a6, trust, a7 = self.enter_unknown()
        receipt = self.receipt(token0, seq=0, outcome=Outcome.NOT_COMMITTED)
        decision = a7.process_receipt(receipt)
        self.assertTrue(decision.authenticated)
        self.assertTrue(decision.reconcile_accept)
        self.assertEqual(trust.next_receipt_seq, 1)
        self.assertFalse(store.unresolved_valid)
        self.assertEqual(store.last_outcome, Outcome.NOT_COMMITTED)

        token1 = self.token(1)
        a6.logic_reset()
        self.assertTrue(a6.load(token1))
        successor = a6.dispatch(token1, commit_effect=True)
        self.assertTrue(successor.forwarded)
        self.assertEqual(a6.external_effect_count, 1)

    def test_authenticated_receipt_consumes_sequence_on_semantic_reject(self):
        token0, store, _, trust, a7 = self.enter_unknown()
        stale_token = self.token(1)
        receipt = self.receipt(
            stale_token,
            seq=0,
            outcome=Outcome.COMMITTED,
        )
        decision = a7.process_receipt(receipt)
        self.assertTrue(decision.authenticated)
        self.assertFalse(decision.reconcile_accept)
        self.assertEqual(
            decision.reconcile_reject_code,
            ReconcileRejectCode.ATTEMPT_MISMATCH,
        )
        self.assertEqual(trust.next_receipt_seq, 1)
        self.assertTrue(store.unresolved_valid)
        self.assertFalse(store.terminal_committed)

    def test_receipt_sequence_replay_is_rejected(self):
        token, store, _, trust, a7 = self.enter_unknown()
        receipt = self.receipt(token, seq=0, outcome=Outcome.NOT_COMMITTED)
        first = a7.process_receipt(receipt)
        second = a7.process_receipt(receipt)
        self.assertTrue(first.authenticated)
        self.assertFalse(second.authenticated)
        self.assertEqual(
            second.auth_reject_code,
            ReceiptRejectCode.RECEIPT_SEQUENCE,
        )
        self.assertEqual(trust.next_receipt_seq, 1)
        self.assertFalse(store.unresolved_valid)

    def test_exact_committed_receipt_terminally_closes_lineage(self):
        token0, store, a6, trust, a7 = self.enter_unknown()
        negative = self.receipt(token0, seq=0, outcome=Outcome.NOT_COMMITTED)
        self.assertTrue(a7.process_receipt(negative).reconcile_accept)

        token1 = self.token(1)
        a6.logic_reset()
        a6.load(token1)
        a6.dispatch(token1, commit_effect=True)
        committed = self.receipt(token1, seq=1, outcome=Outcome.COMMITTED)
        decision = a7.process_receipt(committed)
        self.assertTrue(decision.authenticated)
        self.assertTrue(decision.reconcile_accept)
        self.assertTrue(store.terminal_committed)
        self.assertEqual(trust.next_receipt_seq, 2)

        token2 = self.token(2)
        a6.logic_reset()
        a6.load(token2)
        replay = a6.dispatch(token2, commit_effect=True)
        self.assertFalse(replay.forwarded)
        self.assertEqual(replay.reject_code, RejectCode.TERMINAL_COMMITTED)
        self.assertEqual(a6.external_effect_count, 1)

    def test_exact_conflict_receipt_fails_closed(self):
        token, store, a6, _, a7 = self.enter_unknown()
        receipt = self.receipt(token, seq=0, outcome=Outcome.CONFLICT)
        decision = a7.process_receipt(receipt)
        self.assertTrue(decision.authenticated)
        self.assertTrue(decision.reconcile_accept)
        self.assertTrue(store.terminal_conflict)

        token1 = self.token(1)
        a6.logic_reset()
        a6.load(token1)
        retry = a6.dispatch(token1, commit_effect=True)
        self.assertFalse(retry.forwarded)
        self.assertEqual(retry.reject_code, RejectCode.TERMINAL_CONFLICT)

    def test_logic_restart_preserves_trust_sequence_and_outcome(self):
        token, store, a6, trust, a7 = self.enter_unknown()
        receipt = self.receipt(token, seq=0, outcome=Outcome.NOT_COMMITTED)
        a7.process_receipt(receipt)
        a6.logic_reset()
        self.assertEqual(trust.next_receipt_seq, 1)
        self.assertEqual(trust.trusted_device_id, self.DEVICE_ID)
        self.assertEqual(trust.trusted_key_epoch, self.KEY_EPOCH)
        self.assertEqual(store.last_outcome, Outcome.NOT_COMMITTED)

    def test_scenario_result(self):
        result = scenario_result()
        self.assertTrue(result["forged_receipt_blocked"])
        self.assertTrue(result["negative_receipt_authenticated"])
        self.assertTrue(result["negative_receipt_applied"])
        self.assertTrue(result["stale_receipt_replay_blocked"])
        self.assertTrue(result["foreign_device_receipt_blocked"])
        self.assertTrue(result["committed_receipt_authenticated"])
        self.assertTrue(result["committed_receipt_applied"])
        self.assertTrue(result["terminal_replay_blocked"])
        self.assertEqual(result["external_effect_count"], 1)
        self.assertEqual(result["next_receipt_sequence"], 2)
        self.assertEqual(result["last_outcome"], "COMMITTED")
        self.assertEqual(len(result["result_digest_sha256"]), 64)


if __name__ == "__main__":
    unittest.main()

from __future__ import annotations

import json
import sys
import unittest
from dataclasses import replace
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

from tools.astra_capu_effect_authority_a1 import (  # noqa: E402
    AuthorityIdentity,
    AuthorityTicket,
    ContractError,
    Outcome,
    OutcomeEvidence,
    Stage,
    canonical_digest,
    recover,
    sha256_text,
)


def identity(*, attempt: int = 0, incarnation: int = 7, epoch: int = 11) -> AuthorityIdentity:
    return AuthorityIdentity(
        queue_incarnation=incarnation,
        queue_epoch=epoch,
        slot_id=2,
        command_id="cmd-tensor-17",
        attempt_id=attempt,
        effect_id="dma-effect-9001",
    )


def proposed() -> AuthorityTicket:
    return AuthorityTicket.proposed(
        authority_id="auth-0001",
        actor_id="agent-7",
        intent_commitment=sha256_text("intent:run-safe-kernel"),
        state_commitment=sha256_text("state:model-shard-4"),
        policy_commitment=sha256_text("policy:tenant-42"),
        checkpoint_commitment=sha256_text("checkpoint:pre-dispatch"),
        identity=identity(),
    )


def committed() -> AuthorityTicket:
    return (
        proposed()
        .transition(Stage.GROUNDED)
        .transition(Stage.AUTHORIZED)
        .transition(Stage.COMMITTED)
    )


def evidence(ticket: AuthorityTicket, outcome: Outcome, **changes: object) -> OutcomeEvidence:
    base = OutcomeEvidence(
        schema="capu.hardware.accelerator-effect-outcome-evidence.v1.0-a1",
        evidence_id=f"ev-{outcome.value.lower()}",
        authority_id=ticket.authority_id,
        identity=ticket.identity,
        outcome=outcome,
        source="synthetic-device-readback",
        evidence_commitment=sha256_text(f"evidence:{outcome.value}"),
    )
    return replace(base, **changes)


class EffectAuthorityA1Tests(unittest.TestCase):
    def test_happy_path_committed_effect_seals(self) -> None:
        dispatched = committed().dispatch()
        resolved = dispatched.reconcile(evidence(dispatched, Outcome.COMMITTED))
        sealed = resolved.retire_and_seal()
        self.assertEqual(sealed.stage, Stage.SEALED)
        self.assertTrue(sealed.completion_receipt)
        self.assertTrue(sealed.retired)
        self.assertFalse(sealed.may_replay)
        self.assertEqual(len(sealed.sealed_receipt or ""), 64)

    def test_unknown_blocks_replay_retire_and_seal(self) -> None:
        unknown = committed().dispatch()
        self.assertTrue(unknown.outcome_unknown)
        self.assertFalse(unknown.may_replay)
        self.assertFalse(unknown.may_retire)
        with self.assertRaises(ContractError):
            unknown.begin_retry()
        with self.assertRaises(ContractError):
            unknown.retire_and_seal()

    def test_foreign_queue_identity_is_rejected(self) -> None:
        unknown = committed().dispatch()
        foreign = evidence(
            unknown,
            Outcome.COMMITTED,
            identity=replace(unknown.identity, queue_epoch=unknown.identity.queue_epoch - 1),
        )
        with self.assertRaisesRegex(ContractError, "foreign or stale"):
            unknown.reconcile(foreign)

    def test_foreign_authority_id_is_rejected(self) -> None:
        unknown = committed().dispatch()
        foreign = evidence(unknown, Outcome.COMMITTED, authority_id="auth-foreign")
        with self.assertRaisesRegex(ContractError, "foreign authority_id"):
            unknown.reconcile(foreign)

    def test_exact_negative_evidence_opens_only_next_attempt(self) -> None:
        first = committed().dispatch()
        negative = first.reconcile(evidence(first, Outcome.NOT_COMMITTED))
        self.assertTrue(negative.may_replay)
        retry = negative.begin_retry()
        self.assertEqual(retry.identity.attempt_id, 1)
        self.assertFalse(retry.negative_receipt)
        self.assertFalse(retry.replay_authorized)
        self.assertEqual(retry.stage, Stage.COMMITTED)

        retry_unknown = retry.dispatch()
        stale = evidence(first, Outcome.NOT_COMMITTED)
        with self.assertRaisesRegex(ContractError, "foreign or stale"):
            retry_unknown.reconcile(stale)

    def test_conflict_is_fail_closed(self) -> None:
        unknown = committed().dispatch()
        conflict = unknown.reconcile(evidence(unknown, Outcome.CONFLICT))
        self.assertEqual(conflict.stage, Stage.CONFLICT)
        self.assertFalse(conflict.may_replay)
        self.assertFalse(conflict.may_retire)
        with self.assertRaises(ContractError):
            conflict.dispatch()

    def test_dispatch_before_commit_is_rejected(self) -> None:
        with self.assertRaisesRegex(ContractError, "committed authority"):
            proposed().dispatch()

    def test_stale_checkpoint_cannot_override_durable_unknown(self) -> None:
        checkpoint = committed()
        durable = checkpoint.dispatch()
        restored = recover(checkpoint, durable)
        self.assertEqual(restored.stage, Stage.DISPATCHED)
        self.assertTrue(restored.issue_witness)
        self.assertTrue(restored.outcome_unknown)

    def test_stale_checkpoint_cannot_override_completion_receipt(self) -> None:
        checkpoint = committed()
        durable_unknown = checkpoint.dispatch()
        durable_committed = durable_unknown.reconcile(
            evidence(durable_unknown, Outcome.COMMITTED)
        )
        restored = recover(checkpoint, durable_committed)
        self.assertEqual(restored.stage, Stage.RECONCILED_COMMITTED)
        self.assertTrue(restored.completion_receipt)
        self.assertFalse(restored.may_replay)

    def test_cross_authority_recovery_mix_is_rejected(self) -> None:
        checkpoint = committed()
        foreign = replace(checkpoint, authority_id="auth-foreign")
        with self.assertRaisesRegex(ContractError, "different authorities"):
            recover(checkpoint, foreign)

    def test_canonical_digest_changes_for_every_authority_dimension(self) -> None:
        ticket = committed()
        baseline = canonical_digest(ticket)
        mutations = [
            replace(ticket, intent_commitment=sha256_text("intent:mutated")),
            replace(ticket, policy_commitment=sha256_text("policy:mutated")),
            replace(ticket, checkpoint_commitment=sha256_text("checkpoint:mutated")),
            replace(ticket, identity=replace(ticket.identity, queue_incarnation=8)),
            replace(ticket, identity=replace(ticket.identity, queue_epoch=12)),
            replace(ticket, identity=replace(ticket.identity, slot_id=3)),
            replace(ticket, identity=replace(ticket.identity, command_id="cmd-other")),
            replace(ticket, identity=replace(ticket.identity, attempt_id=1)),
            replace(ticket, identity=replace(ticket.identity, effect_id="effect-other")),
        ]
        for mutated in mutations:
            self.assertNotEqual(baseline, canonical_digest(mutated))

    def test_fixture_round_trip(self) -> None:
        fixture = json.loads((ROOT / "examples/hardware/astra-capu-v1-a1-valid.json").read_text())
        self.assertEqual(fixture["schema"], "capu.hardware.accelerator-effect-authority.fixture.v1.0-a1")
        self.assertEqual(fixture["expected"]["final_stage"], "SEALED")
        self.assertEqual(fixture["expected"]["duplicate_effects"], 0)


if __name__ == "__main__":
    unittest.main(verbosity=2)

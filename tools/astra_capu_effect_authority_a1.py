from __future__ import annotations

import hashlib
import json
from dataclasses import asdict, dataclass, replace
from enum import Enum
from typing import Any, Mapping

DOMAIN = "ASTRA-CAPU:EFFECT-AUTHORITY:A1:V1\u0000"
HEX_256_LEN = 64


class ContractError(ValueError):
    """Raised when an authority or evidence transition is not permitted."""


class Stage(str, Enum):
    PROPOSED = "PROPOSED"
    GROUNDED = "GROUNDED"
    AUTHORIZED = "AUTHORIZED"
    COMMITTED = "COMMITTED"
    DISPATCHED = "DISPATCHED"
    RECONCILED_NOT_COMMITTED = "RECONCILED_NOT_COMMITTED"
    RECONCILED_COMMITTED = "RECONCILED_COMMITTED"
    CONFLICT = "CONFLICT"
    SEALED = "SEALED"


class Outcome(str, Enum):
    NOT_COMMITTED = "NOT_COMMITTED"
    COMMITTED = "COMMITTED"
    CONFLICT = "CONFLICT"


@dataclass(frozen=True)
class AuthorityIdentity:
    queue_incarnation: int
    queue_epoch: int
    slot_id: int
    command_id: str
    attempt_id: int
    effect_id: str

    def validate(self) -> None:
        for name in ("queue_incarnation", "queue_epoch", "slot_id", "attempt_id"):
            value = getattr(self, name)
            if not isinstance(value, int) or value < 0:
                raise ContractError(f"{name} must be a non-negative integer")
        for name in ("command_id", "effect_id"):
            value = getattr(self, name)
            if not isinstance(value, str) or not value.strip():
                raise ContractError(f"{name} must be a non-empty string")


@dataclass(frozen=True)
class AuthorityTicket:
    schema: str
    authority_id: str
    actor_id: str
    intent_commitment: str
    state_commitment: str
    policy_commitment: str
    checkpoint_commitment: str
    identity: AuthorityIdentity
    stage: Stage
    issue_witness: bool = False
    negative_receipt: bool = False
    completion_receipt: bool = False
    conflict_receipt: bool = False
    replay_authorized: bool = False
    retired: bool = False
    sealed_receipt: str | None = None

    @staticmethod
    def proposed(
        *,
        authority_id: str,
        actor_id: str,
        intent_commitment: str,
        state_commitment: str,
        policy_commitment: str,
        checkpoint_commitment: str,
        identity: AuthorityIdentity,
    ) -> "AuthorityTicket":
        ticket = AuthorityTicket(
            schema="capu.hardware.accelerator-effect-authority.v1.0-a1",
            authority_id=authority_id,
            actor_id=actor_id,
            intent_commitment=intent_commitment,
            state_commitment=state_commitment,
            policy_commitment=policy_commitment,
            checkpoint_commitment=checkpoint_commitment,
            identity=identity,
            stage=Stage.PROPOSED,
        )
        ticket.validate()
        return ticket

    def validate(self) -> None:
        if self.schema != "capu.hardware.accelerator-effect-authority.v1.0-a1":
            raise ContractError("unsupported schema")
        for name in ("authority_id", "actor_id"):
            value = getattr(self, name)
            if not isinstance(value, str) or not value.strip():
                raise ContractError(f"{name} must be a non-empty string")
        for name in (
            "intent_commitment",
            "state_commitment",
            "policy_commitment",
            "checkpoint_commitment",
        ):
            _validate_sha256(name, getattr(self, name))
        self.identity.validate()

        receipts = sum(
            int(v)
            for v in (
                self.negative_receipt,
                self.completion_receipt,
                self.conflict_receipt,
            )
        )
        if receipts > 1:
            raise ContractError("negative/completion/conflict receipts are mutually exclusive")
        if self.issue_witness and self.negative_receipt:
            raise ContractError("negative receipt must consume the issue witness")
        if self.issue_witness and self.completion_receipt:
            raise ContractError("completion receipt must consume the issue witness")
        if self.issue_witness and self.conflict_receipt:
            raise ContractError("conflict receipt must consume the issue witness")
        if self.replay_authorized and not self.negative_receipt:
            raise ContractError("replay authority requires exact NOT_COMMITTED evidence")
        if self.retired and not self.completion_receipt:
            raise ContractError("retirement requires a durable completion receipt")
        if self.stage is Stage.DISPATCHED and not self.issue_witness:
            raise ContractError("DISPATCHED requires a durable issue witness")
        if self.stage is Stage.RECONCILED_NOT_COMMITTED and not self.negative_receipt:
            raise ContractError("NOT_COMMITTED reconciliation requires a negative receipt")
        if self.stage is Stage.RECONCILED_COMMITTED and not self.completion_receipt:
            raise ContractError("COMMITTED reconciliation requires a completion receipt")
        if self.stage is Stage.CONFLICT and not self.conflict_receipt:
            raise ContractError("CONFLICT stage requires a conflict receipt")
        if self.stage is Stage.SEALED:
            if not self.completion_receipt or not self.retired or not self.sealed_receipt:
                raise ContractError("SEALED requires completion, retirement and proof receipt")
            _validate_sha256("sealed_receipt", self.sealed_receipt)

    @property
    def outcome_unknown(self) -> bool:
        return self.stage is Stage.DISPATCHED and self.issue_witness

    @property
    def may_dispatch(self) -> bool:
        return self.stage is Stage.COMMITTED and not self.issue_witness

    @property
    def may_retire(self) -> bool:
        return self.stage is Stage.RECONCILED_COMMITTED and self.completion_receipt

    @property
    def may_replay(self) -> bool:
        return (
            self.stage is Stage.RECONCILED_NOT_COMMITTED
            and self.negative_receipt
            and self.replay_authorized
        )

    def transition(self, next_stage: Stage) -> "AuthorityTicket":
        allowed: dict[Stage, tuple[Stage, ...]] = {
            Stage.PROPOSED: (Stage.GROUNDED,),
            Stage.GROUNDED: (Stage.AUTHORIZED,),
            Stage.AUTHORIZED: (Stage.COMMITTED,),
        }
        if next_stage not in allowed.get(self.stage, ()):
            raise ContractError(f"transition {self.stage.value}->{next_stage.value} is not permitted")
        result = replace(self, stage=next_stage)
        result.validate()
        return result

    def dispatch(self) -> "AuthorityTicket":
        if not self.may_dispatch:
            raise ContractError("dispatch requires a committed authority ticket")
        result = replace(self, stage=Stage.DISPATCHED, issue_witness=True)
        result.validate()
        return result

    def reconcile(self, evidence: "OutcomeEvidence") -> "AuthorityTicket":
        if not self.outcome_unknown:
            raise ContractError("outcome evidence is accepted only for an UNKNOWN dispatched attempt")
        evidence.validate()
        if evidence.authority_id != self.authority_id:
            raise ContractError("foreign authority_id")
        if evidence.identity != self.identity:
            raise ContractError("foreign or stale authority identity")
        if evidence.outcome is Outcome.NOT_COMMITTED:
            result = replace(
                self,
                stage=Stage.RECONCILED_NOT_COMMITTED,
                issue_witness=False,
                negative_receipt=True,
                completion_receipt=False,
                conflict_receipt=False,
                replay_authorized=True,
            )
        elif evidence.outcome is Outcome.COMMITTED:
            result = replace(
                self,
                stage=Stage.RECONCILED_COMMITTED,
                issue_witness=False,
                negative_receipt=False,
                completion_receipt=True,
                conflict_receipt=False,
                replay_authorized=False,
            )
        else:
            result = replace(
                self,
                stage=Stage.CONFLICT,
                issue_witness=False,
                negative_receipt=False,
                completion_receipt=False,
                conflict_receipt=True,
                replay_authorized=False,
            )
        result.validate()
        return result

    def begin_retry(self) -> "AuthorityTicket":
        if not self.may_replay:
            raise ContractError("retry requires exact durable NOT_COMMITTED evidence")
        result = replace(
            self,
            identity=replace(self.identity, attempt_id=self.identity.attempt_id + 1),
            stage=Stage.COMMITTED,
            negative_receipt=False,
            replay_authorized=False,
        )
        result.validate()
        return result

    def retire_and_seal(self) -> "AuthorityTicket":
        if not self.may_retire:
            raise ContractError("retirement requires exact committed outcome evidence")
        pre_receipt = replace(self, retired=True)
        receipt = canonical_digest({"proof_receipt_for": canonical_record(pre_receipt)})
        result = replace(pre_receipt, stage=Stage.SEALED, sealed_receipt=receipt)
        result.validate()
        return result


@dataclass(frozen=True)
class OutcomeEvidence:
    schema: str
    evidence_id: str
    authority_id: str
    identity: AuthorityIdentity
    outcome: Outcome
    source: str
    evidence_commitment: str

    def validate(self) -> None:
        if self.schema != "capu.hardware.accelerator-effect-outcome-evidence.v1.0-a1":
            raise ContractError("unsupported evidence schema")
        for name in ("evidence_id", "authority_id", "source"):
            value = getattr(self, name)
            if not isinstance(value, str) or not value.strip():
                raise ContractError(f"{name} must be a non-empty string")
        self.identity.validate()
        _validate_sha256("evidence_commitment", self.evidence_commitment)


def recover(checkpoint: AuthorityTicket, durable: AuthorityTicket) -> AuthorityTicket:
    """Recover from a potentially stale checkpoint using durable authority/evidence state.

    The durable record is authoritative only when it belongs to the same authority_id and
    is at least as new in (incarnation, epoch, slot, attempt). A foreign durable record is
    rejected rather than mixed with the checkpoint.
    """

    checkpoint.validate()
    durable.validate()
    if checkpoint.authority_id != durable.authority_id:
        raise ContractError("cannot mix checkpoint and durable records from different authorities")
    if _identity_order(durable.identity) < _identity_order(checkpoint.identity):
        raise ContractError("durable record is older than checkpoint identity")
    return durable


def canonical_record(value: Any) -> Any:
    if isinstance(value, Enum):
        return value.value
    if hasattr(value, "__dataclass_fields__"):
        return canonical_record(asdict(value))
    if isinstance(value, Mapping):
        return {str(k): canonical_record(value[k]) for k in sorted(value)}
    if isinstance(value, (list, tuple)):
        return [canonical_record(v) for v in value]
    return value


def canonical_bytes(value: Any) -> bytes:
    payload = {
        "domain": DOMAIN,
        "record": canonical_record(value),
    }
    return json.dumps(
        payload,
        sort_keys=True,
        separators=(",", ":"),
        ensure_ascii=False,
    ).encode("utf-8")


def canonical_digest(value: Any) -> str:
    return hashlib.sha256(canonical_bytes(value)).hexdigest()


def sha256_text(text: str) -> str:
    return hashlib.sha256(text.encode("utf-8")).hexdigest()


def _validate_sha256(name: str, value: str) -> None:
    if not isinstance(value, str) or len(value) != HEX_256_LEN:
        raise ContractError(f"{name} must be a 64-character SHA-256 hex digest")
    try:
        int(value, 16)
    except ValueError as exc:
        raise ContractError(f"{name} must be hexadecimal") from exc


def _identity_order(identity: AuthorityIdentity) -> tuple[int, int, int, int]:
    return (
        identity.queue_incarnation,
        identity.queue_epoch,
        identity.slot_id,
        identity.attempt_id,
    )

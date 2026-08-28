from __future__ import annotations

import hashlib
import re
import struct
from copy import deepcopy
from typing import Any, Iterable, Mapping

REQUEST_SCHEMA = "capu.accelerator-effect-authority.request.v1"
EVIDENCE_SCHEMA = "capu.accelerator-effect-authority.evidence.v1"
LIFECYCLE_SCHEMA = "capu.accelerator-effect-authority.lifecycle.v1"

REQUEST_DOMAIN = b"CAPU:ACCELERATOR-EFFECT-AUTHORITY:REQUEST:V1\x00"
EVIDENCE_DOMAIN = b"CAPU:ACCELERATOR-EFFECT-AUTHORITY:EVIDENCE:V1\x00"

HEX_256_RE = re.compile(r"^[0-9a-f]{64}$")
ID_RE = re.compile(r"^[A-Za-z0-9][A-Za-z0-9._:/-]{0,127}$")
OUTCOME_CLASS_RE = re.compile(r"^[a-z][a-z0-9._-]{0,127}$")
REASON_RE = re.compile(r"^[A-Z][A-Z0-9_]{0,63}$")

DECISION_CODE = {"ACCEPTED": 1, "REJECTED": 2, "HELD": 3}
EXECUTION_STATE_CODE = {
    "NOT_STARTED": 0,
    "STARTED": 1,
    "RECOVERING": 2,
    "RECONCILE_REQUIRED": 3,
    "CLOSED": 4,
}
COMPLETION_STATE_CODE = {"NOT_COMMITTED": 0, "UNKNOWN": 1, "COMMITTED": 2}

REQUEST_FIELDS = {
    "schema",
    "intent_id",
    "principal_id",
    "policy_commitment",
    "state_commitment",
    "queue_incarnation",
    "queue_epoch",
    "slot_id",
    "command_id",
    "execution_epoch",
    "attempt_id",
    "effect_id",
    "resource_commitment",
    "expected_outcome_class",
    "expires_at_epoch",
}

EVIDENCE_FIELDS = {
    "schema",
    "request_commitment",
    "sequence",
    "previous_evidence_commitment",
    "decision",
    "execution_state",
    "completion_state",
    "authorization_evidence_commitment",
    "execution_evidence_commitment",
    "negative_outcome_evidence_commitment",
    "committed_outcome_evidence_commitment",
    "receipt_commitment",
    "next_state_commitment",
    "evidence_required",
    "recovery_required",
    "reason_code",
}

OPTIONAL_EVIDENCE_COMMITMENTS = (
    "previous_evidence_commitment",
    "authorization_evidence_commitment",
    "execution_evidence_commitment",
    "negative_outcome_evidence_commitment",
    "committed_outcome_evidence_commitment",
    "receipt_commitment",
    "next_state_commitment",
)


def _require_exact_fields(value: Mapping[str, Any], expected: set[str], *, name: str) -> None:
    actual = set(value)
    missing = sorted(expected - actual)
    extra = sorted(actual - expected)
    if missing or extra:
        raise ValueError(f"{name} fields mismatch: missing={missing} extra={extra}")


def _require_string(value: Any, *, name: str, pattern: re.Pattern[str]) -> str:
    if not isinstance(value, str) or not pattern.fullmatch(value):
        raise ValueError(f"invalid {name}: {value!r}")
    return value


def _require_commitment(value: Any, *, name: str) -> str:
    if not isinstance(value, str) or not HEX_256_RE.fullmatch(value):
        raise ValueError(f"invalid {name}: expected 64 lowercase hex characters")
    return value


def _require_optional_commitment(value: Any, *, name: str) -> str | None:
    if value is None:
        return None
    return _require_commitment(value, name=name)


def _require_u32(value: Any, *, name: str) -> int:
    if isinstance(value, bool) or not isinstance(value, int) or not 0 <= value <= 0xFFFFFFFF:
        raise ValueError(f"invalid {name}: expected uint32")
    return value


def _require_bool(value: Any, *, name: str) -> bool:
    if not isinstance(value, bool):
        raise ValueError(f"invalid {name}: expected boolean")
    return value


def _pack_u8(value: int) -> bytes:
    return struct.pack(">B", value)


def _pack_u32(value: int) -> bytes:
    return struct.pack(">I", value)


def _pack_bool(value: bool) -> bytes:
    return _pack_u8(1 if value else 0)


def _pack_string(value: str) -> bytes:
    encoded = value.encode("utf-8")
    return _pack_u32(len(encoded)) + encoded


def _pack_commitment(value: str) -> bytes:
    return bytes.fromhex(value)


def _pack_optional_commitment(value: str | None) -> bytes:
    return b"\x00" if value is None else b"\x01" + _pack_commitment(value)


def validate_request(request: Mapping[str, Any]) -> None:
    if not isinstance(request, Mapping):
        raise ValueError("request must be an object")
    _require_exact_fields(request, REQUEST_FIELDS, name="request")
    if request["schema"] != REQUEST_SCHEMA:
        raise ValueError("unsupported request schema")

    for field in ("intent_id", "principal_id", "command_id", "effect_id"):
        _require_string(request[field], name=field, pattern=ID_RE)
    _require_string(
        request["expected_outcome_class"],
        name="expected_outcome_class",
        pattern=OUTCOME_CLASS_RE,
    )
    for field in ("policy_commitment", "state_commitment", "resource_commitment"):
        _require_commitment(request[field], name=field)
    for field in (
        "queue_incarnation",
        "queue_epoch",
        "slot_id",
        "execution_epoch",
        "attempt_id",
        "expires_at_epoch",
    ):
        _require_u32(request[field], name=field)

    if request["expires_at_epoch"] < request["execution_epoch"]:
        raise ValueError("expires_at_epoch cannot precede execution_epoch")


def canonical_request_payload(request: Mapping[str, Any]) -> bytes:
    validate_request(request)
    return b"".join(
        [
            REQUEST_DOMAIN,
            _pack_string(request["schema"]),
            _pack_string(request["intent_id"]),
            _pack_string(request["principal_id"]),
            _pack_commitment(request["policy_commitment"]),
            _pack_commitment(request["state_commitment"]),
            _pack_u32(request["queue_incarnation"]),
            _pack_u32(request["queue_epoch"]),
            _pack_u32(request["slot_id"]),
            _pack_string(request["command_id"]),
            _pack_u32(request["execution_epoch"]),
            _pack_u32(request["attempt_id"]),
            _pack_string(request["effect_id"]),
            _pack_commitment(request["resource_commitment"]),
            _pack_string(request["expected_outcome_class"]),
            _pack_u32(request["expires_at_epoch"]),
        ]
    )


def request_commitment(request: Mapping[str, Any]) -> str:
    return hashlib.sha256(canonical_request_payload(request)).hexdigest()


def validate_evidence(evidence: Mapping[str, Any]) -> None:
    if not isinstance(evidence, Mapping):
        raise ValueError("evidence must be an object")
    _require_exact_fields(evidence, EVIDENCE_FIELDS, name="evidence")
    if evidence["schema"] != EVIDENCE_SCHEMA:
        raise ValueError("unsupported evidence schema")

    _require_commitment(evidence["request_commitment"], name="request_commitment")
    sequence = _require_u32(evidence["sequence"], name="sequence")
    for field in OPTIONAL_EVIDENCE_COMMITMENTS:
        _require_optional_commitment(evidence[field], name=field)
    if sequence == 0 and evidence["previous_evidence_commitment"] is not None:
        raise ValueError("sequence 0 cannot have previous_evidence_commitment")
    if sequence > 0 and evidence["previous_evidence_commitment"] is None:
        raise ValueError("sequence > 0 requires previous_evidence_commitment")

    decision = evidence["decision"]
    execution_state = evidence["execution_state"]
    completion_state = evidence["completion_state"]
    if decision not in DECISION_CODE:
        raise ValueError("invalid decision")
    if execution_state not in EXECUTION_STATE_CODE:
        raise ValueError("invalid execution_state")
    if completion_state not in COMPLETION_STATE_CODE:
        raise ValueError("invalid completion_state")
    _require_bool(evidence["evidence_required"], name="evidence_required")
    _require_bool(evidence["recovery_required"], name="recovery_required")
    _require_string(evidence["reason_code"], name="reason_code", pattern=REASON_RE)

    auth = evidence["authorization_evidence_commitment"]
    execution = evidence["execution_evidence_commitment"]
    negative = evidence["negative_outcome_evidence_commitment"]
    committed = evidence["committed_outcome_evidence_commitment"]
    receipt = evidence["receipt_commitment"]
    next_state = evidence["next_state_commitment"]

    if negative is not None and committed is not None:
        raise ValueError("negative and committed outcome evidence are mutually exclusive")

    if sequence == 0:
        if decision == "REJECTED":
            if execution_state != "NOT_STARTED" or completion_state != "NOT_COMMITTED":
                raise ValueError("initial rejection must be NOT_STARTED / NOT_COMMITTED")
            if any(value is not None for value in (auth, execution, negative, committed, receipt, next_state)):
                raise ValueError("initial rejection cannot carry effect-authority evidence")
            if evidence["evidence_required"] or evidence["recovery_required"]:
                raise ValueError("initial rejection cannot require recovery/evidence")
            return
        if decision != "ACCEPTED":
            raise ValueError("sequence 0 must be ACCEPTED or REJECTED")
        if execution_state != "NOT_STARTED" or completion_state != "NOT_COMMITTED":
            raise ValueError("initial acceptance must be NOT_STARTED / NOT_COMMITTED")
        if auth is None:
            raise ValueError("initial acceptance requires authorization evidence")
        if any(value is not None for value in (execution, negative, committed, receipt, next_state)):
            raise ValueError("initial acceptance cannot claim execution/outcome evidence")
        if evidence["evidence_required"] or evidence["recovery_required"]:
            raise ValueError("initial acceptance cannot require recovery/evidence")
        return

    if completion_state == "UNKNOWN":
        if execution_state not in {"STARTED", "RECOVERING", "RECONCILE_REQUIRED"}:
            raise ValueError("UNKNOWN requires an in-flight/recovery execution state")
        if execution is None:
            raise ValueError("UNKNOWN requires execution evidence")
        if any(value is not None for value in (negative, committed, receipt, next_state)):
            raise ValueError("UNKNOWN cannot carry resolved outcome or receipt")
        if not evidence["evidence_required"]:
            raise ValueError("UNKNOWN must require discriminating evidence")
        if execution_state == "STARTED":
            if decision != "ACCEPTED" or evidence["recovery_required"]:
                raise ValueError("STARTED/UNKNOWN must be accepted and not yet recovery-required")
        else:
            if decision != "HELD" or not evidence["recovery_required"]:
                raise ValueError("recovery UNKNOWN must be held and recovery-required")
        return

    if completion_state == "COMMITTED":
        if decision != "ACCEPTED" or execution_state != "CLOSED":
            raise ValueError("COMMITTED must be ACCEPTED and CLOSED")
        if execution is None or committed is None or receipt is None or next_state is None:
            raise ValueError("COMMITTED requires execution, outcome, receipt, and next-state evidence")
        if negative is not None:
            raise ValueError("COMMITTED cannot carry negative outcome evidence")
        if evidence["evidence_required"] or evidence["recovery_required"]:
            raise ValueError("COMMITTED cannot remain evidence/recovery-required")
        return

    if completion_state == "NOT_COMMITTED":
        if decision != "HELD" or execution_state != "CLOSED":
            raise ValueError("resolved NOT_COMMITTED must be HELD and CLOSED")
        if execution is None or negative is None:
            raise ValueError("resolved NOT_COMMITTED requires execution and negative outcome evidence")
        if any(value is not None for value in (committed, receipt, next_state)):
            raise ValueError("NOT_COMMITTED cannot carry committed receipt/next-state evidence")
        if evidence["evidence_required"] or evidence["recovery_required"]:
            raise ValueError("resolved NOT_COMMITTED cannot remain evidence/recovery-required")
        return

    raise ValueError("unhandled evidence state")


def canonical_evidence_payload(evidence: Mapping[str, Any]) -> bytes:
    validate_evidence(evidence)
    return b"".join(
        [
            EVIDENCE_DOMAIN,
            _pack_string(evidence["schema"]),
            _pack_commitment(evidence["request_commitment"]),
            _pack_u32(evidence["sequence"]),
            _pack_optional_commitment(evidence["previous_evidence_commitment"]),
            _pack_u8(DECISION_CODE[evidence["decision"]]),
            _pack_u8(EXECUTION_STATE_CODE[evidence["execution_state"]]),
            _pack_u8(COMPLETION_STATE_CODE[evidence["completion_state"]]),
            _pack_optional_commitment(evidence["authorization_evidence_commitment"]),
            _pack_optional_commitment(evidence["execution_evidence_commitment"]),
            _pack_optional_commitment(evidence["negative_outcome_evidence_commitment"]),
            _pack_optional_commitment(evidence["committed_outcome_evidence_commitment"]),
            _pack_optional_commitment(evidence["receipt_commitment"]),
            _pack_optional_commitment(evidence["next_state_commitment"]),
            _pack_bool(evidence["evidence_required"]),
            _pack_bool(evidence["recovery_required"]),
            _pack_string(evidence["reason_code"]),
        ]
    )


def evidence_commitment(evidence: Mapping[str, Any]) -> str:
    return hashlib.sha256(canonical_evidence_payload(evidence)).hexdigest()


def _transition_allowed(previous: Mapping[str, Any], current: Mapping[str, Any]) -> bool:
    prev_exec = previous["execution_state"]
    prev_completion = previous["completion_state"]
    current_pair = (current["execution_state"], current["completion_state"])

    if prev_exec == "CLOSED":
        return False
    if prev_exec == "NOT_STARTED" and prev_completion == "NOT_COMMITTED":
        return current_pair == ("STARTED", "UNKNOWN")
    if prev_exec == "STARTED" and prev_completion == "UNKNOWN":
        return current_pair in {
            ("RECOVERING", "UNKNOWN"),
            ("RECONCILE_REQUIRED", "UNKNOWN"),
            ("CLOSED", "NOT_COMMITTED"),
            ("CLOSED", "COMMITTED"),
        }
    if prev_exec == "RECOVERING" and prev_completion == "UNKNOWN":
        return current_pair in {
            ("RECONCILE_REQUIRED", "UNKNOWN"),
            ("CLOSED", "NOT_COMMITTED"),
            ("CLOSED", "COMMITTED"),
        }
    if prev_exec == "RECONCILE_REQUIRED" and prev_completion == "UNKNOWN":
        return current_pair in {("CLOSED", "NOT_COMMITTED"), ("CLOSED", "COMMITTED")}
    return False


def validate_lifecycle(lifecycle: Mapping[str, Any]) -> dict[str, Any]:
    expected_fields = {"schema", "request", "evidence"}
    if not isinstance(lifecycle, Mapping):
        raise ValueError("lifecycle must be an object")
    _require_exact_fields(lifecycle, expected_fields, name="lifecycle")
    if lifecycle["schema"] != LIFECYCLE_SCHEMA:
        raise ValueError("unsupported lifecycle schema")

    request = lifecycle["request"]
    evidence_items = lifecycle["evidence"]
    validate_request(request)
    if not isinstance(evidence_items, list) or not evidence_items:
        raise ValueError("lifecycle evidence must be a non-empty array")

    req_commitment = request_commitment(request)
    evidence_commitments: list[str] = []

    for index, evidence in enumerate(evidence_items):
        validate_evidence(evidence)
        if evidence["request_commitment"] != req_commitment:
            raise ValueError(f"evidence[{index}] has foreign request commitment")
        if evidence["sequence"] != index:
            raise ValueError(f"evidence[{index}] sequence is not contiguous")
        expected_previous = None if index == 0 else evidence_commitments[index - 1]
        if evidence["previous_evidence_commitment"] != expected_previous:
            raise ValueError(f"evidence[{index}] breaks the evidence commitment chain")
        if index > 0 and not _transition_allowed(evidence_items[index - 1], evidence):
            raise ValueError(f"evidence[{index}] is not an allowed lifecycle transition")
        evidence_commitments.append(evidence_commitment(evidence))

    if evidence_items[0]["decision"] == "REJECTED" and len(evidence_items) != 1:
        raise ValueError("rejected request lifecycle must terminate immediately")

    return {
        "request_commitment": req_commitment,
        "evidence_commitments": evidence_commitments,
        "terminal": evidence_items[-1]["execution_state"] == "CLOSED",
        "completion_state": evidence_items[-1]["completion_state"],
    }


def apply_mutation(document: Mapping[str, Any], path: Iterable[str | int], value: Any) -> dict[str, Any]:
    result = deepcopy(document)
    cursor: Any = result
    segments = list(path)
    if not segments:
        raise ValueError("mutation path cannot be empty")
    for segment in segments[:-1]:
        cursor = cursor[segment]
    cursor[segments[-1]] = value
    return result

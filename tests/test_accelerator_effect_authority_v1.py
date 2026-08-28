from __future__ import annotations

import json
import sys
from copy import deepcopy
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

from tools.accelerator_effect_authority_v1 import (  # noqa: E402
    apply_mutation,
    canonical_evidence_payload,
    canonical_request_payload,
    evidence_commitment,
    request_commitment,
    validate_evidence,
    validate_lifecycle,
)

FIXTURES = ROOT / "fixtures" / "accelerator-effect-authority-v1"


def load_json(name: str) -> dict:
    return json.loads((FIXTURES / name).read_text())


def assert_changed(name: str, before: bytes | str, after: bytes | str) -> None:
    changed = before != after
    print(f"{name}={int(changed)}")
    assert changed


def mutate_request(base: dict, field: str, value: object) -> None:
    changed = deepcopy(base)
    changed[field] = value
    assert_changed(
        f"request_{field}_commitment_changed",
        request_commitment(base),
        request_commitment(changed),
    )


def expect_rejected(name: str, lifecycle: dict, expected_error: str) -> None:
    try:
        validate_lifecycle(lifecycle)
    except ValueError as exc:
        ok = expected_error in str(exc)
        print(f"{name}={int(ok)} error={exc}")
        assert ok, (expected_error, str(exc))
        return
    raise AssertionError(f"{name}: lifecycle was unexpectedly accepted")


def main() -> None:
    lifecycle = load_json("valid-lifecycle.json")
    result = validate_lifecycle(lifecycle)
    request = lifecycle["request"]
    evidence = lifecycle["evidence"]

    print(f"request_commitment={result['request_commitment']}")
    print(f"terminal_evidence_commitment={result['evidence_commitments'][-1]}")
    print(f"terminal={int(result['terminal'])}")
    print(f"completion_state={result['completion_state']}")

    mutate_request(request, "intent_id", "intent:invoice-124")
    mutate_request(request, "principal_id", "principal:agent-8")
    mutate_request(request, "policy_commitment", "a" * 64)
    mutate_request(request, "state_commitment", "b" * 64)
    mutate_request(request, "queue_incarnation", 3)
    mutate_request(request, "queue_epoch", 1)
    mutate_request(request, "slot_id", 1)
    mutate_request(request, "command_id", "command:pay-invoice-124")
    mutate_request(request, "execution_epoch", 10)
    mutate_request(request, "attempt_id", 2)
    mutate_request(request, "effect_id", "effect:bank-transfer-124")
    mutate_request(request, "resource_commitment", "c" * 64)
    mutate_request(request, "expected_outcome_class", "payment.refunded")
    mutate_request(request, "expires_at_epoch", 13)

    baseline = evidence_commitment(evidence[3])
    alternatives: list[tuple[str, dict]] = []

    alt = deepcopy(evidence[3]); alt["request_commitment"] = "d" * 64
    alternatives.append(("evidence_request_commitment_changed", alt))
    alt = deepcopy(evidence[3]); alt["sequence"] = 5
    alternatives.append(("evidence_sequence_changed", alt))
    alt = deepcopy(evidence[3]); alt["previous_evidence_commitment"] = "e" * 64
    alternatives.append(("evidence_previous_commitment_changed", alt))
    alt = deepcopy(evidence[3]); alt["execution_state"] = "RECOVERING"; alt["reason_code"] = "RECOVERY_BARRIER"
    alternatives.append(("evidence_execution_state_changed", alt))
    alt = deepcopy(evidence[3]); alt["execution_evidence_commitment"] = "f" * 64
    alternatives.append(("evidence_execution_commitment_changed", alt))
    alt = deepcopy(evidence[3]); alt["reason_code"] = "EXACT_EVIDENCE_REQUIRED"
    alternatives.append(("evidence_reason_code_changed", alt))

    for name, alternative in alternatives:
        validate_evidence(alternative)
        assert_changed(name, baseline, evidence_commitment(alternative))

    negative = deepcopy(evidence[4])
    negative.update(
        {
            "decision": "HELD",
            "completion_state": "NOT_COMMITTED",
            "negative_outcome_evidence_commitment": "9" * 64,
            "committed_outcome_evidence_commitment": None,
            "receipt_commitment": None,
            "next_state_commitment": None,
            "reason_code": "OUTCOME_NOT_COMMITTED",
        }
    )
    validate_evidence(negative)
    assert_changed(
        "completion_class_and_outcome_commitment_changed",
        evidence_commitment(evidence[4]),
        evidence_commitment(negative),
    )

    assert canonical_request_payload(request) == canonical_request_payload(deepcopy(request))
    assert canonical_evidence_payload(evidence[4]) == canonical_evidence_payload(deepcopy(evidence[4]))
    print("canonical_encoding_deterministic=1")

    adversarial = load_json("adversarial-cases.json")
    for case in adversarial["cases"]:
        if case.get("operation") == "append_copy":
            candidate = deepcopy(lifecycle)
            appended = deepcopy(candidate["evidence"][case["source_index"]])
            appended["sequence"] = len(candidate["evidence"])
            appended["previous_evidence_commitment"] = evidence_commitment(candidate["evidence"][-1])
            candidate["evidence"].append(appended)
        else:
            candidate = apply_mutation(lifecycle, case["path"], case["value"])
        expect_rejected(case["name"], candidate, case["expected_error"])

    print("ACCELERATOR_EFFECT_AUTHORITY_V1_PASS")


if __name__ == "__main__":
    main()

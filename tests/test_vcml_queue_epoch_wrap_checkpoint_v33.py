from dataclasses import replace
from pathlib import Path
import sys

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from tools.vcml_queue_epoch_wrap_checkpoint_v33 import (
    COMMITTED,
    UNKNOWN,
    UNISSUED,
    QueueEpochWrapCheckpointV33,
    authority_consistent,
    canonical_digest,
    successor_identity_valid,
)


def base_state() -> QueueEpochWrapCheckpointV33:
    # Historical checkpoint: incarnation 1 / epoch 0.
    # Current durable slot after numeric epoch wrap: incarnation 2 / epoch 0.
    return QueueEpochWrapCheckpointV33(
        runtime_ready=True,
        slot_pending=True,
        live_incarnation=2,
        live_queue_epoch=0,
        live_command_id=1,
        live_execution_epoch=2,
        live_effect_id=3,
        effect_state=UNKNOWN,
        durable_slot_valid=True,
        durable_incarnation=2,
        durable_queue_epoch=0,
        durable_command_id=1,
        durable_execution_epoch=2,
        durable_effect_id=3,
        last_retired_valid=True,
        last_retired_incarnation=1,
        last_retired_queue_epoch=255,
        checkpoint_valid=True,
        checkpoint_pending=True,
        checkpoint_incarnation=1,
        checkpoint_queue_epoch=0,
        checkpoint_command_id=1,
        checkpoint_execution_epoch=2,
        checkpoint_effect_id=3,
        checkpoint_effect_state=UNISSUED,
        issue_receipt=True,
        negative_receipt=False,
        completion_receipt=False,
        stale_evidence_quarantined=True,
    )


def changed(name: str, before: QueueEpochWrapCheckpointV33, after: QueueEpochWrapCheckpointV33) -> None:
    ok = canonical_digest(before) != canonical_digest(after)
    print(f"{name}={int(ok)}")
    assert ok


def rejected(name: str, state: QueueEpochWrapCheckpointV33) -> None:
    ok = not authority_consistent(state)
    print(f"{name}={int(ok)}")
    assert ok


def check(name: str, ok: bool) -> None:
    print(f"{name}={int(ok)}")
    assert ok


def main() -> None:
    s = base_state()
    assert authority_consistent(s)

    changed("live_incarnation_change_digest_changed", s, replace(s, live_incarnation=3, durable_incarnation=3))
    changed("durable_incarnation_change_digest_changed", s, replace(s, durable_incarnation=3, live_incarnation=3))
    changed("retired_incarnation_change_digest_changed", s, replace(s, last_retired_incarnation=0))
    changed("checkpoint_incarnation_change_digest_changed", s, replace(s, checkpoint_incarnation=0))
    changed("queue_epoch_change_digest_changed", s, replace(s, live_queue_epoch=1, durable_queue_epoch=1))
    changed("stale_evidence_quarantine_digest_changed", s, replace(s, stale_evidence_quarantined=False))

    rejected(
        "wrap_without_incarnation_increment_rejected",
        replace(s, live_incarnation=1, durable_incarnation=1),
    )
    rejected(
        "wrap_with_skipped_incarnation_rejected",
        replace(s, live_incarnation=3, durable_incarnation=3),
    )
    rejected(
        "future_incarnation_checkpoint_rejected",
        replace(s, checkpoint_incarnation=3, checkpoint_queue_epoch=0),
    )
    rejected(
        "unknown_without_issue_receipt_rejected",
        replace(s, issue_receipt=False),
    )
    rejected(
        "committed_without_completion_receipt_rejected",
        replace(s, effect_state=COMMITTED, issue_receipt=False, completion_receipt=False),
    )

    check("nonwrap_same_incarnation_successor_accepted", successor_identity_valid(7, 9, 7, 10))
    check("nonwrap_incarnation_change_rejected", not successor_identity_valid(7, 9, 8, 10))
    check("exact_wrap_successor_accepted", successor_identity_valid(7, 255, 8, 0))
    check("same_incarnation_numeric_wrap_rejected", not successor_identity_valid(7, 255, 7, 0))
    check("skipped_incarnation_wrap_rejected", not successor_identity_valid(7, 255, 9, 0))
    check("incarnation_exhaustion_fail_closed", not successor_identity_valid(255, 255, 0, 0))

    print(f"stale_same_epoch_foreign_incarnation_checkpoint_preserved={int(authority_consistent(s))}")
    print(f"canonical_digest={canonical_digest(s)}")
    print("VCML_QUEUE_EPOCH_WRAP_CHECKPOINT_V33_PASS")


if __name__ == "__main__":
    main()

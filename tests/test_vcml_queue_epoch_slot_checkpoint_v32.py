from dataclasses import replace

from tools.vcml_queue_epoch_slot_checkpoint_v32 import (
    COMMITTED,
    UNKNOWN,
    UNISSUED,
    QueueEpochSlotCheckpointV32,
    authority_consistent,
    canonical_digest,
)


def base_state() -> QueueEpochSlotCheckpointV32:
    # Epoch 2 checkpoint is stale; epoch 3 is the durable reused slot.
    return QueueEpochSlotCheckpointV32(
        runtime_ready=True,
        slot_pending=True,
        live_queue_epoch=3,
        live_command_id=5,
        live_execution_epoch=6,
        live_effect_id=7,
        effect_state=UNKNOWN,
        durable_slot_valid=True,
        durable_queue_epoch=3,
        durable_command_id=5,
        durable_execution_epoch=6,
        durable_effect_id=7,
        last_retired_valid=True,
        last_retired_queue_epoch=2,
        checkpoint_valid=True,
        checkpoint_pending=True,
        checkpoint_queue_epoch=2,
        checkpoint_command_id=5,
        checkpoint_execution_epoch=6,
        checkpoint_effect_id=7,
        checkpoint_effect_state=UNISSUED,
        issue_receipt=True,
        negative_receipt=False,
        completion_receipt=False,
        stale_evidence_quarantined=True,
    )


def changed(name: str, before: QueueEpochSlotCheckpointV32, after: QueueEpochSlotCheckpointV32) -> None:
    ok = canonical_digest(before) != canonical_digest(after)
    print(f"{name}={int(ok)}")
    assert ok


def rejected(name: str, state: QueueEpochSlotCheckpointV32) -> None:
    ok = not authority_consistent(state)
    print(f"{name}={int(ok)}")
    assert ok


def main() -> None:
    s = base_state()
    assert authority_consistent(s)

    changed("queue_epoch_change_digest_changed", s, replace(s, live_queue_epoch=4, durable_queue_epoch=4))
    changed("retired_epoch_change_digest_changed", s, replace(s, last_retired_queue_epoch=1))
    changed("checkpoint_epoch_change_digest_changed", s, replace(s, checkpoint_queue_epoch=1))
    changed("durable_identity_change_digest_changed", s, replace(s, durable_effect_id=8, live_effect_id=8))
    changed("issue_receipt_change_digest_changed", s, replace(s, issue_receipt=False, effect_state=UNISSUED))
    changed("stale_evidence_quarantine_digest_changed", s, replace(s, stale_evidence_quarantined=False))

    rejected(
        "same_epoch_slot_reuse_rejected",
        replace(s, live_queue_epoch=2, durable_queue_epoch=2),
    )
    rejected(
        "skipped_epoch_slot_reuse_rejected",
        replace(s, live_queue_epoch=4, durable_queue_epoch=4),
    )
    rejected(
        "unknown_without_issue_receipt_rejected",
        replace(s, issue_receipt=False),
    )
    rejected(
        "committed_without_completion_receipt_rejected",
        replace(s, effect_state=COMMITTED, issue_receipt=False, completion_receipt=False),
    )
    rejected(
        "future_checkpoint_epoch_rejected",
        replace(s, checkpoint_queue_epoch=4),
    )

    print(f"stale_checkpoint_predates_reused_slot_preserved={int(authority_consistent(s))}")
    print(f"canonical_digest={canonical_digest(s)}")
    print("VCML_QUEUE_EPOCH_SLOT_CHECKPOINT_V32_PASS")


if __name__ == "__main__":
    main()

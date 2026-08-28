from dataclasses import replace
from pathlib import Path
import sys

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from tools.vcml_concurrent_dma_queue_checkpoint_v31 import (
    COMMITTED,
    UNKNOWN,
    ConcurrentDMAQueueCheckpointV31,
    authority_consistent,
    canonical_digest,
)


def base_state() -> ConcurrentDMAQueueCheckpointV31:
    return ConcurrentDMAQueueCheckpointV31(
        runtime_ready=True,
        tx_pending=(True, True),
        tx_retired=(False, False),
        live_queue_epoch=3,
        live_command_ids=(10, 11),
        live_execution_epochs=(4, 4),
        live_effect_ids=(8, 9),
        fragment_states=(COMMITTED, COMMITTED, COMMITTED, COMMITTED),
        durable_tx_valid=(True, True),
        durable_queue_epoch=3,
        durable_command_ids=(10, 11),
        durable_execution_epochs=(4, 4),
        durable_effect_ids=(8, 9),
        checkpoint_valid=True,
        checkpoint_tx_pending=(True, True),
        checkpoint_tx_retired=(False, False),
        checkpoint_queue_epoch=3,
        checkpoint_command_ids=(10, 11),
        checkpoint_execution_epochs=(4, 4),
        checkpoint_effect_ids=(8, 9),
        checkpoint_fragment_states=(COMMITTED, COMMITTED, COMMITTED, UNKNOWN),
        checkpoint_owner_valid=0b1111,
        checkpoint_owner_map=(0, 0, 1, 2),
        issue_receipt_bitmap=0,
        negative_receipt_bitmap=0,
        completion_receipt_bitmap=0b1111,
        durable_owner_valid=0b1111,
        durable_owner_map=(0, 3, 3, 2),
    )


def main() -> None:
    s = base_state()
    assert authority_consistent(s)
    d = canonical_digest(s)

    q = replace(s, live_queue_epoch=4, durable_queue_epoch=4, checkpoint_queue_epoch=4)
    assert canonical_digest(q) != d
    print("queue_epoch_change_digest_changed=1")

    swapped = replace(
        s,
        live_command_ids=(11, 10),
        durable_command_ids=(11, 10),
        checkpoint_command_ids=(11, 10),
        live_effect_ids=(9, 8),
        durable_effect_ids=(9, 8),
        checkpoint_effect_ids=(9, 8),
    )
    assert canonical_digest(swapped) != d
    print("transaction_slot_swap_digest_changed=1")

    younger_retired_first = replace(s, tx_pending=(True, False), tx_retired=(False, True))
    assert not authority_consistent(younger_retired_first)
    print("younger_retired_before_older_rejected=1")

    owner_without_commit = replace(s, completion_receipt_bitmap=0b0111)
    assert not authority_consistent(owner_without_commit)
    print("owner_without_fragment_commit_rejected=1")

    overlap_before_older = replace(
        s,
        fragment_states=(UNKNOWN, COMMITTED, COMMITTED, UNKNOWN),
        issue_receipt_bitmap=0b1001,
        completion_receipt_bitmap=0b0110,
        durable_owner_valid=0b1100,
        durable_owner_map=(0, 0, 1, 2),
    )
    assert not authority_consistent(overlap_before_older)
    print("younger_overlap_without_older_completion_rejected=1")

    foreign_checkpoint_slot = replace(s, checkpoint_effect_ids=(8, 7))
    assert not authority_consistent(foreign_checkpoint_slot)
    print("foreign_checkpoint_transaction_slot_rejected=1")

    no_younger_durable_slot = replace(s, durable_tx_valid=(True, False))
    assert not authority_consistent(no_younger_durable_slot)
    print("younger_fragment_evidence_without_durable_slot_rejected=1")

    wrong_durable_identity = replace(s, durable_effect_ids=(8, 7))
    assert not authority_consistent(wrong_durable_identity)
    print("durable_slot_identity_mismatch_rejected=1")

    # A checkpoint may legitimately predate TX1. Durable TX1 slot authority and
    # later fragment evidence must coexist with that stale checkpoint without
    # allowing the slot to disappear or be reused.
    stale_pre_tx1 = replace(
        s,
        checkpoint_tx_pending=(True, False),
        checkpoint_command_ids=(10, 0),
        checkpoint_execution_epochs=(4, 0),
        checkpoint_effect_ids=(8, 0),
        checkpoint_fragment_states=(0, 0, 0, 0),
        checkpoint_owner_valid=0,
        checkpoint_owner_map=(0, 0, 0, 0),
    )
    assert authority_consistent(stale_pre_tx1)
    assert canonical_digest(stale_pre_tx1) != d
    print("stale_checkpoint_predates_younger_slot_preserved=1")

    print(f"canonical_digest={d}")
    print("VCML_CONCURRENT_DMA_QUEUE_CHECKPOINT_V31_PASS")


if __name__ == "__main__":
    main()

from pathlib import Path
import sys
sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from dataclasses import replace
from tools.vcml_overlapping_dma_checkpoint_v30 import (
    COMMITTED,
    NOT_COMMITTED,
    UNKNOWN,
    OverlappingFragmentCheckpointV30,
    authority_consistent,
    canonical_digest,
)

base = OverlappingFragmentCheckpointV30(
    runtime_ready=True,
    command_pending=True,
    live_command_id=12,
    live_execution_epoch=7,
    live_effect_id=14,
    fragment_states=(COMMITTED, UNKNOWN, COMMITTED, UNKNOWN),
    checkpoint_valid=True,
    checkpoint_command_pending=True,
    checkpoint_command_id=12,
    checkpoint_execution_epoch=7,
    checkpoint_effect_id=14,
    checkpoint_fragment_states=(COMMITTED, UNKNOWN, COMMITTED, UNKNOWN),
    checkpoint_owner_valid=0b1111,
    checkpoint_owner_map=(0, 0, 2, 2),
    issue_receipt_bitmap=0b1010,
    negative_receipt_bitmap=0,
    completion_receipt_bitmap=0b0101,
    receipt_command_id=12,
    receipt_execution_epoch=7,
    receipt_effect_id=14,
    durable_owner_valid=0b1111,
    durable_owner_map=(0, 0, 2, 2),
)

assert authority_consistent(base)
d0 = canonical_digest(base)

mutations = {
    "fragment_states_change": replace(base, fragment_states=(COMMITTED, NOT_COMMITTED, COMMITTED, UNKNOWN)),
    "checkpoint_fragment_states_change": replace(base, checkpoint_fragment_states=(COMMITTED, UNKNOWN, COMMITTED, COMMITTED)),
    "issue_receipt_bitmap_change": replace(base, issue_receipt_bitmap=0b0010),
    "negative_receipt_bitmap_change": replace(base, negative_receipt_bitmap=0b0010),
    "completion_receipt_bitmap_change": replace(base, completion_receipt_bitmap=0b1101),
    "checkpoint_owner_change": replace(base, checkpoint_owner_map=(3, 0, 2, 2)),
    "durable_owner_change": replace(base, durable_owner_map=(3, 0, 2, 2)),
    "durable_owner_valid_change": replace(base, durable_owner_valid=0b0111),
    "receipt_identity_change": replace(base, receipt_effect_id=13),
}
for name, candidate in mutations.items():
    assert canonical_digest(candidate) != d0
    print(f"{name}_digest_changed=1")

committed_without_receipt = replace(base, fragment_states=(COMMITTED, COMMITTED, COMMITTED, UNKNOWN))
assert not authority_consistent(committed_without_receipt)
print("committed_without_completion_receipt_rejected=1")

foreign_receipt = replace(base, receipt_effect_id=13)
assert not authority_consistent(foreign_receipt)
print("foreign_receipt_identity_mixed_state_rejected=1")

owner_without_commit = replace(base, durable_owner_map=(3, 0, 2, 2))
assert not authority_consistent(owner_without_commit)
print("owner_without_fragment_commit_rejected=1")

overlap_owner_wrong_lane = replace(base, durable_owner_map=(1, 0, 2, 2))
assert not authority_consistent(overlap_owner_wrong_lane)
print("overlap_owner_wrong_lane_rejected=1")

print(f"canonical_digest={d0}")
print("VCML_OVERLAPPING_DMA_CHECKPOINT_V30_PASS")

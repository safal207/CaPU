from pathlib import Path
import sys
from dataclasses import replace

ROOT = Path(__file__).resolve().parents[1]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

from tools.vcml_cross_generation_checkpoint_v24 import CrossGenerationState, digest, digest_hex, verify

BASE_V23 = bytes.fromhex("c00fbcd530c4183e9266ecddb44720bbce7bb3a0141c4b0ca4977c64707faac0")

base = CrossGenerationState(
    base_v23_digest=BASE_V23,
    last_retired_valid=1,
    last_retired_generation=5,
    pending=1,
    pending_generation=6,
    asid=2,
    translation_epoch=7,
    vpn=9,
    required_harts=3,
    delivered_bitmap=1,
    ack_bitmap=1,
    quarantined_delivery_bitmap=1,
    quarantined_ack_bitmap=2,
    quarantine_events=2,
)

commitment = digest(base)
assert verify(base, commitment)

mutations = {
    "last_retired_generation": replace(base, last_retired_generation=4),
    "pending_generation": replace(base, pending_generation=7),
    "delivered_bitmap": replace(base, delivered_bitmap=3),
    "ack_bitmap": replace(base, ack_bitmap=3),
    "quarantined_delivery_bitmap": replace(base, quarantined_delivery_bitmap=0),
    "quarantined_ack_bitmap": replace(base, quarantined_ack_bitmap=0),
    "quarantine_events": replace(base, quarantine_events=3),
    "pending": replace(base, pending=0),
}

for name, candidate in mutations.items():
    assert digest(candidate) != commitment, name
    print(f"{name}_change_digest_changed=1")

mixed = replace(base, pending_generation=7, quarantined_delivery_bitmap=0, quarantine_events=0)
assert not verify(mixed, commitment)
print("mixed_cross_generation_authority_rejected=1")
print(f"canonical_digest={digest_hex(base)}")
print("VCML_CROSS_GENERATION_CHECKPOINT_V24_PASS")

#!/usr/bin/env python3
from copy import deepcopy
from tools.vcml_multihart_shootdown_checkpoint_v22 import checkpoint_digest, verify

base = {
    "base_checkpoint_digest": "a712a5c668e856614bbab51ba9a772cb88c8740e4cb5e7bf18bf6b27a669812f",
    "shootdown_pending": True,
    "shootdown_generation": 9,
    "asid": 3,
    "translation_epoch": 8,
    "vpn": 4,
    "required_harts": 3,
    "ack_bitmap": 1,
}

digest = checkpoint_digest(base)
assert verify(base, digest)

mutations = {
    "generation_change": ("shootdown_generation", 10),
    "asid_change": ("asid", 2),
    "epoch_change": ("translation_epoch", 9),
    "vpn_change": ("vpn", 5),
    "required_harts_change": ("required_harts", 1),
    "ack_bitmap_change": ("ack_bitmap", 3),
    "pending_change": ("shootdown_pending", False),
}

for name, (field, value) in mutations.items():
    candidate = deepcopy(base)
    candidate[field] = value
    assert checkpoint_digest(candidate) != digest
    assert not verify(candidate, digest)
    print(f"{name}_digest_changed=1")

mixed = deepcopy(base)
mixed["shootdown_generation"] = 10
mixed["ack_bitmap"] = 3
assert not verify(mixed, digest)
print("mixed_quorum_authority_rejected=1")
print(f"canonical_digest={digest}")
print("VCML_MULTIHART_SHOOTDOWN_CHECKPOINT_V22_PASS")

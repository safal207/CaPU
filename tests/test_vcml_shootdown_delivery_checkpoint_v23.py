#!/usr/bin/env python3
from copy import deepcopy
from pathlib import Path
import sys
sys.path.insert(0,str(Path(__file__).resolve().parents[1]))
from tools.vcml_shootdown_delivery_checkpoint_v23 import checkpoint_digest,verify

BASE={
  "base_checkpoint_digest":"72a3861a9a34f357e797d2f9781abe62a5cb30087c01dce9acd8af1b4060d15f",
  "shootdown_pending":True,
  "shootdown_generation":10,
  "asid":3,
  "translation_epoch":9,
  "vpn":5,
  "required_harts":3,
  "delivered_bitmap":1,
  "ack_bitmap":1,
  "attempts0":2,
  "attempts1":1,
}

def mutate(k,v):
  x=deepcopy(BASE);x[k]=v;return x

def main():
  d=checkpoint_digest(BASE);assert verify(BASE,d)
  tests={
    "generation_change":mutate("shootdown_generation",11),
    "required_harts_change":mutate("required_harts",1),
    "delivered_bitmap_change":mutate("delivered_bitmap",3),
    "ack_bitmap_change":mutate("ack_bitmap",0),
    "attempts0_change":mutate("attempts0",3),
    "attempts1_change":mutate("attempts1",2),
    "pending_change":mutate("shootdown_pending",False),
  }
  for label,s in tests.items():
    assert checkpoint_digest(s)!=d and not verify(s,d);print(label+"_digest_changed=1")
  mixed=deepcopy(BASE);mixed["delivered_bitmap"]=3;mixed["attempts1"]=3
  assert not verify(mixed,d);print("mixed_delivery_authority_rejected=1")
  print(f"canonical_digest={d}")
  print("VCML_SHOOTDOWN_DELIVERY_CHECKPOINT_V23_PASS")
if __name__=="__main__":main()

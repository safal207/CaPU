#!/usr/bin/env python3
from copy import deepcopy
from pathlib import Path
import sys
sys.path.insert(0,str(Path(__file__).resolve().parents[1]))
from tools.vcml_tlb_checkpoint_v21 import commitment_hex,verify
BASE={"base_payload":0xA51,"tlb_valid":True,"tlb_asid":3,"tlb_epoch":7,"tlb_vpn":4,"tlb_ppn":9,"perm_r":True,"perm_w":False,"perm_x":True,"perm_u":True,"shootdown_pending":False,"shootdown_asid":0,"shootdown_epoch":0,"shootdown_vpn":0}
KW=dict(checkpoint_ref=3,checkpoint_epoch=6,checkpoint_ref_width=4,checkpoint_epoch_width=4,base_payload_width=12,asid_width=3,translation_epoch_width=4,vpn_width=4,ppn_width=4)
def mutate(k,v):
 x=deepcopy(BASE);x[k]=v;return x
def main():
 d=commitment_hex(BASE,**KW);assert verify(BASE,d,**KW)
 tests={"tlb_asid_change_digest_changed":mutate("tlb_asid",2),"tlb_epoch_change_digest_changed":mutate("tlb_epoch",8),"tlb_mapping_change_digest_changed":mutate("tlb_ppn",8),"tlb_permission_change_digest_changed":mutate("perm_w",True)}
 for label,s in tests.items():
  assert commitment_hex(s,**KW)!=d and not verify(s,d,**KW);print(label+"=1")
 s=deepcopy(BASE);s.update(shootdown_pending=True,shootdown_asid=3,shootdown_epoch=8,shootdown_vpn=4)
 assert commitment_hex(s,**KW)!=d and not verify(s,d,**KW);print("shootdown_authority_change_digest_changed=1")
 mixed=deepcopy(BASE);mixed["tlb_epoch"]=8;mixed["shootdown_pending"]=True;mixed["shootdown_epoch"]=8
 assert not verify(mixed,d,**KW);print("mixed_tlb_authority_rejected=1")
 print(f"canonical_digest={d}");print("VCML_TLB_CHECKPOINT_V21_PASS")
if __name__=="__main__":main()

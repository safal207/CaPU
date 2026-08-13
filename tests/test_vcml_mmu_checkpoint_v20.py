#!/usr/bin/env python3
from copy import deepcopy
from pathlib import Path
import sys
sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from tools.vcml_mmu_checkpoint_v20 import commitment_hex, verify

BASE={
    "base_payload":0xA51,"root":0x3,"asid":0x5,"translation_epoch":0x7,
    "vpn":0x4,"ppn":0x9,"perm_r":True,"perm_w":False,"perm_x":True,"perm_u":True,
    "fault_pending":False,"fault_vaddr":0,"fault_cause":0,
}
KW=dict(checkpoint_ref=2,checkpoint_epoch=5,checkpoint_ref_width=4,checkpoint_epoch_width=4,
        base_payload_width=12,root_width=4,asid_width=3,translation_epoch_width=4,
        vpn_width=4,ppn_width=4,page_offset_width=2,fault_cause_width=3)

def mutated(key,value):
    x=deepcopy(BASE); x[key]=value; return x

def main():
    digest=commitment_hex(BASE,**KW)
    assert verify(BASE,digest,**KW)
    tests={
      "root_change_digest_changed": mutated("root",6),
      "asid_change_digest_changed": mutated("asid",2),
      "translation_epoch_change_digest_changed": mutated("translation_epoch",6),
      "mapping_change_digest_changed": mutated("ppn",8),
      "permission_change_digest_changed": mutated("perm_w",True),
    }
    for label,s in tests.items():
        changed=commitment_hex(s,**KW)!=digest
        assert changed and not verify(s,digest,**KW)
        print(f"{label}=1")
    fault=deepcopy(BASE); fault.update(fault_pending=True,fault_vaddr=0x12,fault_cause=1)
    assert commitment_hex(fault,**KW)!=digest and not verify(fault,digest,**KW)
    print("fault_context_change_digest_changed=1")
    mixed=deepcopy(BASE); mixed["root"]=6; mixed["asid"]=2
    assert not verify(mixed,digest,**KW)
    print("mixed_memory_view_rejected=1")
    print(f"canonical_digest={digest}")
    print("VCML_MMU_CHECKPOINT_V20_PASS")

if __name__=="__main__": main()

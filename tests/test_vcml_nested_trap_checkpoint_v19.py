#!/usr/bin/env python3
from copy import deepcopy
from pathlib import Path
import sys
sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from tools.vcml_replay_snapshot import SCHEMA as REPLAY_SCHEMA
from tools.vcml_causal_checkpoint_v14 import build_causal_snapshot
from tools.vcml_arch_checkpoint_v17 import build_arch_snapshot
from tools.vcml_trap_checkpoint_v18 import build_trap_snapshot
from tools.vcml_nested_trap_checkpoint_v19 import (
    build_nested_snapshot, checkpoint_commitment_hex, verify_checkpoint_commitment
)

KW=dict(checkpoint_ref=0x51,checkpoint_epoch=9,checkpoint_ref_width=8,checkpoint_epoch_width=8,pc_width=16,cause_width=8)

def digest(s): return checkpoint_commitment_hex(s,**KW)

def main():
    causal=build_causal_snapshot({"schema":REPLAY_SCHEMA,"capacity":4,"spent_refs":[0x110,0x120]},
        causal_head_valid=True,causal_head_transition_id=0x3301,causal_head_gen=7,sealed_chain=False)
    arch=build_arch_snapshot(causal,recovery_epoch=0x31,pc=0x40,gprs=[0,0x80,0x55,0],status=0xA5)
    v18=build_trap_snapshot(arch,privilege_mode=1,trap_pending=False,trap_is_interrupt=False,
        trap_cause=0,trap_return_pc=0,trap_return_privilege=0,interrupt_mask=False)
    outer={"is_interrupt":False,"cause":3,"return_pc":0x40,"return_privilege":1,"target_privilege":2}
    inner={"is_interrupt":True,"cause":5,"return_pc":0x80,"return_privilege":2,"target_privilege":3}
    base=build_nested_snapshot(v18,privilege=3,delegation_mask=0b1100,trap_depth=2,contexts=[outer,inner])
    d=digest(base)

    for label,mut in (
        ("delegation",lambda x:x.__setitem__("delegation_mask",0b1000)),
        ("privilege",lambda x:x.__setitem__("privilege",2)),
        ("parent_context",lambda x:x["contexts"][0].__setitem__("return_pc",0x41)),
        ("nested_context",lambda x:x["contexts"][1].__setitem__("cause",6)),
    ):
        x=deepcopy(base); mut(x); assert digest(x)!=d, label

    mixed=deepcopy(base); mixed["contexts"][0]["return_privilege"]=0
    assert not verify_checkpoint_commitment(mixed,d,**KW)

    assert verify_checkpoint_commitment(base,d,**KW)
    print(f"canonical_digest={d}")
    print("delegation_change_digest_changed=1")
    print("parent_context_change_digest_changed=1")
    print("nested_context_change_digest_changed=1")
    print("mixed_parent_snapshot_rejected=1")
    print("VCML_NESTED_TRAP_CHECKPOINT_V19_PASS")

if __name__=="__main__": main()

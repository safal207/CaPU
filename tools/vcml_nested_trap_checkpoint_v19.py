#!/usr/bin/env python3
from __future__ import annotations
import hashlib, hmac
from typing import Any, Mapping
from tools.vcml_trap_checkpoint_v18 import validate_trap_snapshot

SCHEMA = "capu.vcml.nested-trap-checkpoint.v0.19"
DOMAIN = b"CaPU-vCML-nested-trap-checkpoint-v0.19\x00"


def _u(v:int, bits:int, label:str)->bytes:
    v=int(v)
    if v < 0 or v >= (1<<bits):
        raise ValueError(f"{label} exceeds {bits}-bit width")
    return v.to_bytes((bits+7)//8,"big")


def build_nested_snapshot(base_v18:Mapping[str,Any], *, privilege:int, delegation_mask:int,
                          trap_depth:int, contexts:list[Mapping[str,Any]])->dict[str,Any]:
    validate_trap_snapshot(base_v18)
    s={"schema":SCHEMA,"base_v18":dict(base_v18),"privilege":int(privilege),
       "delegation_mask":int(delegation_mask),"trap_depth":int(trap_depth),
       "contexts":[dict(x) for x in contexts]}
    validate_nested_snapshot(s)
    return s


def validate_nested_snapshot(s:Mapping[str,Any])->None:
    if s.get("schema") != SCHEMA: raise ValueError("unsupported nested trap schema")
    validate_trap_snapshot(s["base_v18"])
    d=int(s["trap_depth"])
    if d not in (0,1,2): raise ValueError("trap_depth must be 0..2")
    ctx=list(s["contexts"])
    if len(ctx)!=d: raise ValueError("contexts must exactly match trap_depth")
    if int(s["privilege"]) not in range(4): raise ValueError("privilege must be 0..3")
    if int(s["delegation_mask"]) not in range(16): raise ValueError("delegation_mask must be 4-bit")
    for c in ctx:
        required={"is_interrupt","cause","return_pc","return_privilege","target_privilege"}
        if set(c)!=required: raise ValueError("non-canonical trap context")
        if int(c["return_privilege"]) not in range(4) or int(c["target_privilege"]) not in range(4):
            raise ValueError("context privilege must be 0..3")


def canonical_payload(s:Mapping[str,Any], *, checkpoint_ref:int, checkpoint_epoch:int,
                      checkpoint_ref_width:int=16, checkpoint_epoch_width:int=16,
                      pc_width:int=16, cause_width:int=8)->bytes:
    validate_nested_snapshot(s)
    from tools.vcml_trap_checkpoint_v18 import canonical_payload as v18_payload
    base=v18_payload(s["base_v18"],checkpoint_ref=checkpoint_ref,checkpoint_epoch=checkpoint_epoch,
                     checkpoint_ref_width=checkpoint_ref_width,checkpoint_epoch_width=checkpoint_epoch_width,
                     recovery_epoch_width=8,pc_width=pc_width,data_width=32,
                     transition_id_width=64,authorization_ref_width=16,slots=4,
                     privilege_width=2,cause_width=cause_width)
    out=bytearray(DOMAIN)
    out.extend(len(base).to_bytes(4,"big")); out.extend(base)
    out.extend(_u(s["privilege"],2,"privilege"))
    out.extend(_u(s["delegation_mask"],4,"delegation_mask"))
    out.extend(_u(s["trap_depth"],2,"trap_depth"))
    for c in s["contexts"]:
        out.append(1 if c["is_interrupt"] else 0)
        out.extend(_u(c["cause"],cause_width,"cause"))
        out.extend(_u(c["return_pc"],pc_width,"return_pc"))
        out.extend(_u(c["return_privilege"],2,"return_privilege"))
        out.extend(_u(c["target_privilege"],2,"target_privilege"))
    for _ in range(2-len(s["contexts"])):
        out.extend(b"\x00" * (1 + (cause_width+7)//8 + (pc_width+7)//8 + 1 + 1))
    return bytes(out)


def checkpoint_commitment_hex(s:Mapping[str,Any], **kw:Any)->str:
    return hashlib.sha256(canonical_payload(s,**kw)).hexdigest()


def verify_checkpoint_commitment(s:Mapping[str,Any], commitment_hex:str, **kw:Any)->bool:
    try: supplied=bytes.fromhex(commitment_hex)
    except ValueError: return False
    expected=bytes.fromhex(checkpoint_commitment_hex(s,**kw))
    return len(supplied)==len(expected) and hmac.compare_digest(supplied,expected)

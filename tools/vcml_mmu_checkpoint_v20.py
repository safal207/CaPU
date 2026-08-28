#!/usr/bin/env python3
"""Canonical CaPU v0.20 MMU/page-fault checkpoint helpers."""
from __future__ import annotations
import hashlib, hmac
from typing import Mapping, Any

SCHEMA = "capu.vcml.mmu-translation-checkpoint.v0.20"
DOMAIN = b"CaPU-vCML-mmu-translation-checkpoint-v0.20\x00"


def _u(v:int,bits:int,label:str)->bytes:
    v=int(v)
    if v < 0 or v >= (1<<bits):
        raise ValueError(f"{label} exceeds {bits}-bit width")
    return v.to_bytes((bits+7)//8,"big")


def canonical_payload(snapshot:Mapping[str,Any], *, checkpoint_ref:int, checkpoint_epoch:int,
                      checkpoint_ref_width:int=16, checkpoint_epoch_width:int=16,
                      base_payload_width:int=256, root_width:int=12, asid_width:int=8,
                      translation_epoch_width:int=8, vpn_width:int=8, ppn_width:int=8,
                      page_offset_width:int=4, fault_cause_width:int=3)->bytes:
    required={"base_payload","root","asid","translation_epoch","vpn","ppn","perm_r","perm_w","perm_x","perm_u","fault_pending","fault_vaddr","fault_cause"}
    if set(snapshot)!=required:
        raise ValueError("snapshot keys must exactly match v0.20 authority schema")
    vaddr_width=vpn_width+page_offset_width
    if not bool(snapshot["fault_pending"]):
        if int(snapshot["fault_vaddr"]) != 0 or int(snapshot["fault_cause"]) != 0:
            raise ValueError("non-zero fault context requires fault_pending")
    out=bytearray(DOMAIN)
    out.extend(_u(checkpoint_ref,checkpoint_ref_width,"checkpoint_ref"))
    out.extend(_u(checkpoint_epoch,checkpoint_epoch_width,"checkpoint_epoch"))
    out.extend(_u(snapshot["base_payload"],base_payload_width,"base_payload"))
    out.extend(_u(snapshot["root"],root_width,"root"))
    out.extend(_u(snapshot["asid"],asid_width,"asid"))
    out.extend(_u(snapshot["translation_epoch"],translation_epoch_width,"translation_epoch"))
    out.extend(_u(snapshot["vpn"],vpn_width,"vpn"))
    out.extend(_u(snapshot["ppn"],ppn_width,"ppn"))
    for k in ("perm_r","perm_w","perm_x","perm_u","fault_pending"):
        out.append(1 if bool(snapshot[k]) else 0)
    out.extend(_u(snapshot["fault_vaddr"],vaddr_width,"fault_vaddr"))
    out.extend(_u(snapshot["fault_cause"],fault_cause_width,"fault_cause"))
    return bytes(out)


def commitment_bytes(snapshot:Mapping[str,Any],**kwargs:Any)->bytes:
    return hashlib.sha256(canonical_payload(snapshot,**kwargs)).digest()

def commitment_hex(snapshot:Mapping[str,Any],**kwargs:Any)->str:
    return commitment_bytes(snapshot,**kwargs).hex()

def verify(snapshot:Mapping[str,Any], commitment_hex_value:str, **kwargs:Any)->bool:
    try: supplied=bytes.fromhex(commitment_hex_value)
    except ValueError: return False
    expected=commitment_bytes(snapshot,**kwargs)
    return len(supplied)==len(expected) and hmac.compare_digest(supplied,expected)

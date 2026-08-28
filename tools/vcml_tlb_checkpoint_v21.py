#!/usr/bin/env python3
import hashlib
SCHEMA=b"capu.vcml.tlb-shootdown-authority.v0.21\0"

def _u(v,w): return int(v).to_bytes((w+7)//8,'big')
def canonical_bytes(s,*,checkpoint_ref,checkpoint_epoch,checkpoint_ref_width=8,checkpoint_epoch_width=8,base_payload_width=16,asid_width=3,translation_epoch_width=4,vpn_width=4,ppn_width=4):
    out=bytearray(SCHEMA)
    out+=_u(checkpoint_ref,checkpoint_ref_width)+_u(checkpoint_epoch,checkpoint_epoch_width)
    out+=_u(s['base_payload'],base_payload_width)
    out+=bytes([bool(s['tlb_valid'])])+_u(s['tlb_asid'],asid_width)+_u(s['tlb_epoch'],translation_epoch_width)+_u(s['tlb_vpn'],vpn_width)+_u(s['tlb_ppn'],ppn_width)
    out+=bytes([bool(s['perm_r']),bool(s['perm_w']),bool(s['perm_x']),bool(s['perm_u'])])
    out+=bytes([bool(s['shootdown_pending'])])+_u(s['shootdown_asid'],asid_width)+_u(s['shootdown_epoch'],translation_epoch_width)+_u(s['shootdown_vpn'],vpn_width)
    return bytes(out)
def commitment_hex(s,**kw): return hashlib.sha256(canonical_bytes(s,**kw)).hexdigest()
def verify(s,digest,**kw): return commitment_hex(s,**kw)==digest.lower()

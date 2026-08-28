#!/usr/bin/env python3
import hashlib

DOMAIN=b"CAPU:VCML:SHOOTDOWN-DELIVERY-RELIABILITY:V0.23\x00"

def _u(v,n):
    if not isinstance(v,int) or v<0 or v >= (1<<(8*n)):
        raise ValueError(f"integer out of range for {n} bytes: {v!r}")
    return v.to_bytes(n,"big")

def _b(v): return b"\x01" if bool(v) else b"\x00"

def canonical_payload(s):
    base=bytes.fromhex(s["base_checkpoint_digest"])
    if len(base)!=32: raise ValueError("base_checkpoint_digest must be SHA-256 hex")
    return b"".join([
        DOMAIN,base,
        _b(s["shootdown_pending"]),
        _u(s["shootdown_generation"],1),
        _u(s["asid"],1),
        _u(s["translation_epoch"],1),
        _u(s["vpn"],1),
        _u(s["required_harts"],1),
        _u(s["delivered_bitmap"],1),
        _u(s["ack_bitmap"],1),
        _u(s["attempts0"],1),
        _u(s["attempts1"],1),
    ])

def checkpoint_digest(s): return hashlib.sha256(canonical_payload(s)).hexdigest()
def verify(s,expected): return checkpoint_digest(s)==expected.lower()

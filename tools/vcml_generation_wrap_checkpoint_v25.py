from __future__ import annotations
import hashlib, json
DOMAIN=b'capu.vcml.generation-wrap-aba.v0.25\0'
FIELDS=(
 'base_v24_digest','retired_valid','retired_incarnation','retired_generation',
 'pending','pending_incarnation','pending_generation','pending_asid','pending_epoch','pending_vpn',
 'required_harts','delivered_bitmap','ack_bitmap','quarantined_delivery_bitmap','quarantined_ack_bitmap'
)
def canonical_bytes(state:dict)->bytes:
    missing=[k for k in FIELDS if k not in state]
    if missing: raise ValueError(f'missing fields: {missing}')
    obj={k:state[k] for k in FIELDS}
    return DOMAIN+json.dumps(obj,sort_keys=True,separators=(',',':')).encode()
def digest(state:dict)->str:
    return hashlib.sha256(canonical_bytes(state)).hexdigest()
def verify(state:dict, commitment:str)->bool:
    return digest(state)==commitment

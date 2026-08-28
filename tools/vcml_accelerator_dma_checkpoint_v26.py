from __future__ import annotations
import hashlib, json

DOMAIN=b'capu.vcml.accelerator-dma-recovery.v0.26\0'
FIELDS=(
    'base_v25_digest',
    'runtime_ready','command_pending','live_command_id','live_execution_epoch','live_effect_id',
    'dma_issued','effect_spent','reconcile_required',
    'checkpoint_valid','checkpoint_command_pending','checkpoint_command_id',
    'checkpoint_execution_epoch','checkpoint_effect_id','checkpoint_dma_issued','checkpoint_effect_spent',
    'receipt_valid','receipt_command_id','receipt_execution_epoch','receipt_effect_id',
)

def canonical_bytes(state:dict)->bytes:
    missing=[k for k in FIELDS if k not in state]
    if missing:
        raise ValueError(f'missing fields: {missing}')
    obj={k:state[k] for k in FIELDS}
    return DOMAIN+json.dumps(obj,sort_keys=True,separators=(',',':')).encode()

def digest(state:dict)->str:
    return hashlib.sha256(canonical_bytes(state)).hexdigest()

def verify(state:dict, commitment:str)->bool:
    return digest(state)==commitment

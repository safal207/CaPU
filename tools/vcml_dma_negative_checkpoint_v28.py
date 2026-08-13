from __future__ import annotations
import hashlib, json

DOMAIN=b'capu.vcml.dma-negative-completion.v0.28\0'
FIELDS=(
 'base_v27_digest','runtime_ready','command_pending','live_command_id','live_execution_epoch','live_effect_id',
 'dma_issued','completion_state','evidence_required',
 'checkpoint_valid','checkpoint_command_pending','checkpoint_command_id','checkpoint_execution_epoch','checkpoint_effect_id','checkpoint_dma_issued','checkpoint_completion_state',
 'issue_receipt_valid','issue_receipt_command_id','issue_receipt_execution_epoch','issue_receipt_effect_id',
 'negative_receipt_valid','negative_receipt_command_id','negative_receipt_execution_epoch','negative_receipt_effect_id',
 'completion_receipt_valid','completion_receipt_command_id','completion_receipt_execution_epoch','completion_receipt_effect_id'
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

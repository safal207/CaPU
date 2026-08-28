from pathlib import Path
import sys
sys.path.insert(0,str(Path(__file__).resolve().parents[1]))
from tools.vcml_accelerator_dma_checkpoint_v26 import digest,verify

BASE={
    'base_v25_digest':'7d9f5a93ece085b6ed104a1f54f800410ae9ea08856a4c0092689aefc067319f',
    'runtime_ready':1,
    'command_pending':1,
    'live_command_id':5,
    'live_execution_epoch':3,
    'live_effect_id':9,
    'dma_issued':0,
    'effect_spent':0,
    'reconcile_required':1,
    'checkpoint_valid':1,
    'checkpoint_command_pending':1,
    'checkpoint_command_id':5,
    'checkpoint_execution_epoch':3,
    'checkpoint_effect_id':9,
    'checkpoint_dma_issued':0,
    'checkpoint_effect_spent':0,
    'receipt_valid':1,
    'receipt_command_id':5,
    'receipt_execution_epoch':3,
    'receipt_effect_id':9,
}

c=digest(BASE)
for field in [
    'command_pending','live_command_id','live_execution_epoch','live_effect_id',
    'dma_issued','effect_spent','reconcile_required','checkpoint_valid',
    'checkpoint_command_id','checkpoint_execution_epoch','checkpoint_effect_id',
    'checkpoint_dma_issued','checkpoint_effect_spent','receipt_valid',
    'receipt_command_id','receipt_execution_epoch','receipt_effect_id',
]:
    m=dict(BASE)
    m[field]=(m[field]+1) if isinstance(m[field],int) else 'x'
    assert digest(m)!=c,field
    print(f'{field}_change_digest_changed=1')

mixed=dict(BASE)
mixed['receipt_effect_id']=8
mixed['reconcile_required']=0
assert not verify(mixed,c)
print('mixed_dma_receipt_authority_rejected=1')

stale=dict(BASE)
stale['checkpoint_effect_spent']=0
stale['receipt_valid']=0
assert not verify(stale,c)
print('stale_checkpoint_without_receipt_rejected=1')

print('canonical_digest='+c)
print('VCML_ACCELERATOR_DMA_CHECKPOINT_V26_PASS')

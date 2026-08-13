from pathlib import Path
import sys
sys.path.insert(0,str(Path(__file__).resolve().parents[1]))
from tools.vcml_durable_negative_checkpoint_v28 import digest,verify

BASE={
 'base_v27_digest':'0e823705c97b662ea3b49c0642a336fb8db240410e8a2f50881db760ac86120f',
 'runtime_ready':1,'command_pending':1,'live_command_id':9,'live_execution_epoch':5,'live_effect_id':12,
 'dma_issued':0,'completion_state':'NOT_COMMITTED','evidence_required':0,
 'checkpoint_valid':1,'checkpoint_command_pending':1,'checkpoint_command_id':9,'checkpoint_execution_epoch':5,'checkpoint_effect_id':12,
 'checkpoint_dma_issued':1,'checkpoint_completion_state':'UNKNOWN',
 'issue_receipt_valid':0,'issue_receipt_command_id':9,'issue_receipt_execution_epoch':5,'issue_receipt_effect_id':12,
 'negative_receipt_valid':1,'negative_receipt_command_id':9,'negative_receipt_execution_epoch':5,'negative_receipt_effect_id':12,
 'completion_receipt_valid':0,'completion_receipt_command_id':0,'completion_receipt_execution_epoch':0,'completion_receipt_effect_id':0,
}

c=digest(BASE)
for field in [
 'runtime_ready','command_pending','live_command_id','live_execution_epoch','live_effect_id','dma_issued','completion_state','evidence_required',
 'checkpoint_dma_issued','checkpoint_completion_state','issue_receipt_valid','negative_receipt_valid','negative_receipt_command_id','negative_receipt_execution_epoch','negative_receipt_effect_id','completion_receipt_valid'
]:
    m=dict(BASE)
    v=m[field]
    if isinstance(v,int): m[field]=v+1
    else: m[field]='COMMITTED' if v!='COMMITTED' else 'UNKNOWN'
    assert digest(m)!=c,field
    print(f'{field}_change_digest_changed=1')

mixed=dict(BASE)
mixed['negative_receipt_valid']=0
mixed['completion_state']='UNKNOWN'; mixed['evidence_required']=1; mixed['dma_issued']=1
assert not verify(mixed,c)
print('durable_negative_to_unknown_mixed_state_rejected=1')

foreign=dict(BASE)
foreign['negative_receipt_effect_id']=13
assert not verify(foreign,c)
print('foreign_negative_receipt_mixed_state_rejected=1')

replay=dict(BASE)
replay['dma_issued']=1; replay['completion_state']='UNKNOWN'; replay['evidence_required']=1; replay['negative_receipt_valid']=1
assert not verify(replay,c)
print('stale_negative_receipt_survives_retry_mixed_state_rejected=1')

print('canonical_digest='+c)
print('VCML_DURABLE_NEGATIVE_CHECKPOINT_V28_PASS')

from pathlib import Path
import sys
sys.path.insert(0,str(Path(__file__).resolve().parents[1]))
from tools.vcml_dma_completion_checkpoint_v27 import digest,verify

BASE={
 'base_v26_digest':'ddfdc07cde04d3f732e8f479f4fbd8edd094494734801cf7c172468626809b9d',
 'runtime_ready':1,'command_pending':1,'live_command_id':7,'live_execution_epoch':4,'live_effect_id':10,
 'dma_issued':1,'completion_state':'UNKNOWN','evidence_required':1,
 'checkpoint_valid':1,'checkpoint_command_pending':1,'checkpoint_command_id':7,'checkpoint_execution_epoch':4,'checkpoint_effect_id':10,
 'checkpoint_dma_issued':0,'checkpoint_completion_state':'NOT_COMMITTED',
 'issue_receipt_valid':1,'issue_receipt_command_id':7,'issue_receipt_execution_epoch':4,'issue_receipt_effect_id':10,
 'completion_receipt_valid':0,'completion_receipt_command_id':0,'completion_receipt_execution_epoch':0,'completion_receipt_effect_id':0,
}

c=digest(BASE)
for field in [
 'runtime_ready','command_pending','live_command_id','live_execution_epoch','live_effect_id','dma_issued','completion_state','evidence_required',
 'checkpoint_dma_issued','checkpoint_completion_state','issue_receipt_valid','issue_receipt_effect_id','completion_receipt_valid'
]:
    m=dict(BASE)
    v=m[field]
    if isinstance(v,int): m[field]=v+1
    else: m[field]='COMMITTED' if v!='COMMITTED' else 'UNKNOWN'
    assert digest(m)!=c,field
    print(f'{field}_change_digest_changed=1')

mixed=dict(BASE)
mixed['completion_state']='NOT_COMMITTED'; mixed['evidence_required']=0; mixed['issue_receipt_valid']=0
assert not verify(mixed,c)
print('unknown_to_replayable_mixed_state_rejected=1')

mixed2=dict(BASE)
mixed2['completion_state']='COMMITTED'; mixed2['evidence_required']=0; mixed2['completion_receipt_valid']=1; mixed2['completion_receipt_command_id']=7; mixed2['completion_receipt_execution_epoch']=4; mixed2['completion_receipt_effect_id']=11
assert not verify(mixed2,c)
print('foreign_completion_receipt_mixed_state_rejected=1')

print('canonical_digest='+c)
print('VCML_DMA_COMPLETION_CHECKPOINT_V27_PASS')

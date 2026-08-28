from pathlib import Path
import sys
sys.path.insert(0,str(Path(__file__).resolve().parents[1]))
from tools.vcml_multibeat_dma_checkpoint_v29 import digest,verify

BASE={
 'base_v28_digest':'2ef0d09873fa10b8e0c73ad436222b98b3d89f9ab2176a00862e8b20c94a0d53',
 'runtime_ready':1,'command_pending':1,'live_command_id':11,'live_execution_epoch':6,'live_effect_id':13,
 'beat_states':['COMMITTED','COMMITTED','NOT_COMMITTED','UNISSUED'],
 'checkpoint_valid':1,'checkpoint_command_pending':1,'checkpoint_command_id':11,'checkpoint_execution_epoch':6,'checkpoint_effect_id':13,
 'checkpoint_beat_states':['COMMITTED','COMMITTED','UNKNOWN','UNISSUED'],
 'issue_receipt_bitmap':0,'negative_receipt_bitmap':4,'completion_receipt_bitmap':3,
 'receipt_command_id':11,'receipt_execution_epoch':6,'receipt_effect_id':13,
}

c=digest(BASE)
for field in [
 'runtime_ready','command_pending','live_command_id','live_execution_epoch','live_effect_id',
 'checkpoint_valid','checkpoint_command_pending','checkpoint_command_id','checkpoint_execution_epoch','checkpoint_effect_id',
 'issue_receipt_bitmap','negative_receipt_bitmap','completion_receipt_bitmap',
 'receipt_command_id','receipt_execution_epoch','receipt_effect_id'
]:
    m=dict(BASE); m[field]=m[field]+1
    assert digest(m)!=c,field
    print(f'{field}_change_digest_changed=1')

for field in ['beat_states','checkpoint_beat_states']:
    m=dict(BASE); m[field]=list(BASE[field]); m[field][2]='COMMITTED'
    assert digest(m)!=c,field
    print(f'{field}_change_digest_changed=1')

mixed=dict(BASE); mixed['beat_states']=list(BASE['beat_states']); mixed['beat_states'][0]='NOT_COMMITTED'
assert not verify(mixed,c)
print('committed_prefix_replay_mixed_state_rejected=1')

foreign=dict(BASE); foreign['receipt_effect_id']=14
assert not verify(foreign,c)
print('foreign_receipt_identity_mixed_state_rejected=1')

retry=dict(BASE); retry['beat_states']=list(BASE['beat_states']); retry['beat_states'][2]='UNKNOWN'; retry['issue_receipt_bitmap']=4
assert not verify(retry,c)
print('stale_negative_receipt_survives_retry_mixed_state_rejected=1')

checkpoint_mix=dict(BASE); checkpoint_mix['checkpoint_beat_states']=list(BASE['checkpoint_beat_states']); checkpoint_mix['checkpoint_beat_states'][2]='COMMITTED'
assert not verify(checkpoint_mix,c)
print('partial_checkpoint_state_substitution_rejected=1')

print('canonical_digest='+c)
print('VCML_MULTIBEAT_DMA_CHECKPOINT_V29_PASS')

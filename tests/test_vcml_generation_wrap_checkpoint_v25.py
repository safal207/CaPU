from pathlib import Path
import sys
sys.path.insert(0,str(Path(__file__).resolve().parents[1]))
from tools.vcml_generation_wrap_checkpoint_v25 import digest,verify
BASE={
 'base_v24_digest':'4c7656a9e36e9d921c8f72e2d43c5e3e00f919fef381f681ba45b4cb1d276ea2',
 'retired_valid':1,'retired_incarnation':2,'retired_generation':0,
 'pending':1,'pending_incarnation':2,'pending_generation':1,'pending_asid':2,'pending_epoch':9,'pending_vpn':6,
 'required_harts':1,'delivered_bitmap':0,'ack_bitmap':0,'quarantined_delivery_bitmap':1,'quarantined_ack_bitmap':1,
}
c=digest(BASE)
for field in ['retired_incarnation','retired_generation','pending_incarnation','pending_generation','delivered_bitmap','ack_bitmap','quarantined_delivery_bitmap','quarantined_ack_bitmap','pending']:
    m=dict(BASE); m[field]=(m[field]+1) if isinstance(m[field],int) else 'x'
    assert digest(m)!=c,field
    print(f'{field}_change_digest_changed=1')
mixed=dict(BASE); mixed['pending_generation']=0; mixed['pending_incarnation']=1
assert not verify(mixed,c)
print('mixed_aba_authority_rejected=1')
print('canonical_digest='+c)
print('VCML_GENERATION_WRAP_CHECKPOINT_V25_PASS')

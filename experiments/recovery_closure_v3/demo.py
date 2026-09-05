"""Live, bounded demonstration. These are synthetic effects, never real payments."""
import argparse
import json
from test_http import scenario

p = argparse.ArgumentParser()
p.add_argument('--case', choices=('delayed', 'lost'), default='delayed')
a = p.parse_args()
gate = 'after_check' if a.case == 'delayed' else 'drop_before_effect'
print('LIVE LOOPBACK LAB — SQLite rows are the effects; no real money or devices.', flush=True)
print('Policy                         Effects at recovery   Final effects', flush=True)
for policy in ('hold', 'snapshot_negative', 'admission_fence', 'atomic_fence', 'operation_idempotency'):
    r = scenario(policy, gate, None if policy == 'operation_idempotency' else 'native')
    print(f"{policy:30} {r['effects_at_recovery']:19} {r['final_effects']:15}", flush=True)
print('No CPU advantage or superiority over a correct conventional implementation is claimed.', flush=True)

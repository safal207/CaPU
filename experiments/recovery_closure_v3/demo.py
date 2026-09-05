"""Live bounded demonstration: synthetic effects, not payments or devices."""
import argparse
from dependency_preflight import verify_runtime


def main() -> None:
    """Require the actual candidate dependency before loading any HTTP scenarios."""
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--case', choices=('delayed', 'lost'), default='delayed')
    args = parser.parse_args()
    verify_runtime()
    from test_http import scenario
    gate = 'after_check' if args.case == 'delayed' else 'drop_before_effect'
    print('LIVE LOOPBACK LAB — SQLite rows are the effects; no real money or devices.', flush=True)
    print('Policy                         Effects at recovery   Final effects', flush=True)
    for policy in ('hold', 'snapshot_negative', 'admission_fence', 'atomic_fence', 'operation_idempotency'):
        result = scenario(policy, gate, None if policy == 'operation_idempotency' else 'native')
        print(f"{policy:30} {result['effects_at_recovery']:19} {result['final_effects']:15}", flush=True)
    print('No CPU advantage or superiority over a correct conventional implementation is claimed.', flush=True)


if __name__ == '__main__':
    main()

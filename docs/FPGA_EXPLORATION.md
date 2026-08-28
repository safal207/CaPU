# Minimal CaPU FPGA exploration

This note defines the smallest explanatory co-processor state machine for the Phase 4 roadmap. The repository now contains stronger RTL experiments, but this interface remains the portable minimum for a first implementation.

## States

| State | Meaning | Allowed successors |
|---|---|---|
| `RECEIVED` | exact action identity captured | `VALIDATING`, `REJECTED` |
| `VALIDATING` | cause, policy and identity checked | `HELD`, `COMMITTED`, `REJECTED` |
| `HELD` | permitted but not mature | `VALIDATING`, `COMMITTED`, `EXPIRED`, `FAILED` |
| `COMMITTED` | exact action durably authorized | `EXECUTED`, `FAILED` |
| `EXECUTED` | one effect permit emitted | terminal |
| `REJECTED` | validation or policy failed | terminal |
| `EXPIRED` | maturity deadline elapsed | terminal |
| `FAILED` | commit or internal failure | terminal |

## Candidate ports

```text
CauseIn.valid, CauseIn.action_id, CauseIn.parent_digest
PolicyIn.permit, PolicyIn.mature, PolicyIn.expired
CommitIn.ready, CommitIn.ok
CommitOut.valid, CommitOut.action_id
EffectOut.execute, EffectOut.action_id
TraceOut.valid, TraceOut.state, TraceOut.decision_code
```

All authority-bearing identities must have fixed widths in a concrete profile. Backpressure and reset semantics must be explicit.

## Forbidden-path assertions

```text
EffectOut.execute
=> prior CommitOut.ok for the same action_id

state inside {REJECTED, EXPIRED, FAILED}
=> !EffectOut.execute

CommitIn.ok && CommitIn.action_id != active_action_id
=> !EffectOut.execute && no authority-state mutation

reset_or_recovery_active
=> !EffectOut.execute

one accepted action_id
=> at most one EffectOut.execute pulse unless an exact successor attempt is authorized
```

## Simulation scenarios

1. valid + mature + commit success produces exactly one execute pulse;
2. commit failure produces none;
3. hold followed by maturity and commit produces none before commit and one after;
4. expiry while held produces none;
5. stale/foreign commit acknowledgement produces none and does not mutate active authority;
6. reset racing a would-be execute masks the visible effect.

The machine-readable lifecycle fixture in [`examples/conformance/lifecycle-matrix.json`](../examples/conformance/lifecycle-matrix.json) supplies the software-level expected paths.

## Non-claims

This is an exploration interface, not a chip design or production safety certification. It does not define CDC, reset distribution, persistent storage, bus protocol, timing closure, area/power, cryptographic verification, arbitrary concurrency, or liveness. The more advanced repository RTL remains bounded evidence for its stated models, not a finished FPGA product.

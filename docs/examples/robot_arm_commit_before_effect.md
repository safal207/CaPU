# Mock robot-arm commit-before-effect scenario

This example defines a testable control-flow narrative for moving a mock robot arm from a safe pose to a pickup pose. It does not claim production robotics safety.

## Inputs

```text
action_id: move-042
requested_pose: pickup-A
operator_permission: granted
workspace_clear: sensor evidence
speed_limit: 0.15 m/s
authority_digest: binds all fields above
```

## Allowed path

```text
GATE
  validate action identity, operator permission, pose and speed policy
  -> PERMIT

INCUBATE
  workspace_clear is not yet known
  -> HOLD (motor permit remains 0)
  receive exact sensor evidence for move-042
  -> MATURE

COMMIT
  durably record authority_digest for move-042
  -> COMMIT_OK (motor permit remains 0 during commit)

EXECUTE
  emit one motor permit bound to move-042 and pickup-A
  -> actuator effect may begin
```

## Blocked paths

| Condition | Decision | Required actuator result |
|---|---|---|
| workspace sensor reports occupied | `REJECT_WORKSPACE_OCCUPIED` | no motor permit |
| sensor evidence is missing until TTL | `EXPIRED_NO_EXECUTE` | no motor permit |
| authority identity differs from sensor evidence | `REJECT_FOREIGN_EVIDENCE` | no motor permit |
| durable commit fails | `REJECT_COMMIT_FAILED` | no motor permit |
| controller restarts after dispatch with no completion evidence | `UNKNOWN` | no success claim and no blind replay |

## Test oracle

```text
MOTOR_PERMIT(move-042)
=> GATE_PERMIT(move-042)
&& MATURE(move-042)
&& COMMIT_OK(move-042)
```

The test must fail if a motor permit appears before `COMMIT_OK`, after a reject/expiry/commit failure, or under a different action identity.

## Boundary

The scenario models authorization ordering only. It does not model mechanical dynamics, emergency stops, redundant sensors, safe torque off, control-loop stability, functional-safety certification, or human-safe deployment.

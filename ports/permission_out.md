# PermissionOut Port

The **PermissionOut** port emits a decision after gating/incubation.

Decision and reason enums are canonical in [DECISION_CODES.md](../DECISION_CODES.md).
See [DEPENDENCIES.md](../DEPENDENCIES.md) for boundary ownership (no new formats).

## Output Contract

```
decision:
  decision: ACCEPT | HOLD | REJECT | EXPIRE
  reason_code: <from DECISION_CODES.md>
  explain: string (optional, one line)
  next_check_at: string (RFC3339, optional; used for HOLD)
  policy_snapshot: string (optional hash/id)
```

## Notes

- `explain` is short and human-readable (no essays).
- `next_check_at` indicates when the cause should be re-evaluated.
- This port only describes the output shape, not policy logic.

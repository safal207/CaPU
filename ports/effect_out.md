# EffectOut Port

The **EffectOut** port emits an `effect_plan` after a cause is **COMMITTED**.
The plan is a minimal, neutral structure derived from the committed cause.

See [DEPENDENCIES.md](../DEPENDENCIES.md) for canonical boundaries and
[DECISION_CODES.md](../DECISION_CODES.md) for decision enums.

## Output Contract

```
effect_plan:
  effect_type: string
  target: string
  parameters: object
  idempotency_key: string (cause_id recommended)
  safety:
    dry_run_allowed: boolean (optional)
    max_retries: number (optional)
```

## Notes

- `effect_plan` is derived from a committed cause; it is not a new cause schema.
- Executors may adapt the plan into their own execution format.
- Idempotency should be preserved by using `cause_id` or a stable key.

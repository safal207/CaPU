# CaPU Validation Results

Tracked local validation snapshot for the current CaPU reference runtime and schema surface.

## Summary

- Total checks: **3**
- Passed: **3**
- Failed: **0**

## Checks

| command | status |
|---|---|
| `npm run validate:examples` | PASS |
| `npm run test:reference` | PASS |
| `npm run verify:golden` | PASS |

## Outputs

### `npm run validate:examples`

- Status: **PASS**
- Stdout:
```text
> validate:examples
> node scripts/validate-examples.mjs

OK examples/ports-causein.json
OK examples/ports-decision.json
OK examples/ports-effectplan.json
OK examples/ports-traceevent.json
OK examples/golden_flow.jsonl

All example files are valid
```

### `npm run test:reference`

- Status: **PASS**
- Stdout:
```text
> test:reference
> node scripts/test-reference-runtime.mjs

reference runtime checks passed
```

### `npm run verify:golden`

- Status: **PASS**
- Stdout:
```text
> verify:golden
> node scripts/verify-golden.mjs

golden fixture verification passed
```


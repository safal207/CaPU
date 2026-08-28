# CaPU lifecycle conformance matrix

Every CaPU implementation should reproduce the same result for these minimum lifecycle paths. The machine-readable fixture is [`examples/conformance/lifecycle-matrix.json`](../examples/conformance/lifecycle-matrix.json), and `npm run validate:conformance` enforces both its schema and the commit-before-effect ordering rules.

| ID | Required path | Expected decision | Execute? | Fixture/test |
|---|---|---|---:|---|
| `valid-mature-commit-ok` | valid → permit → mature → commit_ok → execute_ok | `EXECUTE_OK` | 1 | present |
| `valid-mature-commit-fail` | valid → permit → mature → commit_fail → no_execute | `REJECT_COMMIT_FAILED` | 0 | present |
| `valid-hold-mature-commit-ok` | valid → permit → hold → mature → commit_ok → execute_ok | `EXECUTE_OK` | 1 | present |
| `valid-hold-expire` | valid → permit → hold → expire → no_execute | `EXPIRED_NO_EXECUTE` | 0 | present |
| `invalid-reject` | invalid → reject → no_execute | `REJECT_INVALID` | 0 | present |
| `policy-denied-reject` | policy_denied → reject → no_execute | `REJECT_POLICY_DENIED` | 0 | present |
| `missing-parent-hold` | missing_parent → hold → no_execute until parent available | `EXECUTE_OK` after parent | 1 | present |

The validator rejects a fixture when:

- `EXECUTE` appears without an earlier `COMMIT_OK` for the scenario;
- `EXECUTE` appears after `COMMIT_FAIL`, `EXPIRE`, or rejection;
- a held scenario executes before `MATURE`;
- a missing-parent scenario executes before `PARENT_AVAILABLE`;
- the expected execution count or final decision code differs from the trace;
- any required scenario is absent or duplicated.

This matrix verifies deterministic fixture semantics. It is not a production safety certification and does not replace transport, persistence, concurrency, liveness, or hardware verification.

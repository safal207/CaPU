# Recovery closure: where a safe retry becomes possible

**Experimental reference — not production infrastructure.** This directory investigates a missing *integration contract*, not a newly discovered defect in CaPU HTTP v2. The original v2 correctly refuses to reinterpret a missing record as a negative outcome.

## Main finding

A receipt saying "not executed yet" is insufficient for a safe new attempt while an old request can still execute. Even a persistent cancellation tombstone fails if the receiver checks it only on admission and then pauses before the effect. In the candidate receiver, the closure check and effect insertion share a single SQLite transaction. This provides a bounded recovery demonstration without inventing a new authorization.

This is a new reproducible experiment for this project, **not a claim to have invented fencing, idempotency, or exactly-once processing**. A normal FSM with the same receiver contract is deliberately retained as an equal-guarantee control. A conventional operation-key idempotency implementation is another strong control.

## Run

```sh
cd experiments/recovery_closure_v3
python -m pip install -r requirements.txt
python source_pins.py
python run.py --output evidence-rerun
python validate_results.py evidence-rerun
python demo.py --case delayed
python demo.py --case lost
```

The downloadable source package also includes the pinned dependencies for offline reproduction after installing cryptography. A fresh Git checkout obtains exact source blobs through `source_pins.py`, verifies their Git blob IDs, and then runs the original bootstrap to verify CaPU A6/A7 and ATMAN authority pins. No unpinned branch is imported.

## What is compared

| Arm | Missing result | Where an old attempt is blocked | Purpose |
|---|---|---|---|
| `hold` | Remains UNKNOWN | Controller refuses retry | Existing conservative contract |
| `snapshot_negative` | Mislabelled NOT_COMMITTED | Nowhere | Deliberately unsafe mutation |
| `admission_fence` | Returns NOT_COMMITTED | Before the processing pause | Deliberately weak mutation |
| `atomic_fence` | Returns NOT_COMMITTED only after durable closure | Same receiver transaction as effect | Candidate receiver contract |
| `operation_idempotency` | No negative-outcome inference required | One result per stable operation key | Conventional service-side control |

The first four arms use both unmodified native CaPU and the existing ordinary FSM. They share the original ATMAN authority verifier, fixture receipt authentication, transport and persistence. Only lifecycle transition logic differs. The fifth arm retries directly against receiver-side operation deduplication and does **not** claim to use CaPU authority or attempt-bound negative receipts.

The candidate has a uniqueness constraint only per **attempt**, not per logical operation. Thus the duplicate across attempts 0 and 1 is genuinely observable in the weak controls. The conventional idempotency control intentionally deduplicates the entire logical operation.

## Measurement boundary

One logical operation, two attempts, one closure query, receipt application and optional replay. The finite model enumerates 56 causal orderings for each initial-delivery condition and each of five policies: 560 traces total. These counts are **not probabilities of production incidents** and do not establish unbounded correctness.

Live tests use a receiver subprocess, loopback HTTP and a separate read-only observer process. Controller method calls run in the test process, with persisted controller state; the receiver restart case kills and restarts the actual receiver process. Earlier v1/v2 crash tests are rerun separately and are not re-labelled as new tests.

SQLite row insertion **is** the effect. Closure and that effect are in the same database. This does not make a SQLite record atomic with a payment provider, robot, email delivery or other remote side effect.

## Evidence and review

`evidence/observed-summary.json` is the observed summary, while `evidence/archive-parts/` retains all new trace files and the test log without losing bytes. Run `python restore_evidence.py` and `python validate_results.py evidence-restored` to verify the original observations. The downloadable ZIP additionally preserves the complete v1/v2 regression outputs. `EVIDENCE_MANIFEST.json` records uncompressed and compressed hashes. `PROTOCOL.md` records the hypotheses written before the new trials. `VALIDATION.md` records recomputation and limitations. Test PASS is not independent code review. Keep this work in a draft PR without merging until the agreed review gate is satisfied.

## Why this is useful

The kit distinguishes three outcomes that must not be conflated: unsafe retry, safe but blocked recovery, and safe recoverable execution under an explicit receiver contract. An integration can be tested against that contract rather than branded "safe" just because its logs or receipts are signed.

The commercial hypothesis is a repeatable recovery-conformance test and integration service for agent tool execution. Customer demand, integration effort, willingness to pay and superiority over existing solutions are **unmeasured**.

## Boundaries that remain open

A7 receipt tags and authority keys are public deterministic lab fixtures, not production credentials. There is no Byzantine-device defense, bypass-resistant deployment, storage rollback protection, physical power-loss proof, multi-region failover or finite-time progress during receiver unavailability. Authorization remains linearized at controller admission. Reconciliation does not renew an expired grant. No Bardo/COSMIC code is exercised; no full ATMAN runtime, hardware, speed or energy claim is made.

## Prior art and source context

AWS, "Making retries safe with idempotent APIs": https://aws.amazon.com/builders-library/making-retries-safe-with-idempotent-APIs/

Martin Kleppmann, "How to do distributed locking" (2016): https://martin.kleppmann.com/2016/02/08/how-to-do-distributed-locking.html

gRPC, "Cancellation": https://grpc.io/docs/guides/cancellation/

These sources already establish relevant retry, receiver-enforcement and cancellation limitations. This experiment makes those boundaries executable in the pinned CaPU/ATMAN composition; it does not establish scientific priority.

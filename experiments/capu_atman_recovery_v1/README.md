# CaPU × ATMAN: process-crash recovery laboratory

**Status:** bounded software composition experiment; not a production runtime.

This experiment executes the **unmodified** CaPU A6/A7 Python models and
ATMAN's **unmodified** Ed25519 authority module, pinned to exact commits and
verified by Git blob ID before import. It supplies the missing integration
boundary: current authorization + durable dispatch reservation + a separately
stored mock effect + late outcome reconciliation after process termination.

## Reproduce

Python 3.11+ and `cryptography==46.0.4` are required. Tested here on Python
3.13.5. The archive includes exact upstream module snapshots; repository
checkouts download the same three pinned files with the bootstrap command.

```sh
python -m pip install cryptography==46.0.4
python bootstrap.py
python run.py --output evidence
```

No account, API key, paid service, FPGA, real actuator or private credential is
used. The keys and receipt secret in `proof.py` are **public test fixtures**.
Do not reuse them for any real system.

The first bootstrap may access three fixed raw.githubusercontent.com URLs.
Every subsequent import validates the downloaded source before execution.
No automatic fallback to a newer revision is allowed.

## Exact upstream boundary

| Component | Commit | File |
|---|---|---|
| CaPU A6 | `5cdaa5280348841bf8448c5a7844c273df257c5d` | `tools/astra_capu_outcome_reconciliation_a6.py` |
| CaPU A7 | same | `tools/astra_capu_authenticated_receipt_a7.py` |
| ATMAN authority | `e62c279b9148a7ae9dd1a4654f6ddeea6add4a3f` | `model/authority.py` |

A7's existing deterministic scenario must retain result digest
`6781dbfbd1b529866709980a3a85a38bd37f505daaddd53fd7c8e106ab863d2f`.
The A7 source is from draft PR #102, not an assertion that A7 is merged into
CaPU main. Only ATMAN authority is imported; its complete governance runtime
is not integrated. Bardo and COSMIC are deliberately outside this experiment.

## The tested story

```text
ATMAN signed action + exact state version + current policy generation
  -> CaPU A6 reserves the attempt as UNKNOWN
  -> controller commits authorization and reservation in control.sqlite
  -> non-idempotent counter appends the effect to separate device.sqlite
  -> child process exits without cleanup before acknowledgement
  -> fresh process loads UNKNOWN and blocks same/successor attempts
  -> forged negative receipt is rejected without consuming receipt sequence
  -> policy changes; the historical effect still needs reconciliation
  -> exact late A7 COMMITTED receipt closes the original attempt
  -> even a newly authorized retry is blocked by terminal outcome
```

`AUTHORIZATION_COMMITTED` and effect `COMMITTED` are distinct events. The
counter deliberately has no deduplication constraint: a duplicate invocation
would create a second effect, making the tested failure observable.

## Crash and concurrency coverage

The tests terminate child processes with `os._exit` at five named cut points:
before controller commit, after controller commit, after device effect commit,
during receipt reconciliation, and after receipt reconciliation commit.
This is process-failure injection, **not a physical power-loss experiment**.

A separate test runs two dispatch processes against one controller database.
The reservation, current-context verification and audit write share a
`BEGIN IMMEDIATE` transaction. Device effects are in a separate transaction
and separate database: there is no fictitious cross-system atomic commit.

Receipt-sequence consumption and outcome reconciliation are committed together.
A7's existing rule is preserved: an authenticated but semantically rejected
receipt consumes its sequence; an authentication rejection does not.

Negative cases cover stale policy, stale state, wrong role/scope, expired and
future-dated authorization, changed action, malformed authority, uncommitted
requests, foreign lineage/device/key epoch, wrong receipt sequence/attempt,
forged or malformed receipts, terminal conflict and missing storage.

## Fair conventional baseline

The second arm independently implements an ordinary finite-state machine. It
receives the same data and shares the same SQLite persistence, actual ATMAN
signature verifier and low-level synthetic tag calculation. It does **not**
call the native CaPU dispatch or reconciliation state-transition methods.

Both arms execute the same 26 named scenarios. Two additional tests check the
existing A6 scenario and exact A7 result digest. One differential test compares
24 seeded traces of 12 actions each: **288 transition comparisons**.

The total is **55 tests**, not 55 independent bugs or proofs. Equal results
show compatibility for these checks. They do not establish a correctness,
performance or novelty advantage over a well-built conventional system.

## Trust and non-claims

The controller, fixture key provisioning, local storage and mock device are
trusted. The device receipt primitive remains A7's transparent rotate/XOR
synthetic tag; it is not production authentication. The adapter assumes the
mock command cannot be duplicated or injected outside its dispatch method.
There is no real transport, external isolation or unbypassable hardware gate.

Authorization is evaluated at **durable admission**, not at the exact physical
instant of the external effect. Revocation after admission does not retroactively
cancel an already admitted operation. Historical receipts are reconciled without
reusing old execution permission; new attempts still require current permission.

If the process exits after reservation but before invoking the device, the
controller also sees UNKNOWN. It must not infer NOT_COMMITTED from missing
rows or a timeout. Only a definitive trusted receipt can release a successor.
Consequently indefinite HOLD is allowed: **no general liveness or exactly-once
guarantee is claimed**.

The source uses SQLite rollback journals and synchronous=FULL. Persistence
remains conditional on filesystem, OS and storage behavior; no torn-write,
adversarial rollback, corrupt disk or power-loss guarantee is established here.
See https://www.sqlite.org/atomiccommit.html for SQLite's assumptions.

The evidence JSON records source hashes, environment, decisions and counts. Its
digest detects changes relative to a known digest, not omitted events, false
inputs, an independent timestamp or an external trust anchor.

No CPU/FPGA speed, energy, full ATMAN runtime, Bardo/COSMIC composition,
multi-organization governance, or real payment effect is demonstrated.

## Files and next acceptance boundary

`bootstrap.py` verifies upstream inputs; `proof.py` implements the adapter and
baseline; `test_proof.py` holds the cases; `run.py` produces the manifest and
human-readable log. `evidence/result.json` is the machine-readable local run.

Before production or broader integration, replace the mock effect/receipt seam
with one real, independently observable device/API operation and test its
transport, idempotency, receipt finality and admission/revocation contract.
The current experiment must not be renamed a complete platform implementation.

# CaPU × ATMAN — bounded loopback HTTP recovery v2

This experiment extends the **process boundary**, not the production claim.
The v1 source and PR #103 head (`977864167c65f161e6db87b3d14257a11a67516f`)
remain unchanged. This candidate belongs on a separate branch and **draft PR**.
No merge, deployment, main publication, or ready-for-review transition.

## What is actually external?

1. A controller subprocess owns only its controller SQLite path and a loopback URL.
2. A separate HTTP device process executes a non-idempotent counter append in its
   own SQLite ledger. The durable insertion **is** the effect in this lab.
3. A third, stdlib-only observer process opens that device ledger read-only. It
   counts actual requests/effects and hashes the observed rows, without importing
   controller code or reading controller state.

This is a real TCP/HTTP and process boundary on **one trusted host**, not a real
payment, physical actuator, third-party deployment, WAN or independent attestor.
Process separation does not create OS permission separation. The device deliberately
accepts direct lab calls; bypass-resistant endpoint enforcement is out of scope.

## Central scenario

```
ATMAN authority -> durable A6 UNKNOWN reservation -> one HTTP POST
 -> device effect committed -> response held/lost
 -> independent observer sees effect -> controller process killed
 -> new controller process refuses retry while UNKNOWN
 -> policy changes -> exact historical positive receipt arrives
 -> A7 reconciliation commits outcome -> new attempts remain blocked
```

The device database path is never passed to a controller worker. The observer
triggers the kill only after it has read the effect, while the controller is
still awaiting the held response. The controller and device have no shared
transaction. A receipt query with no matching row returns UNKNOWN, never a
manufactured NOT_COMMITTED. HTTP 503, malformed JSON and socket timeout do not
release the reservation. The HTTP client makes one request with no automatic
retry, redirect or proxy behavior.

## Tests and equal-guarantee comparison

There are 14 named scenarios for each of two arms (28 tests): normal ACK,
connection loss after/before the effect, HTTP 503 after the effect, malformed ACK,
observer-triggered controller kill, timeout, device-process restart, receipt
tampering, full-token receipt lookup, competing dispatch workers, stale authority,
receipt replay, and unguarded direct-call duplication.

The ordinary FSM arm shares HTTP/SQLite I/O, ATMAN authority verification and the
synthetic receipt primitive, but not native CaPU lifecycle transitions. The runner
compares the recorded controller states and **independently observed device rows**
for every named scenario, not merely test pass counts.

The unguarded control intentionally sends two identical HTTP effect requests:
they must produce two effects. An ambiguous duplicate ledger yields CONFLICT,
not a fabricated clean COMMITTED receipt. This control also demonstrates the
explicit lack of bypass resistance; it is not an architectural superiority claim.

## Reproduce

From repository root (Python 3.11 or 3.13):

```sh
python -m pip install -r experiments/capu_atman_recovery_v1/requirements.txt
python experiments/capu_atman_recovery_v1/bootstrap.py
python experiments/capu_atman_recovery_v1/run.py --output evidence-v1
python experiments/capu_atman_http_recovery_v2/run.py --output evidence-v2
```

The isolated workflow bootstraps the three pinned upstream modules, runs both
suites, and uploads results. `result.json` includes source hashes, environment,
all observations and a digest. Check the exit code and actual CI run: a local
PASS is not CI PASS or review approval. Source verification pins the reused v1
bootstrap and adapter; upstream modules are verified by the unchanged bootstrap.

## Non-claims / review boundary

- Public deterministic fixture keys and A7 synthetic rotate/XOR receipt tags are
  unchanged. No production authentication or cryptographic security claim.
- One trusted controller/device/lineage, one unresolved attempt. No general
  exactly-once or liveness guarantee; UNKNOWN may remain blocked indefinitely.
- No physical power-loss/NVRAM, storage rollback, Byzantine device, malicious
  host, distributed atomic commit or production transport proof.
- Authorization linearizes at durable admission, not at physical actuation.
  A late positive receipt records history; it does not renew old authority.
- The observer is a separate observation path, not an independent organization,
  timestamp, trust anchor, or proof that all external events were recorded.
- No CPU/FPGA speed, energy, full ATMAN, Bardo/COSMIC integration, or advantage
  over the equal-guarantee ordinary FSM is established.
- Only native Codex review is the review gate. One request per final candidate
  head; do not mutate that head after review. Keep draft and unmerged if quota
  prevents review. Tests or manual inspection are not review approval.

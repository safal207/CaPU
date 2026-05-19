# CMC Canonical Trace Encoding

Status: v0 canonical encoding note / executable research scaffold.

This document defines the current canonical trace-event encoding used by CMC trace JSONL output and SHA-256 trace sealing.

It is intentionally narrow.

The goal is to make the current integrity claim reviewer-checkable:

```text
A reviewer should know exactly which bytes are hashed for each trace event.
```

This document does not claim a production cryptographic protocol or certified trace-storage format.

---

## Why this exists

Hash-chain integrity only matters if the input bytes are stable.

CMC currently seals trace events with this rule:

```text
trace_hash_n = SHA256(previous_trace_hash || canonical_event_line_n)
```

Therefore, the project needs to define:

- which fields are included,
- in what order,
- how `null` is represented,
- how strings are escaped,
- whether trailing newlines are hashed,
- what changes count as drift or tampering.

---

## Current implementation surface

The v0 canonical trace event is produced by:

```text
rust/cmc-core/src/lib.rs
TraceEvent::to_json_line()
CausalMemoryController::trace_jsonl()
```

The SHA-256 sealing path is implemented by:

```text
rust/cmc-core/src/trace_crypto.rs
trace_hash(prev_hash, event)
seal_trace(jsonl)
verify_trace(sealed)
```

The saved SHA-256 fixtures are:

```text
rust/cmc-core/fixtures/trace_integrity/sha256_valid.jsonl
rust/cmc-core/fixtures/trace_integrity/sha256_tampered.jsonl
```

The fixture verifier is:

```text
rust/cmc-core/src/bin/verify_trace_sha256_fixture.rs
```

---

## Canonical event fields

Current v0 trace events include exactly these fields:

```text
seq
kind
decision
address
effect_id
cause_id
message
```

The canonical field order is fixed:

```json
{"seq":<seq>,"kind":"<kind>","decision":"<decision>","address":<address-or-null>,"effect_id":<effect-id-or-null>,"cause_id":<cause-id-or-null>,"message":"<message>"}
```

There are no spaces between fields in the current canonical line.

There is no trailing newline inside the event line itself.

---

## Field rules

| Field | Type | Encoding rule |
| --- | --- | --- |
| `seq` | unsigned integer | decimal number, no quotes |
| `kind` | enum string | quoted uppercase string |
| `decision` | enum string | quoted uppercase string |
| `address` | optional unsigned integer | decimal number or `null` |
| `effect_id` | optional unsigned integer | decimal number or `null` |
| `cause_id` | optional unsigned integer | decimal number or `null` |
| `message` | static string | quoted string with current escaping rules |

Current `kind` values:

```text
WRITE
READ
EFFECT
```

Current `decision` values:

```text
ACCEPT_WRITE
ACCEPT_READ
ACCEPT_EFFECT
REJECT_MISSING_CAUSE
REJECT_UNKNOWN_CAUSE
REJECT_EFFECT_BEFORE_COMMIT
```

---

## String escaping rules

The current v0 implementation escapes `message` by replacing:

```text
\  -> \\
"  -> \"
```

The current messages are static ASCII strings used by the simulator.

Important v0 limitation:

```text
Only backslash and quote escaping are explicitly handled today.
```

If future messages include newline, tab, carriage return, or non-ASCII normalization-sensitive content, the canonical encoding rules should be expanded and tested before making stronger compatibility claims.

---

## JSONL rules

`trace_jsonl()` serializes trace events as:

```text
event_line_1\nevent_line_2\n...
```

If the trace is non-empty, the JSONL string ends with a final newline.

`seal_trace(jsonl)` processes lines using:

```text
jsonl.lines().filter(|line| !line.trim().is_empty())
```

That means:

- each non-empty line becomes one sealed event,
- the trailing file newline is not part of an individual event hash,
- empty lines are ignored by the current sealing implementation.

For current reviewer evidence, saved sealed fixtures store the event line as the `event` string field, not as raw multi-line JSONL.

---

## Hash input bytes

For each sealed event:

```text
input_bytes = UTF8(previous_trace_hash || canonical_event_line)
trace_hash = SHA256(input_bytes)
```

The genesis hash is:

```text
0000000000000000000000000000000000000000000000000000000000000000
```

The first event uses the genesis hash as `previous_trace_hash`.

Each later event uses the previous event's `trace_hash`.

---

## Example canonical event line

Example line from the saved SHA-256 valid fixture:

```json
{"seq":1,"kind":"WRITE","decision":"REJECT_MISSING_CAUSE","address":53261,"effect_id":null,"cause_id":null,"message":"memory write requires an explicit cause"}
```

Its saved sealed record stores:

```json
{"prev_hash":"0000000000000000000000000000000000000000000000000000000000000000","event":"{\"seq\":1,\"kind\":\"WRITE\",\"decision\":\"REJECT_MISSING_CAUSE\",\"address\":53261,\"effect_id\":null,\"cause_id\":null,\"message\":\"memory write requires an explicit cause\"}","trace_hash":"b5cfe56e4b061c5846d6aa45efb9ea6ce47f1a8e0960f86805f6cbc940933271"}
```

---

## What counts as drift

For v0, drift means the canonical event line changes while the scenario is expected to remain stable.

Examples:

- field order changes,
- enum string changes,
- `null` becomes omitted,
- number formatting changes,
- message text changes,
- escaping behavior changes,
- event count changes,
- trace event order changes.

Replay fixture fingerprints detect developer fixture drift.

SHA-256 sealed fixtures detect trace-integrity changes and tampering in saved sealed traces.

These are related but not identical:

```text
replay fixture fingerprint != SHA-256 trace-integrity hash
```

---

## What counts as tampering

For v0 sealed trace evidence, tampering means a saved sealed event is modified without recomputing a valid chain.

Examples:

- changing `decision`,
- changing `cause_id`,
- changing `address`,
- changing `message`,
- changing `prev_hash`,
- removing an event,
- reordering events,
- appending an unauthorized event without a valid chain.

Current saved tamper fixture covers one explicit case:

```text
first event decision changed from REJECT_MISSING_CAUSE to ACCEPT_WRITE while preserving the old trace_hash
```

`verify_trace_sha256_fixture` must reject this at event 1.

---

## Current executable checks

From `rust/cmc-core`:

```bash
cargo run --bin verify_trace_sha256 --locked
cargo run --bin verify_trace_sha256_tampered --locked
cargo run --bin verify_trace_sha256_fixture --locked
```

From repository root:

```bash
npm run review:cmc
```

CI also runs the SHA-256 generated trace checks and saved sealed fixture verifier.

---

## Current honest claim

The current repository can claim:

```text
CMC v0 trace events have a stable documented canonical line format, can be sealed using a std-only SHA-256 reference path, can be saved as sealed fixtures, and can be verified against tampering through executable checks.
```

---

## Non-claims

The current encoding does not yet claim:

- full RFC 8785 JSON Canonicalization Scheme compatibility,
- production cryptographic protocol design,
- certified trace storage,
- hardware root of trust,
- adversarial runtime isolation,
- full Unicode normalization policy,
- complete escape handling for all possible future message strings,
- backward-compatible stable format guarantee across all future versions.

---

## Versioning rule

This document defines:

```text
CMC canonical trace encoding v0
```

Any future change to field order, field set, enum string, null handling, escaping, or hash input construction should be treated as a canonical encoding version change.

Future versions should preserve old fixtures or provide a migration note.

---

## Next work

Useful next steps:

1. add tests that assert exact canonical event lines,
2. add tests for string escaping behavior,
3. add removed-event and reordered-event SHA-256 negative fixtures,
4. add a `trace_integrity/MANIFEST.tsv` linking sealed fixtures to scenario meaning,
5. optionally implement a dedicated canonical encoder helper instead of formatting inline,
6. optionally align with a formal JSON canonicalization scheme if dependency policy changes.

---

## One-line summary

```text
Canonical trace encoding v0 defines the exact event-line bytes that CMC hashes for SHA-256 trace integrity.
```

# CaPU Runtime HTTP API

Status: minimal local HTTP sidecar contract for the CaPU runtime/API path.

This document describes the current reference HTTP surface exposed by:

```bash
cd rust/cmc-core
cargo run --bin capu_runtime_http_sidecar --locked
```

Self-test mode:

```bash
cd rust/cmc-core
cargo run --bin capu_runtime_http_sidecar --locked -- --self-test
```

Expected marker:

```text
result=capu_runtime_http_sidecar_verified
```

Current maturity movement represented by this contract:

```text
Software reference processor: ~62% -> ~63%
Runtime sidecar/API:        ~30% -> ~38%
Hardware/device path:       ~5%  -> ~5%
```

---

## Scope

The HTTP sidecar is a minimal std-only reference service. It is intended to prove that CaPU decisions, audit records, and replay summaries can cross a local runtime boundary.

It is not yet:

- production-ready
- OpenAPI-backed
- authenticated
- async/nonblocking
- a stable public API
- a complete policy engine

The current goal is executable evidence, not production infrastructure.

---

## Routes

```text
GET  /capu/health
POST /capu/decide
POST /capu/audit
POST /capu/replay
```

All responses are JSON objects.

---

## GET /capu/health

Purpose:

```text
Check that the local CaPU sidecar is running.
```

Response fields:

```text
route
status
service
```

Example response:

```json
{"route":"/capu/health","status":"ok","service":"capu-runtime-http-sidecar"}
```

Saved fixture:

```text
rust/cmc-core/fixtures/capu_runtime_http/responses/health.json
```

---

## POST /capu/decide

Purpose:

```text
Decode a transition request and return a CaPU unit decision.
```

Currently supported transition classes:

```text
persona_memory
external_action
```

Persona-memory request example:

```json
{"transition_type":"persona_memory","transition_id":"http-p1-reject","memory":"raw inferred preference","cause_id":null}
```

External-action request example:

```json
{"transition_type":"external_action","transition_id":"http-p6-accept","action_kind":"send_email","cause_id":101,"commit":true}
```

Response fields:

```text
route
decision_class
code
invariant_id
boundary
verdict
```

Saved request fixture:

```text
rust/cmc-core/fixtures/capu_runtime_http/requests/decide_p1_missing_cause.json
```

Saved response fixture:

```text
rust/cmc-core/fixtures/capu_runtime_http/responses/decide_p1_missing_cause.json
```

Current P1 blocked decision example:

```json
{"route":"/capu/decide","decision_class":"reject","code":"REJECT_PERSONA_MEMORY_WITHOUT_CAUSE","invariant_id":"P1","boundary":"persona_memory_requires_cause","verdict":"blocked_persona_memory_without_cause"}
```

---

## POST /capu/audit

Purpose:

```text
Decode a transition request, run the CaPU decision unit, and return an audit-shaped response.
```

Response fields:

```text
route
transition_id
invariant_id
boundary
verdict
accepted
```

Saved request fixture:

```text
rust/cmc-core/fixtures/capu_runtime_http/requests/audit_p6_committed.json
```

Saved response fixture:

```text
rust/cmc-core/fixtures/capu_runtime_http/responses/audit_p6_committed.json
```

Current P6 accepted audit example:

```json
{"route":"/capu/audit","transition_id":"http-p6-accept","invariant_id":"P6","boundary":"action_requires_commit","verdict":"accepted_committed_action","accepted":true}
```

---

## POST /capu/replay

Purpose:

```text
Return a replay summary for a canonical sealed audit chain.
```

Current replay modes:

```text
P1 canonical pair
P6 canonical pair
```

P1 request example:

```json
{"invariant_id":"P1","replay":"canonical_pair"}
```

P1 response fields:

```text
route
invariant_id
result
events
p1_boundary_events
rejected_without_cause
```

Saved request fixture:

```text
rust/cmc-core/fixtures/capu_runtime_http/requests/replay_p1_pair.json
```

Saved response fixture:

```text
rust/cmc-core/fixtures/capu_runtime_http/responses/replay_p1_pair.json
```

Current P1 replay example:

```json
{"route":"/capu/replay","invariant_id":"P1","result":"capu_runtime_http_replay_valid","events":2,"p1_boundary_events":2,"rejected_without_cause":1}
```

---

## Current verification path

The HTTP API contract is backed by executable checks:

```text
capu_runtime_http_sidecar --self-test
 -> starts local server on an ephemeral port
 -> sends real HTTP requests
 -> checks saved request/response fixtures
 -> emits reviewer-visible marker
```

Reviewer marker:

```text
result=capu_runtime_http_sidecar_verified
```

---

## Limitations

Current known limitations:

- JSON parsing is deliberately minimal and std-only.
- The sidecar accepts only the current reference request shapes.
- The route surface is not authenticated.
- The API is not yet versioned.
- Response schemas are not yet generated from a formal schema source.
- Replay currently uses canonical pairs instead of arbitrary submitted traces.
- No OpenAPI file exists yet.

These limitations are intentional for the current milestone. The next maturity step should add schema files, richer examples, and a more stable client contract.

---

## Next runtime/API milestones

Recommended order:

1. Wire HTTP self-test into `npm run review:cmc`.
2. Add JSON schema files for request/response objects.
3. Add negative HTTP fixtures.
4. Add a documented version prefix or explicit API version field.
5. Add a tiny client example.
6. Add OpenAPI or OpenAPI-like generated documentation.

Target after this contract milestone:

```text
Software reference processor: ~63%
Runtime sidecar/API:        ~38%
Hardware/device path:       ~5%
```

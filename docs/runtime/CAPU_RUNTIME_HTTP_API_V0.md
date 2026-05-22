# CaPU Runtime HTTP API v0

Status: reference API contract for the minimal CaPU runtime sidecar.

This document describes the current local HTTP sidecar contract implemented by:

```text
rust/cmc-core/src/bin/capu_runtime_http_sidecar.rs
```

The implementation is intentionally std-only and reference-grade. It is not a production HTTP framework and not yet an OpenAPI-backed public API.

Current maturity represented by this contract:

```text
Software reference processor: ~62%
Runtime sidecar/API:        ~70%
Hardware/device path:       ~5%
```

---

## Machine-readable API manifest

The current route/case/fixture map is also recorded as a machine-readable manifest:

```text
schemas/runtime-http/api-manifest.v0.json
```

It is verified by:

```bash
npm run validate:runtime-http-manifest
```

The manifest checks that route cases point to existing request/response fixtures and that response fixtures agree with declared routes, invariants, boundaries, and error shapes.

---

## Minimal client example

A std-only Node client example demonstrates how an external consumer can launch the sidecar and call the v0 HTTP routes:

```text
examples/runtime_http_client.mjs
```

Run it from the repository root:

```bash
npm run example:runtime-http-client
```

Expected marker:

```text
result=runtime_http_client_example_verified
```

The client example verifies these routes over real local HTTP calls:

```text
GET  /capu/health
POST /capu/decide
POST /capu/audit
POST /capu/replay
GET  /capu/unknown
```

---

## Runtime command

From `rust/cmc-core`:

```bash
cargo run --bin capu_runtime_http_sidecar --locked -- --addr 127.0.0.1:8787
```

Self-test:

```bash
cargo run --bin capu_runtime_http_sidecar --locked -- --self-test
```

Expected self-test marker:

```text
result=capu_runtime_http_sidecar_verified
```

---

## Routes

```text
GET  /capu/health
POST /capu/decide
POST /capu/audit
POST /capu/replay
```

All current responses use JSON object bodies.

---

## GET /capu/health

Purpose:

```text
Verify that the local sidecar is alive.
```

Example response:

```json
{
  "route": "/capu/health",
  "status": "ok",
  "service": "capu-runtime-http-sidecar"
}
```

Fixture:

```text
fixtures/capu_runtime_http/responses/health.json
```

---

## POST /capu/decide

Purpose:

```text
Decode an external transition request and return the CaPU decision.
```

Current supported transition classes:

```text
persona_memory
external_action
```

### Persona memory request

Example request:

```json
{
  "transition_type": "persona_memory",
  "transition_id": "http-p1-reject",
  "memory": "raw inferred preference",
  "cause_id": null
}
```

Example response:

```json
{
  "route": "/capu/decide",
  "decision_class": "reject",
  "code": "REJECT_PERSONA_MEMORY_WITHOUT_CAUSE",
  "invariant_id": "P1",
  "boundary": "persona_memory_requires_cause",
  "verdict": "blocked_persona_memory_without_cause"
}
```

Fixtures:

```text
fixtures/capu_runtime_http/requests/decide_p1_missing_cause.json
fixtures/capu_runtime_http/responses/decide_p1_missing_cause.json
```

### External action request: rejected

Example request:

```json
{
  "transition_type": "external_action",
  "transition_id": "http-p6-reject",
  "action_kind": "send_email",
  "cause_id": null,
  "commit": false
}
```

Example response:

```json
{
  "route": "/capu/decide",
  "decision_class": "reject",
  "code": "REJECT_ACTION_WITHOUT_COMMIT",
  "invariant_id": "P6",
  "boundary": "action_requires_commit",
  "verdict": "blocked_action_without_commit"
}
```

Fixtures:

```text
fixtures/capu_runtime_http/requests/decide_p6_uncommitted.json
fixtures/capu_runtime_http/responses/decide_p6_uncommitted.json
```

### External action request: accepted

Example request:

```json
{
  "transition_type": "external_action",
  "transition_id": "http-p6-accept",
  "action_kind": "send_email",
  "cause_id": 101,
  "commit": true
}
```

Example response:

```json
{
  "route": "/capu/decide",
  "decision_class": "accept",
  "code": "ACCEPT_COMMITTED_ACTION",
  "invariant_id": "P6",
  "boundary": "action_requires_commit",
  "verdict": "accepted_committed_action"
}
```

Fixtures:

```text
fixtures/capu_runtime_http/requests/decide_p6_committed.json
fixtures/capu_runtime_http/responses/decide_p6_committed.json
```

Expected P6 decision semantics:

```text
commit=false -> REJECT_ACTION_WITHOUT_COMMIT
commit=true  -> ACCEPT_COMMITTED_ACTION
```

---

## POST /capu/audit

Purpose:

```text
Return an audit-shaped decision response for a transition.
```

### Rejected P6 audit

Example request:

```json
{
  "transition_type": "external_action",
  "transition_id": "http-p6-reject",
  "action_kind": "send_email",
  "cause_id": null,
  "commit": false
}
```

Example response:

```json
{
  "route": "/capu/audit",
  "transition_id": "http-p6-reject",
  "invariant_id": "P6",
  "boundary": "action_requires_commit",
  "verdict": "blocked_action_without_commit",
  "accepted": false
}
```

Fixtures:

```text
fixtures/capu_runtime_http/requests/audit_p6_uncommitted.json
fixtures/capu_runtime_http/responses/audit_p6_uncommitted.json
```

### Accepted P6 audit

Example request:

```json
{
  "transition_type": "external_action",
  "transition_id": "http-p6-accept",
  "action_kind": "send_email",
  "cause_id": 101,
  "commit": true
}
```

Example response:

```json
{
  "route": "/capu/audit",
  "transition_id": "http-p6-accept",
  "invariant_id": "P6",
  "boundary": "action_requires_commit",
  "verdict": "accepted_committed_action",
  "accepted": true
}
```

Fixtures:

```text
fixtures/capu_runtime_http/requests/audit_p6_committed.json
fixtures/capu_runtime_http/responses/audit_p6_committed.json
```

---

## POST /capu/replay

Purpose:

```text
Return replay evidence for a canonical P1 or P6 sealed audit pair.
```

Current v0 replay is not yet arbitrary user-submitted replay. It selects a canonical pair by invariant marker.

### P1 canonical replay

Example request:

```json
{
  "invariant_id": "P1",
  "replay": "canonical_pair"
}
```

Example response:

```json
{
  "route": "/capu/replay",
  "invariant_id": "P1",
  "result": "capu_runtime_http_replay_valid",
  "events": 2,
  "p1_boundary_events": 2,
  "rejected_without_cause": 1
}
```

Fixtures:

```text
fixtures/capu_runtime_http/requests/replay_p1_pair.json
fixtures/capu_runtime_http/responses/replay_p1_pair.json
```

### P6 canonical replay

Example request:

```json
{
  "invariant_id": "P6",
  "replay": "canonical_pair"
}
```

Example response:

```json
{
  "route": "/capu/replay",
  "invariant_id": "P6",
  "result": "capu_runtime_http_replay_valid",
  "events": 2,
  "p6_boundary_events": 2,
  "rejected_without_commit": 1
}
```

Fixtures:

```text
fixtures/capu_runtime_http/requests/replay_p6_pair.json
fixtures/capu_runtime_http/responses/replay_p6_pair.json
```

---

## Error responses

The v0 sidecar includes controlled error fixtures for basic HTTP boundary failures.

### Unknown route

Example request:

```http
GET /capu/unknown HTTP/1.1
```

Expected status:

```text
404 Not Found
```

Example response:

```json
{
  "status": "error",
  "error": "route_not_found"
}
```

Fixture:

```text
fixtures/capu_runtime_http/responses/unknown_route.json
```

### Malformed request

Example malformed request:

```text
BROKEN
```

Expected status:

```text
400 Bad Request
```

Example response:

```json
{
  "status": "error",
  "error": "bad_request:missing path"
}
```

Fixture:

```text
fixtures/capu_runtime_http/responses/malformed_request.json
```

---

## Current verified evidence

The sidecar currently verifies:

```text
health route
P1 rejected decide route
P6 rejected decide route
P6 accepted decide route
P6 rejected audit route
P6 accepted audit route
P1 replay route
P6 replay route
unknown-route error response
malformed-request error response
saved request fixtures
saved response fixtures
schema-checked response fixtures
manifest-checked route/case/fixture map
external client example over local HTTP
real local TCP HTTP round trips in --self-test mode
```

The self-test and client example use ephemeral local addresses and send real HTTP requests through local TCP/HTTP.

---

## Non-claims

This v0 contract does not claim:

```text
production HTTP service
authentication
authorization
streaming
OpenAPI completeness
stable public SDK
arbitrary replay submission
production error taxonomy
```

It is a local reference sidecar contract for reviewer-visible evidence.

---

## Next API milestones

Recommended next steps:

```text
1. Add production-grade error taxonomy only after the v0 surface stabilizes.
2. Add arbitrary replay submission after canonical replay coverage is stable.
3. Generate OpenAPI from the manifest after the route surface stabilizes.
4. Add a tiny SDK wrapper only after the client example stabilizes.
```

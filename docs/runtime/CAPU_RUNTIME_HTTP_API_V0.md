# CaPU Runtime HTTP API v0

Status: reference API contract for the minimal CaPU runtime sidecar.

This document describes the current local HTTP sidecar contract implemented by:

```text
rust/cmc-core/src/bin/capu_runtime_http_sidecar.rs
```

The implementation is intentionally std-only and reference-grade. It is not a production HTTP framework and not yet an OpenAPI-backed public API.

Current maturity movement represented by this contract:

```text
Software reference processor: ~62%
Runtime sidecar/API:        ~30%
Hardware/device path:       ~5%
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

### External action request

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

Expected decision semantics:

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

---

## Current verified evidence

The sidecar currently verifies:

```text
health route
P1 decide route
P6 audit route
P1 replay route
saved request fixtures
saved response fixtures
real local TCP HTTP round trip in --self-test mode
```

The self-test uses an ephemeral local address and sends real HTTP requests through `TcpStream`.

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
1. Add JSON schema files for request and response fixtures.
2. Add OpenAPI-style route summary.
3. Add P6 replay request/response fixture.
4. Add error fixtures for unknown route and malformed request.
5. Add a minimal client example.
```

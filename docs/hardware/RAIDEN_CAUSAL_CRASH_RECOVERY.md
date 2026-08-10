# Raiden Causal Crash-Recovery Verification

## Goal

Use Google TPU Raiden KV-cache crash recovery as an external validation target for the CaPU Causal Verification Field.

The target property is:

```text
For every meaningful interruption point during KV-cache persistence,
restart must converge to a safe and deterministic state that can be verified
from durable evidence.
```

This is a QA/reliability research target, not a vulnerability claim.

## Upstream baseline

Raiden already contains recovery E2E coverage for a completed save followed by process death and restart. The current JAX recovery test uses subprocess phases and can force the JAX CPU backend, making the first verification stage possible without physical TPU hardware.

Relevant upstream paths:

```text
google/tpu-raiden
  tpu_raiden/api/jax/kv_cache_store_recovery_e2e_test.py
  tpu_raiden/api/torch/kv_cache_store_recovery_e2e_test.py
  tpu_raiden/kv_cache/kv_cache_metadata.cc
  tpu_raiden/kv_cache/kv_cache_metadata_shm.cc
  tpu_raiden/kv_cache/kv_cache_metadata_shm_test.cc
```

## Existing known-good recovery path

```text
Phase A
  create cache
  -> insert blocks
  -> pin
  -> save
  -> poll save to completion
  -> release
  -> verify host-resident state
  -> SIGKILL

Phase B
  fresh process
  -> attach surviving shared memory
  -> rebuild metadata/LRU state
  -> verify recovered blocks
  -> load blocks
  -> compare recovered bytes
```

The current baseline also checks identity mismatch behavior so a restart under a different model identity cold-starts instead of resurrecting incompatible state.

## Verification gap to explore

The highest-value next step is interruption **inside** the persistence transition rather than only after save completion.

Conceptual transition field:

```text
S0 HBM_ONLY
  |
  | save()
  v
S1 SAVE_REQUESTED
  |
  | fault point A
  v
S2 HOST_WRITE_IN_PROGRESS
  |
  | fault point B
  v
S3 HOST_BYTES_WRITTEN
  |
  | fault point C
  v
S4 METADATA_COMMIT_IN_PROGRESS
  |
  | fault point D
  v
S5 METADATA_COMMITTED
  |
  | fault point E
  v
S6 HOST_RECOVERABLE
```

The exact internal checkpoints must be mapped to the implementation before executable fault injection is added.

## CaPU event model

Each injected crash becomes one event:

```text
E = <S, C, Phi, T, tau, R, V, P>
```

Example:

```text
S   = HOST_WRITE_IN_PROGRESS
C   = explicit fault injection
Phi = persistence/save
T   = device cache -> host shared-memory cache
Tau = crash at checkpoint B before metadata commit
R   = restart -> missing/recovered/rejected block
V   = no invalid partial entry; bytes and identity invariants hold
P   = phase markers + exit code + metadata snapshot + hashes + test result
```

## Initial crash-transition matrix

| ID | Phase | Fault point | Expected safe recovery | Primary verification | Proof artifact |
|---|---|---|---|---|---|
| RDN-001 | before save | SIGKILL before request | cold/missing host copy | lookup has no recovered host block | trace + exit code |
| RDN-002 | save requested | SIGKILL immediately after request | no partially valid recovered entry | metadata validity invariant | metadata dump/hash |
| RDN-003 | host write | SIGKILL during host persistence | safe reject or complete recover, never partial-valid | byte integrity + validity | byte hash + trace |
| RDN-004 | metadata commit | SIGKILL during metadata update | incomplete metadata must not become valid | valid-bit/entry invariant | metadata snapshot |
| RDN-005 | committed | SIGKILL after metadata durable commit | deterministic warm recovery | identity + block mapping | trace + recovered state hash |
| RDN-006 | post-save baseline | SIGKILL after completion | full warm recovery | recovered bytes equal original | current-style E2E markers |
| RDN-007 | restart identity mismatch | model UID changes | cold start / reject old cache | no stale lookup hits | identity evidence |
| RDN-008 | restart geometry mismatch | block geometry changes | reformat/cold path | old bindings absent | metadata evidence |

Expected results deliberately allow either recovery or rejection where implementation semantics require deeper inspection. The invariant is fail-safe determinism, not forced warm recovery.

## Core invariants

### RDN-INV-001 — No partial-valid metadata

A crash during metadata mutation must never leave an entry that is considered valid while containing partially updated fields.

### RDN-INV-002 — Identity isolation

State created for one model/config identity must not be resurrected under an incompatible identity.

### RDN-INV-003 — Durable commit survives restart

Once a save is durably committed according to Raiden semantics, a process crash must not silently erase the committed binding unless recovery deliberately rejects it for a validated compatibility reason.

### RDN-INV-004 — Bytes match binding

A recovered hash/block binding must refer to the same bytes that were persisted before the crash.

### RDN-INV-005 — Recovery is deterministic

Given the same durable shared-memory contents and compatible runtime identity, repeated restart should produce the same recovery classification and observable state.

### RDN-INV-006 — Cold start is clean

If recovery validation fails, recreated state must not expose stale bindings from the rejected segment.

### RDN-INV-007 — Proof is phase-specific

A successful process exit alone is insufficient. Each test phase must emit a checkpoint marker only after the relevant assertions have passed.

## Proof bundle v0

Each scenario should eventually generate a machine-readable bundle:

```text
evidence/raiden/RDN-XXX/
  manifest.json
  pre_state.json
  fault.json
  restart_state.json
  invariants.json
  stdout.log
  stderr.log
  hashes.json
  proof.json
```

Example `proof.json` shape:

```json
{
  "scenario": "RDN-004",
  "target": "google/tpu-raiden",
  "phase": "metadata_commit",
  "transition": "host_persist_to_recoverable",
  "fault": "SIGKILL",
  "pre_state_hash": "...",
  "restart_state_hash": "...",
  "verification": "pass|fail|inconclusive",
  "evidence_sha256": ["..."]
}
```

## CPU-first execution strategy

Stage 1 deliberately stays CPU-first:

```text
upstream source inspection
  -> reproduce existing JAX CPU recovery E2E
  -> identify exact save/metadata checkpoints
  -> add deterministic fault injection in a research harness
  -> collect proof bundles
```

TPU hardware should only be required later for behavior that depends on TPU-specific transfer, topology, DMA, device-memory, or production inference paths.

## Success criteria for the first CaPU validation

The first milestone is complete when we have:

1. one reproducible baseline recovery scenario on CPU;
2. at least two injected interruption checkpoints inside a transition;
3. explicit invariants for both checkpoints;
4. deterministic pass/fail/inconclusive semantics;
5. a proof bundle that can be independently inspected;
6. a clear comparison between the upstream baseline and the added causal-temporal coverage.

## Next implementation step

Build a small external harness around the upstream recovery test that records phase markers and evidence without changing Raiden semantics first. After the exact transition boundaries are understood, decide whether the strongest contribution belongs upstream as additional tests or remains as an external CaPU verification adapter.

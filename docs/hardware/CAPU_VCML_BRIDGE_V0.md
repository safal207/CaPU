# CaPU ↔ vCML Bridge v0

Status: experimental semantic/hardware bridge. Current hardware step: **CaPU Core v0.9 bounded one-shot root authorization replay guard**.

> Verification note: the v0.9 implementation, deterministic scenarios, software audit, and bounded formal envelope are described below. GitHub Actions evidence is immutable per run; PR #69 records the latest verified branch head and its final artifact IDs. This document intentionally avoids requiring its own evidence IDs to equal the latest rerun IDs.

This layer connects the CaPU causal STORE retirement boundary to CML/vCML without embedding a full causal journal in RTL.

## Source semantics

The bridge follows the vCML / CTAG semantics from `safal207/Causal-Memory-Layer` pinned at `1635804f127b7840dca0cd2679c0f001552b7b10`.

```text
b15..b12  DOM    4 bits
b11..b8   CLASS  4 bits
b7..b4    GEN    4 bits
b3..b1    LHINT  3 bits
b0        SEAL   1 bit
```

CTAG is compact causal metadata, not cryptography. `LHINT` is not parent identity, and `SEAL` is not a signature or authorization proof.

## Retained causal boundaries

### v0.3 — CTAG admission

```text
metadata_valid
&& DOM != RESERVED(15)
&& CLASS == WRITE(2)
```

### v0.4 — committed SEAL

A committed `SEAL` blocks automatic continuation until a legitimate explicit root establishes a new local epoch.

### v0.5 — exact committed parent

Ordinary continuation must name the exact committed `causal_head_transition_id`. `TRANSITION_ID_WIDTH == PARENT_REF_WIDTH` is required for the prototype comparison.

### v0.6 — committed GEN and anti-wrap

```text
NORMAL_CONTINUATION_ADMISSION
    => HEAD_VALID
    && !SEALED_CHAIN
    && !GEN_EXHAUSTED
    && PARENT_REF == COMMITTED_HEAD
    && GEN == COMMITTED_GEN + 1

COMMITTED_GEN == F
    => NO_AUTOMATIC_CHILD
```

Automatic `F -> 0` continuation is forbidden; a new root starts at `GEN=0`.

### v0.7 — root intent versus root authorization

`explicit_new_cause` is intent only. A separate trusted upstream `root_authorized` decision is required. The bit is not cryptographic authentication.

### v0.8 — authorization provenance

A bare trusted YES is insufficient. An admitted root must also carry:

```text
root_authorization_ref != 0
root_policy_epoch       // opaque provenance only
```

`root_policy_epoch` is not a freshness counter, nonce, or replay barrier.

## v0.9 — bounded one-shot authorization replay guard

v0.9 makes `root_authorization_ref` one-shot within one **volatile controller reset lifetime**.

```text
SPENT_AUTHORIZATION_SLOTS = 4   // default
```

The spent set has no eviction. Replay identity is `root_authorization_ref` itself; changing `root_policy_epoch` cannot make a spent ref fresh again.

### Root admission

```text
ROOT_ADMISSION
    => explicit_new_cause
    && root_authorized
    && root_authorization_ref != 0
    && AUTHORIZATION_REF_FRESH
    && !AUTHORIZATION_CAPACITY_EXHAUSTED
    && parent_ref == 0
    && GEN == 0
    && CTAG_SEMANTIC_ACCEPT
    && gate_allow
    && execute_ok
    && !buffer_valid
```

Fail-closed cases include unauthorized root, zero authorization ref, any previously spent ref, and a fresh ref when the finite spent set is already full.

### Consumption happens at retirement, not admission

```text
ROOT_RETIREMENT(auth_ref)
    => SPENT(auth_ref)
```

A speculative authorized root followed by `flush` does not write memory, emit a vCML event, or mutate the spent set. Its ref remains fresh for a later retry if no successful root retirement has consumed it.

### Non-adjacent replay

The guard is not a last-ref cache:

```text
commit root(ref=A)
commit root(ref=B)
commit root(ref=C)
request root(ref=A)
        ↓
REJECT
```

A changed opaque policy epoch does not bypass this comparison.

### Capacity and reset

With four default slots, after four distinct refs are consumed the controller rejects a fifth root rather than evict old replay state. Reset clears the volatile table. Therefore v0.9 does not claim replay protection across reset or power loss.

## Root-only provenance binding

An admitted root latches authorization decision/reference/policy epoch through speculation. An ordinary continuation forces these root-provenance fields to zero even when external root sidebands are spuriously high.

```text
VISIBLE_ROOT_COMMIT
    => RETIRED_ROOT_AUTHORIZED
    && RETIRED_AUTHORIZATION_REF != 0
    && RETIRED_AUTHORIZATION_REF_SPENT
```

The wrapper exposes prototype observability signals:

```text
authorization_ref_fresh
authorization_replay_detected
authorization_capacity_exhausted
spent_authorization_count
retired_authorization_ref_spent
```

They are local state, not cryptographic attestations.

## Flush semantics

```text
FLUSH
    => NO_RETIREMENT_EVENT
    && COMMITTED_HEAD unchanged
    && COMMITTED_GEN unchanged
    && COMMITTED_SEAL unchanged
    && LAST_RETIRED_AUTH_PROVENANCE unchanged
    && SPENT_AUTHORIZATION_SET unchanged
```

## v0.9 invariant set

```text
MEMORY_VISIBLE_WRITE
    => VALID_CAUSAL_COMMIT
    && VALIDATOR_ACCEPTED_CTAG

NORMAL_CONTINUATION_ADMISSION
    => HEAD_VALID
    && !SEALED_CHAIN
    && !GEN_EXHAUSTED
    && PARENT_REF == COMMITTED_HEAD
    && GEN == COMMITTED_GEN + 1

EXPLICIT_NEW_CAUSE_ADMISSION
    => ROOT_AUTHORIZED
    && AUTHORIZATION_REF != 0
    && AUTHORIZATION_REF_FRESH
    && !AUTHORIZATION_CAPACITY_EXHAUSTED
    && PARENT_REF == 0
    && GEN == 0

SPENT_AUTHORIZATION_REF
    => NO_ROOT_ADMISSION

AUTHORIZATION_CAPACITY_EXHAUSTED
    => NO_FRESH_ROOT_ADMISSION

VISIBLE_ROOT_COMMIT
    => RETIRED_ROOT_AUTHORIZED
    && RETIRED_AUTHORIZATION_REF_SPENT
    && SPENT_COUNT increments by exactly one

NON_ROOT_RETIREMENT
    => SPENT_COUNT unchanged

NO_VISIBLE_ROOT_RETIREMENT
    => SPENT_COUNT unchanged

CONTINUATION_RETIREMENT
    => NO_ROOT_AUTHORIZATION_PROVENANCE

FLUSH
    => NO_RETIREMENT_EVENT
    && COMMITTED_HEAD_GEN_SEAL unchanged
    && LAST_RETIRED_AUTH_PROVENANCE unchanged
    && SPENT_COUNT unchanged
```

## vCML software projection and replay-window audit

`tools/vcml_bridge.py` projects exact retired root provenance into a vCML-style record and covers those emitted fields with deterministic SHA-256 record integrity.

v0.9 adds:

```python
verify_authorization_replay_window(records, capacity=4)
```

The audit mirrors one volatile hardware lifetime: duplicate root refs fail even with a different policy epoch, four unique roots fit default capacity, a fifth fails closed, and continuations must carry zero root provenance. Reset/power-cycle boundaries are separate audit lifetimes.

## Deterministic verification trajectory

The v0.9 RTL testbench covers:

- structural/CTAG/unauthorized/zero-ref rejection;
- first root `A110` consumed (`spent=1`);
- immediate `A110` replay rejection with a changed policy epoch;
- continuation isolation from root sidebands;
- exact parent/GEN and SEAL behavior;
- root `A130` admitted then flushed without consumption;
- the same `A130` later committed exactly once (`spent=2`);
- full GEN progression to `F` without spent changes from continuations;
- root `A162` after exhaustion (`spent=3`);
- non-adjacent replay of old `A110` after intervening roots;
- fourth root `A164` filling the table (`spent=4`);
- fifth fresh root `A165` rejected at capacity.

Expected marker:

`CAPU_VCML_BRIDGE_V09_RTL_PASS`

The Python semantic bridge/audit suite contains **19 tests**.

## Formal verification envelope

Reduced-width bounded instance:

```text
ADDR_WIDTH                = 4
DATA_WIDTH                = 8
CTAG_WIDTH                = 16
TRANSITION_ID_WIDTH       = 8
PARENT_REF_WIDTH          = 8
GEN_WIDTH                 = 4
ROOT_AUTHORIZATION_WIDTH  = 1
AUTHORIZATION_REF_WIDTH   = 4
POLICY_EPOCH_WIDTH        = 4
SPENT_AUTHORIZATION_SLOTS = 4
```

CI proves safety through **36 formal CPU sampling steps** and cover reachability through **40 steps** using pinned SBY `b1a1e98cba941ec8433f8dc27f416cd7bb7f14be`, Yosys 0.33, and Z3 4.8.12. The workflow is fail-closed: proof sealing requires literal `DONE (PASS)` and rejects `DONE (ERROR)`.

The formal input bundle SHA-256 for this v0.9 implementation is:

`5c03f0740ed6f36ce7501d931db4e077eeeb3381df4b37aa62ba3e0099c54244`

Cover is non-vacuous for authorized root retirement, unauthorized/zero-ref rejection, spent-ref replay rejection, normal continuation, root under SEAL, root after GEN exhaustion, spent capacity full, and fresh-root rejection at full capacity. The current envelope produces eight VCD witnesses; two capacity cover statements can share one witness, and the long GEN-exhaustion path reaches step 36.

## Non-goals / claim boundary

v0.9 does **not** claim cryptographic authorization, authenticated issuer identity, signature/MAC/key/certificate verification, that refs are unforgeable real-world capabilities, freshness beyond the local spent-table comparison, freshness/anti-replay semantics for `root_policy_epoch`, persistence across reset/power loss, global or distributed replay coordination, unbounded replay history, safe eviction/compaction, persistent spent-set recovery, correctness of upstream policy, cryptographic lineage, globally unique transition IDs, a complete CPU/ISA/cache/coherence proof, or a parametric proof across every width/set size.

The narrow v0.9 result is: **within one volatile controller lifetime and a bounded no-eviction spent-reference set, a root authorization reference is consumed only by successful root retirement, cannot be reused afterward even across intervening roots or a changed opaque policy epoch, is not consumed by flush, and causes fresh roots to fail closed once local replay-state capacity is exhausted.** All earlier CTAG, exact-parent, GEN, SEAL, causal-commit, and retirement-evidence boundaries remain in force.

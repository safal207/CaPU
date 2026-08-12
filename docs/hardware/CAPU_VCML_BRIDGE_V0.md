# CaPU ↔ vCML Bridge v0

Status: experimental semantic/hardware bridge. Current hardware step: **CaPU Core v0.9 bounded one-shot root authorization replay guard**.

This layer connects the CaPU causal STORE retirement boundary to CML/vCML without embedding a full causal journal in RTL.

## Source semantics

The bridge follows the vCML / CTAG semantics from `safal207/Causal-Memory-Layer` pinned at:

`1635804f127b7840dca0cd2679c0f001552b7b10`

Canonical CTAG layout:

```text
b15..b12  DOM    4 bits
b11..b8   CLASS  4 bits
b7..b4    GEN    4 bits
b3..b1    LHINT  3 bits
b0        SEAL   1 bit
```

CTAG is compact causal metadata, not cryptography. `LHINT` is not parent identity, and `SEAL` is not a signature or authorization proof.

## Hardware / software split

Each speculative STORE carries compact execution and causal metadata:

```text
address
data
ctag                       : 16 bits
transition_id              : implementation-width reference
parent_ref                 : implementation-width reference
explicit_new_cause         : 1 bit root intent
buffered_root_authorized   : 1 bit root-qualified trusted decision
buffered_authorization_ref : opaque authorization provenance reference
buffered_policy_epoch      : opaque policy-version field
```

The full causal record remains a software projection after retirement. Exact local parent matching uses `transition_id / parent_ref`; `LHINT` remains only a hint.

## Retained boundaries

### v0.3 — local CTAG validation

Strict STORE admission requires:

```text
metadata_valid
&& DOM != RESERVED(15)
&& CLASS == WRITE(2)
```

### v0.4 — committed SEAL state

`capu_seal_controller` maintains volatile `sealed_chain` state. A sealed chain blocks automatic continuation independently of otherwise-correct parent or generation metadata.

### v0.5 — committed causal head

`capu_causal_head_controller` retains:

```text
causal_head_valid
causal_head_transition_id
```

An ordinary continuation must name the exact committed head. `TRANSITION_ID_WIDTH == PARENT_REF_WIDTH` is required so the comparison is not silently truncated or extended.

### v0.6 — committed causal generation

The committed head also carries:

```text
causal_head_gen : 4 bits
```

Automatic continuation requires exact next generation and refuses automatic wrap:

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

A fresh local epoch starts at `GEN=0`.

### v0.7 — root intent versus root authorization

`explicit_new_cause` is root intent only. A separate upstream trust decision is required:

```text
explicit_new_cause
&& root_authorized
```

`root_authorized` is a trusted sideband, not cryptographic authentication.

### v0.8 — authorization provenance anchor

A trusted YES bit by itself does not identify which decision allowed the root. v0.8 added:

```text
root_authorization_ref : 16 bits by default
root_policy_epoch      : 8 bits by default
```

`root_authorization_ref` is an opaque provenance / capability reference. Zero means no authorization reference.

`root_policy_epoch` is an opaque upstream policy-version field. It is preserved through retirement but is not interpreted as a freshness counter, nonce, or replay barrier.

## v0.9 — bounded one-shot authorization replay guard

v0.9 makes `root_authorization_ref` one-shot within one volatile controller reset lifetime.

The hardware contains a bounded spent-reference set:

```text
SPENT_AUTHORIZATION_SLOTS = 4   // default

spent_authorization_valid[slot]
spent_authorization_refs[slot]
```

There is **no eviction** in v0.9. The replay identity is the authorization reference itself; `root_policy_epoch` remains opaque and changing it cannot make a spent ref fresh.

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

Therefore these fail closed before speculation:

```text
root_authorized = 0
    => REJECT

root_authorization_ref = 0
    => REJECT

SPENT(root_authorization_ref)
    => REJECT

AUTHORIZATION_CAPACITY_EXHAUSTED
    => REJECT even a fresh authorization_ref
```

### Consumption boundary

A reference is consumed only by successful authorized-root retirement:

```text
ROOT_RETIREMENT(auth_ref)
    => SPENT(auth_ref)
```

Admission alone does not consume it. A speculative root followed by `flush` produces no memory write, no vCML event, no spent-set mutation, and the same ref remains fresh for a later retry.

### Non-adjacent replay

This is not a last-reference cache:

```text
commit root(ref=A)
commit root(ref=B)
commit root(ref=C)
request root(ref=A)
        ↓
REJECT
```

A changed opaque policy epoch does not bypass the spent check.

### Capacity

With the default four slots:

```text
spent = {A, B, C, D}
request root(ref=E)
        ↓
REJECT until reset
```

Failing closed at capacity avoids silently evicting old replay state. Reset clears the volatile table, so v0.9 does not claim replay protection across reset or power loss.

### Observability

The wrapper exposes:

```text
authorization_ref_fresh
authorization_replay_detected
authorization_capacity_exhausted
spent_authorization_count
retired_authorization_ref_spent
```

These are local prototype state, not cryptographic attestations.

## Root-only provenance binding

An admitted root latches authorization decision/reference/policy epoch. An ordinary continuation forces all root-provenance fields to zero, even if root sidebands are spuriously high.

A visible root must carry exact retired provenance and the retired ref must already be represented in the spent set:

```text
VISIBLE_ROOT_COMMIT
    => RETIRED_ROOT_AUTHORIZED
    && RETIRED_AUTHORIZATION_REF != 0
    && RETIRED_AUTHORIZATION_REF_SPENT
```

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

This keeps speculative authorization distinct from consumed authorization.

## Core v0.9 invariants

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

## vCML projection and replay-window audit

`tools/vcml_bridge.py` projects exact retired root provenance into the emitted vCML-style record and seals the record bytes with deterministic SHA-256 integrity.

v0.9 also adds:

```python
verify_authorization_replay_window(records, capacity=4)
```

The software audit mirrors one volatile hardware lifetime: duplicate root refs fail even with a different policy epoch, four unique refs fit the default capacity, a fifth root fails closed, and continuations must carry zero root provenance. Reset/power-cycle boundaries must be supplied as separate audit lifetimes.

## Deterministic RTL and software verification

Final verified run: **`31561835031`** on branch head **`ecbcf5fcdb4c96ec0dcfae13ce35a0ca33c25cc7`**.

RTL/semantic job: **`94005577434` — success**.

The deterministic trajectory includes:

- initial authorization and structural rejection cases;
- first root `A110` consumed (`spent=1`);
- immediate `A110` replay rejection with changed policy epoch;
- continuation isolation from root sidebands;
- SEAL and exact parent/GEN enforcement;
- root `A130` admitted then flushed without consumption;
- the same `A130` later committed exactly once (`spent=2`);
- GEN progression to `F` without spent-state changes from continuations;
- root `A162` after exhaustion (`spent=3`);
- non-adjacent `A110` replay rejection after intervening roots;
- fourth root `A164` filling the table (`spent=4`);
- fifth fresh root `A165` rejected at capacity.

Marker:

`CAPU_VCML_BRIDGE_V09_RTL_PASS`

Python semantic bridge/audit tests: **19/19 PASS**.

Final executable evidence:

```text
artifact: capu-vcml-bridge-v09-evidence
artifact ID: 9128007119
size: 1402 bytes
ZIP SHA-256: 67ee05caaf061726a46d6840879f9502537c23d274b0faede1c4dc5ae4d855b4
```

## Formal verification envelope

Formal job: **`94005628089` — success**.

Reduced formal instance:

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

Safety:

```text
BMC depth: 36
steps checked: 0..35
engine: smtbmc --unroll z3 -- --noincr
Yosys: 0.33 (2584903a060)
Z3: 4.8.12
SBY pinned: b1a1e98cba941ec8433f8dc27f416cd7bb7f14be
DONE (PASS, rc=0)
```

Cover:

```text
depth: 40
8 VCD witnesses: trace0.vcd ... trace7.vcd
capacity-full + capacity-reject cover statements: step 11
root-after-GEN-exhaustion witness: step 36
DONE (PASS, rc=0)
```

The cover envelope establishes non-vacuity for authorized-root retirement, unauthorized/zero-ref rejection, spent-ref replay rejection, normal continuation, root under SEAL, root after GEN exhaustion, spent-set capacity full, and fresh-root rejection at full capacity. Two capacity statements share one step-11 witness.

Final sealed formal evidence:

```text
schema: capu.hardware.vcml-formal-proof.v0.9
formal input SHA-256: 5c03f0740ed6f36ce7501d931db4e077eeeb3381df4b37aa62ba3e0099c54244
safety log SHA-256: a6e819c3fa656d2239693444ed418c4a4760cd282c8ca93309f6d5a76643996f
cover log SHA-256: b568a379141d3d7db4d17bade92049a47633db520a802c17213cbc36f955ceab
artifact: capu-vcml-v09-formal-evidence
artifact ID: 9128093675
size: 349071 bytes
ZIP SHA-256: 756ed60ce227eaa73d450a53971269aaac313ed148016061a7ea80703cb56fd4
```

CI remains fail-closed: evidence is sealed only after literal `DONE (PASS)` for safety and cover and absence of `DONE (ERROR)`.

## Repository-level verification

On the same final branch head `ecbcf5fcdb4c96ec0dcfae13ce35a0ca33c25cc7`:

```text
Validate Examples       run 31561835030  success
CaPU Core v0 RTL Smoke  run 31561835037  success
CaPU vCML Bridge v0     run 31561835031  success
```

## Non-goals / claim boundary

v0.9 does **not** claim:

- cryptographic root authorization or authenticated issuer identity;
- signature/MAC/key/certificate/attestation verification;
- that a reference is unforgeable or denotes a valid real-world capability;
- freshness/nonce semantics beyond comparison against the local spent table;
- freshness, monotonicity, or anti-replay semantics for `root_policy_epoch`;
- replay protection across reset or power loss;
- persistent or global replay protection;
- coordination across cores, controllers, machines, or distributed agents;
- persistent spent-set recovery before architectural effects;
- unbounded replay history: default capacity is four;
- safe eviction or compaction of spent references;
- correctness of the upstream authorization policy;
- cryptographic lineage/authenticated parent identity;
- globally unique or collision-resistant transition IDs;
- a complete CPU/ISA/cache/coherence proof;
- a parametric formal proof across every possible width or spent-set size.

The narrow v0.9 result is: **within one volatile controller lifetime and a bounded no-eviction spent-reference set, a root authorization reference is consumed only by successful root retirement, cannot be reused afterward even across intervening roots or a changed opaque policy epoch, is not consumed by flush, and causes fresh roots to fail closed once local replay-state capacity is exhausted.** All previously established CTAG, exact-parent, generation, SEAL, causal-commit, and retirement-evidence bindings remain in force.

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

The v0.8 root boundary was:

```text
EXPLICIT_NEW_CAUSE_ADMISSION
    => root_authorized
    && root_authorization_ref != 0
    && parent_ref == 0
    && GEN == 0
```

with the existing CTAG, gate, execute, and empty-buffer checks.

## v0.9 — bounded one-shot authorization replay guard

v0.8 could prove that a root carried a concrete authorization reference, but it deliberately allowed that same reference to be presented again later. v0.9 makes the authorization reference **one-shot within one volatile controller reset lifetime**.

The hardware contains a bounded spent-reference set:

```text
SPENT_AUTHORIZATION_SLOTS = 4   // default

spent_authorization_valid[slot]
spent_authorization_refs[slot]
```

The set has **no eviction** in v0.9.

The replay identity is the authorization reference itself:

```text
authorization identity = root_authorization_ref
```

`root_policy_epoch` is not part of that identity. Changing the policy epoch therefore cannot make a spent authorization reference fresh again.

### Admission rule

A fresh root may enter speculation only when:

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

The following fail closed before speculation:

```text
root_authorized = 0
    => REJECT

root_authorization_ref = 0
    => REJECT

SPENT(root_authorization_ref)
    => REJECT

AUTHORIZATION_CAPACITY_EXHAUSTED
    => REJECT even a new/fresh root ref
```

### Consumption boundary

An authorization reference becomes spent only when an authorized root **successfully retires**:

```text
ROOT_RETIREMENT(auth_ref)
    => SPENT(auth_ref)
```

Admission alone does not consume it.

This matters for speculation and recovery:

```text
authorized root candidate(ref=A)
        ↓
speculative buffer
        ↓
flush
        ↓
NO memory write
NO vCML event
NO spent-set mutation
        ↓
ref A remains fresh
```

Therefore a flushed root candidate may legitimately retry the same authorization reference once later, provided it has not been committed elsewhere in the same controller lifetime.

### Replay semantics

After retirement, reuse is blocked even after other roots have committed:

```text
commit root(ref=A)
commit root(ref=B)
commit root(ref=C)
request root(ref=A)
        ↓
REJECT
```

This is intentionally stronger than a last-reference cache.

Changing `root_policy_epoch` does not bypass the spent check:

```text
commit root(ref=A, policy_epoch=1)
request root(ref=A, policy_epoch=99)
        ↓
REJECT
```

### Capacity semantics

The default prototype tracks four spent references. There is no eviction:

```text
spent = {A, B, C, D}
capacity = 4

request root(ref=E)
        ↓
REJECT until reset
```

Failing closed at capacity avoids silently forgetting an older spent reference and reopening replay via eviction.

Reset clears this volatile spent set. Consequently v0.9 does **not** claim replay protection across reset or power loss.

### Hardware observability

The v0.9 wrapper exposes:

```text
authorization_ref_fresh
authorization_replay_detected
authorization_capacity_exhausted
spent_authorization_count
retired_authorization_ref_spent
```

These expose the local prototype state; they are not cryptographic security attestations.

## Root-only provenance binding

On an admitted root:

```text
buffered_root_authorized         = root_authorized
buffered_root_authorization_ref  = root_authorization_ref
buffered_root_policy_epoch       = root_policy_epoch
```

On an ordinary continuation all root provenance fields are forced to zero, even when root sideband inputs are spuriously high:

```text
NORMAL_CONTINUATION
    => buffered_root_authorized = 0
    && buffered_root_authorization_ref = 0
    && buffered_root_policy_epoch = 0
```

On successful retirement the latched values become event evidence:

```text
retired_root_authorized
retired_root_authorization_ref
retired_root_policy_epoch
```

A visible root must additionally have its authorization reference present in the local spent set:

```text
VISIBLE_ROOT_COMMIT
    => RETIRED_ROOT_AUTHORIZED
    && RETIRED_AUTHORIZATION_REF != 0
    && RETIRED_AUTHORIZATION_REF_SPENT
```

## Flush semantics

Flush does not mutate committed causal state, previous retired provenance, or the spent authorization set:

```text
FLUSH
    => NO_RETIREMENT_EVENT
    && COMMITTED_HEAD unchanged
    && COMMITTED_GEN unchanged
    && COMMITTED_SEAL unchanged
    && LAST_RETIRED_AUTH_PROVENANCE unchanged
    && SPENT_AUTHORIZATION_SET unchanged
```

This preserves the distinction between a speculative authorization candidate and a consumed authorization.

## Full admission policy

Normal continuation:

```text
issue_valid
&& gate_allow
&& execute_ok
&& CTAG_SEMANTIC_ACCEPT
&& HEAD_VALID
&& !SEALED_CHAIN
&& !GEN_EXHAUSTED
&& parent_ref == causal_head_transition_id
&& GEN == causal_head_gen + 1
&& !buffer_valid
```

Fresh root:

```text
issue_valid
&& gate_allow
&& execute_ok
&& CTAG_SEMANTIC_ACCEPT
&& explicit_new_cause
&& root_authorized
&& root_authorization_ref != 0
&& AUTHORIZATION_REF_FRESH
&& !AUTHORIZATION_CAPACITY_EXHAUSTED
&& parent_ref == 0
&& GEN == 0
&& !buffer_valid
```

Root authorization provenance and replay state are not required for ordinary continuation.

## Retirement boundary

Memory visibility still requires:

```text
buffer_valid
&& causal_valid
&& buffered_ctag_valid
&& commit_request
&& !flush
```

Primary v0.9 invariants:

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

SEALED_CHAIN && !EXPLICIT_NEW_CAUSE
    => NO_AUTOMATIC_CHILD_ADMISSION

GEN_EXHAUSTED && !EXPLICIT_NEW_CAUSE
    => NO_AUTOMATIC_CHILD_ADMISSION

FLUSH
    => NO_RETIREMENT_EVENT
    && COMMITTED_HEAD_GEN_SEAL unchanged
    && LAST_RETIRED_AUTH_PROVENANCE unchanged
    && SPENT_COUNT unchanged

VISIBLE_WRITE
    => exact CTAG / transition_id / parent_ref
       / root_authorized / authorization_ref / policy_epoch binding
```

## vCML software projection and replay-window audit

`tools/vcml_bridge.py` projects the retired provenance into each vCML-style causal record:

```json
{
  "root_authorized": true,
  "root_authorization_ref": 41217,
  "root_policy_epoch": 7,
  "integrity": "sha256:..."
}
```

The SHA-256 integrity field covers the emitted decision, reference, and policy epoch. This detects post-projection byte mutation; it does not authenticate the upstream issuer or validate a real-world capability.

v0.9 also adds:

```python
verify_authorization_replay_window(records, capacity=4)
```

The software audit mirrors one volatile hardware lifetime:

- duplicate authorized-root refs are rejected, including duplicates with a different policy epoch;
- up to four unique committed root refs are accepted by the default model;
- a fifth unique root is rejected because v0.9 has no eviction;
- continuations remain valid only with zero root provenance;
- a reset/power-cycle must be audited as a separate lifetime because the helper does not infer reset events.

## Deterministic RTL verification

The v0.9 deterministic trajectory covers:

- headless continuation, invalid CTAG, malformed root, unauthorized root, and zero-ref rejection;
- first authorized root commit consuming `A110` (`spent=1`);
- immediate `A110` replay rejection despite a changed policy epoch;
- continuation root-sideband isolation;
- stale/skipped GEN and wrong-parent rejection;
- SEAL enforcement;
- authorized root `A130` admitted and flushed without consuming the ref;
- the same `A130` then committing successfully exactly once (`spent=2`);
- full GEN progression to `F` with spent state unchanged by continuations;
- automatic `F -> 0` continuation rejection;
- fresh authorized root `A162` after GEN exhaustion (`spent=3`);
- non-adjacent replay `A110` after intervening roots rejected;
- fourth unique root `A164` filling the no-eviction table (`spent=4`);
- fifth fresh root `A165` rejected due to spent-set capacity.

Expected marker:

`CAPU_VCML_BRIDGE_V09_RTL_PASS`

Implementation-head verification run `31561421051` produced that marker and passed **19/19** Python semantic tests.

Executable evidence from that run:

```text
artifact: capu-vcml-bridge-v09-evidence
artifact ID: 9127859119
ZIP SHA-256: 048df0a4ff660d7222d211d40f3676e30d831281dc5ea56f6f658c3d7352fefa
```

## Formal verification envelope

Safety explores arbitrary bounded inputs for **36 formal CPU sampling steps**. Cover explores **40 steps**.

Reduced-width formal instance:

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
REQUIRE_WRITE_CLASS       = true
```

The v0.9 implementation-head run `31561421051`, formal job `94004407406`, produced literal:

```text
Safety depth 36: DONE (PASS, rc=0)
Cover depth 40:  DONE (PASS, rc=0)
```

Safety checked all steps `0..35`. The spent-set increases only on visible authorized-root retirement; continuation, non-root retirement, idle cycles, and flush do not consume authorization references.

Cover emitted **8 VCD witness traces** (`trace0.vcd` through `trace7.vcd`). The non-vacuity envelope includes:

1. authorized root retirement;
2. unauthorized root rejection;
3. zero-ref root rejection;
4. spent-ref replay rejection;
5. normal continuation after root;
6. authorized root under SEAL;
7. authorized root after generation exhaustion;
8. spent-set capacity full;
9. fresh-root rejection at full capacity.

Two capacity-related cover statements are satisfied in the same witness at step 11. The root-after-generation-exhaustion witness is reached at step 36.

Formal evidence from the implementation-head run:

```text
schema: capu.hardware.vcml-formal-proof.v0.9
formal input SHA-256: 5c03f0740ed6f36ce7501d931db4e077eeeb3381df4b37aa62ba3e0099c54244
safety log SHA-256: d5454cbc732141469ea3c90101c01fdd5663aec8b96f25982e1b82fadf092af4
cover log SHA-256: 6b3e2829752960bf37e3c6dc652b5dd9944daaaa04e3e74705794f7cf43b8f09
artifact: capu-vcml-v09-formal-evidence
artifact ID: 9127947233
ZIP SHA-256: f0782108425d3d61bcc4d5cc32eff51dabb412364431727a848be7287e168bea
```

CI remains fail-closed: evidence is sealed only after literal `DONE (PASS)` for safety and cover and absence of `DONE (ERROR)`.

## Non-goals / claim boundary

v0.9 does **not** claim:

- cryptographic root authorization;
- authenticated issuer/principal identity;
- signature, MAC, key, certificate, or attestation verification;
- that an authorization ref is unforgeable or represents a valid real-world capability;
- freshness or nonce semantics outside the local spent-set comparison;
- freshness, monotonicity, or anti-replay semantics for `root_policy_epoch`;
- replay protection across reset or power loss;
- persistent or global replay protection;
- replay coordination across multiple controllers, cores, machines, or distributed agents;
- persistent spent-set recovery before architectural effects;
- unbounded replay history: the default set contains four entries;
- eviction or safe compaction of spent references;
- correctness of the upstream authorization policy;
- cryptographic lineage or authenticated parent identity;
- globally unique or collision-resistant `transition_id`;
- `LHINT` identity verification;
- persistent head/GEN/SEAL/provenance state across reset or power loss;
- complete CPU/ISA/cache/coherence proof;
- a parametric formal proof across every possible width or spent-set size.

The narrow v0.9 result is: **within one volatile controller lifetime and a bounded no-eviction spent-reference set, a root authorization reference is consumed only by successful root retirement, cannot be reused afterward even across intervening roots or a changed opaque policy epoch, is not consumed by flush, and causes fresh roots to fail closed once local replay-state capacity is exhausted.** All previously established CTAG, exact-parent, generation, SEAL, causal-commit, and retirement-evidence bindings remain in force.

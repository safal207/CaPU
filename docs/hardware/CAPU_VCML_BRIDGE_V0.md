# CaPU ↔ vCML Bridge v0

Status: experimental semantic/hardware bridge. Current hardware step: **CaPU Core v0.8 root authorization provenance / capability anchor**.

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

Each speculative STORE carries the compact execution fields:

```text
address
data
ctag                       : 16 bits
transition_id              : implementation-width reference
parent_ref                 : implementation-width reference
explicit_new_cause         : 1 bit root intent
buffered_root_authorized   : 1 bit root-qualified trusted decision
buffered_authorization_ref : opaque provenance reference
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

## v0.8 — authorization provenance anchor

A trusted YES bit by itself does not identify which decision allowed the root. v0.8 adds two root-qualified provenance fields:

```text
root_authorization_ref : 16 bits by default
root_policy_epoch      : 8 bits by default
```

`root_authorization_ref` is an **opaque provenance / capability reference**. Zero is reserved as “no authorization reference”.

`root_policy_epoch` is an **opaque upstream policy-version field**. v0.8 binds it to the retired event, but does not interpret it as a freshness counter or anti-replay nonce.

A fresh root may enter speculation only when:

```text
EXPLICIT_NEW_CAUSE_ADMISSION
    => explicit_new_cause
    && root_authorized
    && root_authorization_ref != 0
    && parent_ref == 0
    && GEN == 0
    && CTAG_SEMANTIC_ACCEPT
    && gate_allow
    && execute_ok
    && !buffer_valid
```

Therefore both of these fail closed before speculation:

```text
root_authorized = 0
authorization_ref != 0
    => REJECT

root_authorized = 1
authorization_ref = 0
    => REJECT
```

The second case is the new v0.8 boundary: a bare trusted YES is no longer sufficient evidence to establish a fresh causal epoch.

## Root-only provenance binding

On an admitted root:

```text
buffered_root_authorized         = root_authorized
buffered_root_authorization_ref  = root_authorization_ref
buffered_root_policy_epoch       = root_policy_epoch
```

On an ordinary continuation all root provenance fields are forced to zero, even if the external root sideband inputs are spuriously high:

```text
NORMAL_CONTINUATION
    => buffered_root_authorized = 0
    && buffered_root_authorization_ref = 0
    && buffered_root_policy_epoch = 0
```

On successful retirement, the latched values become event evidence:

```text
retired_root_authorized
retired_root_authorization_ref
retired_root_policy_epoch
```

These historical registers are meaningful only when qualified by:

```text
vcml_event_valid == memory_write_enable
```

A visible structural root retirement must carry a nonzero provenance reference:

```text
VISIBLE_ROOT_COMMIT
    => RETIRED_ROOT_AUTHORIZED
    && RETIRED_AUTHORIZATION_REF != 0
```

The policy epoch is preserved exactly but remains semantically opaque.

## Flush semantics

Authorization provenance is speculative until retirement:

```text
old committed head/gen/seal + last retired evidence
        ↓
authorized root admitted
        ↓
flush
        ↓
NO memory write
NO vcml_event
old committed head/gen/seal unchanged
last retired auth/ref/policy_epoch unchanged
```

Thus an authorized-but-flushed root does not become history.

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
&& parent_ref == 0
&& GEN == 0
&& !buffer_valid
```

Root authorization provenance is not required for ordinary continuation.

## Retirement boundary

Memory visibility still requires:

```text
buffer_valid
&& causal_valid
&& buffered_ctag_valid
&& commit_request
&& !flush
```

Primary v0.8 invariants:

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
    && PARENT_REF == 0
    && GEN == 0

UNAUTHORIZED_OR_ZERO_REF_EXPLICIT_ROOT
    => NO_ROOT_ADMISSION

VISIBLE_ROOT_COMMIT
    => RETIRED_ROOT_AUTHORIZED
    && RETIRED_AUTHORIZATION_REF != 0

CONTINUATION_RETIREMENT
    => NO_ROOT_AUTHORIZATION_PROVENANCE

SEALED_CHAIN && !EXPLICIT_NEW_CAUSE
    => NO_AUTOMATIC_CHILD_ADMISSION

GEN_EXHAUSTED && !EXPLICIT_NEW_CAUSE
    => NO_AUTOMATIC_CHILD_ADMISSION

FLUSH
    => NO_RETIREMENT_EVENT
    && COMMITTED_HEAD_GEN_SEAL_UNCHANGED
    && LAST_RETIRED_AUTH_PROVENANCE_UNCHANGED

VISIBLE_WRITE
    => exact CTAG / transition_id / parent_ref
       / root_authorized / authorization_ref / policy_epoch binding
```

## vCML software projection

`tools/vcml_bridge.py` projects the retired provenance fields into the emitted record:

```json
{
  "root_authorized": true,
  "root_authorization_ref": 41217,
  "root_policy_epoch": 7,
  "integrity": "sha256:..."
}
```

The SHA-256 integrity field covers all three values. Post-projection modification of the decision, reference, or policy epoch is detectable.

This protects the emitted bytes only. It does **not** prove who issued the authorization, whether the reference names a real capability, whether the capability is still valid, or whether the policy epoch is fresh.

The software adapter rejects internally inconsistent retirement evidence such as:

```text
root_authorized = true, authorization_ref = 0
```

or unauthorized/non-root evidence carrying nonzero root provenance.

## Deterministic RTL verification

The v0.8 trajectory covers:

- headless continuation rejection;
- invalid CTAG and malformed root rejection;
- unauthorized initial root rejection;
- trusted root with zero authorization reference rejection;
- authorized root commit with exact auth-ref and policy-epoch retirement binding;
- spurious root sideband/provenance on a continuation being ignored;
- stale/skipped GEN and wrong-parent rejection;
- continuation retirement carrying zero root provenance;
- SEAL blocking otherwise-correct continuation;
- unauthorized and zero-ref replacement roots under SEAL rejection;
- authorized root under SEAL followed by flush with no event and unchanged committed/evidence state;
- replacement root with a different authorization reference and policy epoch;
- full GEN progression to `F`;
- automatic `F -> 0` rejection;
- unauthorized and zero-ref roots after exhaustion rejection;
- authorized referenced root after exhaustion establishing a fresh local epoch.

Expected marker:

`CAPU_VCML_BRIDGE_V08_RTL_PASS`

The Python semantic bridge has deterministic unit coverage for exact provenance projection, width validation, inconsistent evidence rejection, and integrity tamper detection.

## Formal verification envelope

Safety explores arbitrary bounded inputs for **36 formal CPU sampling steps**. Cover explores **40 steps**.

Reduced-width formal instance:

```text
ADDR_WIDTH               = 4
DATA_WIDTH               = 8
CTAG_WIDTH               = 16
TRANSITION_ID_WIDTH      = 8
PARENT_REF_WIDTH         = 8
GEN_WIDTH                = 4
ROOT_AUTHORIZATION_WIDTH = 1
AUTHORIZATION_REF_WIDTH  = 4
POLICY_EPOCH_WIDTH       = 4
REQUIRE_WRITE_CLASS      = true
```

Formal safety checks exact retirement binding for authorization decision, nonzero reference, and policy epoch while retaining the CTAG, parent, GEN, SEAL, anti-wrap, flush, and causal-commit invariants.

Cover requires the following classes to be reachable rather than vacuous:

1. authorized root commit with nonzero authorization reference;
2. unauthorized explicit-root rejection;
3. trusted-but-zero-reference root rejection;
4. authorized root followed by a normal continuation;
5. authorized referenced root under a sealed state;
6. authorized referenced root after generation exhaustion.

CI remains fail-closed: evidence is sealed only after literal `DONE (PASS)` for safety and cover and absence of `DONE (ERROR)`.

## Non-goals / claim boundary

v0.8 does **not** claim:

- cryptographic root authorization;
- authenticated issuer/principal identity;
- signature, MAC, key, certificate, or attestation verification;
- that `root_authorization_ref` is globally unique, unforgeable, or a valid capability;
- freshness or nonce semantics for `root_authorization_ref`;
- freshness, monotonicity, or anti-replay semantics for `root_policy_epoch`;
- correctness of the upstream authorization policy;
- cryptographic lineage or authenticated parent identity;
- globally unique or collision-resistant `transition_id`;
- `LHINT` identity verification;
- persistent head/GEN/SEAL/provenance state across reset or power loss;
- global or persistent replay protection;
- protection against reuse of an otherwise accepted authorization reference;
- complete CPU/ISA/cache/coherence proof;
- parametric proof across every configured width.

The narrow v0.8 result is: CaPU no longer accepts a fresh root based solely on a trusted YES bit. It requires a nonzero authorization provenance reference, binds that reference and an opaque policy epoch through speculation and retirement, prevents continuations from inheriting root provenance, and projects the exact retired provenance into vCML evidence while retaining the earlier parent, generation, SEAL, anti-wrap, and causal-commit boundaries.

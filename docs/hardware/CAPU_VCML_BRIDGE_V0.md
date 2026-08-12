# CaPU ↔ vCML Bridge v0

Status: experimental semantic/hardware bridge. Current hardware step: **CaPU Core v0.7 authorized root / epoch anchor**.

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

## Architectural split

Each speculative STORE carries:

```text
address
data
ctag                    : 16 bits
transition_id           : implementation-width reference
parent_ref              : implementation-width reference
explicit_new_cause      : 1 bit root intent
buffered_root_authorized: 1 bit root-qualified admission evidence
```

The input `root_authorized` sideband is sampled only for an explicit root. Continuations never acquire root authorization evidence even if that input is spuriously high.

The full vCML-style record remains a software projection after retirement. Exact local parent matching uses `transition_id / parent_ref`; `LHINT` remains only a hint.

## Retained layers

### v0.3 local CTAG validation

Strict STORE admission still requires:

```text
metadata_valid
&& DOM != RESERVED(15)
&& CLASS == WRITE(2)
```

### v0.4 committed SEAL state

`capu_seal_controller` maintains volatile `sealed_chain` state. A sealed chain blocks automatic continuation independently of otherwise-correct parent or generation metadata.

### v0.5 committed causal head

`capu_causal_head_controller` retains exact committed transition identity:

```text
causal_head_valid
causal_head_transition_id
```

An ordinary continuation must name that exact committed head. `TRANSITION_ID_WIDTH == PARENT_REF_WIDTH` is required so the comparison is not silently truncated or extended.

### v0.6 committed causal generation

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

A new local epoch starts at `GEN=0`.

## v0.7 authorized root boundary

v0.6 deliberately left one trust decision outside the hardware model: any caller that asserted `explicit_new_cause=1` could attempt a fresh root if the structural fields were valid.

v0.7 separates **root intent** from **root authorization**:

```text
explicit_new_cause : caller asks to start a fresh chain
root_authorized    : trusted upstream boundary permits that root
```

A fresh root is admitted only when all conditions agree:

```text
EXPLICIT_NEW_CAUSE_ADMISSION
    => explicit_new_cause
    && root_authorized
    && parent_ref == 0
    && GEN == 0
    && CTAG_SEMANTIC_ACCEPT
    && gate_allow
    && execute_ok
```

Therefore:

```text
explicit_new_cause=1
root_authorized=0
    => reject before speculation
```

`root_authorized` is intentionally a **trusted upstream authorization signal**, not a cryptographic signature, authenticated principal, capability token, freshness proof, or proof that the upstream policy itself is correct.

### Root authorization evidence binding

When an authorized root enters speculation, the root-qualified fact is latched:

```text
buffered_root_authorized = explicit_new_cause && root_authorized
```

On successful retirement it becomes:

```text
retired_root_authorized
```

The field is meaningful only when qualified by the retirement pulse:

```text
vcml_event_valid == memory_write_enable
```

A visible structural root retirement (`parent_ref=0, GEN=0`) must carry:

```text
VISIBLE_ROOT_COMMIT => retired_root_authorized == 1
```

A continuation retirement carries `retired_root_authorized=0`.

### Flush semantics

Authorization admission is speculative until commit. A root may be authorized and buffered, then flushed:

```text
old committed head/gen/seal
      ↓
authorized root admitted
      ↓
flush
      ↓
NO vcml_event
NO memory write
old head/gen/seal unchanged
last retired authorization field unchanged
```

The last retired metadata registers are historical fields; they are not event pulses. Their current relevance is always qualified by `vcml_event_valid`.

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

Explicit root:

```text
issue_valid
&& gate_allow
&& execute_ok
&& CTAG_SEMANTIC_ACCEPT
&& explicit_new_cause
&& root_authorized
&& parent_ref == 0
&& GEN == 0
&& !buffer_valid
```

The root authorization sideband is not required for ordinary continuation.

## Retirement boundary

A memory-visible write still requires:

```text
buffer_valid
&& causal_valid
&& buffered_ctag_valid
&& commit_request
&& !flush
```

Primary v0.7 invariants:

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
    && PARENT_REF == 0
    && GEN == 0

UNAUTHORIZED_EXPLICIT_ROOT
    => NO_ROOT_ADMISSION

VISIBLE_ROOT_COMMIT
    => RETIRED_ROOT_AUTHORIZED

SEALED_CHAIN && !EXPLICIT_NEW_CAUSE
    => NO_AUTOMATIC_CHILD_ADMISSION

GEN_EXHAUSTED && !EXPLICIT_NEW_CAUSE
    => NO_AUTOMATIC_CHILD_ADMISSION

FLUSH
    => NO_RETIREMENT_EVENT
    && COMMITTED_HEAD_GEN_SEAL_UNCHANGED
    && LAST_RETIRED_ROOT_AUTH_FIELD_UNCHANGED

VISIBLE_WRITE
    => exact CTAG / transition_id / parent_ref / root-authorization binding
```

## vCML software projection

`tools/vcml_bridge.py` projects the retired hardware event into a vCML-style record and now includes:

```json
{
  "ctag": 16896,
  "parent_cause": null,
  "root_authorized": true,
  "integrity": "sha256:..."
}
```

The integrity hash covers `root_authorized`, so post-projection tampering with that field is detectable. This only protects the emitted record bytes; it does not prove the truth or origin of the upstream authorization decision.

## Deterministic RTL verification

The v0.7 trajectory covers:

- headless continuation rejection;
- invalid CTAG root rejection;
- malformed root parent rejection;
- malformed root GEN rejection;
- unauthorized initial root rejection;
- authorized initial root commit with retirement authorization evidence;
- valid continuation with `root_authorized=0`;
- stale/skipped GEN and wrong-parent rejection;
- continuation retirement carrying no root authorization evidence;
- SEAL blocking an otherwise-correct continuation;
- unauthorized replacement root under seal rejection;
- authorized root under seal followed by flush with no event and unchanged committed state;
- committed authorized replacement root;
- continuation progression through GEN `1..F` with no root authorization bit;
- automatic `F -> 0` rejection;
- unauthorized root rejection after GEN exhaustion;
- authorized root commit after GEN exhaustion establishing a fresh local epoch.

Expected marker:

`CAPU_VCML_BRIDGE_V07_RTL_PASS`

## Formal verification envelope

The v0.7 safety task explores arbitrary bounded inputs for **36 formal CPU sampling steps**. The cover task explores **40 steps**.

Reduced-width formal instance:

```text
ADDR_WIDTH               = 4
DATA_WIDTH               = 8
CTAG_WIDTH               = 16
TRANSITION_ID_WIDTH      = 8
PARENT_REF_WIDTH         = 8
GEN_WIDTH                = 4
ROOT_AUTHORIZATION_WIDTH = 1
REQUIRE_WRITE_CLASS      = true
```

Safety checks include the retained CTAG, SEAL, exact-parent, GEN-successor, anti-wrap and retirement-binding invariants plus:

```text
ACCEPTED_EXPLICIT_ROOT => root_authorized
UNAUTHORIZED_EXPLICIT_ROOT => rejected
VISIBLE_ROOT_COMMIT => retired_root_authorized
FLUSH => no retirement event and no mutation of last retired authorization field
```

The cover task requires authorized-root success, unauthorized-root rejection, valid normal continuation, authorized root under a sealed chain, and an authorized root path after generation exhaustion to be reachable rather than vacuous.

CI is fail-closed: formal evidence is sealed only after literal `DONE (PASS)` for both safety and cover and absence of `DONE (ERROR)`.

## Non-goals / claim boundary

v0.7 does **not** claim:

- cryptographic root authorization;
- identity or authenticity of the component driving `root_authorized`;
- freshness, nonce, capability, signature, key, or certificate semantics for root authorization;
- correctness of the upstream authorization policy;
- cryptographic lineage or authenticated parent identity;
- globally unique or collision-resistant `transition_id`;
- `LHINT` identity verification;
- persistent head/GEN/SEAL/authorization state across reset or power loss;
- global or persistent replay protection;
- protection against replay across separately authorized fresh roots;
- a complete CPU/ISA/cache/coherence proof;
- a parametric proof across every configured width.

The narrow v0.7 result is: CaPU now distinguishes **requesting a new causal root** from **being allowed to establish one**, rejects unauthorized roots before speculation, and preserves the accepted root authorization fact through retirement and into the vCML-style evidence projection while retaining the v0.6 parent, generation, SEAL, anti-wrap and causal-commit boundaries.

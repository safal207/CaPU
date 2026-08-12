# CaPU ↔ vCML Bridge v0

Status: experimental semantic/hardware bridge. Current hardware step: **CaPU Core v0.6 committed causal generation + anti-wrap enforcement**.

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
ctag               : 16 bits
transition_id      : implementation-width reference
parent_ref         : implementation-width reference
explicit_new_cause : 1 bit admission intent
```

The full vCML-style record remains a software projection after retirement. Exact local parent matching uses `transition_id / parent_ref`; `LHINT` remains only a hint.

## Retained layers

### v0.3 local CTAG validation

Strict STORE admission still requires:

```text
metadata_valid
&& DOM != RESERVED(15)
&& CLASS == WRITE(2)
```

The CTAG validator only decodes `GEN`; it does not authenticate it. v0.6 interprets `GEN` in the outer causal admission policy.

### v0.4 committed SEAL state

`capu_seal_controller` maintains volatile `sealed_chain` state.

```text
normal commit, SEAL=1      => sealed_chain = 1
normal commit, SEAL=0      => cannot weaken an existing seal
explicit root commit, 0    => sealed_chain = 0
explicit root commit, 1    => sealed_chain = 1
speculative root + flush   => previous committed seal remains
```

A sealed chain blocks automatic continuation independently of otherwise-correct parent or generation metadata.

### v0.5 committed causal head

`capu_causal_head_controller` retains exact committed transition identity:

```text
causal_head_valid
causal_head_transition_id
```

An ordinary continuation must name that exact committed head. `TRANSITION_ID_WIDTH == PARENT_REF_WIDTH` is required so the comparison is not silently truncated or extended.

## v0.6 committed causal generation

v0.6 extends the committed head with:

```text
causal_head_gen : 4 bits
```

Only successful retirement updates `causal_head_transition_id` and `causal_head_gen`. Speculative admission and `flush` cannot mutate either field.

### Explicit root policy

A fresh local causal chain starts structurally at:

```text
explicit_new_cause == 1
parent_ref == 0
GEN == 0
```

So:

```text
EXPLICIT_NEW_CAUSE_ADMISSION
    => PARENT_REF == 0
    && GEN == 0
```

This is a local fail-closed convention, not proof that the root is semantically authorized. `explicit_new_cause` remains unauthenticated in v0.6.

### Normal continuation policy

An automatic child is admitted only if all committed continuity checks agree:

```text
NORMAL_CONTINUATION_ADMISSION
    => causal_head_valid
    && !sealed_chain
    && !generation_exhausted
    && parent_ref == causal_head_transition_id
    && GEN == causal_head_gen + 1
```

Thus exact parent identity is necessary but no longer sufficient: generation must also advance by exactly one.

The following fail before speculation:

```text
same parent, stale GEN       => reject
same parent, skipped GEN     => reject
next GEN, wrong parent       => reject
sealed chain, exact child    => reject
```

### Fail-closed 4-bit exhaustion

A 4-bit counter must not silently wrap.

```text
causal_head_gen == 4'hF
    => generation_exhausted = 1
    => no automatic continuation
```

In particular:

```text
GEN F -> GEN 0 automatic child
    => reject
```

The only local structural escape is a new explicit root with `parent_ref=0, GEN=0`.

A root plus generations `1..F` therefore gives at most 16 committed generation values in one local chain segment before a new explicit root is required. SEAL may close the chain earlier.

This is intentionally fail-closed rather than modulo arithmetic: an old generation value is never made current merely because the 4-bit field wrapped.

## Commit versus speculation

Committed causal state is:

```text
causal_head_valid
causal_head_transition_id
causal_head_gen
sealed_chain
```

A speculative explicit root may be flushed:

```text
old head/gen/seal
    ↓
explicit root admitted
    ↓
flush
    ↓
old head/gen/seal unchanged
```

Only commit replaces the committed causal state.

Reset clears this experimental volatile state. v0.6 does not claim persistence across reset or power loss.

## STORE admission and retirement

A STORE may enter speculation only when:

```text
issue_valid
&& gate_allow
&& execute_ok
&& CTAG_SEMANTIC_ACCEPT
&& CAUSAL_PARENT_AND_GEN_POLICY_ACCEPT
&& !buffer_valid
```

A memory-visible write still requires the existing causal retirement boundary:

```text
buffer_valid
&& causal_valid
&& buffered_ctag_valid
&& commit_request
&& !flush
```

Primary invariants:

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
    => PARENT_REF == 0
    && GEN == 0

SEALED_CHAIN && !EXPLICIT_NEW_CAUSE
    => NO_AUTOMATIC_CHILD_ADMISSION

GEN_EXHAUSTED && !EXPLICIT_NEW_CAUSE
    => NO_AUTOMATIC_CHILD_ADMISSION

FLUSH
    => COMMITTED_HEAD_GEN_AND_SEAL_UNCHANGED

VISIBLE_WRITE
    => RETIRED_CTAG == COMMITTED_CTAG
    && RETIRED_TRANSITION_ID == COMMITTED_TRANSITION_ID
    && RETIRED_PARENT_REF == COMMITTED_PARENT_REF

VCML_EVENT_VALID == MEMORY_VISIBLE_WRITE
```

## Deterministic RTL verification

The v0.6 RTL trajectory covers:

- headless continuation rejection;
- invalid CTAG rejection;
- explicit root with nonzero parent rejection;
- explicit root with nonzero GEN rejection;
- first root commit establishing `head + GEN=0`;
- exact-parent `GEN+1` admission;
- flush preserving committed head and GEN;
- stale GEN rejection;
- skipped GEN rejection;
- wrong-parent rejection even with correct GEN;
- committed GEN progression;
- SEAL blocking an otherwise-correct parent+GEN child;
- explicit root under seal and flush preserving old head/GEN/seal;
- committed replacement root resetting local GEN to zero;
- deterministic progression through GEN `1..F`;
- `GEN=F` exhaustion;
- forbidden `F -> 0` automatic wrap;
- explicit root admission after exhaustion followed by flush preserving the exhausted committed state.

Marker:

`CAPU_VCML_BRIDGE_V06_RTL_PASS`

## Formal verification envelope

The v0.6 safety task explores arbitrary bounded inputs for **36 formal CPU sampling steps**. The cover task explores **40 steps** so the complete `GEN=0 -> ... -> F -> rejected wrap` path is reachable rather than merely asserted abstractly.

Reduced-width formal instance:

```text
ADDR_WIDTH          = 4
DATA_WIDTH          = 8
CTAG_WIDTH          = 16
TRANSITION_ID_WIDTH = 8
PARENT_REF_WIDTH    = 8
GEN_WIDTH           = 4
REQUIRE_WRITE_CLASS = true
```

The safety proof checks exact retirement metadata binding, CTAG acceptance, exact committed-parent matching, strict GEN successor policy, root `GEN=0`, SEAL blocking, generation exhaustion, and preservation of committed head/GEN/seal across flush.

The cover task requires three non-vacuity classes to be reachable:

1. root followed by a valid automatic continuation;
2. explicit root path while a committed sealed state exists;
3. committed progression to `GEN=F` followed by a rejected automatic continuation.

CI is fail-closed: evidence is sealed only after literal `DONE (PASS)` for both safety and cover and absence of `DONE (ERROR)`.

## Non-goals / claim boundary

v0.6 does **not** claim:

- cryptographic lineage or authenticated parent identity;
- globally unique or collision-resistant `transition_id`;
- authentication of `explicit_new_cause`;
- semantic authorization of `parent_ref==0, GEN==0` as a real-world root;
- `LHINT` identity verification;
- persistent head/GEN/SEAL state across reset or power loss;
- a global or persistent replay counter;
- protection against replay across a separately authorized explicit-root reset;
- a complete CPU/ISA/cache/coherence proof;
- a parametric proof across every configured width.

The narrow v0.6 result is: CaPU now binds ordinary continuation to both the exact last committed causal transition and the exact next local CTAG generation, and refuses automatic 4-bit generation wrap. This provides a mechanically checkable local stale-generation/anti-wrap boundary while preserving the existing causal commit, SEAL, retirement-binding, and vCML event semantics.

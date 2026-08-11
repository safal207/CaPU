# CaPU ↔ vCML Bridge v0

Status: experimental semantic/hardware bridge. Current hardware step: **CaPU Core v0.5 committed causal-head parent enforcement**.

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

CTAG is compact causal metadata, not cryptography. `LHINT` is not parent identity, and `SEAL` is not a signature or proof of authorization.

## Architectural split

CaPU carries a compact projection with each speculative STORE:

```text
address
data
ctag               : 16 bits
transition_id      : implementation-width reference
parent_ref         : implementation-width reference
explicit_new_cause : 1 bit admission intent
```

The full vCML-style record remains a software projection after retirement. Exact local parent matching uses `transition_id` / `parent_ref`; the 3-bit `LHINT` remains only a hint.

## v0.3 local CTAG validation retained

Strict STORE admission requires:

```text
metadata_valid
&& DOM != RESERVED(15)
&& CLASS == WRITE(2)
```

`GEN` remains opaque at this layer and `LHINT` is not recomputed.

## v0.4 SEAL state retained

`capu_seal_controller` maintains the volatile committed continuation-control bit `sealed_chain`.

```text
normal commit, SEAL=1      => sealed_chain = 1
normal commit, SEAL=0      => does not weaken an existing seal
explicit root commit, 0    => sealed_chain = 0
explicit root commit, 1    => sealed_chain = 1
speculative root + flush   => previous committed seal remains
```

A sealed chain blocks an automatic child even if that candidate otherwise carries valid CTAG metadata.

## v0.5 committed causal head

`capu_causal_head_controller` adds minimal committed causal identity state:

```text
causal_head_valid
causal_head_transition_id
```

Only retirement changes this state:

```text
COMMIT transition T
    => causal_head_valid = 1
    => causal_head_transition_id = T
```

Speculative admission and `flush` cannot update the committed head.

### Normal continuation policy

An ordinary continuation is admitted only if a committed head exists, the chain is not sealed, and the candidate names that exact committed transition:

```text
NORMAL_CONTINUATION_ADMISSION
    => causal_head_valid
    && !sealed_chain
    && parent_ref == causal_head_transition_id
```

Thus a candidate with a stale, missing, or otherwise unequal `parent_ref` fails closed before the speculative STORE buffer.

A sealed chain blocks automatic continuation independently of parent equality:

```text
sealed_chain && !explicit_new_cause
    => NO_AUTOMATIC_CHILD_ADMISSION
```

### Explicit root policy

v0.5 intentionally uses a narrow root rule:

```text
explicit_new_cause == 1
    => parent_ref == 0
```

This allows a fresh root to be attempted when no head exists or when a previous chain is sealed. A speculative root does not replace the committed head or seal; only its successful commit does.

Therefore:

```text
explicit root admitted -> flush
    => old head unchanged
    => old seal unchanged

explicit root commits as T
    => causal_head = T
    => seal state becomes that root's SEAL policy
```

`explicit_new_cause` is an experimental admission signal, not authenticated authority. `parent_ref == 0` is a local structural root convention, not proof that the root is semantically legitimate.

## STORE admission and retirement

A STORE may enter speculation only when the local CTAG and parent policies accept it:

```text
issue_valid
&& gate_allow
&& execute_ok
&& CTAG_SEMANTIC_ACCEPT
&& PARENT_POLICY_ACCEPT
&& !buffer_valid
```

where:

```text
PARENT_POLICY_ACCEPT =
    explicit_new_cause
      ? (parent_ref == 0)
      : (causal_head_valid
         && !sealed_chain
         && parent_ref == causal_head_transition_id)
```

A memory-visible write still requires the causal commit boundary over the exact buffered metadata.

Primary invariants:

```text
MEMORY_VISIBLE_WRITE
    => VALID_CAUSAL_COMMIT
    && VALIDATOR_ACCEPTED_CTAG

NORMAL_CONTINUATION_ADMISSION
    => HEAD_VALID
    && !SEALED_CHAIN
    && PARENT_REF == COMMITTED_HEAD

EXPLICIT_NEW_CAUSE_ADMISSION
    => PARENT_REF == 0

SEALED_CHAIN && !EXPLICIT_NEW_CAUSE
    => NO_AUTOMATIC_CHILD_ADMISSION

FLUSH
    => COMMITTED_HEAD_AND_SEAL_UNCHANGED

VISIBLE_WRITE
    => RETIRED_CTAG == COMMITTED_CTAG
    && RETIRED_TRANSITION_ID == COMMITTED_TRANSITION_ID
    && RETIRED_PARENT_REF == COMMITTED_PARENT_REF

VCML_EVENT_VALID == MEMORY_VISIBLE_WRITE
```

The current v0.5 implementation requires `TRANSITION_ID_WIDTH == PARENT_REF_WIDTH` so the hardware comparison is exact and does not rely on implicit truncation or extension.

## Executable verification

The deterministic RTL trajectory covers:

- headless automatic child rejection;
- invalid CTAG rejection;
- malformed explicit root (`parent_ref != 0`) rejection;
- first explicit root commit establishing the causal head;
- exact-parent continuation admission;
- speculative continuation flush preserving the committed head;
- wrong-parent continuation rejection before speculation;
- sealed exact-parent commit establishing both new head and seal;
- exact-parent child rejected while sealed;
- explicit root under seal followed by flush preserving old head and seal;
- committed explicit root replacing the head and opening a fresh chain;
- continuation from that fresh head.

Marker: `CAPU_VCML_BRIDGE_V05_RTL_PASS`.

## Formal verification envelope

The v0.5 safety task explores arbitrary bounded inputs for **28 formal CPU sampling steps**. A separate cover task explores **16 steps**.

The reduced-width formal instance is:

```text
ADDR_WIDTH          = 4
DATA_WIDTH          = 8
CTAG_WIDTH          = 16
TRANSITION_ID_WIDTH = 8
PARENT_REF_WIDTH    = 8
REQUIRE_WRITE_CLASS = true
```

The safety proof checks the exact retirement metadata binding, local CTAG rules, exact committed-parent admission rule, root rule, sealed-chain rule, and preservation of committed head/seal across flush.

The reachability task separately demonstrates that both policy paths are non-vacuous: a committed root followed by a valid normal continuation, and an explicit root path reachable while a committed sealed state exists.

CI is fail-closed: formal evidence is sealed only after literal `DONE (PASS)` for both safety and cover and no `DONE (ERROR)`.

## Non-goals / claim boundary

v0.5 does **not** claim:

- cryptographic lineage or authenticated parent identity;
- that `transition_id` is globally collision-resistant;
- `LHINT` identity verification;
- validated `GEN` history;
- authentication of `explicit_new_cause`;
- semantic proof that `parent_ref == 0` is an authorized root;
- persistent causal-head or seal state across reset/power loss;
- a complete CPU/ISA/cache/coherence model;
- a parametric proof across every configured width.

The narrow v0.5 result is: CaPU now maintains the identity of the last committed causal transition and uses exact local `parent_ref` equality to reject stale/wrong automatic continuations before speculation, while preserving the existing CTAG, SEAL, causal-commit, retirement-binding, and vCML event boundaries.

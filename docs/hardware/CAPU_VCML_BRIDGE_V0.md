# CaPU ↔ vCML Bridge v0

Status: experimental semantic/hardware bridge. Current hardware step: **CaPU Core v0.4 stateful SEAL continuation control**.

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
ctag             : 16 bits
transition_id    : implementation-width reference
parent_ref       : implementation-width reference
explicit_new_cause : 1 bit admission intent
```

The full vCML-style record remains a software projection after retirement. Exact lineage continues to use `transition_id` / `parent_ref`; the 3-bit `LHINT` is only a hint.

## v0.3 local CTAG validation retained

Strict STORE admission still requires:

```text
metadata_valid
&& DOM != RESERVED(15)
&& CLASS == WRITE(2)
```

`GEN` remains an opaque 4-bit epoch at this layer. `LHINT` is not recomputed. A valid `SEAL=1` CTAG may commit the current WRITE; v0.4 gives that bit stateful meaning only for later continuation.

## v0.4 stateful SEAL controller

`capu_seal_controller` adds one architectural continuation-control state bit:

```text
sealed_chain
```

A normal committed transition with `CTAG.SEAL=1` sets `sealed_chain=1`. While that state is active, an ordinary child/continuation cannot enter the speculative STORE buffer.

```text
sealed_chain && !explicit_new_cause
    => NO_AUTOMATIC_CHILD_ADMISSION
```

A caller may request an explicit new cause/root boundary with `explicit_new_cause=1`. This permits the candidate to enter speculation even while the previous chain is sealed, but **does not clear the committed seal at admission time**.

This distinction is intentional. A speculative new cause may be flushed. Clearing `sealed_chain` merely because such a candidate was issued would allow a flushed candidate to reopen a previously committed sealed chain.

Therefore the state changes only at retirement:

```text
committed normal STORE, SEAL=0
    => existing open/sealed state is not weakened

committed normal STORE, SEAL=1
    => sealed_chain = 1

committed explicit new cause, SEAL=0
    => sealed_chain = 0   // fresh open chain

committed explicit new cause, SEAL=1
    => sealed_chain = 1   // fresh chain immediately sealed

flushed explicit new cause
    => previous committed sealed_chain remains unchanged
```

Reset clears the experimental `sealed_chain` latch in v0.4. This is not persistent causal state across reset/power loss.

## STORE admission and retirement

A STORE may enter speculation only when:

```text
issue_valid
&& gate_allow
&& execute_ok
&& CTAG_SEMANTIC_ACCEPT
&& !buffer_valid
&& (!sealed_chain || explicit_new_cause)
```

A memory-visible write still requires the existing causal commit boundary over accepted metadata.

Primary invariants:

```text
MEMORY_VISIBLE_WRITE
    => VALID_CAUSAL_COMMIT
    && VALIDATOR_ACCEPTED_CTAG

SEALED_CHAIN && !EXPLICIT_NEW_CAUSE
    => NO_AUTOMATIC_CHILD_ADMISSION

FLUSHED_EXPLICIT_NEW_CAUSE
    => PREVIOUS_COMMITTED_SEAL_REMAINS

VISIBLE_WRITE
    => RETIRED_CTAG == COMMITTED_CTAG
    && RETIRED_TRANSITION_ID == COMMITTED_TRANSITION_ID
    && RETIRED_PARENT_REF == COMMITTED_PARENT_REF

VCML_EVENT_VALID == MEMORY_VISIBLE_WRITE
```

The software bridge continues to map non-zero `parent_ref` deterministically to `parent_cause = capu-transition:<parent_ref>`; zero remains `null` and is not automatically declared a valid root by hardware.

## Executable verification

The deterministic RTL trajectory covers:

- invalid CTAG rejection;
- unsealed commit followed by ordinary continuation;
- sealed commit followed by blocked automatic child;
- explicit new-cause speculation under an active seal;
- flush of that speculative new cause preserving the old committed seal;
- committed explicit new cause with `SEAL=0` opening a fresh chain;
- ordinary continuation on the fresh chain.

Marker: `CAPU_VCML_BRIDGE_V04_RTL_PASS`.

## Formal verification envelope

The v0.4 safety task explores arbitrary bounded inputs for **24 formal CPU sampling steps**. A separate cover task explores **12 steps**.

The current reduced-width instance is:

```text
ADDR_WIDTH          = 4
DATA_WIDTH          = 8
CTAG_WIDTH          = 16
TRANSITION_ID_WIDTH = 8
PARENT_REF_WIDTH    = 8
REQUIRE_WRITE_CLASS = true
```

The safety proof checks the STORE/CTAG metadata binding plus the sealed-chain admission rule. The reachability task separately covers both an ordinary continuation after an unsealed commit and an explicit new-cause admission while a prior committed seal remains active.

CI is fail-closed: formal evidence is sealed only after literal `DONE (PASS)` for both safety and cover and no `DONE (ERROR)`.

## Non-goals / claim boundary

v0.4 does **not** claim:

- cryptographic lineage or authorization;
- `LHINT` identity verification;
- validated `GEN` history;
- that `explicit_new_cause` itself is authenticated by hardware;
- a proof that `parent_ref == 0` is semantically a legitimate root;
- persistent `sealed_chain` across reset/power loss;
- a complete CPU/ISA/cache/coherence model;
- a parametric proof across all configured widths.

The narrow v0.4 result is: CaPU now keeps minimal state about whether a committed causal chain is sealed, blocks implicit continuation from that state, and requires an explicit new-cause boundary to begin another speculative chain while preserving the prior seal until the replacement cause actually commits.

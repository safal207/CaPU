# CaPU ↔ vCML Bridge v0

Status: experimental semantic/hardware bridge. Current hardware step: **CaPU Core v0.3 local CTAG semantic validation**.

This layer connects the CaPU causal STORE retirement boundary to the Causal Memory Layer (CML) / vCML semantic model without embedding a full causal journal in RTL.

## Source semantics

The bridge follows the vCML / CTAG semantics from `safal207/Causal-Memory-Layer` pinned at:

`1635804f127b7840dca0cd2679c0f001552b7b10`

Relevant upstream definitions:

- `vcml/FORMAT.md` — causal record semantics
- `vcml/CTAG.md` — canonical 16-bit CTAG layout
- `cml/ctag.py` — reference CTAG implementation

CTAG layout:

```text
b15..b12  DOM    4 bits
b11..b8   CLASS  4 bits
b7..b4    GEN    4 bits
b3..b1    LHINT  3 bits
b0        SEAL   1 bit
```

CTAG is a compact semantic marker. It is not cryptography, a signature, or proof of parent identity. In particular, the 3-bit `LHINT` MUST NOT be treated as a unique lineage identifier.

## Architectural split

CaPU hardware carries only a compact causal projection with a speculative STORE:

```text
address
data
ctag             : 16 bits
transition_id    : implementation-width reference
parent_ref       : implementation-width reference
```

The full vCML-style causal record is emitted in software after retirement:

```text
actor
action
object
permitted_by
parent_cause
timestamp
ctag
integrity
```

This preserves the separation of responsibilities:

- **CaPU** controls when an effect may become externally visible.
- **CTAG validator** checks only narrow, local STORE semantics before speculative admission.
- **CMC metadata** carries causal identity across the retirement boundary.
- **vCML bridge** expands the retired hardware event into an append-only causal record.
- **CML/vCML audit** reasons about richer causal coherence after the fact.

## v0.3 local CTAG validator

`capu_ctag_validator` is combinational and intentionally small. In the normal strict STORE configuration it accepts a CTAG only when:

```text
metadata_valid
&& DOM != RESERVED(15)
&& CLASS == WRITE(2)
```

`CLASS=NONE(0)` is therefore rejected, as are READ/EXEC/other non-WRITE classes on the normal STORE path. `REQUIRE_WRITE_CLASS` is an explicit module parameter for experiments that use a different boundary; strict STORE mode is the default.

The validator does **not** pretend to verify semantics that cannot be established from one local 16-bit value:

- `GEN` is carried as an opaque 4-bit epoch; v0.3 does not prove epoch history.
- `LHINT` is carried as an opaque 3-bit lineage hint; v0.3 does not recompute it or use it as parent identity.
- `SEAL=1` does not reject the current valid WRITE. It is continuation-control metadata: downstream logic must not interpret a sealed record as permission to auto-continue a causal chain.

`store_ctag_valid` remains the upstream metadata-present/accepted signal. Local semantic acceptance is the conjunction of that signal and the validator rules above.

## STORE admission and retirement

`capu_vcml_store_buffer` wraps the existing one-entry `capu_store_buffer`.

A STORE may enter the speculative buffer only when:

```text
issue_valid
&& gate_allow
&& execute_ok
&& CTAG_SEMANTIC_ACCEPT
&& !buffer_valid
```

A memory-visible write may retire only when the existing causal commit condition succeeds for an entry that was admitted with validator-accepted CTAG metadata.

### INV-CML-001

```text
MEMORY_VISIBLE_WRITE
    => VALID_CAUSAL_COMMIT
    && VALIDATOR_ACCEPTED_CTAG
```

### INV-CML-002

```text
BUFFERED_CTAG_VALID
    => CTAG.DOM != RESERVED
    && CTAG.CLASS == WRITE
```

### INV-CML-003

For every emitted hardware vCML bridge event, the exact metadata is bound to the same retirement:

```text
retired.ctag          == committed.ctag
retired.transition_id == committed.transition_id
retired.parent_ref    == committed.parent_ref
```

The software bridge maps `parent_ref` deterministically to:

```text
parent_cause = capu-transition:<parent_ref>
```

except `parent_ref == 0`, which is represented as `parent_cause = null` and must be justified by the software caller as an explicit root/gap case.

## Formal verification envelope

The formal harness uses a global formal processor sampling clock and a ghost commit witness to bind a visible STORE to the exact speculative entry authorized at the preceding sampling edge.

The safety task explores arbitrary bounded environment inputs for 20 formal CPU sampling steps and checks:

```text
MEMORY_VISIBLE_WRITE
    => VALID_CAUSAL_COMMIT
    && VALIDATOR_ACCEPTED_CTAG

BUFFERED_CTAG_VALID
    => CTAG.DOM != RESERVED
    && CTAG.CLASS == WRITE

VCML_EVENT_VALID == MEMORY_VISIBLE_WRITE

VISIBLE_WRITE
    => RETIRED_CTAG == COMMITTED_CTAG
    && RETIRED_TRANSITION_ID == COMMITTED_TRANSITION_ID
    && RETIRED_PARENT_REF == COMMITTED_PARENT_REF
```

A separate depth-8 cover task must find a reachable trajectory in which a validator-accepted WRITE CTAG participates in a causal commit that produces both `memory_write_enable` and `vcml_event_valid`. This prevents a safety PASS from being accepted merely because retirement is unreachable.

The current formal instance is intentionally reduced for solver tractability while retaining the canonical CTAG width:

```text
ADDR_WIDTH          = 4
DATA_WIDTH          = 8
CTAG_WIDTH          = 16
TRANSITION_ID_WIDTH = 8
PARENT_REF_WIDTH    = 8
REQUIRE_WRITE_CLASS = true
```

Therefore the formal result is evidence for this explicit finite-width instance. It is not a parametric proof for every width configuration and does not by itself prove the default 64-bit transition/parent reference configuration.

The CI is fail-closed: a proof artifact is sealed only after the safety run reports `DONE (PASS)` and the non-vacuity cover run also reports `DONE (PASS)`. Solver logs and formal inputs are SHA-256 sealed into the evidence artifact.

## Non-goals

v0.3 does **not** claim:

- that CTAG proves lineage identity;
- that a 16-bit CTAG is cryptographic evidence;
- that hardware verifies `LHINT` against `parent_ref`;
- that hardware proves `GEN` history or epoch correctness;
- that `SEAL` is a signature or authorization proof;
- that hardware generates a complete vCML journal;
- persistent causal memory across reset/power loss;
- a complete CPU, ISA, cache-coherence, or persistent-memory model;
- a parametric proof covering every configured field width.

The narrow v0.3 claim is that CaPU can reject a small class of locally invalid STORE CTAGs before speculation, carry accepted causal metadata through retirement, and expose a deterministic event for the richer software vCML/CML layer.

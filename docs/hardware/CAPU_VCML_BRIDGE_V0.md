# CaPU ↔ vCML Bridge v0

Status: experimental semantic/hardware bridge.

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
- **CMC metadata** carries compact causal identity across the retirement boundary.
- **vCML bridge** expands the retired hardware event into an append-only causal record.
- **CML/vCML audit** reasons about causal coherence after the fact.

## v0 hardware contract

`capu_vcml_store_buffer` wraps the existing one-entry `capu_store_buffer`.

A STORE may enter the speculative buffer only when:

```text
issue_valid
&& gate_allow
&& execute_ok
&& store_ctag_valid
&& !buffer_valid
```

The wrapper does not infer CTAG validity from CTAG bit values. `store_ctag_valid` is an explicit acceptance signal supplied by the upstream CMC / metadata-validation path.

A memory-visible write may retire only when the existing causal commit condition succeeds for an entry that was accepted with valid CTAG metadata.

### INV-CML-001

```text
MEMORY_VISIBLE_WRITE
    => VALID_CAUSAL_COMMIT
    && VALID_CTAG_METADATA
```

### INV-CML-002

For every emitted vCML bridge event:

```text
retired.parent_ref
    == bridge_input.parent_ref
```

and the software bridge maps it deterministically to:

```text
parent_cause = capu-transition:<parent_ref>
```

except `parent_ref == 0`, which is represented as `parent_cause = null` and must be justified by the software caller as an explicit root/gap case.

## Formal verification envelope

The formal harness uses the formal global clock directly as the processor sampling clock and a ghost commit witness to bind a visible STORE to the exact speculative entry authorized at the preceding sampling edge.

The safety task checks arbitrary environment inputs for 20 formal CPU sampling steps and requires:

```text
MEMORY_VISIBLE_WRITE
    => VALID_CAUSAL_COMMIT
    && VALID_CTAG_METADATA

VCML_EVENT_VALID == MEMORY_VISIBLE_WRITE

VISIBLE_WRITE
    => RETIRED_CTAG == COMMITTED_CTAG
    && RETIRED_TRANSITION_ID == COMMITTED_TRANSITION_ID
    && RETIRED_PARENT_REF == COMMITTED_PARENT_REF
```

A separate cover task must also find a reachable trajectory in which a valid CTAG-bearing causal commit produces both `memory_write_enable` and `vcml_event_valid`. This prevents a safety result from being accepted solely because retirement is unreachable.

The current formal instance is intentionally reduced for solver tractability while retaining the canonical CTAG width:

```text
ADDR_WIDTH          = 4
DATA_WIDTH          = 8
CTAG_WIDTH          = 16
TRANSITION_ID_WIDTH = 8
PARENT_REF_WIDTH    = 8
```

Therefore the formal result is evidence for this explicit finite-width instance. It is not a parametric proof for every width configuration and does not by itself prove the default 64-bit transition/parent reference configuration.

The CI is fail-closed: a proof artifact is sealed only after the safety run reports `DONE (PASS)` and the non-vacuity cover run also reports `DONE (PASS)`. Solver logs and formal inputs are SHA-256 sealed into the evidence artifact.

## Non-goals

v0 does **not** claim:

- that CTAG proves lineage identity;
- that a 16-bit CTAG is cryptographic evidence;
- that hardware generates a complete vCML journal;
- persistent causal memory across reset/power loss;
- a complete CPU, ISA, cache-coherence, or persistent-memory model;
- equivalence between `LHINT` and `parent_cause`;
- a parametric proof covering every configured field width.

The narrow claim is that CaPU can carry a compact, CML-compatible causal projection through speculative STORE retirement and emit enough deterministic metadata for software to construct a vCML-style causal record.
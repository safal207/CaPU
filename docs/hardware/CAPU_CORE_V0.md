# CaPU Core v0

## Purpose

CaPU Core v0 is a minimal hardware-oriented execution model for proving one architectural rule:

> **No externally visible state change before a valid causal commit.**

The core is intentionally small. It is not a performance-oriented CPU. Its purpose is to make the causal boundary between speculative work and architectural state explicit, testable, and eventually implementable in RTL.

## Pipeline

```text
FETCH
  ↓
DECODE
  ↓
GATE
  ↓
EXECUTE (speculative)
  ↓
CAUSAL VALIDATION
  ↓
COMMIT
  ↓
ARCHITECTURAL STATE
```

A rejected or invalid transition never reaches architectural state.

## Architectural state vs speculative state

`architectural_state` is the externally visible state of the core. `speculative_state` may change during execution, but it is not observable as committed state until causal validation succeeds.

For v0, the distinction is deliberately stronger than in a conventional educational pipeline:

```text
execute_ok && !causal_valid  => speculative result only
causal_valid && commit       => architectural state may change
```

The core therefore treats commit as a semantic boundary, not merely a pipeline stage.

## CMC record

The Causal Memory Controller (CMC) associates each candidate transition with a compact causal record:

```text
transition_id
pre_state_hash
cause
permission
phase
logical_time
recovery_point
post_state_hash
proof
```

v0 RTL does not yet implement cryptographic hashing. The fields define the contract that later versions must carry into a proof-producing implementation.

## Causal verification field

The execution record is interpreted through the CaPU verification tuple:

```text
E = <S, C, Phi, T, tau, R, V, P>
```

- `S` — state before/after the candidate transition
- `C` — cause that requested the transition
- `Phi` — execution phase
- `T` — proposed transition
- `tau` — logical time / ordering point
- `R` — recovery point if the transition cannot commit
- `V` — invariant validation result
- `P` — evidence/proof associated with the decision

## v0 commit contract

A transition may commit only when all of the following are true:

1. A candidate operation is present.
2. Gate permission is valid.
3. Speculative execution completed successfully.
4. Causal validation succeeded.
5. Commit is explicitly requested for the validated candidate.

In Boolean form:

```text
commit_allowed = candidate_valid
              && gate_allow
              && execute_ok
              && causal_valid
              && commit_request
```

The architectural write enable is defined as:

```text
architectural_write_enable = commit_allowed
```

There is no alternate write path.

## Failure and recovery semantics

### Gate rejection

If `gate_allow == 0`, the candidate is rejected before execution may become architectural.

Result:

```text
architectural_state unchanged
speculative candidate discarded
```

### Execute failure

If speculative execution fails, no commit is allowed.

Result:

```text
architectural_state unchanged
recovery = pre_state
```

### Causal validation failure

A computed value is not sufficient evidence for architectural change. If `causal_valid == 0`, the speculative result is discarded.

Result:

```text
architectural_state unchanged
recovery = pre_state
```

### Commit absent

A valid speculative result remains non-architectural until commit is asserted.

This makes the boundary observable in tests: an operation may be fully computed and causally valid while still producing no architectural side effect.

### Interruption before commit

A pipeline interruption or rejected candidate before commit discards the speculative candidate and leaves the last committed architectural state unchanged.

### Hardware reset

In v0, `rst_n` initializes the architectural register to zero. Durable restoration of a previously committed architectural state across a hardware reset is explicitly out of scope for v0 and belongs to a later recovery/checkpoint design.

## Primary invariants

### INV-CAPU-CORE-001 — No effect before commit

```text
!commit_allowed -> next(architectural_state) == architectural_state
```

### INV-CAPU-CORE-002 — Gate dominates commit

```text
!gate_allow -> !architectural_write_enable
```

### INV-CAPU-CORE-003 — Validation dominates commit

```text
!causal_valid -> !architectural_write_enable
```

### INV-CAPU-CORE-004 — Execution failure is contained

```text
!execute_ok -> !architectural_write_enable
```

### INV-CAPU-CORE-005 — One commit, one architectural transition

One accepted commit pulse may create at most one architectural state update.

## Initial instruction model

v0 uses a deliberately tiny operation model: a candidate carries a proposed `result_value`. The RTL does not yet implement a complete ISA. This keeps the first experiment focused on the causal commit boundary rather than instruction decoding complexity.

A future v1 can introduce a small ISA such as:

```text
ADD   rd, rs1, rs2
MOVI  rd, imm
STORE addr, rs
```

`STORE` is the most important future case because it introduces an externally visible memory side effect. The same invariant must then extend from register state to memory visibility:

> A store may enter a speculative buffer before commit, but must not become externally visible before a valid causal commit.

## Relationship to conventional CPU design

CaPU Core v0 is compatible with familiar processor concepts such as speculative execution, retirement, precise state, store buffering, and recovery. Its distinguishing design question is narrower:

> Not only "did the operation execute?", but "what evidence makes this transition legitimate enough to become architectural reality?"

The v0 RTL is therefore best viewed as a minimal causal commit controller that can later be embedded in a real pipeline.

## Minimal experiment

The v0 RTL experiment demonstrates five trajectories:

1. `gate=0` — no architectural update.
2. `gate=1, execute_ok=1, causal_valid=0` — no architectural update.
3. `gate=1, execute_ok=1, causal_valid=1, commit_request=0` — no architectural update.
4. All commit predicates true — exactly one architectural update.
5. A later execute failure cannot corrupt the previously committed value.

The CI smoke test also verifies the defined reset initialization value.

## Next hardware steps

1. Add stronger temporal/formal assertions for INV-CAPU-CORE-001 through 005.
2. Introduce a one-entry speculative store buffer.
3. Extend CMC metadata from interface contract to synthesizable storage.
4. Add a tiny ISA and compare CaPU commit semantics against a conventional retirement model.
5. Add checkpoint/recovery semantics for architectural state across reset-class failures.

# CaPU vCML Precise Trap / Privilege Recovery v0.18

## Claim

v0.18 extends the v0.17 checkpoint authority boundary with the smallest trap and
privilege context needed to make recovery precise across an exception or
interrupt boundary.

The authoritative checkpoint record is now conceptually:

```text
v0.17 architectural + causal + replay checkpoint bytes
+ privilege mode
+ trap pending / kind / cause
+ trap return PC
+ trap return privilege
+ interrupt mask
        ↓
one domain-separated canonical v0.18 payload
        ↓
one SHA-256 commitment
        ↓
PREPARE → PERSIST → ANCHOR AUTHORITY → EXACT RESTORE
```

The runtime proof surface then requires that exact restored trap/privilege state
before normal execution can resume.

## Threat model

v0.18 closes three bounded composition failures.

### Foreign trap context

```text
valid v0.17 architectural/causal snapshot A
+
trap / privilege context B
=
REJECT
```

Checkpoint epoch or recovery epoch equality is not enough. The trap context
itself must be part of the same committed record.

### Wrong-privilege continuation

```text
live privilege = P
normal continuation presented as Q
P != Q
=
REJECT
```

A correct PC is not sufficient if the continuation is attempted in the wrong
privilege mode.

### Pre-trap visible effect

A speculative effect admitted before a taken trap must not become visible across
the trap boundary. Trap entry, recovery, and restore attempts are visible-effect
barriers.

## Bounded trap model

v0.18 deliberately uses a small architectural trap model:

- 2-bit privilege mode;
- one pending trap context;
- exception or interrupt kind;
- bounded cause code;
- return PC;
- return privilege mode;
- one interrupt-mask bit;
- no nested trap stack.

Exception entry has strict priority over interrupt entry in the same cycle.
Interrupt entry is allowed only when the interrupt mask is clear. A pending trap
blocks a second trap entry; nested traps are deferred to a later version.

## Precise trap entry

Given a live restored state and no recovery/restore boundary:

```text
EXCEPTION_VALID
  > INTERRUPT_VALID && !INTERRUPT_MASK
  > TRAP_RETURN
  > NORMAL_STEP
```

On accepted trap entry, v0.18 atomically records:

```text
trap_pending          = 1
trap_is_interrupt     = selected trap kind
trap_cause            = selected cause
trap_return_pc        = pre-trap live PC
trap_return_privilege = pre-trap privilege
live_pc               = selected trap vector
live_privilege        = selected target privilege
```

The same cycle is a visible-effect barrier. A one-entry speculative-effect model
is included only so the bounded proof can express and check that pre-trap work
cannot retire after the trap is taken.

## Trap return

A trap return is accepted only while a live pending trap context exists and no
higher-priority trap/recovery/restore boundary is active.

Accepted return restores exactly the recorded return PC and return privilege and
clears the pending trap marker. The model does not claim a complete ISA-specific
`mret`/`sret` implementation.

## Checkpoint content binding

`tools/vcml_trap_checkpoint_v18.py` treats the complete v0.17 canonical payload as
an embedded authoritative base and adds the v0.18 trap fields under a new domain
separator.

This deliberately preserves v0.17 semantics rather than re-encoding causal or
replay state a second, incompatible way.

Changing any of the following changes the v0.18 SHA-256 commitment:

- any v0.17 recovery-relevant architectural, causal, or replay field;
- current privilege mode;
- trap pending bit;
- trap kind;
- trap cause;
- trap return PC;
- trap return privilege;
- interrupt mask.

Speculative-effect state is rejected as non-authoritative input and is not part
of the checkpoint schema.

## Authority barriers

As in v0.17, recovery and every restore attempt are checkpoint-authority
barriers:

```text
RECOVERY_OR_RESTORE
  => NO_PREPARE
  && NO_PERSIST_ACCEPT
  && NO_AUTHORITY_COMMIT
  && PENDING_AUTHORITY_DISCARDED
```

This prevents a candidate prepared against an older live state from gaining
checkpoint authority after the architectural world has changed.

## Core invariants

The intended bounded invariants are:

```text
RESTORE_ACCEPT
  => SNAPSHOT_PAYLOAD == ANCHOR_PAYLOAD
  && SNAPSHOT_PAYLOAD == EXACT_REPACKED_ARCH_CAUSAL_TRAP_STATE

FOREIGN_TRAP_OR_PRIVILEGE_BYTES
  => RESTORE_REJECT

PRIVILEGE_MISMATCH
  => NORMAL_STEP_REJECT

MASKED_INTERRUPT
  => NO_INTERRUPT_TRAP_ENTRY

EXCEPTION_AND_INTERRUPT_SAME_CYCLE
  => EXCEPTION_WINS

TRAP_ENTER
  => RETURN_PC == PRE_TRAP_PC
  && RETURN_PRIVILEGE == PRE_TRAP_PRIVILEGE
  && NO_VISIBLE_EFFECT

PRE_TRAP_SPECULATION
  && TRAP_ENTER
  => SPECULATION_DISCARDED

TRAP_RETURN
  => PC == RECORDED_RETURN_PC
  && PRIVILEGE == RECORDED_RETURN_PRIVILEGE

RECOVERY
  => RUNTIME_NOT_READY
```

## Deterministic trajectory

The v0.18 RTL trajectory is intended to exercise:

1. reject checkpoint preparation with altered privilege bytes;
2. prepare, persist, and authority-commit one exact complete v0.18 payload;
3. reject restore where the anchor is valid but explicit privilege state differs;
4. exact restore of PC, privilege, trap-idle state, mask, and embedded v0.17 base;
5. reject a normal step presented under the wrong privilege;
6. reject a masked interrupt;
7. admit one speculative effect;
8. present exception + interrupt + effect commit together and prove exception
   priority plus zero visible effect;
9. prove the pre-trap speculative effect is gone after trap entry;
10. return exactly to the saved PC and privilege;
11. execute one correct-privilege normal continuation;
12. begin recovery and prove runtime closes.

## Formal scope

The formal harness uses reduced widths and bounded model checking. It targets both
safety and reachability, including exact restore, restore mismatch, privilege
rejection, masked interrupt, exception entry, interrupt entry, trap return,
speculation kill, and checkpoint authority commit.

## Claim boundary

v0.18 does **not** claim:

- a full RISC-V, x86, ARM, or other ISA exception model;
- nested traps or a trap stack;
- complete CSR semantics;
- delegation registers;
- page faults, TLB/MMU state, or privilege-dependent address translation;
- asynchronous interrupt synchronization/metastability behavior;
- NMI/debug mode;
- timer or external interrupt controllers;
- a full reorder buffer or production speculative pipeline;
- cache/coherence/multicore recovery;
- RTL SHA-256 verification;
- durable-media correctness;
- production-width or unbounded correctness.

The narrow claim is that a reduced one-trap architectural context is bound to the
same checkpoint authority as the v0.17 architectural/causal/replay record, and
that resumed local execution fails closed on wrong privilege, masked interrupt,
foreign trap bytes, recovery/restore boundaries, and pre-trap speculative-effect
retirement.

## Natural next step

A credible v0.19 should add **nested/delegated trap state or privilege-specific
CSR authority**, rather than jumping directly to caches or multicore. The next
state should only be added if its bytes can participate in the same exact
checkpoint authority and recovery boundary.

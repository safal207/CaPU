# CaPU vCML Delegated + Nested Trap Authority v0.19

## Claim

v0.19 extends the exact v0.18 trap/privilege checkpoint authority with a bounded two-level trap stack and an explicit delegation mask. The delegation policy and both trap frames are checkpoint-authoritative state.

```text
v0.18 exact checkpoint
+ current privilege
+ delegation mask
+ trap depth (0..2)
+ outer trap frame
+ inner trap frame
        ↓
one canonical checkpoint payload
        ↓
one commitment / authority
        ↓
exact restore → delegated nested trap entry/return
```

## Threat model

The model fails closed when otherwise-valid components are composed under the wrong authority:

- valid architectural/causal/trap state + foreign delegation policy;
- valid inner trap + foreign outer/parent trap context;
- trap entry to a target privilege not allowed by the current delegation mask;
- a third trap when the bounded stack is already depth 2;
- trap return at depth 0;
- wrong-privilege normal continuation;
- pre-trap speculative visible effect crossing accepted trap entry/return, recovery or restore.

## Bounded semantics

The model intentionally supports only two trap frames. On accepted trap entry, the current PC and privilege are captured in the next free frame, the requested cause/kind/target privilege are recorded, PC moves to the supplied trap vector and privilege moves to the authorized target. On return, the top frame restores its exact recorded parent PC/privilege and is invalidated.

`delegation_mask[target_privilege]` is the modeled authority predicate. It is deliberately small and does not attempt to model a production ISA CSR delegation hierarchy.

## Core invariants

```text
RESTORE_ACCEPT
  => SNAPSHOT == ANCHOR == EXACT_REPACKED_V0_19_STATE

TRAP_ENTER_ACCEPT
  => TARGET_PRIVILEGE_AUTHORIZED
  && DEPTH < 2
  && PARENT_PC_PRIVILEGE_CAPTURED

UNAUTHORIZED_DELEGATION
  => NO_TRAP_ENTER

DEPTH == 2 && TRAP_ENTER
  => REJECT

TRAP_RETURN_ACCEPT
  => EXACT_TOP_PARENT_PC_PRIVILEGE_RESTORED

DEPTH == 0 && TRAP_RETURN
  => REJECT

FOREIGN_DELEGATION_OR_PARENT_CONTEXT
  => CHECKPOINT_DIGEST_CHANGED / RESTORE_REJECT

TRAP_OR_RECOVERY_BOUNDARY
  => NO_VISIBLE_EFFECT
```

## Claim boundary

This is a bounded reduced-width two-level trap/delegation model. It does not claim full ISA CSR delegation semantics, arbitrary trap-stack depth, page-fault/MMU/TLB recovery, NMI/debug behavior, interrupt-controller correctness, asynchronous synchronization correctness, production speculation, caches/coherence/multicore, RTL SHA-256, durable media or unbounded correctness.

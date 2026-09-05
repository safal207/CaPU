# Recovery closure experiment — protocol fixed before new trials

Date: 2026-09-05. Decision: whether CaPU/ATMAN supports a defensible investor-facing recovery demonstration, not whether it replaces a CPU.

Source: unchanged CaPU HTTP v2 at 8a2f2a37023a50aeac52cb8c8aed84b2eeceec88; CaPU A6/A7 and ATMAN authority pins from its bootstrap. Old HTTP behavior remains a safe HOLD control. New receiver/adapters below are experimental additions, NOT defects attributed to v2.

H1: Reinterpreting an empty result lookup as NOT_COMMITTED admits a duplicate when the original request is delayed.
H2: A persistent attempt tombstone checked only at request admission is insufficient if an already admitted handler is paused before its effect.
H3: Checking that tombstone in the SAME receiver transaction as the effect prevents this counterexample and permits retry after a permanently dropped first request.
H4: A conventional FSM given the same receiver guarantee matches native CaPU. Operation-key idempotency is a strong conventional control; no architectural superiority is presumed.

Arms: hold, snapshot_negative (deliberately unsafe), admission_fence (deliberately weak), atomic_fence (candidate), operation_idempotency (separate conventional control).

Primary outcome: number of durable effect rows per logical operation; >1 is unsafe. Completion after a permanently dropped initial request is measured separately from safety. No timing, throughput, energy, revenue or investor-interest claims from these trials.

Finite model: enumerate all interleavings preserving each local causal chain; two attempts, one closure query, one receipt application, one optional replay. Report exact bounded trace counts, NOT empirical incident probabilities or unbounded proof.

HTTP: real loopback sockets and a receiver subprocess; test-controlled gates before/after admission; SQLite insertion itself is the effect. Native/FSM use unchanged upstream authority and lifecycle logic. Use a separate read-only observer; do not hide duplicates behind operation dedup in the candidate. Candidate only deduplicates the same attempt. Closure and effect share one transactional database; no cross-system atomicity is claimed.

Non-claims: new distributed-systems theorem, patentability/priority, real external payment, production receipt cryptography, Byzantine protection, physical power loss, unavailable receiver recovery, complete ATMAN/Bardo/COSMIC integration, silicon acceleration, market validation. Public deterministic fixture keys only, no expenditure or deployment.

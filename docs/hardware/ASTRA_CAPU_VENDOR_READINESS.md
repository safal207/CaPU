# ASTRA–CaPU Vendor Readiness

Status: strategic assessment / evidence-gated roadmap.

## Verdict

CaPU is currently credible as:

```text
architecture research
+ executable software reference
+ bounded formal hardware semantics
+ candidate control-plane coprocessor concept
```

CaPU is not currently credible as:

```text
production AI processor
licensable accelerator RTL
vendor-ready silicon IP
measured replacement for CPU/GPU/TPU/NPU compute
```

The right near-term target is **architecture review, research collaboration, benchmark participation, or a scoped prototype evaluation** — not a claim that a complete processor is ready for procurement.

## Readiness ladder

| Layer | Current position | Evidence needed for the next gate |
| --- | --- | --- |
| Problem thesis | Strong | External reviewer agreement on the failure class and boundary |
| Software reference | Strong but scoped | One canonical intent-to-effect contract across runtime and evidence |
| Bounded formal slices | Strong research signal | Integrated top-level properties and compositional proof plan |
| Synthesizable controller | Not yet established | Lint/synthesis-clean RTL with stable interfaces |
| FPGA prototype | Not yet established | Real command queue, fault injection, recovery receipts |
| PPA / overhead | Not yet measured | Area, frequency, latency, throughput, power, storage overhead |
| Vendor integration | Not yet established | Adapter to a real runtime/device interface and vendor workload |
| Production trust root | Not yet established | Durable monotonic identity, key management, authenticated receipts |

## Strategic positioning

Bad pitch:

> We built a new TPU.

Credible pitch:

> We are developing a causal execution and recovery controller that can sit beside existing AI compute fabrics and preserve exact authority, checkpoint continuity, uncertainty, and effect provenance across failures.

## Why a large AI lab might evaluate it

The relevant evaluation question is:

```text
Can a long-running autonomous or accelerator-backed workload
recover from crash, timeout, duplicate delivery, stale checkpoint,
or uncertain external completion without inventing authority,
duplicating effects, or corrupting trusted memory?
```

CaPU offers a concrete architecture for testing that question.

## Minimum evidence package before serious vendor outreach

1. **Reference architecture** — stable blocks and interfaces.
2. **Canonical execution contract** — intent, authority, command, outcome, receipt.
3. **Killer deterministic fixture** — crash at the ambiguous effect boundary.
4. **Negative controls** — stale authority, duplicate dispatch, false success, conflict.
5. **Integrated software adapter** — current runtime to synthetic accelerator.
6. **Synthesizable guard** — commit-before-dispatch and receipt-gated replay.
7. **Formal evidence** — bounded properties and explicit proof boundary.
8. **Measured overhead** — decision latency, queue throughput, state/receipt size.
9. **Reproduction kit** — one command, fixed toolchain, machine-readable result.
10. **One-page evaluation request** — a narrow technical question, not a broad sales pitch.

## Vendor-specific angle

### Frontier model lab / agent infrastructure team

Lead with:

- long-running agent continuity;
- tool and external-effect provenance;
- false-success prevention;
- exact recovery after ambiguous completion;
- trusted memory updates only after outcome evidence.

### AI accelerator / systems team

Lead with:

- command queue authority;
- DMA replay and partial-completion recovery;
- checkpoint/receipt reconciliation;
- stale identity and ABA protection;
- distributed control-plane recovery;
- measurable overhead at the boundary rather than inside tensor math.

## Go / no-go gate

Proceed to serious outreach only when the following sentence is demonstrably true:

> On one reproducible workload, CaPU prevents a duplicate or falsely completed effect across an injected crash while the baseline does not, and the result is bound to an exact intent, authority, checkpoint, command, outcome, and proof receipt with measured overhead.

Until then, outreach should be framed as research discovery and architecture feedback.

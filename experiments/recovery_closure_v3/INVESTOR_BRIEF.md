# Safe recovery for agent actions

## Executive Summary

**We built a reproducible test for a dangerous recovery boundary.** A missing result is not evidence that an old command can no longer execute. In a deliberately faulty receiver, a retry and a delayed original request both produce effects. Checking a durable closure at the actual effect transaction prevents that counterexample in this laboratory.

**The result is a project-level research contribution, not a new distributed-systems invention.** The same contract works with a conventional state machine. A stable operation-idempotency key is also a successful conventional control. No superiority, customer demand, revenue, silicon performance or production safety is established.

## The demonstration distinguishes safety from getting work done

The unit measured is a durable SQLite row per logical operation. Two rows mean a duplicate effect; zero rows after a permanently lost request mean unfinished work. A separate read-only process observes the receiver ledger. All traffic is loopback HTTP on one trusted host.

| Receiver policy | Delayed original, after release | Permanently lost original |
|---|---:|---:|
| Conservative HOLD | 1 effect, but 0 at the recovery checkpoint | 0 effects |
| Empty lookup treated as negative | 2 effects | 1 effect |
| Closure checked only on admission | 2 effects | 1 effect |
| Closure checked atomically with effect | 1 effect | 1 effect |
| Conventional operation-key idempotency | 1 effect | 1 effect |

These are two deliberately controlled demonstrations, not measured customer incident rates. The weak rows are intentional mutation controls, not bugs attributed to the earlier conservative CaPU v2.

Run `python demo.py --case delayed` and `python demo.py --case lost`. Do not omit the successful conventional control from a presentation.

## What the evidence establishes

The new HTTP suite passed 40 test methods without failures, errors or skips. The finite model enumerated 560 distinct bounded traces: 56 causal schedules, two initial-delivery conditions and five policies. All 16 native-CaPU/conventional-FSM matrix comparisons matched. Full new traces and logs are retained losslessly; `restore_evidence.py` verifies their original byte identities.

The integration hypothesis is executable: a receiver's negative receipt must close the old attempt's future effect path, not merely report a past snapshot. It must not become a new execution grant. Tests also cover receiver restart, a tampered negative receipt, changed authority generation and a foreign operation's closure.

## A defensible product hypothesis

Build a recovery-conformance kit for teams whose agents invoke consequential tools. The proposed value is finding unsafe retries and explaining the receiver contract needed to repair them. The first test of this business hypothesis should be one real connector integration and an external team reproducing a failure and its correction. Measure integration effort, useful defects found and willingness to pay; do not infer those from this lab.

A usable introduction: “We test whether an agent workflow can recover from an ambiguous tool result without duplicating the action or silently using stale authority. Our current reference makes the boundary reproducible, including negative controls and conventional alternatives.”

## Further questions before an investment claim

Can a real target service enforce a stable operation identity or close an old attempt? What happens when the receiver is unavailable, its storage is rolled back, or multiple regions disagree? Is the kit easier to integrate or more diagnostic than existing tests? Is there a paying owner for the failure mode? These questions remain unanswered.

## Caveats and assumptions

SQLite insertion is the effect. Closure and effect share one database transaction; no atomicity with an arbitrary external payment or device is proved. Public fixture keys and synthetic A7 tags are not production authentication. No Byzantine protection, physical power-loss proof, deployment bypass resistance, unbounded exactly-once guarantee, hardware acceleration or full four-repository integration is claimed. Independent code review and external reproduction remain separate gates.

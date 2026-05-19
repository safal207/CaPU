# CMC Replay Fixture Corpus

Status: early conformance-style fixture corpus.

This directory collects canonical replay cases for CMC.

The goal is to move from individual demos toward a replay conformance suite.

## Fixture cases

| Fixture | Purpose |
| --- | --- |
| `missing_cause.jsonl` | A write is rejected because no cause was supplied. |
| `forbidden_effect_before_commit.jsonl` | An effect is rejected because its cause exists but is not committed. |
| `valid_committed_effect.jsonl` | A write/effect path succeeds with committed causes. |
| `tampered_decision.jsonl` | A trace that should fail integrity verification after decision mutation. |
| `diverged_replay_expected.jsonl` | Expected blocked-transition replay output. |
| `diverged_replay_actual.jsonl` | Diverged replay output for comparison demos. |

## Why this exists

CMC is not only a simulator. It is moving toward replayable legitimacy evidence:

```text
transition -> decision -> trace -> replay -> integrity -> admissibility
```

A fixture corpus lets future tooling verify that accepted, rejected, tampered, and diverged traces remain stable across implementation changes.

## Non-claims

These fixtures are not a final trace standard and not cryptographic evidence. They are early reproducible examples for CMC-0 behavior.

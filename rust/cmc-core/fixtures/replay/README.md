# CMC Replay Fixture Corpus

Status: early conformance-style fixture corpus.

This directory collects canonical replay cases for CMC.

The goal is to move from individual demos toward a replay conformance suite.

## Checked fixture cases

These fixtures are currently checked by both:

```bash
cargo run --bin replay_fixture_verify --locked
cargo run --bin replay_fingerprint_verify --locked
```

| Fixture | Decision | Events | Fingerprint | Purpose |
| --- | --- | ---: | --- | --- |
| `missing_cause.jsonl` | `REJECT_MISSING_CAUSE` | 1 | `88fd99689760140e` | A write is rejected because no cause was supplied. |
| `unknown_cause.jsonl` | `REJECT_UNKNOWN_CAUSE` | 1 | `d8c4983b8a5a0ab0` | A write is rejected because the referenced cause is unknown. |
| `forbidden_effect_before_commit_fixture.jsonl` | `REJECT_EFFECT_BEFORE_COMMIT` | 1 | `28bf87f68e4ec6cb` | An effect is rejected because its cause exists but is not committed. |
| `valid_committed_effect.jsonl` | `ACCEPT_EFFECT` | 1 | `e3e96ba017e2c235` | An effect is accepted after committed causal authorization. |

## Corpus coverage

Current checked coverage:

```text
negative write/no cause
negative write/unknown cause
negative effect/before commit
positive effect/after commit
```

This gives the corpus both rejection evidence and positive legitimacy evidence.

## Why this exists

CMC is not only a simulator. It is moving toward replayable legitimacy evidence:

```text
transition -> decision -> trace -> replay -> integrity -> admissibility
```

A fixture corpus lets future tooling verify that accepted, rejected, tampered, and diverged traces remain stable across implementation changes.

## Current limits

The current fixture fingerprints use the developer FNV-1a64 stability implementation. They are useful for detecting fixture drift, but they are not production cryptographic evidence.

The current corpus is still small. Phase 2 should expand it toward at least 8 legitimacy violation classes.

## Non-claims

These fixtures are not a final trace standard and not cryptographic evidence. They are early reproducible examples for CMC-0 behavior.

# CMC Replay Fixture Golden Manifest

Status: canonical fixture manifest for the current CMC replay corpus.

This document explains the fixture manifest. The machine-readable source of truth is:

```text
fixtures/replay/MANIFEST.tsv
```

The TSV manifest records the scenario ID, invariant ID, fixture path, expected decision, event count, and developer-stability fingerprint for each checked replay fixture.

Both replay verifier binaries read this manifest:

```text
rust/cmc-core/src/bin/replay_fixture_verify.rs
rust/cmc-core/src/bin/replay_fingerprint_verify.rs
```

---

## Machine-readable manifest format

```tsv
scenario_id	invariant_id	path	decision	events	fingerprint
write_missing_cause	I1	fixtures/replay/missing_cause.jsonl	REJECT_MISSING_CAUSE	1	88fd99689760140e
write_unknown_cause	I2	fixtures/replay/unknown_cause.jsonl	REJECT_UNKNOWN_CAUSE	1	d8c4983b8a5a0ab0
effect_before_commit	I3	fixtures/replay/forbidden_effect_before_commit_fixture.jsonl	REJECT_EFFECT_BEFORE_COMMIT	1	28bf87f68e4ec6cb
valid_committed_effect	I4	fixtures/replay/valid_committed_effect.jsonl	ACCEPT_EFFECT	1	e3e96ba017e2c235
```

---

## Checked fixtures

| Scenario | Invariant | Fixture | Expected decision | Events | Fingerprint |
| --- | --- | --- | --- | ---: | --- |
| `write_missing_cause` | `I1` | `missing_cause.jsonl` | `REJECT_MISSING_CAUSE` | 1 | `88fd99689760140e` |
| `write_unknown_cause` | `I2` | `unknown_cause.jsonl` | `REJECT_UNKNOWN_CAUSE` | 1 | `d8c4983b8a5a0ab0` |
| `effect_before_commit` | `I3` | `forbidden_effect_before_commit_fixture.jsonl` | `REJECT_EFFECT_BEFORE_COMMIT` | 1 | `28bf87f68e4ec6cb` |
| `valid_committed_effect` | `I4` | `valid_committed_effect.jsonl` | `ACCEPT_EFFECT` | 1 | `e3e96ba017e2c235` |

---

## Evidence chain

The manifest makes the replay evidence chain explicit:

```text
invariant -> scenario -> fixture -> verifier -> reviewer command -> CI
```

This lets reviewers see which invariant a replay fixture is exercising, instead of treating fixtures as disconnected examples.

---

## Verification commands

From `rust/cmc-core`:

```bash
cargo run --bin replay_fixture_verify --locked
cargo run --bin replay_fingerprint_verify --locked
```

From repository root:

```bash
npm run review:cmc
```

---

## Coverage summary

```text
I1 negative write/no cause
I2 negative write/unknown cause
I3 negative effect/before commit
I4 positive effect/after commit
```

This is still a small corpus, but it now contains both illegitimate transition rejection and legitimate committed effect acceptance.

---

## Current fingerprint limit

The fingerprints are developer-stability fingerprints using the current FNV-1a64 implementation.

They detect fixture drift.

They are not production cryptographic evidence.

---

## Next manifest step

The next step is to add richer metadata, for example:

```text
category	severity	expected_verdict
```

That would help convert replay verification into an auditor-facing report.

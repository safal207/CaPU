# CMC Replay Fixture Golden Manifest

Status: canonical fixture manifest for the current CMC replay corpus.

This document explains the fixture manifest. The machine-readable source of truth is:

```text
fixtures/replay/MANIFEST.tsv
```

The TSV manifest records the expected decision, event count, and developer-stability fingerprint for each checked replay fixture.

Both replay verifier binaries read this manifest:

```text
rust/cmc-core/src/bin/replay_fixture_verify.rs
rust/cmc-core/src/bin/replay_fingerprint_verify.rs
```

---

## Machine-readable manifest format

```tsv
path	decision	events	fingerprint
fixtures/replay/missing_cause.jsonl	REJECT_MISSING_CAUSE	1	88fd99689760140e
fixtures/replay/unknown_cause.jsonl	REJECT_UNKNOWN_CAUSE	1	d8c4983b8a5a0ab0
fixtures/replay/forbidden_effect_before_commit_fixture.jsonl	REJECT_EFFECT_BEFORE_COMMIT	1	28bf87f68e4ec6cb
fixtures/replay/valid_committed_effect.jsonl	ACCEPT_EFFECT	1	e3e96ba017e2c235
```

---

## Checked fixtures

| Fixture | Expected decision | Events | Fingerprint |
| --- | --- | ---: | --- |
| `missing_cause.jsonl` | `REJECT_MISSING_CAUSE` | 1 | `88fd99689760140e` |
| `unknown_cause.jsonl` | `REJECT_UNKNOWN_CAUSE` | 1 | `d8c4983b8a5a0ab0` |
| `forbidden_effect_before_commit_fixture.jsonl` | `REJECT_EFFECT_BEFORE_COMMIT` | 1 | `28bf87f68e4ec6cb` |
| `valid_committed_effect.jsonl` | `ACCEPT_EFFECT` | 1 | `e3e96ba017e2c235` |

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
negative write/no cause
negative write/unknown cause
negative effect/before commit
positive effect/after commit
```

This is still a small corpus, but it now contains both illegitimate transition rejection and legitimate committed effect acceptance.

---

## Current fingerprint limit

The fingerprints are developer-stability fingerprints using the current FNV-1a64 implementation.

They detect fixture drift.

They are not production cryptographic evidence.

---

## Next manifest step

The next implementation step is to expand the manifest with scenario IDs and invariant IDs, for example:

```text
scenario_id	invariant_id	path	decision	events	fingerprint
```

That would connect replay fixtures directly to `CMC_INVARIANTS.md`.

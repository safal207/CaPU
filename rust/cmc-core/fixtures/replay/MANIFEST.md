# CMC Replay Fixture Golden Manifest

Status: canonical fixture manifest for the current CMC replay corpus.

This manifest records the expected decision, event count, and developer-stability fingerprint for each checked replay fixture.

The manifest is documentation for now. The executable source of truth is currently:

```text
rust/cmc-core/src/bin/replay_fixture_verify.rs
rust/cmc-core/src/bin/replay_fingerprint_verify.rs
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

The next implementation step is to make this manifest machine-readable or parseable so the verifier does not hardcode fixture expectations in Rust.

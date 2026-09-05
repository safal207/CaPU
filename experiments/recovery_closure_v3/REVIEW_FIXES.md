# Evidence-verifier hardening — 2026-09-05

> Historical local-patch record. See [PUBLICATION.md](PUBLICATION.md) for the
> publication/dependency follow-up. The sections below describe the earlier
> local run, not the current PR head.

Status: locally tested patch based on CaPU PR #106 at
`d64f9809f90532d52c2992174e63c1a216a50211`. Not published, not merged,
not externally approved. This changes evidence checking and restoration, not
the experimental receiver's state-transition or effect semantics.

## Findings addressed in this patch

1. Equal native/FSM output is no longer sufficient. Each of the 36 HTTP
   records must have the expected identity and independently calculated effect
   count. Expected values supplied by the report are checked, not trusted.
   Both summary tables are reconstructed from the raw records. The 16 pair
   records and all seven boundary identities are mandatory.
2. The producer input inventory is explicit and complete for this lab version.
   Empty, missing, extra and changed entries fail. It includes the runner,
   validator, test source, restoration tool, contract and requirements.
3. Validation uses explicit exceptions and nonzero CLI exit codes; `-O`, `-OO`
   and `PYTHONOPTIMIZE` do not bypass it. Model and HTTP scenario assertions
   are also explicit exceptions. Running the full harness under optimization
   is refused because upstream pinned code is outside this hardening patch.
4. New evidence uses schema `/2`, records the actual Git revision when
   available, records dirty status, and separates the pinned v2 dependency.
   Exported source without Git records `null` rather than inventing a commit.
5. The exact historical archive is accepted only with `--historical` and fixed
   artifact checksums. All retained fields of `evidence/observed-summary.json`
   are protected by exact checksums for both original archive and repository formatting and its numeric claims are reconciled.
6. Archive restoration uses POSIX directory descriptors, no-follow and exclusive
   opens. Existing matching regular files are not rewritten. Symlinked paths,
   non-regular files and different existing contents are rejected. Unsupported
   platforms fail closed. This does not establish arbitrary hostile-host or
   storage-rollback protection.
7. The proposed workflow disables checkout credential persistence and adds
   regression checks for the validator in ordinary and optimized Python.

## Historical commit-label correction (without rewriting measurements)

The original summary's `source_commit` value
`8a2f2a37023a50aeac52cb8c8aed84b2eeceec88` names the v2 DEPENDENCY.
It is not the producing v3 revision. The six recorded experiment-source hashes
match source files contained in candidate `d64f9809...`. That byte identity is
not a retroactive measurement of the original runtime's Git HEAD.

Original summary, archive chunks and hashes are retained unchanged. The Git
observed-summary remains exactly as published. The ZIP contains a differently
formatted but value-identical copy; both exact byte identities are supported. `evidence_contract.json` records the candidate containing those
bytes; fresh `run.py` records its own provenance. Historical restoration must
not be described as a new run or as execution of the current patched producer.

## Fixed-contract validation, not general verification

The v3 transcript has a fixed, deterministic contract. Alongside semantic checks,
canonical model and HTTP transcript hashes pin all less prominent raw fields.
A legitimate scenario or ordering change therefore also requires explicit
review of the contract; this validator is not a generic verifier for later
experiments. Trusted verifier code and contract inputs remain assumptions.
Checksums do not authenticate an author, independently witness execution, or
prove completeness of external events. Two matching wrong implementations are
rejected for the stated cases; this is not an unbounded correctness proof.

## Local verification

Python 3.13.5, Linux, already installed cryptography 46.0.4. No dependency was
installed or upgraded for this run.

- 32 validator/restoration test methods pass in normal mode.
- The same 32 pass under `python -O`; internal subcases also check `-OO` and
  `PYTHONOPTIMIZE=1`. These are the same methods, not 64 new safety guarantees.
- A full new HTTP run passes all 40 methods with no failures/errors/skips.
- 560 bounded model traces and full HTTP transcripts match the original JSON
  files byte-for-byte. Fresh summary/provenance and elapsed times are different
  by design.
- Fresh and historical evidence pass normal and optimized CLI validation.
- Original v1/v2 suites were not rerun in this patch step.
- One earlier combined tool invocation hit its execution timeout. Its partial
  HTTP log is retained separately and is not counted as a completed run.

## Still open before external execution or merge

The requirements file still pins `cryptography==46.0.4`. CodeRabbit's statement
that the experiment does not import it directly is incomplete: pinned
`proof.py` and ATMAN `authority.py` import it transitively. Official upstream
advisories/changelog identify fixes after that version. A reviewed update,
compatibility run and current dependency scan are still required. Do not treat
this patch's local synthetic run as approval of that dependency for production.

No corrected code has been pushed from this session; no new GitHub CI or
CodeRabbit review has run on this patch. CodeRabbit's seven threads remain
review data, not approval. No Codex request was made. A draft invitation to
João is held separately, not sent and not evidence of his participation.

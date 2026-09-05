# PR #106: validator fixes and dependency follow-up

This follow-up applies the locally reviewed validator/restoration patch to the
existing `research/recovery-closure-v3` branch. The parent is
`d64f9809f90532d52c2992174e63c1a216a50211`; main is not changed. Keep the PR
draft and unmerged pending review. The owner requested assistant self-review
and optional CodeRabbit review, explicitly without Codex.

## Scope and evidence

The receiver, observer, lifecycle policies and pinned upstream source are
unchanged. This is evidence-verifier hardening, not a new recovery result or
new algorithm. `REVIEW_FIXES.md` and `evidence/review-fix-2026-09-05/` preserve
the earlier local patch results on Python 3.13.5 / cryptography 46.0.4.
They are not CI evidence for the dependency update.

`requirements.txt` now pins cryptography 50.0.1. Upstream lists that release
on 2026-08-25 and security fixes since 46.0.4:
https://cryptography.io/en/latest/changelog/
https://pypi.org/project/cryptography/50.0.1/

The local environment could not download the new wheel (network/DNS failure).
Consequently compatibility of 50.0.1 must be established by the actual new CI
runs, not by relabeling the earlier local results. The workflow installs and
checks 50.0.1, records the Python/OpenSSL/package environment, reruns the 32
validator/restoration methods in normal and optimized mode, reruns all 40 HTTP
methods and 560 bounded model traces, then validates fresh and historical
artifacts. It also scans resolved requirements using pip-audit 2.10.1 in a
separate environment; scan failure is not suppressed.

Inspect the real run conclusion and artifacts. A configured workflow is not
an executed check. A clean dependency scan only means no known findings in
that scan; it is not a security or production certification.

## Historical provenance, deliberately not rewritten

The original `source_commit` field labels the HTTP-v2 dependency, not the v3
producer. Original archive chunks, original observed summary and checksums
remain untouched. `evidence_contract.json` documents the distinction. Historical
validation is opt-in (`--historical`) and byte-pinned. Fresh runs record actual
Git revision/dirty status or explicit unavailability, plus installed cryptography.

## External handoff

No external email or endorsement is part of this change. After CI and review,
a separate bounded reproduction invitation can point to a pinned commit.
SQLite insertion remains the effect; no atomicity for real payments, arbitrary
external services, hostile hosts, production cryptography or hardware is claimed.

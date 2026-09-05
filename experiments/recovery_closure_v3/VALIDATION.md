# Validation record

Assessment: share as a bounded research demonstration with the limitations below; not a production or investment-readiness certificate.

- Source: unchanged CaPU HTTP v2 at 8a2f2a37023a50aeac52cb8c8aed84b2eeceec88, with its pinned CaPU A6/A7 and ATMAN authority modules. New receiver policies and the negative-receipt adapter are separate experimental additions.
- Regressions: original v1 55/55 and v2 28/28 passed again. Their result digests matched the historical files. These are not new independent guarantees.
- New live suite: 40 test methods, zero failures/errors/skips; 36 matrix records and 7 boundary records. Three test methods contain two engine subcases. Native/FSM shared authority, persistence, transport and synthetic authentication; only lifecycle logic differs.
- Model: 560 distinct traces. An independent permutation filter confirmed all 56 linear extensions of the two event chains. `validate_results.py` recomputed the aggregates from full histories and compared all 16 native/FSM pairs.
- Evidence: archive reconstruction reproduced four original output files byte-for-byte. Sizes and SHA-256 values are in EVIDENCE_MANIFEST.json. Hashes are integrity checks, not independent timestamps or completeness attestations.
- Scope: intentionally selected fault schedules and mutation controls. No probability model, incident-rate estimate, speed benchmark or claim that existing conservative v2 is defective.
- Code review: local checks are not independent review. Keep the PR draft; record the native Codex response separately and never substitute another approval.

The standard analytical HTML report packager could not be loaded in this runtime. This delivery uses a repository research note and executable evidence, not a claimed rendered/validated HTML report.

# Repository guide — research lifecycle v1

Shared navigation contract for BardoCompute, COSMIC-ORGANICS, ATMAN-LATTICE and CaPU. Updated: 2026-09-05.

## One entry point, separate readiness dimensions

`README.md` is the short public entry point. `START_HERE.md` explains the paths in Russian. `RESEARCH_INDEX.md` records exact source locations, evidence and non-claims. `PROJECT_STATUS.json` is the machine-readable snapshot. `README.previous.md` preserves the previous root document without moving its relative links.

Track availability, evidence and production readiness separately:

- **Reference:** a documented exact-revision reproduction path; not an assertion of production safety.
- **Research:** a bounded experiment or integration candidate; its result applies only to its declared inputs and environment.
- **Preserved history:** retained evidence or branch; not automatically obsolete or safe to delete.
- **Production:** a separate deployment-specific review, security and operational gate. No entry is promoted merely because CI passes or documentation reaches main.

## Workflow

Choose one question -> identify base commit and scope -> implement on one topic branch -> test positive and negative controls -> save evidence -> review -> explicitly promote the selected result.

Use `docs/<topic>` for documentation, `feat/<topic>` for integration, and `research/<experiment-id>-<topic>` for a new experiment. Preserve existing names. Do not create another numbered branch for a minor repair to the same question unless a frozen review/evidence boundary requires it.

Code changes keep their existing CI and native Codex-review requirements. A documentation-only publication does not approve or merge linked code PRs. Never infer approval from a green check, a bot quota error, a draft PR, or a historical review on another SHA.

## Required experiment record

Record: question; baseline/control; repository and full source SHA; base and dependencies; exact commands and environment; result files and SHA-256 hashes; failed/negative cases; allowed conclusion; non-claims; review status; merge target and status; next falsifiable step. Separate a file checksum from a digest embedded inside the result.

Store compact result summaries, manifests and necessary raw evidence in Git, or a durable explicitly identified release asset when too large. A chat attachment or expiring Actions artifact is not the sole research record. Preserve logs as historical observations; copying them is not a rerun or independent attestation. Do not commit credentials, private datasets or production keys.

## Branch consolidation

Inventory -> classify -> inspect ancestry and open PR bases -> select a reference -> replay its tests -> review promotion -> preserve evidence -> only then consider retirement.

Deletion, renaming, force-pushing, retargeting active research PRs, and changing the default branch are not automatic cleanup steps. Equal branch-head SHAs identify duplicate pointers, not permission to delete. Preserve negative results. Frozen source candidates are changed only through a new explicit review/evidence cycle.

## Maintenance

Update the status and research index in the same PR whenever a code path, claim, evidence location or readiness state changes. Keep absolute source-SHA links for frozen evidence and relative links for current navigation. Snapshot dates and coverage limits must remain visible; do not call a selected-track index a complete repository audit.

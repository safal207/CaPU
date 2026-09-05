# CaPU — research index

Snapshot: 2026-09-05. [Start](README.md) · [Lifecycle](REPOSITORY_GUIDE.md)

This is an index of selected entry tracks, not a complete audit of every branch.

| Track | Exact source | Availability / evidence |
|---|---|---|
| Existing main software reference | `0d7b369a2ed70acdbb7df70f24e18b5e7d35f3c5` | Reference demo and package tests; unchanged by this documentation publication |
| Process recovery v1 | `977864167c65f161e6db87b3d14257a11a67516f` | [Draft PR #103](https://github.com/safal207/CaPU/pull/103); historical 55-test result |
| Loopback HTTP recovery v2 | `8a2f2a37023a50aeac52cb8c8aed84b2eeceec88` | [Draft PR #104](https://github.com/safal207/CaPU/pull/104); includes unchanged v1, historical 28-test result |
| A6/A7 module inputs to the laboratories | `5cdaa5280348841bf8448c5a7844c273df257c5d` | Three-module composition also uses ATMAN authority.py below; not an integration of whole runtimes |
| ATMAN authority input | `e62c279b9148a7ae9dd1a4654f6ddeea6add4a3f` in safal207/ATMAN-LATTICE | Only model/authority.py; upstream identities are embedded in v1 evidence |

## Reproduce the recovery laboratories

From a full clone, create a separate worktree. Keep the navigation checkout intact:

```sh
git fetch origin
git worktree add --detach ../CaPU-recovery 8a2f2a37023a50aeac52cb8c8aed84b2eeceec88
cd ../CaPU-recovery
python -m venv .venv
# Activate .venv for your shell.
python -m pip install -r experiments/capu_atman_recovery_v1/requirements.txt
python experiments/capu_atman_recovery_v1/bootstrap.py
python experiments/capu_atman_recovery_v1/run.py --output evidence-v1
python experiments/capu_atman_http_recovery_v2/run.py --output evidence-v2
```

Bootstrap downloads pinned upstream modules and verifies their hashes. Read the exact-source laboratory README for requirements and trust assumptions. Prior CI lanes used Python 3.11 and 3.13. This documentation pass did not rerun them.

## Evidence and provenance

[Stored original result files and logs](evidence/capu-atman/2026-09-05/README.md) are in Git, not only in chat. Historical v2 CI run: [33940511054](https://github.com/safal207/CaPU/actions/runs/33940511054). Archived local files are not downloaded CI artifacts; do not confuse those provenance types.

v1 compares 288 lifecycle steps; v2 compares 37 paired observations across 14 scenarios. Equal-guarantee conventional controls passed too. No speed/energy or architectural-superiority conclusion follows.

## Review and promotion

Both recovery source heads are unchanged, draft and unmerged as observed. Native Codex review was requested and blocked by quota, not approved. Do not modify a frozen candidate to evade its review boundary. A future code promotion must receive its required review and applicable tests for the exact proposed tree. Documentation/evidence publication neither authorizes nor performs that promotion.

## Preserved history

Existing names, branch heads, PR bases and source layout are preserved. No deletion, rename, force-push, default-branch change or blanket branch merge is part of this organization pass.

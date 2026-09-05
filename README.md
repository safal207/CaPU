# CaPU

**Causal execution admission and recovery — executable references and bounded research.**

CaPU separates authorization to act from evidence that an external effect occurred. An unknown outcome is not permission to retry.

## Start here

| Your goal | Entry point |
|---|---|
| Start in Russian / начать по-русски | [START_HERE.md](START_HERE.md) |
| Run the existing software reference | Commands below |
| Find research, exact sources and limitations | [RESEARCH_INDEX.md](RESEARCH_INDEX.md) |
| Inspect readiness | [PROJECT_STATUS.json](PROJECT_STATUS.json) |
| Preserve work and manage branches | [REPOSITORY_GUIDE.md](REPOSITORY_GUIDE.md) |
| Read the complete previous technical introduction | [README.previous.md](README.previous.md) |

## What can be used today

| Track | Use | Boundary |
|---|---|---|
| Software reference on main | Learn the lifecycle, validate fixtures, run the reference demo | Development/research use; not production certification |
| CaPU × ATMAN v1 | Reproduce process-crash recovery at an exact revision | Draft PR #103; not integrated into main |
| CaPU × ATMAN HTTP v2 | Reproduce separate controller, loopback HTTP device and observer | Draft PR #104; one trusted host, no bypass resistance |
| RTL / formal work | Inspect each profile's own contract and evidence | A software or bounded formal PASS is not a physical-device result |

## Run the main software reference

From a repository checkout with Node.js/npm installed:

```sh
npm ci
npm test
npm run demo:reference
```

These commands come from the existing package scripts. They were not rerun during this documentation pass. The baseline main revision is `0d7b369a2ed70acdbb7df70f24e18b5e7d35f3c5`; navigation publication changes no runtime files or dependencies.

For the separate recovery laboratories, follow the pinned worktree instructions in the [research index](RESEARCH_INDEX.md), not commands for folders absent from main.

## Durable evidence

[CaPU × ATMAN evidence](evidence/capu-atman/2026-09-05/README.md) contains losslessly compressed copies of the original v1/v2 result JSON and test logs, with file hashes, source revisions and reproduction instructions. These are archived historical observations, not new tests or independent attestations. Code remains in its existing pinned PRs.

## Architecture family

[BardoCompute](https://github.com/safal207/BardoCompute): transition representation · [COSMIC-ORGANICS](https://github.com/safal207/COSMIC-ORGANICS): sparse execution · [ATMAN-LATTICE](https://github.com/safal207/ATMAN-LATTICE): authority and governed revision · [CaPU](https://github.com/safal207/CaPU): effect admission and recovery.

This is an integration map, not a verified four-repository system. Full ATMAN, Bardo and COSMIC are not integrated by the recovery experiments.

## Status and history

Readiness snapshot: **2026-09-05**. No production deployment, universal exactly-once guarantee, physical-power-loss guarantee or CPU advantage is established here. UNKNOWN may remain blocked indefinitely.

The original README is preserved byte-for-byte at [README.previous.md](README.previous.md). Existing [license](LICENSE), source layout, CI and research-review gates are unchanged.

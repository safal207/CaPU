# CaPU × ATMAN — preserved evidence, 2026-09-05

[Repository start](../../../README.md) · [Research index](../../../RESEARCH_INDEX.md) · [Manifest](MANIFEST.json)

The four `.gz` files are lossless copies of the original result JSON and test logs provided with the v1 and v2 laboratories. They are stored in Git. Source code remains at exact revisions in the existing draft PRs; this archival publication does not merge or approve those candidates.

| Stage | Source | Recorded local result |
|---|---|---|
| Process recovery v1 | `977864167c65f161e6db87b3d14257a11a67516f` / PR #103 | 55 tests; 288 compared lifecycle steps |
| Loopback HTTP v2 | `8a2f2a37023a50aeac52cb8c8aed84b2eeceec88` / PR #104 | 28 tests = 14 scenarios on two arms; 37 paired observations |

## What was checked during archival

Each compressed file was decompressed and compared byte-for-byte with its original attachment. All eight experiment source hashes recorded in the result files matched the corresponding sources in the supplied v2 package. The Git blob IDs returned for the four uploaded compressed files matched locally calculated blob IDs.

These are archival integrity checks, not a new execution, CI-artifact download, security review or independent attestation. File hashes in the manifest are distinct from each result's embedded digest.

## Inspect and verify

From this directory, run the following Python in a normal interpreter or script. It reads only the four explicitly listed files and prints their uncompressed contents; it does not execute them or overwrite any files.

```python
import gzip
import hashlib
import json
from pathlib import Path

root = Path('.')
manifest = json.loads((root / 'MANIFEST.json').read_text(encoding='utf-8'))
for item in manifest['files']:
    name = item['path']
    if Path(name).name != name or not name.endswith('.gz'):
        raise ValueError('Unexpected evidence path')
    packed = (root / name).read_bytes()
    if len(packed) != item['compressed_bytes'] or hashlib.sha256(packed).hexdigest() != item['compressed_sha256']:
        raise ValueError(f'Compressed evidence mismatch: {name}')
    raw = gzip.decompress(packed)
    if len(raw) != item['original_bytes'] or hashlib.sha256(raw).hexdigest() != item['original_sha256']:
        raise ValueError(f'Original evidence mismatch: {name}')
    print(f'\n--- {name[:-3]} ---\n{raw.decode("utf-8")}')
```

## Trust and review boundaries

Both equal-guarantee conventional controls passed too. No superiority, speed or energy advantage is established. The v2 effect is a deliberately non-idempotent SQLite ledger insertion by a separate loopback HTTP process on one trusted host, not a payment provider or physical device. The bypass control demonstrates that direct unguarded HTTP calls can duplicate the effect. Synthetic receipt authentication, public fixture keys and potentially indefinite UNKNOWN remain limitations.

Native Codex review was requested on the code candidates and blocked by quota. No approval is inferred. No full ATMAN runtime, Bardo or COSMIC integration is claimed.

Reproduction commands and exact source locations are in the [research index](../../../RESEARCH_INDEX.md). Original package ZIP files are not duplicated here because their code is already pinned in Git; this directory preserves the four complete result/log attachments rather than only a summary.

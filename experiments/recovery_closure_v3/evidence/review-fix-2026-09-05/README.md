# Earlier local validator-fix evidence

Lossless archive of all eight evidence files from the previously delivered
validator-fix patch. This is historical Python 3.13.5 / cryptography 46.0.4
local evidence, NOT CI evidence for 50.0.1 and not independent reproduction.

`files.json.bz2.b64` is base64 of a bzip2 JSON object mapping filenames to exact
UTF-8 texts. `MANIFEST.json` records compressed and per-file SHA-256 values.
The `source_patch_sha256` field identifies the original patch, not a new run.

From this directory, inspect without writing files:

```sh
python - <<'PY'
import base64, bz2, hashlib, json
from pathlib import Path
manifest = json.loads(Path('MANIFEST.json').read_text())
packed = base64.b64decode(Path('files.json.bz2.b64').read_text().strip(), validate=True)
if hashlib.sha256(packed).hexdigest() != manifest['compressed_sha256']:
    raise SystemExit('Archive mismatch')
files = json.loads(bz2.decompress(packed))
if set(files) != set(manifest['files']):
    raise SystemExit('Unexpected members')
for name, text in files.items():
    raw = text.encode('utf-8'); expected = manifest['files'][name]
    if len(raw) != expected['bytes'] or hashlib.sha256(raw).hexdigest() != expected['sha256']:
        raise SystemExit('File mismatch: ' + name)
print(files['verification.json'])
PY
```

For new dependency results, inspect the new PR CI artifacts (`ci-evidence` and
`evidence-v3`) and their actual commit/environment records.

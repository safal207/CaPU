"""Restore recorded observations byte-for-byte; does NOT rerun experiments."""
import argparse
import base64
import bz2
import hashlib
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parent

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--output', type=Path, default=ROOT / 'evidence-restored')
    args = parser.parse_args()
    manifest = json.loads((ROOT / 'EVIDENCE_MANIFEST.json').read_text())
    text = ''.join((ROOT / path).read_text().strip() for path in manifest['parts'])
    compressed = base64.b64decode(text, validate=True)
    if hashlib.sha256(compressed).hexdigest() != manifest['compressed_sha256']:
        raise ValueError('compressed evidence hash mismatch')
    data = json.loads(bz2.decompress(compressed))
    if set(data) != set(manifest['files']):
        raise ValueError('unexpected evidence members')
    restored = {}
    for name, value in data.items():
        if Path(name).name != name:
            raise ValueError('invalid evidence filename')
        raw = (json.dumps(value, indent=2, sort_keys=True) + '\n').encode() if name.endswith('.json') else value.encode()
        expected = manifest['files'][name]
        if len(raw) != expected['bytes'] or hashlib.sha256(raw).hexdigest() != expected['sha256']:
            raise ValueError('evidence mismatch: ' + name)
        restored[name] = raw
    args.output.mkdir(parents=True, exist_ok=True)
    for name, raw in restored.items():
        target = args.output / name
        if target.exists() and target.read_bytes() != raw:
            raise FileExistsError('refusing to overwrite different evidence: ' + name)
        target.write_bytes(raw)
    print('RESTORED 4 original evidence files; all sizes and SHA-256 hashes match.')

if __name__ == '__main__':
    main()

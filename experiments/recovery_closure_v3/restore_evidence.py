"""Restore recorded observations byte-for-byte; does NOT rerun experiments."""
import argparse
import base64
import bz2
import hashlib
import json
import os
import stat
from pathlib import Path

ROOT = Path(__file__).resolve().parent


def write_restored(output: Path, restored: dict[str, bytes]) -> None:
    """Use directory descriptors and exclusive no-follow writes (POSIX only).

    Existing matching regular files may be read but are never rewritten.
    Unsupported platforms fail closed rather than falling back to unsafe opens.
    """
    if os.name != 'posix' or not hasattr(os, 'O_NOFOLLOW') or os.open not in os.supports_dir_fd:
        raise RuntimeError('Safe restoration requires POSIX dir_fd and O_NOFOLLOW support')
    flags = os.O_RDONLY | os.O_DIRECTORY | os.O_NOFOLLOW
    absolute = Path(os.path.abspath(output))
    directory = os.open(absolute.anchor, flags)
    try:
        for part in absolute.parts[1:]:
            try:
                os.mkdir(part, 0o700, dir_fd=directory)
            except FileExistsError:
                pass
            child = os.open(part, flags, dir_fd=directory)
            os.close(directory)
            directory = child
        for name, raw in restored.items():
            if Path(name).name != name or name in ('', '.', '..') or '\\' in name:
                raise ValueError('Invalid restored filename')
            try:
                fd = os.open(name, os.O_WRONLY | os.O_CREAT | os.O_EXCL | os.O_NOFOLLOW,
                             0o600, dir_fd=directory)
            except FileExistsError:
                fd = os.open(name, os.O_RDONLY | os.O_NOFOLLOW | os.O_NONBLOCK,
                             dir_fd=directory)
                with os.fdopen(fd, 'rb') as existing:
                    if not stat.S_ISREG(os.fstat(existing.fileno()).st_mode):
                        raise ValueError('Existing evidence is not a regular file: ' + name)
                    if existing.read(len(raw) + 1) != raw:
                        raise FileExistsError('Refusing to overwrite different evidence: ' + name)
                continue
            with os.fdopen(fd, 'wb') as target:
                target.write(raw)
                target.flush()
                os.fsync(target.fileno())
    finally:
        os.close(directory)

def main():
    """Restore the fixed historical archive without relabeling it as a new run."""
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
        if Path(name).name != name or name in ('.', '..', '') or '\\' in name:
            raise ValueError('invalid evidence filename')
        raw = (json.dumps(value, indent=2, sort_keys=True) + '\n').encode() if name.endswith('.json') else value.encode()
        expected = manifest['files'][name]
        if len(raw) != expected['bytes'] or hashlib.sha256(raw).hexdigest() != expected['sha256']:
            raise ValueError('evidence mismatch: ' + name)
        restored[name] = raw
    write_restored(args.output, restored)
    print('RESTORED 4 original evidence files; all sizes and SHA-256 hashes match.')

if __name__ == '__main__':
    main()

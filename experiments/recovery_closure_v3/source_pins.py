"""Load unmodified, hash-checked CaPU/ATMAN source. No code is fetched implicitly."""
from __future__ import annotations
import hashlib
import importlib
import json
from pathlib import Path
import sys
import urllib.request

ROOT = Path(__file__).resolve().parent
REF = '8a2f2a37023a50aeac52cb8c8aed84b2eeceec88'
PINS = {'experiments/capu_atman_recovery_v1/bootstrap.py': 'f78bb3e3908a22188143df27f6079a0de6727205', 'experiments/capu_atman_recovery_v1/proof.py': '58101572a487a454bb4d60e296ab332c81c4b61b', 'experiments/capu_atman_http_recovery_v2/http_boundary.py': '14706efa877a804d9ce90e51b058c201f056b29e', 'LICENSE': '4235d7bdc5e4c3afaf1292abec24d10d88d28360'}


def git_blob(data):
    return hashlib.sha1(b'blob ' + str(len(data)).encode() + b'\0' + data).hexdigest()


def prepare(fetch=False):
    for path, expected in PINS.items():
        dst = ROOT / '.pinned' / path
        if not dst.exists():
            if not fetch:
                raise FileNotFoundError('Run python source_pins.py first: ' + path)
            url = f'https://raw.githubusercontent.com/safal207/CaPU/{REF}/{path}'
            with urllib.request.urlopen(url, timeout=30) as r:
                data = r.read(200000)
            if git_blob(data) != expected:
                raise RuntimeError('Git blob mismatch: ' + path)
            dst.parent.mkdir(parents=True, exist_ok=True)
            dst.write_bytes(data)
        if git_blob(dst.read_bytes()) != expected:
            raise RuntimeError('Git blob mismatch: ' + path)
    v1 = ROOT / '.pinned/experiments/capu_atman_recovery_v1'
    v2 = ROOT / '.pinned/experiments/capu_atman_http_recovery_v2'
    sys.path.insert(0, str(v1))
    old_bootstrap = importlib.import_module('bootstrap')
    old_bootstrap.sources(fetch=fetch)
    sys.path.insert(0, str(v2))
    return importlib.import_module('http_boundary')

if __name__ == '__main__':
    prepare(fetch=True)
    print('Verified source pins:', json.dumps(PINS, sort_keys=True))

"""Fetch pinned, unmodified upstream modules; verify Git blob IDs before use."""
from __future__ import annotations
import hashlib
import importlib.util
from pathlib import Path
import sys
import types
import urllib.request

ROOT = Path(__file__).resolve().parent
PINS = [
    ('capu', 'safal207/CaPU', '5cdaa5280348841bf8448c5a7844c273df257c5d',
     'tools/astra_capu_outcome_reconciliation_a6.py', '4686275e872e5f1348870f09f20fac560be31ff8'),
    ('capu', 'safal207/CaPU', '5cdaa5280348841bf8448c5a7844c273df257c5d',
     'tools/astra_capu_authenticated_receipt_a7.py', 'b79dcf770248a8e8c667f488ebfc36b2d8b80999'),
    ('atman', 'safal207/ATMAN-LATTICE', 'e62c279b9148a7ae9dd1a4654f6ddeea6add4a3f',
     'model/authority.py', '8bb0e7122c3d3acbe5e710ec21537d4413bfb69d'),
]


def verify(data: bytes, expected: str) -> None:
    actual = hashlib.sha1(b'blob ' + str(len(data)).encode() + b'\0' + data).hexdigest()
    if actual != expected:
        raise ValueError(f'Upstream blob mismatch: expected {expected}, got {actual}')


def sources(fetch: bool = False) -> list[Path]:
    paths = []
    for name, repo, ref, path, expected in PINS:
        dest = ROOT / '.upstream' / name / path
        if not dest.exists():
            if not fetch:
                raise FileNotFoundError(f'{dest}: run python bootstrap.py first')
            url = f'https://raw.githubusercontent.com/{repo}/{ref}/{path}'
            with urllib.request.urlopen(url, timeout=30) as response:
                data = response.read(100_000)
            verify(data, expected)
            dest.parent.mkdir(parents=True, exist_ok=True)
            temporary = dest.with_suffix('.download')
            temporary.write_bytes(data)
            temporary.replace(dest)
        verify(dest.read_bytes(), expected)
        paths.append(dest)
    return paths


def module(name: str, path: Path):
    spec = importlib.util.spec_from_file_location(name, path)
    if spec is None or spec.loader is None:
        raise ImportError(str(path))
    value = importlib.util.module_from_spec(spec)
    sys.modules[name] = value
    spec.loader.exec_module(value)
    return value


def load():
    a6_path, a7_path, authority_path = sources()
    # This executable is an isolated experiment, not a replacement tools package.
    if 'tools' not in sys.modules:
        tools = types.ModuleType('tools')
        tools.__path__ = [str(a6_path.parent)]
        sys.modules['tools'] = tools
    a6 = module('tools.astra_capu_outcome_reconciliation_a6', a6_path)
    a7 = module('tools.astra_capu_authenticated_receipt_a7', a7_path)
    authority = module('transition_proof_atman_authority', authority_path)
    return a6, a7, authority


if __name__ == '__main__':
    for path in sources(fetch=True):
        print('PIN_VERIFIED', path.relative_to(ROOT))

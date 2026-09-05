"""Explicit producer-file inventory and honest checkout/archive provenance."""
from __future__ import annotations

import hashlib
from pathlib import Path
import subprocess

ROOT = Path(__file__).resolve().parent
DEPENDENCY_COMMIT = '8a2f2a37023a50aeac52cb8c8aed84b2eeceec88'
SOURCE_FILES = (
    'demo.py', 'finite_model.py', 'observer.py', 'provenance.py',
    'receiver.py', 'restore_evidence.py', 'run.py', 'source_pins.py',
    'test_http.py', 'test_validation.py', 'validate_results.py',
    'requirements.txt', 'evidence_contract.json',
)


def source_hashes(root: Path = ROOT) -> dict[str, str]:
    """Hash the complete declared inventory, rejecting missing or linked sources."""
    hashes = {}
    for name in SOURCE_FILES:
        path = root / name
        if path.is_symlink() or not path.is_file():
            raise ValueError('Missing/non-regular producer input: ' + name)
        hashes[name] = hashlib.sha256(path.read_bytes()).hexdigest()
    return hashes


def revision(root: Path = ROOT) -> dict:
    """Identify the real checkout, or explicitly record that Git is unavailable."""
    def git(*args: str) -> str:
        return subprocess.run(
            ['git', '-C', str(root), *args], capture_output=True, text=True,
            check=True, timeout=10,
        ).stdout.strip()
    try:
        prefix = git('rev-parse', '--show-prefix')
        commit = git('rev-parse', 'HEAD')
        dirty = bool(git('status', '--porcelain', '--untracked-files=all', '--', '.'))
        # A surrounding unrelated Git repository must not label an exported lab.
        tracked = set(git('ls-files', '--', '.').splitlines())
        if not {'run.py', 'receiver.py', 'test_http.py'} <= tracked:
            raise ValueError('Experiment is not tracked in this checkout')
        return {'source_commit': commit, 'source_tree_dirty': dirty,
                'source_revision_status': 'git', 'source_path_prefix': prefix}
    except (OSError, ValueError, subprocess.SubprocessError):
        return {'source_commit': None, 'source_tree_dirty': None,
                'source_revision_status': 'archive_or_git_unavailable',
                'source_path_prefix': None}

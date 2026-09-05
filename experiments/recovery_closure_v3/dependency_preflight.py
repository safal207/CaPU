"""Check the actual installed dependency before running the recovery experiment.

This is a version/smoke-test gate, not a package authenticity attestation or a
vulnerability scan. Historical evidence never goes through this runtime gate.
"""
from __future__ import annotations

import argparse
from importlib import metadata
import json
from pathlib import Path
import platform
import sys

ROOT = Path(__file__).resolve().parent
EXPECTED_VERSION = "50.0.1"


class DependencyError(RuntimeError):
    """The runtime cannot support a claim to have tested the candidate pin."""


def check_version(value: str, label: str) -> None:
    """Reject old, missing, prerelease, or merely claimed compatible versions."""
    if value != EXPECTED_VERSION:
        raise DependencyError(f"{label}: expected {EXPECTED_VERSION}, observed {value!r}")


def check_requirement(path: Path = ROOT / "requirements.txt") -> None:
    """Cross-check the candidate pin against its checked-in requirements file."""
    lines = [line.strip() for line in path.read_text(encoding="utf-8").splitlines()
             if line.strip() and not line.lstrip().startswith("#")]
    if lines != [f"cryptography=={EXPECTED_VERSION}"]:
        raise DependencyError("Unexpected dependency requirement; revise the gate explicitly")


def validate_report(report: dict) -> None:
    """Check recorded version and smoke-test claims; this does not attest a run."""
    keys = {"schema", "package", "installed_version", "module_version", "openssl",
            "python", "ed25519_roundtrip", "changed_message_rejected"}
    if not isinstance(report, dict) or set(report) != keys:
        raise DependencyError("Incomplete or unexpected dependency report")
    if report["schema"] != "capu-dependency-preflight/1" or report["package"] != "cryptography":
        raise DependencyError("Unexpected dependency report identity")
    check_version(report["installed_version"], "Recorded distribution")
    check_version(report["module_version"], "Recorded import")
    if report["ed25519_roundtrip"] is not True or report["changed_message_rejected"] is not True:
        raise DependencyError("Dependency smoke test did not pass")
    for field in ("openssl", "python"):
        if not isinstance(report[field], str) or not report[field].strip():
            raise DependencyError("Missing runtime detail: " + field)


def verify_runtime() -> dict:
    """Read the real installed package and exercise the Ed25519 API it provides."""
    check_requirement()
    try:
        installed = metadata.version("cryptography")
    except metadata.PackageNotFoundError as exc:
        raise DependencyError("cryptography is not installed") from exc
    # Reject before loading fixtures or invoking any HTTP receiver.
    check_version(installed, "Installed cryptography")
    import cryptography
    from cryptography.exceptions import InvalidSignature
    from cryptography.hazmat.backends.openssl.backend import backend
    from cryptography.hazmat.primitives.asymmetric.ed25519 import Ed25519PrivateKey
    check_version(cryptography.__version__, "Imported cryptography")
    # This is deliberately a public, synthetic test key, never a user credential.
    private = Ed25519PrivateKey.from_private_bytes(bytes(range(32)))
    public = private.public_key()
    message = b"CaPU PR106 dependency compatibility smoke test"
    signature = private.sign(message)
    public.verify(signature, message)
    try:
        public.verify(signature, message + b" changed")
    except InvalidSignature:
        rejected = True
    else:
        raise DependencyError("Ed25519 accepted a changed message")
    report = {"schema": "capu-dependency-preflight/1", "package": "cryptography",
              "installed_version": installed, "module_version": cryptography.__version__,
              "openssl": backend.openssl_version_text(), "python": platform.python_version(),
              "ed25519_roundtrip": True, "changed_message_rejected": rejected}
    validate_report(report)
    return report


def main() -> int:
    """Emit a success report only after all real runtime checks pass."""
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path)
    args = parser.parse_args()
    try:
        report = verify_runtime()
        text = json.dumps(report, indent=2, sort_keys=True) + "\n"
        if args.output:
            args.output.parent.mkdir(parents=True, exist_ok=True)
            with args.output.open("x", encoding="utf-8") as stream:
                stream.write(text)
        print(text, end="")
        return 0
    except (DependencyError, ImportError, OSError, ValueError) as exc:
        print("DEPENDENCY_BLOCKED: " + str(exc), file=sys.stderr)
        return 1


if __name__ == "__main__":
    sys.exit(main())

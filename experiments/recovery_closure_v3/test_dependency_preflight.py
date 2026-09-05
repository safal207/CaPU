"""Unit checks of upgrade gating; synthetic positives are NOT compatibility runs."""
from __future__ import annotations
import copy
from importlib import metadata
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest
from unittest import mock
import dependency_preflight as gate

ROOT = Path(__file__).resolve().parent


class DependencyGateTests(unittest.TestCase):
    """Exercise pin enforcement without installing or mocking an upgraded binary."""

    def fixture(self):
        """Return explicitly synthetic metadata for report-validation unit tests."""
        return {"schema": "capu-dependency-preflight/1", "package": "cryptography",
                "installed_version": gate.EXPECTED_VERSION, "module_version": gate.EXPECTED_VERSION,
                "openssl": "synthetic unit fixture", "python": "synthetic unit fixture",
                "ed25519_roundtrip": True, "changed_message_rejected": True}

    def test_candidate_requirement_matches(self):
        """Require an exact checked-in pin, not an open version range."""
        gate.check_requirement()

    def test_old_and_prerelease_versions_rejected(self):
        """The check never silently accepts an old or unrelated version."""
        for value in ("46.0.4", "48.0.1", "50.0.0", "50.0.1rc1", "51.0.0", "", None):
            with self.subTest(version=value), self.assertRaises(gate.DependencyError):
                gate.check_version(value, "unit test")

    def test_exact_version_check(self):
        """Check a version string only; no binary compatibility is inferred."""
        gate.check_version(gate.EXPECTED_VERSION, "unit test")

    def test_changed_requirement_rejected(self):
        """A changed requirements file needs a deliberate gate update."""
        with tempfile.TemporaryDirectory() as td:
            p = Path(td) / "requirements.txt"
            for text in ("cryptography>=50", "cryptography==46.0.4", "", "cryptography==50.0.1\ncffi==2"):
                p.write_text(text)
                with self.subTest(text=text), self.assertRaises(gate.DependencyError):
                    gate.check_requirement(p)

    def test_missing_package_rejected(self):
        """Absent metadata cannot create a success report."""
        with mock.patch.object(gate.metadata, "version", side_effect=metadata.PackageNotFoundError):
            with self.assertRaises(gate.DependencyError):
                gate.verify_runtime()

    def test_old_install_rejected_before_import(self):
        """Stop on installed version before executing crypto or recovery work."""
        with mock.patch.object(gate.metadata, "version", return_value="46.0.4"):
            with self.assertRaisesRegex(gate.DependencyError, "Installed cryptography"):
                gate.verify_runtime()

    def test_complete_synthetic_report_shape(self):
        """A fabricated unit fixture tests shape, not an external success claim."""
        gate.validate_report(self.fixture())

    def test_missing_or_additional_report_field(self):
        """Missing and unexpected claims are rejected."""
        for key in self.fixture():
            data = self.fixture(); data.pop(key)
            with self.subTest(key=key), self.assertRaises(gate.DependencyError):
                gate.validate_report(data)
        data = self.fixture(); data["unverified"] = True
        with self.assertRaises(gate.DependencyError):
            gate.validate_report(data)

    def test_smoke_claims_are_real_booleans(self):
        """Integer truthiness does not count as an executed successful check."""
        for key in ("ed25519_roundtrip", "changed_message_rejected"):
            for value in (False, 1, "true", None):
                data = self.fixture(); data[key] = value
                with self.subTest(key=key, value=value), self.assertRaises(gate.DependencyError):
                    gate.validate_report(data)

    def test_module_and_distribution_both_match(self):
        """Imported-module and installed-distribution versions must agree."""
        for key in ("installed_version", "module_version"):
            data = self.fixture(); data[key] = "46.0.4"
            with self.subTest(key=key), self.assertRaises(gate.DependencyError):
                gate.validate_report(data)

    def test_optimized_wrong_version_still_fails(self):
        """-O and -OO cannot disable the dependency gate."""
        for opt in ("-O", "-OO"):
            result = subprocess.run([sys.executable, opt, "-c",
                                     'import dependency_preflight as d; d.check_version("46.0.4", "unit")'],
                                    cwd=ROOT, capture_output=True, text=True, timeout=10)
            self.assertNotEqual(result.returncode, 0)
            self.assertIn("DependencyError", result.stderr)

    def test_empty_runtime_details_rejected(self):
        """Retain interpreter and backend observations rather than blank labels."""
        for key in ("openssl", "python"):
            data = self.fixture(); data[key] = ""
            with self.subTest(key=key), self.assertRaises(gate.DependencyError):
                gate.validate_report(data)


if __name__ == "__main__":
    unittest.main()

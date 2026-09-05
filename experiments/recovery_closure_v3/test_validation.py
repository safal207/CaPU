"""Negative tests for local evidence verification, not new recovery guarantees."""
from __future__ import annotations

import base64
import bz2
import copy
import hashlib
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest
from unittest import mock

import finite_model
from dependency_preflight import EXPECTED_VERSION
import provenance
import restore_evidence
import validate_results as vr

ROOT = Path(__file__).resolve().parent


class ValidationTests(unittest.TestCase):
    """Mutate isolated fixture copies; never rewrite retained historical evidence."""

    @classmethod
    def setUpClass(cls):
        """Decode exact retained artifacts once without executing the HTTP suite."""
        manifest = json.loads((ROOT / 'EVIDENCE_MANIFEST.json').read_text())
        packed = ''.join((ROOT / p).read_text().strip() for p in manifest['parts'])
        cls.original = json.loads(bz2.decompress(base64.b64decode(packed)))

    def setUp(self):
        """Give each mutation its own fresh directory and schema-/2 unit fixture."""
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.path = Path(self.temp.name)
        for name, value in self.original.items():
            raw = (json.dumps(value, indent=2, sort_keys=True) + '\n') if name.endswith('.json') else value
            (self.path / name).write_text(raw)
        self.s = copy.deepcopy(self.original['summary.json'])
        self.s.update(schema='recovery-closure-experiment/2', **provenance.revision())
        # Synthetic metadata for validator tests, NOT a measured dependency run.
        self.s['environment'] = {'dependencies': {
            'schema': 'capu-dependency-preflight/1', 'package': 'cryptography',
            'installed_version': EXPECTED_VERSION, 'module_version': EXPECTED_VERSION,
            'openssl': 'synthetic unit fixture', 'python': 'synthetic unit fixture',
            'ed25519_roundtrip': True, 'changed_message_rejected': True}}
        self.s['dependency_commit'] = provenance.DEPENDENCY_COMMIT
        self.s['source_sha256'] = provenance.source_hashes()
        self.m = copy.deepcopy(self.original['model.json'])
        self.h = copy.deepcopy(self.original['http-traces.json'])

    def save(self):
        """Write deliberately altered unit-fixture data, not measured results."""
        for name, value in [('summary.json', self.s), ('model.json', self.m), ('http-traces.json', self.h)]:
            (self.path / name).write_text(json.dumps(value, indent=2, sort_keys=True) + '\n')

    def rejected(self, message=None):
        """Require a real validation exception rather than a printed warning."""
        self.save()
        with self.assertRaises(vr.ValidationError) as error:
            vr.validate(self.path)
        if message:
            self.assertIn(message, str(error.exception))

    def test_exact_historical_archive(self):
        """Exact historical bytes are accepted only as historical evidence."""
        self.assertEqual(vr.validate(self.path, historical=True)['status'], 'VALIDATED')

    def test_historical_requires_explicit_mode(self):
        """Old schema is not silently labeled a fresh run."""
        with self.assertRaises(vr.ValidationError):
            vr.validate(self.path)

    def test_fresh_unit_fixture(self):
        """The complete schema-/2 test fixture is accepted."""
        self.save()
        self.assertEqual(vr.validate(self.path)['status'], 'VALIDATED')

    def test_empty_missing_extra_or_changed_source_inventory(self):
        """Source checks cannot be disabled by editing their input inventory."""
        expected = dict(self.s['source_sha256'])
        variants = [{}, {k:v for k,v in expected.items() if k != 'run.py'},
                    {**expected, '../unrelated': '0'*64}, {**expected, 'run.py': '0'*64}]
        for variant in variants:
            with self.subTest(keys=sorted(variant)):
                self.s['source_sha256'] = variant
                self.rejected()

    def test_dependency_version_mislabel_is_rejected(self):
        """A fresh result made with the old dependency is not an upgrade result."""
        self.s['environment']['dependencies']['installed_version'] = '46.0.4'
        self.rejected('Recorded distribution')

    def test_missing_dependency_report_is_rejected(self):
        """Fresh evidence must include actual runtime compatibility metadata."""
        self.s['environment'].pop('dependencies')
        self.rejected('dependency report')

    def test_failed_dependency_smoke_is_rejected(self):
        """A version string alone does not count as a successful runtime check."""
        self.s['environment']['dependencies']['changed_message_rejected'] = False
        self.rejected('smoke test')

    def test_source_file_absence(self):
        """Missing local producer inputs are errors, not optional entries."""
        with self.assertRaises(ValueError):
            provenance.source_hashes(self.path)

    def test_source_commit_misattribution(self):
        """A plausible but different 40-hex commit is rejected."""
        self.s['source_commit'] = 'f' * 40
        self.rejected('revision mismatch')

    def test_dependency_commit_misattribution(self):
        """Dependency and experiment revisions cannot be interchanged."""
        self.s['dependency_commit'] = 'f' * 40
        self.rejected('Dependency revision')

    def test_dirty_status_misattribution(self):
        """A changed checkout status cannot be silently presented as clean."""
        self.s['source_tree_dirty'] = not self.s['source_tree_dirty']
        self.rejected('revision mismatch')

    def test_two_equally_wrong_engines_are_rejected_by_oracle(self):
        """Agreement is insufficient even when the forged expected value agrees."""
        for row in self.h:
            if row.get('policy') == 'atomic_fence' and row['gate'] == 'after_check':
                row['final_effects'] = row['expected_effects'] = 2
                row['steps'][-1]['witness']['effect_count'] = 2
                row['steps'][-1]['witness']['effect_rows'].append(['[167,2,7,1,9,12]', 0])
        self.s['http_matrix'] = [{k:v for k,v in r.items() if k != 'steps'} for r in self.h if 'policy' in r]
        self.rejected('Wrong actual effect count')

    def test_forged_declared_expectation(self):
        """The report does not supply its own success oracle."""
        row = next(r for r in self.h if 'policy' in r)
        row['expected_effects'] = 99
        self.rejected('Wrong declared oracle')

    def test_missing_or_duplicate_http_identity(self):
        """One engine cannot stand in for a missing second engine."""
        row = next(r for r in self.h if r.get('engine') == 'native' and 'policy' in r)
        row['engine'] = 'baseline'
        self.rejected('HTTP scenario')

    def test_missing_http_record(self):
        """A shortened transcript does not keep the success verdict."""
        self.h.pop()
        self.rejected()

    def test_wrong_http_aggregate(self):
        """Saved presentation figures must match the raw records."""
        self.s['http_matrix'][0]['final_effects'] = 99
        self.rejected('HTTP summary')

    def test_wrong_model_aggregate(self):
        """Model totals in the summary are not trusted independently."""
        self.s['model_summary'][0]['duplicate_traces'] = 99
        self.rejected('Summary/model')

    def test_forged_pair_summary(self):
        """A manually set or omitted equality flag is rejected."""
        self.s['native_fsm_comparisons'][0]['equal'] = False
        self.rejected('Comparison summary')

    def test_rehashed_wrong_model(self):
        """Rehashing a modified trace does not make its wrong outcome correct."""
        trace = next(t for t in self.m['traces'] if t['policy'] == 'atomic_fence')
        trace['effect_count'] = 2
        trace['duplicate'] = True
        trace['incomplete'] = False
        trace['history'][-1]['effect_attempts'] = [0, 1]
        self.m['trace_sha256'] = hashlib.sha256(vr.canonical(self.m['traces'])).hexdigest()
        self.rejected('Wrong bounded-model outcome')

    def test_boundary_identity(self):
        """All seven intended boundary records are required."""
        next(r for r in self.h if 'boundary' in r)['boundary'] = 'unknown'
        self.rejected('Boundary identities')

    def test_boundary_raw_witness_change(self):
        """A less prominent negative-case witness is covered by the contract pin."""
        next(r for r in self.h if r.get('boundary') == 'receiver_restart')['after']['effect_count'] = 2
        self.rejected('HTTP transcript')

    def test_failure_skip_and_bool_counts(self):
        """False success, skipped tests and boolean counts must fail closed."""
        for key, value in [('errors', 1), ('failures', 40), ('skipped', 1), ('errors', False)]:
            with self.subTest(key=key, value=value):
                self.s['http_tests'] = dict(vr.EXPECTED_TESTS)
                self.s['http_tests'][key] = value
                self.rejected('HTTP test counts')
        self.s['http_tests'] = dict(vr.EXPECTED_TESTS)
        self.s['success'] = False
        self.rejected('did not succeed')

    def test_modified_observed_summary(self):
        """Retained human-facing figures cannot drift from their historical bytes."""
        self.save()
        obs = json.loads((ROOT / 'evidence/observed-summary.json').read_text())
        obs['native_fsm_all_equal'] = False
        path = self.path / 'observation.json'
        path.write_text(json.dumps(obs))
        with self.assertRaises(vr.ValidationError):
            vr.validate(self.path, observation=path)

    def test_duplicate_json_keys(self):
        """Ambiguous duplicated fields are rejected before interpretation."""
        self.save()
        (self.path / 'summary.json').write_text('{"success": false, "success": true}')
        with self.assertRaises(vr.ValidationError):
            vr.validate(self.path)

    def test_nonfinite_json(self):
        """Non-standard JSON numbers are not silently accepted."""
        path = self.path / 'bad.json'
        path.write_text('{"n": NaN}')
        with self.assertRaises(vr.ValidationError):
            vr.load_json(path)

    def test_cli_rejects_missing_and_malformed_files(self):
        """CLI returns a nonzero exit status, including under -O."""
        (self.path / 'summary.json').write_text('not json')
        result = subprocess.run([sys.executable, '-O', str(ROOT / 'validate_results.py'), str(self.path)],
                                capture_output=True, text=True, timeout=15)
        self.assertNotEqual(result.returncode, 0)
        self.assertIn('REJECTED', result.stderr)

    def test_cli_optimized_valid_and_invalid_evidence(self):
        """-O, -OO and PYTHONOPTIMIZE do not disable evidence checks."""
        for flags, optimize in [(['-O'], None), (['-OO'], None), ([], '1')]:
            with self.subTest(flags=flags, env=optimize):
                self.s['success'] = True
                self.save()
                env = dict(os.environ)
                if optimize:
                    env['PYTHONOPTIMIZE'] = optimize
                command = [sys.executable, *flags, str(ROOT / 'validate_results.py'), str(self.path)]
                result = subprocess.run(command, capture_output=True, text=True, env=env, timeout=15)
                self.assertEqual(result.returncode, 0, result.stderr)
                self.s['success'] = False
                self.save()
                result = subprocess.run(command, capture_output=True, text=True, env=env, timeout=15)
                self.assertNotEqual(result.returncode, 0)

    def test_finite_model_invariants_survive_optimization(self):
        """A broken schedule enumerator cannot pass the model's invariant check."""
        script = 'import finite_model; finite_model.schedules=lambda: []; finite_model.run()'
        result = subprocess.run([sys.executable, '-O', '-c', script], cwd=ROOT,
                                capture_output=True, text=True, timeout=15)
        self.assertNotEqual(result.returncode, 0)
        self.assertIn('AssertionError', result.stderr)


class RestorationTests(unittest.TestCase):
    """Exercise defensive restoration only in isolated temporary directories."""

    def setUp(self):
        """Create an isolated directory for each no-follow regression check."""
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.output = self.root / 'out'
        self.data = {'sample.json': b'{"ok": true}\n'}

    def test_create_and_matching_existing_file(self):
        """Matching files are retained byte-for-byte without being rewritten."""
        restore_evidence.write_restored(self.output, self.data)
        p = self.output / 'sample.json'
        stamp = p.stat().st_mtime_ns
        restore_evidence.write_restored(self.output, self.data)
        self.assertEqual(p.read_bytes(), self.data['sample.json'])
        self.assertEqual(p.stat().st_mtime_ns, stamp)

    def test_different_existing_file(self):
        """Never overwrite a different existing artifact."""
        self.output.mkdir()
        (self.output / 'sample.json').write_bytes(b'preserve')
        with self.assertRaises(FileExistsError):
            restore_evidence.write_restored(self.output, self.data)
        self.assertEqual((self.output / 'sample.json').read_bytes(), b'preserve')

    def test_symlink_file(self):
        """A symlink at the output filename is not followed."""
        self.output.mkdir()
        other = self.root / 'other'
        other.write_bytes(b'preserve')
        (self.output / 'sample.json').symlink_to(other)
        with self.assertRaises(OSError):
            restore_evidence.write_restored(self.output, self.data)
        self.assertEqual(other.read_bytes(), b'preserve')

    def test_symlink_directory(self):
        """A symlink at an output-directory component is rejected."""
        other = self.root / 'other'
        other.mkdir()
        self.output.symlink_to(other, target_is_directory=True)
        with self.assertRaises(OSError):
            restore_evidence.write_restored(self.output, self.data)
        self.assertEqual(list(other.iterdir()), [])

    def test_non_regular_existing_file(self):
        """Reject a FIFO without blocking on its read side."""
        self.output.mkdir()
        os.mkfifo(self.output / 'sample.json')
        with self.assertRaises(ValueError):
            restore_evidence.write_restored(self.output, self.data)

    def test_invalid_member_name(self):
        """Archive member names must be simple non-special basenames."""
        for name in ('../outside', '.', '..', '/absolute', 'a\\b'):
            with self.subTest(name=name), self.assertRaises((ValueError, OSError)):
                restore_evidence.write_restored(self.output, {name: b'no'})

    def test_unsupported_platform_fails_closed(self):
        """Unsupported no-follow semantics must not fall back to Path.write_bytes."""
        with mock.patch.object(restore_evidence.os, 'name', 'unsupported'):
            with self.assertRaises(RuntimeError):
                restore_evidence.write_restored(self.output, self.data)
        self.assertFalse(self.output.exists())


if __name__ == '__main__':
    unittest.main()

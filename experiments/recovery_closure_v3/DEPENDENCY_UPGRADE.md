# Actual dependency gate — 2026-09-05

This follow-up completes the remaining runtime-preflight portion of the prepared
publication candidate. It builds on `c3960204c6a63c9e7f804a65abf0269b5daf726c`;
it does not replace that commit with the old all-in-one patch.

## What changed

`dependency_preflight.py` checks the exact checked-in requirement, installed
distribution version, imported module version, a real Ed25519 sign/verify round
trip, and rejection of a changed message. Expected version: `cryptography==50.0.1`.
The key is a public synthetic fixture, not a credential.

`run.py` and `demo.py` call this gate before importing HTTP fixtures. Fresh
summary evidence records the report under `environment.dependencies`; the
validator requires its complete shape, matching versions, and successful smoke
checks. Both new Python files are part of the explicit producer inventory.

Historical archive bytes and their original metadata remain untouched. Use
`--historical` only for the exact retained original archive. A result made at an
earlier code revision should be validated with that pinned revision, not relabeled
as a fresh result of the new producer.

## Reproduce

From `experiments/recovery_closure_v3` in a checkout of the desired exact commit:

```sh
python -m pip install -r requirements.txt
python -m pip check
python dependency_preflight.py
python -O dependency_preflight.py
python source_pins.py
python -m unittest -v test_validation test_dependency_preflight
python -O -m unittest -v test_validation test_dependency_preflight
python run.py --output ../../evidence-v3
python validate_results.py ../../evidence-v3
python -O validate_results.py ../../evidence-v3
python demo.py --case delayed
python demo.py --case lost
```

There are 47 validator/restoration/dependency test methods, executed in two
interpreter modes; this is not 94 independent safety guarantees. The HTTP suite
remains 40 methods and the finite model remains 560 bounded traces. Synthetic
positive metadata in unit tests tests the validator; it is not a measured
compatibility run.

CI checks out the exact PR head (or the dispatched SHA), installs the actual
pin, records the normal and optimized preflight reports, runs the tests, full
experiment and both demonstrations, and audits runtime requirements in a
separate environment. It preserves the existing contents-read-only permission
and disabled checkout credential persistence. Inspect the final candidate's
actual CI jobs and artifacts; an earlier commit's green badge is not this run.

## Local checks and limitations

The supplied publication archive had all 68 manifest entries verified. Thirteen
base code/config files matched the Git blob identities at `c3960204...` before
applying only the remaining delta. The updated 47-method suite passed normally
and under `-O` on local Python 3.13.5.

Local cryptography remained 46.0.4: both actual preflight invocations rejected it
with exit status 1. A local full HTTP run with 50.0.1 is NOT claimed. The new
version's real execution must be established from the exact-head CI. Complete
local test logs and input hashes are retained in
`evidence/dependency-gate-2026-09-05/LOCAL_CHECKS.json`.

To decode those historical local logs without executing their contents:

```python
import base64, bz2, hashlib, json
from pathlib import Path
p = Path('evidence/dependency-gate-2026-09-05/LOCAL_CHECKS.json')
entry = json.loads(p.read_text())['logs']
raw = bz2.decompress(base64.b64decode(entry['data'], validate=True))
if len(raw) != entry['bytes'] or hashlib.sha256(raw).hexdigest() != entry['sha256']:
    raise SystemExit('Local log archive mismatch')
logs = json.loads(raw)
print('\n'.join(logs))
```

A version/smoke report is neither a package-authenticity attestation nor a
vulnerability scan, and report-shape validation cannot prove an independent
execution. The fixed source/outcome contract remains trusted. No change to the
recovery algorithm, real-payment guarantees, production readiness, architectural
superiority or investment claims is made. No merge or external email is included.
Assistant self-review and CodeRabbit are requested without Codex; keep the PR draft.

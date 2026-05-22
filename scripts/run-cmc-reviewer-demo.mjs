#!/usr/bin/env node

import { spawnSync } from 'node:child_process'
import { fileURLToPath } from 'node:url'
import { dirname, resolve } from 'node:path'

const __filename = fileURLToPath(import.meta.url)
const __dirname = dirname(__filename)
const repoRoot = resolve(__dirname, '..')
const cmcDir = resolve(repoRoot, 'rust/cmc-core')

const rustStep = (name, args, proves) => ({ name, command: 'cargo', args, cwd: cmcDir, proves })
const npmStep = (name, script, proves) => ({
  name,
  command: 'npm',
  args: ['run', script],
  cwd: repoRoot,
  proves,
})

const steps = [
  rustStep('formatting normalization', ['fmt', '--all'], 'Rust sources can be normalized consistently before executable checks.'),
  npmStep('runtime HTTP fixture schema validation', 'validate:runtime-http', 'Saved runtime HTTP request and response fixtures conform to explicit JSON schemas.'),
  npmStep('runtime HTTP API manifest validation', 'validate:runtime-http-manifest', 'The runtime HTTP API manifest maps routes, cases, boundaries, and fixtures to existing checked evidence.'),
  npmStep('runtime HTTP OpenAPI-lite validation', 'validate:runtime-http-openapi-lite', 'The OpenAPI-lite contract covers every manifest route and explicitly records raw HTTP boundary cases.'),
  rustStep('simulator tests', ['test', '--all', '--locked'], 'CMC simulator invariants and CaPU reference units are enforced by tests.'),
  rustStep('blocked-transition demo', ['run', '--bin', 'cmc_demo', '--locked'], 'Illegitimate transitions are blocked and traced.'),
  rustStep('valid trace hash-chain demo', ['run', '--bin', 'verify_trace', '--locked'], 'Expected trace evidence can be verified with the legacy developer hash demo.'),
  rustStep('tampering detection demo', ['run', '--bin', 'verify_trace_tampered', '--locked'], 'Modified trace decisions are detected by the legacy developer hash demo.'),
  rustStep('sha256 trace verification demo', ['run', '--bin', 'verify_trace_sha256', '--locked'], 'Expected trace evidence can be sealed and verified with the std-only SHA-256 reference path.'),
  rustStep('sha256 tampering detection demo', ['run', '--bin', 'verify_trace_sha256_tampered', '--locked'], 'Modified trace decisions are detected by the SHA-256 reference path.'),
  rustStep('sha256 sealed fixture verification', ['run', '--bin', 'verify_trace_sha256_fixture', '--locked'], 'Saved SHA-256 sealed trace fixtures are executable-verified, including tamper detection.'),
  rustStep('persona boundary fixtures', ['run', '--bin', 'persona_boundary_verify', '--locked'], 'Persona memory, state-change, action-commit, and introspection boundaries are manifest-linked and fixture-verified.'),
  rustStep('persona audit report jsonl', ['run', '--bin', 'persona_audit_report', '--locked'], 'Persona/action boundary evidence can be emitted as auditor-facing JSONL.'),
  rustStep('persona audit report examples', ['run', '--bin', 'persona_audit_report_example_verify', '--locked'], 'Saved valid and drift persona/action audit report examples preserve expected schema semantics.'),
  rustStep('persona sha256 sealed fixture verification', ['run', '--bin', 'verify_persona_sha256_fixture', '--locked'], 'Saved SHA-256 sealed persona/action fixtures are executable-verified, including P6 action tamper detection at event 5.'),
  rustStep('capu p6 pipeline demo', ['run', '--bin', 'capu_p6_pipeline_demo', '--locked'], 'CaPU software reference units execute decode -> boundary route -> decision -> audit -> seal -> replay for P6 external actions.'),
  rustStep('capu p6 replay verifier', ['run', '--bin', 'capu_p6_replay_verify', '--locked'], 'Sealed CaPU P6 audit evidence can be independently replay-verified.'),
  rustStep('capu p6 fixture verifier', ['run', '--bin', 'capu_p6_fixture_verify', '--locked'], 'Saved sealed CaPU P6 audit fixtures can be replay-verified and tamper-detected.'),
  rustStep('capu p6 action variants verifier', ['run', '--bin', 'capu_p6_action_variants_verify', '--locked'], 'P6 action-commit semantics apply across multiple external action kinds, not only send_email.'),
  rustStep('capu fixture manifest verifier', ['run', '--bin', 'capu_manifest_verify', '--locked'], 'CaPU saved fixtures are manifest-linked and replay/tamper verified.'),
  rustStep('capu p1 persona memory verifier', ['run', '--bin', 'capu_p1_persona_memory_verify', '--locked'], 'P1 persona-memory writes require explicit causal support and emit sealed audit evidence.'),
  rustStep('capu p1 fixture verifier', ['run', '--bin', 'capu_p1_fixture_verify', '--locked'], 'Saved sealed CaPU P1 persona-memory fixtures can be replay-verified through the reviewer path.'),
  rustStep('capu runtime sidecar smoke', ['run', '--bin', 'capu_runtime_sidecar_smoke', '--locked'], 'The runtime sidecar MVP exposes health, decide, audit, and replay route semantics over the CaPU reference units.'),
  rustStep('capu runtime http sidecar self-test', ['run', '--bin', 'capu_runtime_http_sidecar', '--locked', '--', '--self-test'], 'The runtime HTTP sidecar accepts real local HTTP requests for health, decide, audit, and replay fixtures.'),
  rustStep('replay fixture structure', ['run', '--bin', 'replay_fixture_verify', '--locked'], 'Replay fixtures preserve expected semantic structure.'),
  rustStep('replay fixture fingerprints', ['run', '--bin', 'replay_fingerprint_verify', '--locked'], 'Replay fixture drift is detectable.'),
  rustStep('audit report jsonl', ['run', '--bin', 'cmc_audit_report', '--locked'], 'Manifest-linked replay evidence can be emitted as auditor-facing JSONL.'),
  rustStep('audit report examples', ['run', '--bin', 'audit_report_example_verify', '--locked'], 'Saved valid and drift audit report examples preserve expected schema semantics.'),
  rustStep('replay divergence detection', ['run', '--bin', 'trace_divergence', '--locked'], 'Expected and diverged traces can be compared.'),
]

console.log('CMC reviewer demo')
console.log('goal=verify executable evidence for causal transition legitimacy')
console.log('')

const results = []

for (const step of steps) {
  console.log(`==> ${step.name}`)
  console.log(`command=${step.command} ${step.args.join(' ')}`)
  console.log(`proves=${step.proves}`)

  const result = spawnSync(step.command, step.args, {
    cwd: step.cwd,
    stdio: 'inherit',
    shell: process.platform === 'win32',
  })

  if (result.error) {
    console.error(`result=failed step=${step.name} reason=${result.error.message}`)
    process.exit(1)
  }

  if (result.status !== 0) {
    console.error(`result=failed step=${step.name} exit_code=${result.status}`)
    process.exit(result.status ?? 1)
  }

  results.push(step.name)
  console.log(`status=ok step=${step.name}`)
  console.log('')
}

console.log('CMC reviewer demo summary')
for (const name of results) {
  console.log(`- ${name}: ok`)
}
console.log('result=reviewer_baseline_passed')
console.log('claim=transition legitimacy can be represented, replayed, checked, reported, persona-boundary-verified, action-commit-verified, persona-audit-reportable, persona-audit-example-verified, persona-sha256-sealed, field-level example-verified, SHA-256 sealed, fixture-verified, CaPU-P6-pipeline-verified, CaPU-P6-replay-verified, CaPU-P6-fixture-verified, CaPU-P6-action-variants-verified, CaPU-manifest-verified, CaPU-P1-persona-memory-verified, CaPU-P1-fixture-verified, CaPU-runtime-sidecar-smoke-verified, CaPU-runtime-http-sidecar-verified, CaPU-runtime-http-schema-verified, CaPU-runtime-http-api-manifest-verified, CaPU-runtime-http-openapi-lite-verified, and regression-tested')
console.log('note=this is an executable research scaffold, not production-ready infrastructure')

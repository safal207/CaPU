#!/usr/bin/env node

import { spawnSync } from 'node:child_process'
import { fileURLToPath } from 'node:url'
import { dirname, resolve } from 'node:path'

const __filename = fileURLToPath(import.meta.url)
const __dirname = dirname(__filename)
const repoRoot = resolve(__dirname, '..')
const cmcDir = resolve(repoRoot, 'rust/cmc-core')

const steps = [
  {
    name: 'formatting',
    command: 'cargo',
    args: ['fmt', '--check'],
    cwd: cmcDir,
    proves: 'Rust sources are formatted consistently.',
  },
  {
    name: 'simulator tests',
    command: 'cargo',
    args: ['test', '--all', '--locked'],
    cwd: cmcDir,
    proves: 'CMC simulator invariants are enforced by tests.',
  },
  {
    name: 'blocked-transition demo',
    command: 'cargo',
    args: ['run', '--bin', 'cmc_demo', '--locked'],
    cwd: cmcDir,
    proves: 'Illegitimate transitions are blocked and traced.',
  },
  {
    name: 'valid trace hash-chain demo',
    command: 'cargo',
    args: ['run', '--bin', 'verify_trace', '--locked'],
    cwd: cmcDir,
    proves: 'Expected trace evidence can be verified with the legacy developer hash demo.',
  },
  {
    name: 'tampering detection demo',
    command: 'cargo',
    args: ['run', '--bin', 'verify_trace_tampered', '--locked'],
    cwd: cmcDir,
    proves: 'Modified trace decisions are detected by the legacy developer hash demo.',
  },
  {
    name: 'sha256 trace verification demo',
    command: 'cargo',
    args: ['run', '--bin', 'verify_trace_sha256', '--locked'],
    cwd: cmcDir,
    proves: 'Expected trace evidence can be sealed and verified with the std-only SHA-256 reference path.',
  },
  {
    name: 'sha256 tampering detection demo',
    command: 'cargo',
    args: ['run', '--bin', 'verify_trace_sha256_tampered', '--locked'],
    cwd: cmcDir,
    proves: 'Modified trace decisions are detected by the SHA-256 reference path.',
  },
  {
    name: 'sha256 sealed fixture verification',
    command: 'cargo',
    args: ['run', '--bin', 'verify_trace_sha256_fixture', '--locked'],
    cwd: cmcDir,
    proves: 'Saved SHA-256 sealed trace fixtures are executable-verified, including tamper detection.',
  },
  {
    name: 'persona boundary fixtures',
    command: 'cargo',
    args: ['run', '--bin', 'persona_boundary_verify', '--locked'],
    cwd: cmcDir,
    proves: 'Persona memory, state-change, and introspection boundaries are manifest-linked and fixture-verified.',
  },
  {
    name: 'persona audit report jsonl',
    command: 'cargo',
    args: ['run', '--bin', 'persona_audit_report', '--locked'],
    cwd: cmcDir,
    proves: 'Persona boundary evidence can be emitted as auditor-facing JSONL.',
  },
  {
    name: 'persona audit report examples',
    command: 'cargo',
    args: ['run', '--bin', 'persona_audit_report_example_verify', '--locked'],
    cwd: cmcDir,
    proves: 'Saved valid and drift persona audit report examples preserve expected schema semantics.',
  },
  {
    name: 'replay fixture structure',
    command: 'cargo',
    args: ['run', '--bin', 'replay_fixture_verify', '--locked'],
    cwd: cmcDir,
    proves: 'Replay fixtures preserve expected semantic structure.',
  },
  {
    name: 'replay fixture fingerprints',
    command: 'cargo',
    args: ['run', '--bin', 'replay_fingerprint_verify', '--locked'],
    cwd: cmcDir,
    proves: 'Replay fixture drift is detectable.',
  },
  {
    name: 'audit report jsonl',
    command: 'cargo',
    args: ['run', '--bin', 'cmc_audit_report', '--locked'],
    cwd: cmcDir,
    proves: 'Manifest-linked replay evidence can be emitted as auditor-facing JSONL.',
  },
  {
    name: 'audit report examples',
    command: 'cargo',
    args: ['run', '--bin', 'audit_report_example_verify', '--locked'],
    cwd: cmcDir,
    proves: 'Saved valid and drift audit report examples preserve expected schema semantics.',
  },
  {
    name: 'replay divergence detection',
    command: 'cargo',
    args: ['run', '--bin', 'trace_divergence', '--locked'],
    cwd: cmcDir,
    proves: 'Expected and diverged traces can be compared.',
  },
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
console.log('claim=transition legitimacy can be represented, replayed, checked, reported, persona-boundary-verified, persona-audit-reportable, persona-audit-example-verified, field-level example-verified, SHA-256 sealed, fixture-verified, and regression-tested')
console.log('note=this is an executable research scaffold, not production-ready infrastructure')

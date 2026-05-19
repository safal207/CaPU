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
    proves: 'Expected trace evidence can be verified.',
  },
  {
    name: 'tampering detection demo',
    command: 'cargo',
    args: ['run', '--bin', 'verify_trace_tampered', '--locked'],
    cwd: cmcDir,
    proves: 'Modified trace decisions are detected.',
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
console.log('claim=transition legitimacy can be represented, replayed, checked, and regression-tested')
console.log('note=this is an executable research scaffold, not production-ready infrastructure')

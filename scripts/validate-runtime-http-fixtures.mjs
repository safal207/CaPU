#!/usr/bin/env node

import fs from 'node:fs'
import path from 'node:path'
import { fileURLToPath } from 'node:url'

const __filename = fileURLToPath(import.meta.url)
const __dirname = path.dirname(__filename)
const repoRoot = path.resolve(__dirname, '..')

const requestSchemaPath = path.join(repoRoot, 'schemas/runtime-http/request.schema.json')
const responseSchemaPath = path.join(repoRoot, 'schemas/runtime-http/response.schema.json')
const fixtureRoot = path.join(repoRoot, 'rust/cmc-core/fixtures/capu_runtime_http')
const requestDir = path.join(fixtureRoot, 'requests')
const responseDir = path.join(fixtureRoot, 'responses')

function readJson(filePath) {
  return JSON.parse(fs.readFileSync(filePath, 'utf8'))
}

function fixtureFiles(dir) {
  return fs
    .readdirSync(dir)
    .filter((name) => name.endsWith('.json'))
    .sort()
    .map((name) => path.join(dir, name))
}

function fail(kind, filePath, reason) {
  const relative = path.relative(repoRoot, filePath)
  console.error(`result=runtime_http_fixture_schema_failed kind=${kind} fixture=${relative}`)
  console.error(`reason=${reason}`)
  process.exit(1)
}

function assertString(value, field, kind, filePath) {
  if (typeof value !== 'string' || value.length === 0) {
    fail(kind, filePath, `${field} must be a non-empty string`)
  }
}

function assertIntegerOrNull(value, field, kind, filePath) {
  if (value !== null && (!Number.isInteger(value) || value < 0)) {
    fail(kind, filePath, `${field} must be a non-negative integer or null`)
  }
}

function assertOnlyKeys(value, allowedKeys, kind, filePath) {
  for (const key of Object.keys(value)) {
    if (!allowedKeys.includes(key)) {
      fail(kind, filePath, `unexpected key ${key}`)
    }
  }
}

function validateRequest(value, filePath) {
  if (value.transition_type === 'persona_memory') {
    assertOnlyKeys(value, ['transition_type', 'transition_id', 'memory', 'cause_id'], 'request', filePath)
    assertString(value.transition_id, 'transition_id', 'request', filePath)
    assertString(value.memory, 'memory', 'request', filePath)
    assertIntegerOrNull(value.cause_id, 'cause_id', 'request', filePath)
    return
  }

  if (value.transition_type === 'external_action') {
    assertOnlyKeys(
      value,
      ['transition_type', 'transition_id', 'action_kind', 'cause_id', 'commit'],
      'request',
      filePath,
    )
    assertString(value.transition_id, 'transition_id', 'request', filePath)
    assertString(value.action_kind, 'action_kind', 'request', filePath)
    assertIntegerOrNull(value.cause_id, 'cause_id', 'request', filePath)
    if (typeof value.commit !== 'boolean') {
      fail('request', filePath, 'commit must be boolean')
    }
    return
  }

  if (value.replay === 'canonical_pair') {
    assertOnlyKeys(value, ['invariant_id', 'replay'], 'request', filePath)
    if (!['P1', 'P6'].includes(value.invariant_id)) {
      fail('request', filePath, 'invariant_id must be P1 or P6')
    }
    return
  }

  fail('request', filePath, 'unknown request fixture shape')
}

function validateResponse(value, filePath) {
  if (value.route === '/capu/health') {
    assertOnlyKeys(value, ['route', 'status', 'service'], 'response', filePath)
    if (value.status !== 'ok') fail('response', filePath, 'health status must be ok')
    if (value.service !== 'capu-runtime-http-sidecar') {
      fail('response', filePath, 'health service mismatch')
    }
    return
  }

  if (value.route === '/capu/decide') {
    assertOnlyKeys(
      value,
      ['route', 'decision_class', 'code', 'invariant_id', 'boundary', 'verdict'],
      'response',
      filePath,
    )
    if (!['accept', 'reject', 'hold'].includes(value.decision_class)) {
      fail('response', filePath, 'decision_class must be accept, reject, or hold')
    }
    assertString(value.code, 'code', 'response', filePath)
    if (!['P1', 'P6', 'CAPU'].includes(value.invariant_id)) {
      fail('response', filePath, 'invariant_id must be P1, P6, or CAPU')
    }
    assertString(value.boundary, 'boundary', 'response', filePath)
    assertString(value.verdict, 'verdict', 'response', filePath)
    return
  }

  if (value.route === '/capu/audit') {
    assertOnlyKeys(
      value,
      ['route', 'transition_id', 'invariant_id', 'boundary', 'verdict', 'accepted'],
      'response',
      filePath,
    )
    assertString(value.transition_id, 'transition_id', 'response', filePath)
    if (!['P1', 'P6', 'CAPU'].includes(value.invariant_id)) {
      fail('response', filePath, 'invariant_id must be P1, P6, or CAPU')
    }
    assertString(value.boundary, 'boundary', 'response', filePath)
    assertString(value.verdict, 'verdict', 'response', filePath)
    if (typeof value.accepted !== 'boolean') {
      fail('response', filePath, 'accepted must be boolean')
    }
    return
  }

  if (value.route === '/capu/replay') {
    assertOnlyKeys(
      value,
      [
        'route',
        'invariant_id',
        'result',
        'events',
        'p1_boundary_events',
        'p6_boundary_events',
        'rejected_without_cause',
        'rejected_without_commit',
      ],
      'response',
      filePath,
    )
    if (!['P1', 'P6'].includes(value.invariant_id)) {
      fail('response', filePath, 'invariant_id must be P1 or P6')
    }
    if (value.result !== 'capu_runtime_http_replay_valid') {
      fail('response', filePath, 'unexpected replay result')
    }
    if (!Number.isInteger(value.events) || value.events < 1) {
      fail('response', filePath, 'events must be a positive integer')
    }
    for (const optional of [
      'p1_boundary_events',
      'p6_boundary_events',
      'rejected_without_cause',
      'rejected_without_commit',
    ]) {
      if (optional in value && (!Number.isInteger(value[optional]) || value[optional] < 0)) {
        fail('response', filePath, `${optional} must be a non-negative integer`)
      }
    }
    return
  }

  fail('response', filePath, 'unknown response fixture route')
}

// Keep schema files part of the evidence surface even though this validator is
// dependency-free in CI.
readJson(requestSchemaPath)
readJson(responseSchemaPath)

let checked = 0

for (const filePath of fixtureFiles(requestDir)) {
  validateRequest(readJson(filePath), filePath)
  checked += 1
  console.log(`status=ok kind=request fixture=${path.relative(repoRoot, filePath)}`)
}

for (const filePath of fixtureFiles(responseDir)) {
  validateResponse(readJson(filePath), filePath)
  checked += 1
  console.log(`status=ok kind=response fixture=${path.relative(repoRoot, filePath)}`)
}

console.log(`result=runtime_http_fixture_schemas_verified checked=${checked}`)

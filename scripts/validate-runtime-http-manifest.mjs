#!/usr/bin/env node

import fs from 'node:fs'
import path from 'node:path'
import { fileURLToPath } from 'node:url'

const __filename = fileURLToPath(import.meta.url)
const __dirname = path.dirname(__filename)
const repoRoot = path.resolve(__dirname, '..')
const manifestPath = path.join(repoRoot, 'schemas/runtime-http/api-manifest.v0.json')

function fail(reason) {
  console.error(`result=runtime_http_api_manifest_invalid reason=${JSON.stringify(reason)}`)
  process.exit(1)
}

function readJson(relativeOrAbsolutePath) {
  const filePath = path.isAbsolute(relativeOrAbsolutePath)
    ? relativeOrAbsolutePath
    : path.join(repoRoot, relativeOrAbsolutePath)

  if (!fs.existsSync(filePath)) {
    fail(`missing file: ${path.relative(repoRoot, filePath)}`)
  }

  return JSON.parse(fs.readFileSync(filePath, 'utf8'))
}

function assertString(value, field, routeId) {
  if (typeof value !== 'string' || value.length === 0) {
    fail(`${routeId}.${field} must be a non-empty string`)
  }
}

function assertNullableString(value, field, routeId) {
  if (value !== null && (typeof value !== 'string' || value.length === 0)) {
    fail(`${routeId}.${field} must be null or a non-empty string`)
  }
}

function assertStatusCode(value, routeId) {
  if (!Number.isInteger(value) || ![200, 400, 404, 500].includes(value)) {
    fail(`${routeId}.status_code must be one of 200, 400, 404, 500`)
  }
}

const manifest = readJson(manifestPath)

if (manifest.contract !== 'capu-runtime-http-api-v0') {
  fail('unexpected manifest contract')
}

if (!Array.isArray(manifest.routes) || manifest.routes.length === 0) {
  fail('manifest.routes must be a non-empty array')
}

const ids = new Set()
const routeCases = new Set()
const expectedRoutes = new Set([
  'GET /capu/health',
  'POST /capu/decide',
  'POST /capu/audit',
  'POST /capu/replay',
  'GET /capu/unknown',
  'RAW BROKEN',
])

for (const route of manifest.routes) {
  assertString(route.id, 'id', 'route')
  assertString(route.method, 'method', route.id)
  assertString(route.path, 'path', route.id)
  assertString(route.case, 'case', route.id)
  assertStatusCode(route.status_code, route.id)
  assertNullableString(route.invariant_id, 'invariant_id', route.id)
  assertNullableString(route.boundary, 'boundary', route.id)
  assertNullableString(route.request_fixture, 'request_fixture', route.id)
  assertString(route.response_fixture, 'response_fixture', route.id)

  if (ids.has(route.id)) {
    fail(`duplicate route id: ${route.id}`)
  }
  ids.add(route.id)

  const routeKey = `${route.method} ${route.path}`
  if (!expectedRoutes.has(routeKey)) {
    fail(`unexpected route key: ${routeKey}`)
  }

  const routeCaseKey = `${route.method} ${route.path} ${route.case}`
  if (routeCases.has(routeCaseKey)) {
    fail(`duplicate route case: ${routeCaseKey}`)
  }
  routeCases.add(routeCaseKey)

  if (route.request_fixture) {
    readJson(route.request_fixture)
  }

  const response = readJson(route.response_fixture)

  if (route.status_code === 200) {
    if (response.route !== route.path) {
      fail(`${route.id} response route mismatch: expected ${route.path}, got ${response.route}`)
    }
  }

  if (route.status_code >= 400) {
    if (response.status !== 'error') {
      fail(`${route.id} error response must have status=error`)
    }
    assertString(response.error, 'error', route.id)
  }

  if (route.invariant_id && response.invariant_id && response.invariant_id !== route.invariant_id) {
    fail(`${route.id} invariant mismatch: expected ${route.invariant_id}, got ${response.invariant_id}`)
  }

  if (route.boundary && response.boundary && response.boundary !== route.boundary) {
    fail(`${route.id} boundary mismatch: expected ${route.boundary}, got ${response.boundary}`)
  }

  console.log(`status=ok route=${route.id} method=${route.method} path=${route.path}`)
}

console.log(`result=runtime_http_api_manifest_verified routes=${manifest.routes.length}`)

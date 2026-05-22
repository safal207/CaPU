#!/usr/bin/env node

import fs from 'node:fs'
import path from 'node:path'
import { fileURLToPath } from 'node:url'

const __filename = fileURLToPath(import.meta.url)
const __dirname = path.dirname(__filename)
const repoRoot = path.resolve(__dirname, '..')
const manifestPath = path.join(repoRoot, 'schemas/runtime-http/api-manifest.v0.json')
const openApiPath = path.join(repoRoot, 'schemas/runtime-http/openapi-lite.v0.json')

function fail(reason) {
  console.error(`result=runtime_http_openapi_lite_invalid reason=${JSON.stringify(reason)}`)
  process.exit(1)
}

function readJson(filePath) {
  if (!fs.existsSync(filePath)) {
    fail(`missing file: ${path.relative(repoRoot, filePath)}`)
  }
  return JSON.parse(fs.readFileSync(filePath, 'utf8'))
}

function assertString(value, label) {
  if (typeof value !== 'string' || value.length === 0) {
    fail(`${label} must be a non-empty string`)
  }
}

const manifest = readJson(manifestPath)
const openapi = readJson(openApiPath)

if (openapi.openapi !== '3.1.0') {
  fail('openapi must be 3.1.0')
}

if (openapi['x-capu-source-manifest'] !== 'schemas/runtime-http/api-manifest.v0.json') {
  fail('x-capu-source-manifest must point to api-manifest.v0.json')
}

if (!openapi.info || openapi.info.title !== 'CaPU Runtime HTTP API v0') {
  fail('unexpected OpenAPI info.title')
}

if (!openapi.paths || typeof openapi.paths !== 'object') {
  fail('openapi.paths must be an object')
}

if (!openapi.components?.schemas?.JsonObject) {
  fail('missing JsonObject schema')
}

if (!openapi.components?.schemas?.ErrorResponse) {
  fail('missing ErrorResponse schema')
}

const rawCases = new Map((openapi['x-capu-raw-cases'] ?? []).map((entry) => [entry.id, entry]))
const seenIds = new Set()

for (const route of manifest.routes) {
  assertString(route.id, `route ${route.id}.id`)
  assertString(route.method, `${route.id}.method`)
  assertString(route.path, `${route.id}.path`)

  if (route.method === 'RAW') {
    const raw = rawCases.get(route.id)
    if (!raw) {
      fail(`missing raw case in x-capu-raw-cases: ${route.id}`)
    }
    if (raw.method !== route.method || raw.path !== route.path || raw.status_code !== route.status_code) {
      fail(`raw case mismatch for ${route.id}`)
    }
    seenIds.add(route.id)
    console.log(`status=ok openapi_raw_case=${route.id}`)
    continue
  }

  const pathItem = openapi.paths[route.path]
  if (!pathItem) {
    fail(`missing OpenAPI path for ${route.id}: ${route.path}`)
  }

  const operation = pathItem[route.method.toLowerCase()]
  if (!operation) {
    fail(`missing OpenAPI operation for ${route.method} ${route.path}`)
  }

  if (!Array.isArray(operation['x-capu-route-ids']) || !operation['x-capu-route-ids'].includes(route.id)) {
    fail(`operation ${route.method} ${route.path} missing x-capu-route-id ${route.id}`)
  }

  const response = operation.responses?.[String(route.status_code)]
  if (!response) {
    fail(`operation ${route.method} ${route.path} missing response ${route.status_code}`)
  }

  seenIds.add(route.id)
  console.log(`status=ok openapi_route=${route.id} method=${route.method} path=${route.path}`)
}

const manifestIds = new Set(manifest.routes.map((route) => route.id))
for (const [rawId] of rawCases) {
  if (!manifestIds.has(rawId)) {
    fail(`OpenAPI raw case not present in manifest: ${rawId}`)
  }
}

if (seenIds.size !== manifest.routes.length) {
  fail(`route coverage mismatch: seen=${seenIds.size} manifest=${manifest.routes.length}`)
}

console.log(`result=runtime_http_openapi_lite_verified routes=${seenIds.size}`)

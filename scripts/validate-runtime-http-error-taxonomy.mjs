#!/usr/bin/env node

import fs from 'node:fs'
import path from 'node:path'
import { fileURLToPath } from 'node:url'

const __filename = fileURLToPath(import.meta.url)
const __dirname = path.dirname(__filename)
const repoRoot = path.resolve(__dirname, '..')
const manifestPath = path.join(repoRoot, 'schemas/runtime-http/api-manifest.v0.json')
const taxonomyPath = path.join(repoRoot, 'schemas/runtime-http/error-taxonomy.v0.json')

function fail(reason) {
  console.error(`result=runtime_http_error_taxonomy_invalid reason=${JSON.stringify(reason)}`)
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
const taxonomy = readJson(taxonomyPath)

if (taxonomy.taxonomy !== 'capu-runtime-http-error-taxonomy-v0') {
  fail('unexpected taxonomy id')
}

if (taxonomy.source_manifest !== 'schemas/runtime-http/api-manifest.v0.json') {
  fail('source_manifest must point to api-manifest.v0.json')
}

if (!Array.isArray(taxonomy.errors) || taxonomy.errors.length === 0) {
  fail('taxonomy.errors must be a non-empty array')
}

const manifestRoutes = new Map(manifest.routes.map((route) => [route.id, route]))
const seenIds = new Set()

for (const error of taxonomy.errors) {
  assertString(error.id, 'error.id')
  assertString(error.response_error, `${error.id}.response_error`)
  assertString(error.category, `${error.id}.category`)
  assertString(error.boundary, `${error.id}.boundary`)
  assertString(error.manifest_route_id, `${error.id}.manifest_route_id`)
  assertString(error.fixture, `${error.id}.fixture`)

  if (seenIds.has(error.id)) {
    fail(`duplicate error id: ${error.id}`)
  }
  seenIds.add(error.id)

  if (!Number.isInteger(error.http_status) || error.http_status < 400 || error.http_status > 599) {
    fail(`${error.id}.http_status must be a 4xx/5xx integer`)
  }

  const route = manifestRoutes.get(error.manifest_route_id)
  if (!route) {
    fail(`${error.id} references missing manifest route ${error.manifest_route_id}`)
  }

  if (route.status_code !== error.http_status) {
    fail(`${error.id} status mismatch: taxonomy=${error.http_status} manifest=${route.status_code}`)
  }

  if (route.boundary !== error.boundary) {
    fail(`${error.id} boundary mismatch: taxonomy=${error.boundary} manifest=${route.boundary}`)
  }

  if (route.response_fixture !== error.fixture) {
    fail(`${error.id} fixture mismatch: taxonomy=${error.fixture} manifest=${route.response_fixture}`)
  }

  const fixture = readJson(path.join(repoRoot, error.fixture))
  if (fixture.status !== 'error') {
    fail(`${error.id} fixture status must be error`)
  }

  if (fixture.error !== error.response_error) {
    fail(`${error.id} response_error mismatch: taxonomy=${error.response_error} fixture=${fixture.error}`)
  }

  console.log(`status=ok error_taxonomy_case=${error.id} status_code=${error.http_status} boundary=${error.boundary}`)
}

console.log(`result=runtime_http_error_taxonomy_verified errors=${taxonomy.errors.length}`)

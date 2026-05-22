#!/usr/bin/env node

import fs from 'node:fs'
import path from 'node:path'
import { fileURLToPath } from 'node:url'
import Ajv from 'ajv/dist/2020.js'

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

const ajv = new Ajv({ allErrors: true, strict: true })
const validateRequest = ajv.compile(readJson(requestSchemaPath))
const validateResponse = ajv.compile(readJson(responseSchemaPath))

let checked = 0

function validateFixture(kind, filePath, validate) {
  const value = readJson(filePath)
  const ok = validate(value)
  const relative = path.relative(repoRoot, filePath)

  if (!ok) {
    console.error(`result=runtime_http_fixture_schema_failed kind=${kind} fixture=${relative}`)
    console.error(JSON.stringify(validate.errors, null, 2))
    process.exit(1)
  }

  checked += 1
  console.log(`status=ok kind=${kind} fixture=${relative}`)
}

for (const filePath of fixtureFiles(requestDir)) {
  validateFixture('request', filePath, validateRequest)
}

for (const filePath of fixtureFiles(responseDir)) {
  validateFixture('response', filePath, validateResponse)
}

console.log(`result=runtime_http_fixture_schemas_verified checked=${checked}`)

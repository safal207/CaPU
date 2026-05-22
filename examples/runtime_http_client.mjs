#!/usr/bin/env node

import fs from 'node:fs'
import http from 'node:http'
import net from 'node:net'
import path from 'node:path'
import { spawn } from 'node:child_process'
import { fileURLToPath } from 'node:url'

const __filename = fileURLToPath(import.meta.url)
const __dirname = path.dirname(__filename)
const repoRoot = path.resolve(__dirname, '..')
const cmcDir = path.join(repoRoot, 'rust/cmc-core')
const fixtureRoot = path.join(cmcDir, 'fixtures/capu_runtime_http')
const CLIENT_TIMEOUT_MS = 120_000

function readFixture(relativePath) {
  return fs.readFileSync(path.join(fixtureRoot, relativePath), 'utf8').trim()
}

function findFreePort() {
  return new Promise((resolve, reject) => {
    const server = net.createServer()
    server.on('error', reject)
    server.listen(0, '127.0.0.1', () => {
      const address = server.address()
      const port = address.port
      server.close(() => resolve(port))
    })
  })
}

function requestJson({ port, method, route, body = '' }) {
  return new Promise((resolve, reject) => {
    const request = http.request(
      {
        hostname: '127.0.0.1',
        port,
        path: route,
        method,
        headers: {
          'content-type': 'application/json',
          'content-length': Buffer.byteLength(body),
        },
        timeout: 10_000,
      },
      (response) => {
        let data = ''
        response.setEncoding('utf8')
        response.on('data', (chunk) => {
          data += chunk
        })
        response.on('end', () => {
          resolve({ statusCode: response.statusCode, body: data.trim() })
        })
      },
    )

    request.on('timeout', () => {
      request.destroy(new Error(`${method} ${route} timed out`))
    })
    request.on('error', reject)
    if (body.length > 0) {
      request.write(body)
    }
    request.end()
  })
}

async function waitForSidecar(port, attempts = 90) {
  let lastError
  for (let attempt = 0; attempt < attempts; attempt += 1) {
    try {
      const response = await requestJson({ port, method: 'GET', route: '/capu/health' })
      if (response.statusCode === 200) {
        return response
      }
    } catch (error) {
      lastError = error
    }
    await new Promise((resolve) => setTimeout(resolve, 500))
  }
  throw new Error(`sidecar did not become ready: ${lastError?.message ?? 'no response'}`)
}

function assertFixture(label, actual, expectedFixture) {
  const expected = readFixture(expectedFixture)
  if (actual.body !== expected) {
    throw new Error(`${label} mismatch\nexpected=${expected}\nactual=${actual.body}`)
  }
  console.log(`status=ok client_case=${label} http_status=${actual.statusCode}`)
}

function stopSidecar(sidecar) {
  if (sidecar.exitCode !== null) {
    return
  }

  if (process.platform === 'win32') {
    sidecar.kill('SIGTERM')
    return
  }

  if (sidecar.pid) {
    try {
      process.kill(-sidecar.pid, 'SIGTERM')
    } catch {
      sidecar.kill('SIGTERM')
    }
  }
}

async function runClient() {
  const port = await findFreePort()
  const addr = `127.0.0.1:${port}`

  const sidecar = spawn(
    'cargo',
    ['run', '--bin', 'capu_runtime_http_sidecar', '--locked', '--', '--addr', addr],
    {
      cwd: cmcDir,
      stdio: 'ignore',
      detached: process.platform !== 'win32',
    },
  )
  sidecar.unref()

  try {
    const health = await waitForSidecar(port)
    assertFixture('health', health, 'responses/health.json')

    const decideBody = readFixture('requests/decide_p6_uncommitted.json')
    const decide = await requestJson({
      port,
      method: 'POST',
      route: '/capu/decide',
      body: decideBody,
    })
    assertFixture('decide_p6_uncommitted', decide, 'responses/decide_p6_uncommitted.json')

    const auditBody = readFixture('requests/audit_p6_committed.json')
    const audit = await requestJson({
      port,
      method: 'POST',
      route: '/capu/audit',
      body: auditBody,
    })
    assertFixture('audit_p6_committed', audit, 'responses/audit_p6_committed.json')

    const replayBody = readFixture('requests/replay_p6_pair.json')
    const replay = await requestJson({
      port,
      method: 'POST',
      route: '/capu/replay',
      body: replayBody,
    })
    assertFixture('replay_p6_pair', replay, 'responses/replay_p6_pair.json')

    const unknown = await requestJson({ port, method: 'GET', route: '/capu/unknown' })
    assertFixture('unknown_route', unknown, 'responses/unknown_route.json')

    console.log(`sidecar_addr=${addr}`)
    console.log('result=runtime_http_client_example_verified')
  } finally {
    stopSidecar(sidecar)
  }
}

async function main() {
  let timeoutId
  const timeout = new Promise((_, reject) => {
    timeoutId = setTimeout(() => {
      reject(new Error(`client example exceeded ${CLIENT_TIMEOUT_MS}ms`))
    }, CLIENT_TIMEOUT_MS)
  })

  try {
    await Promise.race([runClient(), timeout])
  } finally {
    clearTimeout(timeoutId)
  }
}

main().catch((error) => {
  console.error(`result=runtime_http_client_example_failed reason=${error.message}`)
  process.exit(1)
})

import fs from 'node:fs'
import net from 'node:net'
import path from 'node:path'
import { spawn } from 'node:child_process'
import { fileURLToPath } from 'node:url'

const __filename = fileURLToPath(import.meta.url)
const __dirname = path.dirname(__filename)
export const repoRoot = path.resolve(__dirname, '..')
export const cmcDir = path.join(repoRoot, 'rust/cmc-core')
export const fixtureRoot = path.join(cmcDir, 'fixtures/capu_runtime_http')

export function readFixture(relativePath) {
  return fs.readFileSync(path.join(fixtureRoot, relativePath), 'utf8').trim()
}

export function readFixtureJson(relativePath) {
  return JSON.parse(readFixture(relativePath))
}

export function findFreePort() {
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

export function createRuntimeHttpClient({ host = '127.0.0.1', port, timeoutMs = 10_000 } = {}) {
  if (!Number.isInteger(port) || port <= 0) {
    throw new Error('createRuntimeHttpClient requires a positive integer port')
  }

  async function requestJson({ method, route, body = '' }) {
    return new Promise((resolve, reject) => {
      const socket = net.createConnection({ host, port })
      let response = ''
      let settled = false

      const timeout = setTimeout(() => {
        if (!settled) {
          settled = true
          socket.destroy()
          reject(new Error(`${method} ${route} timed out`))
        }
      }, timeoutMs)

      socket.setEncoding('utf8')
      socket.on('connect', () => {
        const request = [
          `${method} ${route} HTTP/1.1`,
          `Host: ${host}:${port}`,
          'Content-Type: application/json',
          `Content-Length: ${Buffer.byteLength(body)}`,
          'Connection: close',
          '',
          body,
        ].join('\r\n')
        socket.end(request)
      })

      socket.on('data', (chunk) => {
        response += chunk
      })

      socket.on('error', (error) => {
        if (!settled) {
          settled = true
          clearTimeout(timeout)
          reject(error)
        }
      })

      socket.on('end', () => {
        if (settled) {
          return
        }
        settled = true
        clearTimeout(timeout)
        const [head = '', rawBody = response] = response.split('\r\n\r\n')
        const statusLine = head.split('\r\n')[0] ?? ''
        const statusCode = Number(statusLine.split(' ')[1] ?? 0)
        const bodyText = rawBody.trim()
        let json = null
        if (bodyText.length > 0) {
          json = JSON.parse(bodyText)
        }
        resolve({ statusCode, body: bodyText, json })
      })
    })
  }

  return {
    async health() {
      return requestJson({ method: 'GET', route: '/capu/health' })
    },
    async decide(payload) {
      return requestJson({ method: 'POST', route: '/capu/decide', body: JSON.stringify(payload) })
    },
    async audit(payload) {
      return requestJson({ method: 'POST', route: '/capu/audit', body: JSON.stringify(payload) })
    },
    async replay(payload) {
      return requestJson({ method: 'POST', route: '/capu/replay', body: JSON.stringify(payload) })
    },
    async unknownRoute() {
      return requestJson({ method: 'GET', route: '/capu/unknown' })
    },
  }
}

export async function waitForSidecar(client, attempts = 90) {
  let lastError
  for (let attempt = 0; attempt < attempts; attempt += 1) {
    try {
      const response = await client.health()
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

export function launchRuntimeHttpSidecar(addr) {
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
  return sidecar
}

export function stopRuntimeHttpSidecar(sidecar) {
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

export function assertFixture(label, actual, expectedFixture) {
  const expected = readFixture(expectedFixture)
  if (actual.body !== expected) {
    throw new Error(`${label} mismatch\nexpected=${expected}\nactual=${actual.body}`)
  }
  console.log(`status=ok sdk_case=${label} http_status=${actual.statusCode}`)
}

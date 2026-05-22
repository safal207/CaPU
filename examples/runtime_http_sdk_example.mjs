#!/usr/bin/env node

import {
  assertFixture,
  createRuntimeHttpClient,
  findFreePort,
  launchRuntimeHttpSidecar,
  readFixtureJson,
  stopRuntimeHttpSidecar,
  waitForSidecar,
} from './runtime_http_sdk.mjs'

const EXAMPLE_TIMEOUT_MS = 120_000

async function runSdkExample() {
  const port = await findFreePort()
  const addr = `127.0.0.1:${port}`
  const sidecar = launchRuntimeHttpSidecar(addr)
  const client = createRuntimeHttpClient({ port })

  try {
    const health = await waitForSidecar(client)
    assertFixture('health', health, 'responses/health.json')

    const decide = await client.decide(readFixtureJson('requests/decide_p6_uncommitted.json'))
    assertFixture('decide_p6_uncommitted', decide, 'responses/decide_p6_uncommitted.json')

    const audit = await client.audit(readFixtureJson('requests/audit_p6_committed.json'))
    assertFixture('audit_p6_committed', audit, 'responses/audit_p6_committed.json')

    const replay = await client.replay(readFixtureJson('requests/replay_p6_pair.json'))
    assertFixture('replay_p6_pair', replay, 'responses/replay_p6_pair.json')

    const unknown = await client.unknownRoute()
    assertFixture('unknown_route', unknown, 'responses/unknown_route.json')

    console.log(`sidecar_addr=${addr}`)
    console.log('sdk_methods=health,decide,audit,replay,unknownRoute')
    console.log('result=runtime_http_sdk_example_verified')
  } finally {
    stopRuntimeHttpSidecar(sidecar)
  }
}

async function main() {
  let timeoutId
  const timeout = new Promise((_, reject) => {
    timeoutId = setTimeout(() => {
      reject(new Error(`sdk example exceeded ${EXAMPLE_TIMEOUT_MS}ms`))
    }, EXAMPLE_TIMEOUT_MS)
  })

  try {
    await Promise.race([runSdkExample(), timeout])
  } finally {
    clearTimeout(timeoutId)
  }
}

main().catch((error) => {
  console.error(`result=runtime_http_sdk_example_failed reason=${error.message}`)
  process.exit(1)
})

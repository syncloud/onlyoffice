import { test, expect, request } from '@playwright/test'
import { ssh } from '../helpers/ssh'

const fullDomain = process.env.PLAYWRIGHT_FULL_DOMAIN ?? 'bookworm-amd64.com'
const appDomain = process.env.PLAYWRIGHT_APP_DOMAIN ?? `onlyoffice.${fullDomain}`

test.describe('Nextcloud-style integration (no Authelia session)', () => {
  test('public OO endpoints are reachable without auth', async () => {
    const ctx = await request.newContext({ ignoreHTTPSErrors: true })
    const healthcheck = await ctx.get(`https://${appDomain}/healthcheck`)
    expect([200, 502]).toContain(healthcheck.status())
    const apijs = await ctx.get(`https://${appDomain}/web-apps/apps/api/documents/api.js`)
    expect(apijs.status()).toBe(200)
  })

  test.skip('UI paths require auth_request (302 to Authelia)', async () => {
    const ctx = await request.newContext({ ignoreHTTPSErrors: true, maxRedirects: 0 })
    const r1 = await ctx.get(`https://${appDomain}/api/files`)
    expect([302, 401]).toContain(r1.status())
    const r2 = await ctx.get(`https://${appDomain}/api/secret`)
    expect([302, 401]).toContain(r2.status())
  })

  test('file fetch requires JWT, accepts valid one without Authelia session', async () => {
    ssh(`mkdir -p /data/onlyoffice/files && printf 'integration-test\n' > /data/onlyoffice/files/integration.txt && chown -R onlyoffice:onlyoffice /data/onlyoffice/files`, { throw: false })

    const ctx = await request.newContext({ ignoreHTTPSErrors: true, maxRedirects: 0 })

    const noTok = await ctx.get(`https://${appDomain}/api/file/integration.txt`)
    expect(noTok.status()).toBe(403)

    const secret = ssh(`snap run onlyoffice.cli jwt-secret`).trim()
    expect(secret.length).toBeGreaterThan(0)
    const token = await mintFileToken(secret, 'integration.txt')

    const ok = await ctx.get(`https://${appDomain}/api/file/integration.txt?token=${encodeURIComponent(token)}`)
    expect(ok.status()).toBe(200)
    expect(await ok.text()).toContain('integration-test')
  })
})

async function mintFileToken(secret: string, file: string): Promise<string> {
  const { createHmac } = await import('node:crypto')
  const header = { alg: 'HS256', typ: 'JWT' }
  const now = Math.floor(Date.now() / 1000)
  const payload = { file, iat: now, exp: now + 600 }
  const b64 = (o: object) =>
    Buffer.from(JSON.stringify(o)).toString('base64url')
  const data = `${b64(header)}.${b64(payload)}`
  const sig = createHmac('sha256', secret).update(data).digest('base64url')
  return `${data}.${sig}`
}

import { Page, expect, Response } from '@playwright/test'
import { execFileSync } from 'node:child_process'
import { writeFileSync, mkdtempSync } from 'node:fs'
import { tmpdir } from 'node:os'
import { join } from 'node:path'

export function editorFrame(page: Page) {
  return page.frameLocator('iframe[name="frameEditor"]')
}

export async function captureEditorConfig(page: Page): Promise<Response> {
  return page.waitForResponse(
    r => r.url().includes('/api/editor-config') && r.status() === 200,
    { timeout: 30_000 }
  )
}

export async function focusCanvas(page: Page) {
  const iframe = page.locator('iframe[name="frameEditor"]')
  await iframe.waitFor({ state: 'visible', timeout: 60_000 })
  const box = await iframe.boundingBox()
  if (!box) throw new Error('frameEditor iframe has no bounding box')
  await page.mouse.click(box.x + box.width / 2, box.y + box.height / 2)
  await page.waitForTimeout(1000)
}

export async function waitEditorRendered(page: Page) {
  await page.getByTestId('editor-loading').waitFor({ state: 'hidden', timeout: 60_000 })
  await page.waitForTimeout(8000)
}

export async function waitForAutosave(page: Page, fileUrl: string, baselineSize: number, timeoutMs = 60_000) {
  const origin = new URL(page.url()).origin
  const abs = fileUrl.startsWith('http') ? fileUrl : origin + fileUrl
  const deadline = Date.now() + timeoutMs
  while (Date.now() < deadline) {
    await page.waitForTimeout(2000)
    const r = await page.request.get(abs)
    if (r.ok()) {
      const buf = Buffer.from(await r.body())
      if (buf.length !== baselineSize) return
    }
  }
  throw new Error(`autosave didn't change file size from ${baselineSize} within ${timeoutMs}ms`)
}

export async function fileSize(page: Page, fileUrl: string): Promise<number> {
  const origin = new URL(page.url()).origin
  const abs = fileUrl.startsWith('http') ? fileUrl : origin + fileUrl
  const r = await page.request.get(abs)
  if (!r.ok()) throw new Error(`fetch ${abs} failed: ${r.status()}`)
  return Buffer.from(await r.body()).length
}

export async function readZipEntry(savedFileBytes: Buffer, entry: string): Promise<string> {
  const dir = mkdtempSync(join(tmpdir(), 'oo-zip-'))
  const f = join(dir, 'doc')
  writeFileSync(f, savedFileBytes)
  return execFileSync('unzip', ['-p', f, entry]).toString('utf-8')
}

export async function fetchSavedFile(page: Page, fileUrl: string): Promise<Buffer> {
  const origin = new URL(page.url()).origin
  const abs = fileUrl.startsWith('http') ? fileUrl : origin + fileUrl
  const r = await page.request.get(abs)
  expect(r.ok(), `fetch ${abs} failed: ${r.status()}`).toBe(true)
  return Buffer.from(await r.body())
}

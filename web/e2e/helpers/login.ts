import { Page, expect } from '@playwright/test'

const deviceUser = process.env.PLAYWRIGHT_DEVICE_USER ?? 'user'
const devicePassword = process.env.PLAYWRIGHT_DEVICE_PASSWORD ?? 'Password1'

export async function login(page: Page) {
  await page.goto('/')
  const username = page.getByRole('textbox', { name: /username/i })
  await expect(username).toBeVisible({ timeout: 30_000 })
  await username.fill(deviceUser)
  await page.getByRole('textbox', { name: /password/i }).fill(devicePassword)
  await page.getByRole('button', { name: /sign in/i }).click()
  await expect(page.getByTestId('brand')).toBeVisible({ timeout: 30_000 })
}

export async function uploadFixture(page: Page, name: string, mime: string, bytes: Buffer) {
  const fileChooserPromise = page.waitForEvent('filechooser')
  await page.getByTestId('upload-button').click()
  const chooser = await fileChooserPromise
  await chooser.setFiles({ name, mimeType: mime, buffer: bytes })
}

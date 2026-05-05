import { test, expect } from '@playwright/test'
import { login } from '../helpers/login'
import { shoot } from '../helpers/screenshot'

test.describe('logout', () => {
  test('logout button clears Authelia session', async ({ page }, testInfo) => {
    await login(page)
    await expect(page.getByTestId('logout-button')).toBeVisible()
    await page.getByTestId('logout-button').click()
    await expect(page.getByRole('textbox', { name: /username/i })).toBeVisible({ timeout: 30_000 })
    await expect(page.getByRole('button', { name: /sign in/i })).toBeVisible()
    await expect(page.getByTestId('logout-button')).toHaveCount(0)
    await shoot(page, testInfo, 'logout')
  })
})

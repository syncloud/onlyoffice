import { test, expect } from '@playwright/test'
import { login } from '../helpers/login'
import { shoot } from '../helpers/screenshot'

test.describe('Nextcloud setup page', () => {
  test('shows server URL and JWT secret with copy buttons', async ({ page }, testInfo) => {
    await login(page)
    const burger = page.getByTestId('nav-burger')
    if (await burger.isVisible()) {
      await burger.click()
      await page.getByTestId('nav-drawer').getByTestId('nav-setup').click()
    } else {
      await page.getByTestId('nav-setup').click()
    }
    await expect(page.getByTestId('setup-url-input')).toBeVisible()
    await expect(page.getByTestId('setup-secret-input')).toBeVisible()
    await shoot(page, testInfo, 'nextcloud-setup')
    await page.getByTestId('setup-secret-copy').click()
  })
})

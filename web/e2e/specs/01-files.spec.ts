import { test, expect } from '@playwright/test'
import { login } from '../helpers/login'
import { shoot } from '../helpers/screenshot'

test.describe('files page', () => {
  test('lists files after login', async ({ page }, testInfo) => {
    await login(page)
    const burger = page.getByTestId('nav-burger')
    if (await burger.isVisible()) {
      await burger.click()
      await page.getByTestId('nav-drawer').getByTestId('nav-files').click()
    } else {
      await page.getByTestId('nav-files').click()
    }
    await expect(page.getByTestId('brand')).toBeVisible()
    await shoot(page, testInfo, 'files-page')
  })
})

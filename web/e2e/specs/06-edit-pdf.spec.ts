import { test, expect } from '@playwright/test'
import { login } from '../helpers/login'
import { shoot } from '../helpers/screenshot'
import { waitEditorRendered } from '../helpers/editor'

test.describe('pdf viewer (.pdf)', () => {
  test('create new pdf and open viewer', async ({ page }, testInfo) => {
    await login(page)
    await page.getByTestId('new-doc-button').click()
    await page.getByText('PDF (.pdf)').click()
    await expect(page.getByTestId('editor-root')).toBeVisible()
    await waitEditorRendered(page)
    await shoot(page, testInfo, 'editor-pdf')
    await expect(page.getByTestId('editor-error')).toHaveCount(0)
  })
})

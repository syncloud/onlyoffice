import { test, expect } from '@playwright/test'
import { login } from '../helpers/login'
import { shoot } from '../helpers/screenshot'
import { waitEditorRendered } from '../helpers/editor'

test.describe('presentation editor (.pptx)', () => {
  test('create new presentation and open editor', async ({ page }, testInfo) => {
    await login(page)
    await page.getByTestId('new-doc-button').click()
    await page.getByText('Presentation (.pptx)').click()
    await expect(page.getByTestId('editor-root')).toBeVisible()
    await waitEditorRendered(page)
    await shoot(page, testInfo, 'editor-pptx')
    await expect(page.getByTestId('editor-error')).toHaveCount(0)
  })
})

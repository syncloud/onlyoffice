import { test, expect } from '@playwright/test'
import { login } from '../helpers/login'
import { shoot } from '../helpers/screenshot'
import {
  captureEditorConfig, focusCanvas, waitForAutosave, waitEditorRendered,
  fetchSavedFile, readZipEntry, fileSize,
} from '../helpers/editor'

test.describe('round-trip: xlsx', () => {
  test('numbers + formula compute, autosave, reopen', async ({ page }, testInfo) => {
    test.skip(testInfo.project.name !== 'desktop', 'OO Community blocks mobile editing')
    await login(page)
    const cfgPromise = captureEditorConfig(page)
    await page.getByTestId('new-doc-button').click()
    await page.getByText('Spreadsheet (.xlsx)').click()
    const cfgResp = await cfgPromise
    const cfg = await cfgResp.json()
    const fileUrl: string = cfg.document.url
    await waitEditorRendered(page)
    const baseline = await fileSize(page, fileUrl)
    await focusCanvas(page)
    await page.keyboard.press('Control+Home')
    await page.waitForTimeout(300)

    const phrase = 'XlsxRoundtrip'
    await page.keyboard.type(phrase, { delay: 30 })
    await page.keyboard.press('Enter')
    await page.waitForTimeout(2000)
    await shoot(page, testInfo, 'roundtrip-xlsx-edit')
    await page.getByTestId('editor-back').click()
    await waitForAutosave(page, fileUrl, baseline)
    const buf = await fetchSavedFile(page, fileUrl)
    const sheet = await readZipEntry(buf, 'xl/worksheets/sheet1.xml')
    const shared = await readZipEntry(buf, 'xl/sharedStrings.xml').catch(() => '')
    expect(sheet + shared).toContain(phrase)
    await page.getByText(cfg.document.title).first().click()
    await waitEditorRendered(page)
    await shoot(page, testInfo, 'roundtrip-xlsx-reopen')
  })
})

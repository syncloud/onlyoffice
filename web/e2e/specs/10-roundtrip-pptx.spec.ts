import { test, expect } from '@playwright/test'
import { login } from '../helpers/login'
import { shoot } from '../helpers/screenshot'
import {
  captureEditorConfig, focusCanvas, waitForAutosave, waitEditorRendered,
  fetchSavedFile, readZipEntry, fileSize,
  expectNoVersionChangedBanner,
} from '../helpers/editor'

test.describe('round-trip: pptx', () => {
  test('type slide title, autosave, reopen', async ({ page }, testInfo) => {
    test.skip(testInfo.project.name !== 'desktop', 'OO Community blocks mobile editing')
    await login(page)
    const cfgPromise = captureEditorConfig(page)
    await page.getByTestId('new-doc-button').click()
    await page.getByText('Presentation (.pptx)').click()
    const cfgResp = await cfgPromise
    const cfg = await cfgResp.json()
    const fileUrl: string = cfg.document.url
    await waitEditorRendered(page)
    const baseline = await fileSize(page, fileUrl)
    await focusCanvas(page)

    const phrase = 'HelloRoundtripPptx'
    await page.keyboard.type(phrase, { delay: 30 })
    await page.waitForTimeout(2000)
    await shoot(page, testInfo, 'roundtrip-pptx-edit')
    await page.getByTestId('editor-back').click()
    await waitForAutosave(page, fileUrl, baseline)
    const buf = await fetchSavedFile(page, fileUrl)
    const xml = await readZipEntry(buf, 'ppt/slides/slide1.xml')
    expect(xml).toContain(phrase)
    await page.getByText(cfg.document.title).first().click()
    await waitEditorRendered(page)
    await shoot(page, testInfo, 'roundtrip-pptx-reopen')
    await expectNoVersionChangedBanner(page)
  })
})

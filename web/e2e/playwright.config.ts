import { defineConfig, devices } from '@playwright/test'

const fullDomain = process.env.PLAYWRIGHT_FULL_DOMAIN ?? 'bookworm-amd64.com'
const appDomain = process.env.PLAYWRIGHT_APP_DOMAIN ?? `onlyoffice.${fullDomain}`
const artifactDir = process.env.PLAYWRIGHT_ARTIFACT_DIR ?? 'artifact'

export default defineConfig({
  testDir: './specs',
  fullyParallel: false,
  workers: 1,
  retries: 0,
  maxFailures: 1,
  reporter: [
    ['list'],
    ['html', { open: 'never', outputFolder: `${artifactDir}/playwright/report` }],
  ],
  outputDir: `${artifactDir}/playwright/test-results`,
  globalTeardown: './globalTeardown.ts',
  timeout: 300_000,
  expect: { timeout: 15_000 },
  use: {
    baseURL: `https://${appDomain}`,
    ignoreHTTPSErrors: true,
    trace: 'retain-on-failure',
    screenshot: 'only-on-failure',
    video: 'retain-on-failure',
    permissions: ['clipboard-read', 'clipboard-write'],
  },
  projects: [
    {
      name: 'desktop',
      use: { ...devices['Desktop Chrome'], viewport: { width: 1440, height: 960 } },
    },
    {
      name: 'mobile',
      use: { ...devices['Desktop Chrome'], viewport: { width: 390, height: 844 } },
    },
  ],
  metadata: {
    appDomain,
    fullDomain,
    artifactDir,
  },
})

<script setup lang="ts">
import { ref, onMounted } from 'vue'
import { NCard, NSpace, NInput, NInputGroup, NButton, NText, NAlert, useMessage } from 'naive-ui'
import { getSecret } from '../api'

const message = useMessage()
const secret = ref('')
const url = ref(window.location.origin)
const loading = ref(true)

onMounted(async () => {
  try {
    secret.value = await getSecret()
  } catch (e: any) {
    message.error('Failed to load secret: ' + (e?.message ?? e))
  } finally {
    loading.value = false
  }
})

async function copy(text: string, what: string) {
  try {
    await navigator.clipboard.writeText(text)
    message.success(what + ' copied')
  } catch {
    message.warning('Copy failed; select and copy manually')
  }
}
</script>

<template>
  <n-space vertical :size="20" style="max-width: 720px; margin: 0 auto">
    <h2 style="margin: 0">Connect to Nextcloud</h2>
    <n-alert type="info">
      Install the <strong>ONLYOFFICE</strong> app inside Nextcloud (Apps → Office &amp;
      text), then paste the values below into <em>Settings → Administration →
      ONLYOFFICE</em>.
    </n-alert>

    <n-card title="Document Server URL">
      <n-input-group>
        <n-input :value="url" data-testid="setup-url-input" readonly />
        <n-button data-testid="setup-url-copy" @click="copy(url, 'URL')">Copy</n-button>
      </n-input-group>
      <n-text depth="3" style="display: block; margin-top: 8px;">
        Paste into "Document Editing Service address".
      </n-text>
    </n-card>

    <n-card title="Secret key">
      <n-input-group>
        <n-input
          :value="loading ? 'loading…' : secret"
          data-testid="setup-secret-input"
          type="password"
          show-password-on="click"
          readonly
        />
        <n-button data-testid="setup-secret-copy" :disabled="loading" @click="copy(secret, 'Secret')">Copy</n-button>
      </n-input-group>
      <n-text depth="3" style="display: block; margin-top: 8px;">
        Paste into "Secret key (leave blank to disable)".
      </n-text>
    </n-card>
  </n-space>
</template>

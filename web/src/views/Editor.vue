<script setup lang="ts">
import { ref, onMounted, onBeforeUnmount } from 'vue'
import { useRouter } from 'vue-router'
import { NSpin } from 'naive-ui'
import { getEditorConfig } from '../api'

const props = defineProps<{ file: string }>()
const router = useRouter()
const loading = ref(true)
const error = ref<string>('')
let editor: any = null

declare global {
  interface Window {
    DocsAPI?: any
  }
}

async function loadScript(src: string): Promise<void> {
  if (document.querySelector(`script[data-src="${src}"]`)) return
  const r = await fetch(src)
  if (!r.ok) throw new Error('script load error: ' + r.status)
  const code = await r.text()
  const s = document.createElement('script')
  s.textContent = code
  s.dataset.src = src
  document.head.appendChild(s)
  s.setAttribute('src', src)
}

const isMobile = () => window.matchMedia('(max-width: 768px)').matches

onMounted(async () => {
  try {
    await loadScript('/web-apps/apps/api/documents/api.js')
    if (!window.DocsAPI) throw new Error('DocsAPI not available')
    const cfg = await getEditorConfig(props.file, isMobile() ? 'mobile' : 'desktop')
    const ready = () => { loading.value = false }
    cfg.events = {
      onAppReady: ready,
      onDocumentReady: ready,
      onError: (e: any) => { error.value = e?.data?.errorDescription ?? 'editor error' },
    }
    editor = new window.DocsAPI.DocEditor('oo-placeholder', cfg)
  } catch (e: any) {
    error.value = e?.message ?? String(e)
    loading.value = false
  }
})

onBeforeUnmount(() => {
  if (editor && typeof editor.destroyEditor === 'function') {
    try { editor.destroyEditor() } catch {}
  }
})

function close() {
  router.push('/files')
}
</script>

<template>
  <div data-testid="editor-root" style="position: relative; width: 100%; height: 100vh;">
    <button
      data-testid="editor-back"
      class="editor-back"
      title="Back to files"
      aria-label="Back to files"
      @click="close"
    >×</button>
    <div
      data-testid="editor-loading"
      v-if="loading && !error"
      style="position: absolute; inset: 0; display: flex; align-items: center; justify-content: center; background: rgba(0,0,0,0.6); z-index: 10;"
    >
      <n-spin size="large" />
    </div>
    <div
      data-testid="editor-error"
      v-if="error"
      style="position: absolute; inset: 0; padding: 24px; color: #f55;"
    >
      <p>Editor failed: {{ error }}</p>
      <button data-testid="editor-close" @click="close">Back to files</button>
    </div>
    <div id="oo-placeholder" data-testid="editor-iframe-host" style="width: 100%; height: 100%;"></div>
  </div>
</template>

<style scoped>
.editor-back {
  position: fixed;
  top: 6px;
  right: 6px;
  z-index: 2147483647;
  width: 28px;
  height: 28px;
  border-radius: 50%;
  border: 0;
  background: rgba(0, 0, 0, 0.55);
  color: #fff;
  font-size: 18px;
  line-height: 1;
  cursor: pointer;
  opacity: 0.7;
}
.editor-back:hover {
  opacity: 1;
  background: rgba(0, 0, 0, 0.8);
}
</style>

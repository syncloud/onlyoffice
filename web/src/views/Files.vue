<script setup lang="ts">
import { ref, onMounted } from 'vue'
import { useRouter } from 'vue-router'
import { NCard, NEmpty, NSpace, NButton, NUpload, NGrid, NGi, NTag, NText, useMessage, useDialog } from 'naive-ui'
import { listFiles, deleteFile, uploadFile, type FileItem } from '../api'

const router = useRouter()
const message = useMessage()
const dialog = useDialog()
const files = ref<FileItem[]>([])
const loading = ref(false)

async function refresh() {
  loading.value = true
  try {
    files.value = await listFiles()
  } catch (e: any) {
    message.error('Failed to list files: ' + (e?.message ?? e))
  } finally {
    loading.value = false
  }
}

onMounted(refresh)

async function onUpload({ file }: { file: { file?: File | null; name: string } }) {
  if (!file.file) return
  try {
    await uploadFile(file.name, file.file)
    message.success('Uploaded ' + file.name)
    await refresh()
  } catch (e: any) {
    message.error('Upload failed: ' + (e?.message ?? e))
  }
}

function onDelete(name: string) {
  dialog.warning({
    title: 'Delete file',
    content: `Delete ${name}? This cannot be undone.`,
    positiveText: 'Delete',
    negativeText: 'Cancel',
    onPositiveClick: async () => {
      try {
        await deleteFile(name)
        message.success('Deleted ' + name)
        await refresh()
      } catch (e: any) {
        message.error('Delete failed: ' + (e?.message ?? e))
      }
    },
  })
}

function open(file: FileItem) {
  router.push({ name: 'edit', params: { file: file.name } })
}

const typeColor: Record<string, 'success' | 'info' | 'warning' | 'error' | 'default'> = {
  word: 'info',
  cell: 'success',
  slide: 'warning',
  pdf: 'error',
  unknown: 'default',
}

function fmtSize(n: number) {
  if (n < 1024) return n + ' B'
  if (n < 1024 * 1024) return (n / 1024).toFixed(1) + ' KB'
  return (n / (1024 * 1024)).toFixed(1) + ' MB'
}
</script>

<template>
  <n-space vertical :size="20">
    <n-space justify="space-between" align="center">
      <h2 style="margin: 0">Files</h2>
      <n-upload :show-file-list="false" :custom-request="onUpload">
        <n-button data-testid="upload-button">Upload</n-button>
      </n-upload>
    </n-space>

    <n-empty v-if="!loading && files.length === 0" description="No files yet — upload or create one" data-testid="files-empty" />

    <n-grid x-gap="16" y-gap="16" cols="1 s:2 m:3 l:4" responsive="screen">
      <n-gi v-for="f in files" :key="f.name">
        <n-card hoverable :data-testid="`file-card-${f.name}`" @click="open(f)" style="cursor: pointer">
          <template #header>
            <span :data-testid="`file-name-${f.name}`">{{ f.name }}</span>
          </template>
          <template #header-extra>
            <n-tag :type="typeColor[f.type]" size="small">{{ f.type }}</n-tag>
          </template>
          <n-text depth="3">{{ fmtSize(f.size) }} — {{ new Date(f.mtime).toLocaleString() }}</n-text>
          <template #footer>
            <n-space justify="end">
              <n-button size="small" :data-testid="`btn-open-${f.name}`" @click.stop="open(f)">Open</n-button>
              <n-button size="small" type="error" :data-testid="`btn-delete-${f.name}`" @click.stop="onDelete(f.name)">Delete</n-button>
            </n-space>
          </template>
        </n-card>
      </n-gi>
    </n-grid>
  </n-space>
</template>

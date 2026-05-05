<script setup lang="ts">
import { computed, h, ref } from 'vue'
import { useRouter, useRoute, RouterLink } from 'vue-router'
import {
  NConfigProvider, NLayout, NLayoutHeader, NLayoutContent, NDropdown,
  NButton, NMenu, NMessageProvider, NDialogProvider, NIcon, NDrawer,
  NDrawerContent, darkTheme,
  type MenuOption
} from 'naive-ui'
import { newFile } from './api'

const router = useRouter()
const route = useRoute()
const drawer = ref(false)

const navOptions: MenuOption[] = [
  {
    label: () => h(RouterLink, { to: '/files', 'data-testid': 'nav-files' }, () => 'Files'),
    key: 'files',
  },
  {
    label: () => h(RouterLink, { to: '/setup', 'data-testid': 'nav-setup' }, () => 'Setup'),
    key: 'setup',
  },
]

const newOptions = [
  { label: 'Word document (.docx)', key: 'docx' },
  { label: 'Spreadsheet (.xlsx)', key: 'xlsx' },
  { label: 'Presentation (.pptx)', key: 'pptx' },
  { label: 'PDF (.pdf)', key: 'pdf' },
]

async function createNew(kind: string | number) {
  const ext = String(kind)
  const stamp = new Date().toISOString().replace(/[:.]/g, '-').slice(0, 19)
  const name = `Untitled-${stamp}.${ext}`
  await newFile(name, ext)
  router.push({ name: 'edit', params: { file: name } })
}

function go(path: string) {
  drawer.value = false
  router.push(path)
}

function logout() {
  const url = new URL(window.location.href)
  const authHost = url.host.replace(/^[^.]+/, 'auth')
  window.location.href = `${url.protocol}//${authHost}/logout?rd=${encodeURIComponent(url.origin)}`
}

const activeNav = computed(() => route.name === 'setup' ? 'setup' : 'files')
const inEditor = computed(() => route.name === 'edit')
</script>

<template>
  <n-config-provider :theme="darkTheme">
    <n-message-provider>
      <n-dialog-provider>
        <n-layout style="height: 100vh">
          <n-layout-header v-if="!inEditor" bordered>
            <div class="header-bar">
              <n-button
                quaternary
                circle
                class="burger"
                data-testid="nav-burger"
                aria-label="menu"
                @click="drawer = true"
              >
                <n-icon size="22">
                  <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round">
                    <line x1="4" y1="7" x2="20" y2="7" />
                    <line x1="4" y1="12" x2="20" y2="12" />
                    <line x1="4" y1="17" x2="20" y2="17" />
                  </svg>
                </n-icon>
              </n-button>
              <strong data-testid="brand" class="brand">ONLYOFFICE</strong>
              <n-menu
                class="nav nav-desktop"
                mode="horizontal"
                :options="navOptions"
                :value="activeNav"
              />
              <span class="spacer" />
              <n-dropdown :options="newOptions" trigger="click" @select="createNew">
                <n-button type="primary" data-testid="new-doc-button">+ New</n-button>
              </n-dropdown>
              <n-button
                quaternary
                data-testid="logout-button"
                aria-label="logout"
                @click="logout"
              >Logout</n-button>
            </div>
          </n-layout-header>
          <n-layout-content :content-style="inEditor ? 'height: 100vh' : 'padding: 24px'">
            <router-view />
          </n-layout-content>
        </n-layout>

        <n-drawer
          v-model:show="drawer"
          :width="280"
          placement="left"
          data-testid="nav-drawer"
        >
          <n-drawer-content closable>
            <template #header>
              <span class="drawer-brand">ONLYOFFICE</span>
            </template>
            <div class="drawer-links">
              <button
                class="drawer-link"
                :class="{ active: activeNav === 'files' }"
                data-testid="nav-files"
                @click="go('/files')"
              >Files</button>
              <button
                class="drawer-link"
                :class="{ active: activeNav === 'setup' }"
                data-testid="nav-setup"
                @click="go('/setup')"
              >Setup</button>
            </div>
          </n-drawer-content>
        </n-drawer>
      </n-dialog-provider>
    </n-message-provider>
  </n-config-provider>
</template>

<style scoped>
.header-bar {
  display: flex;
  align-items: center;
  height: 56px;
  padding: 0 24px;
  gap: 16px;
}
.brand {
  font-size: 18px;
  white-space: nowrap;
}
.nav {
  flex: 1;
}
.spacer {
  flex: 1;
}
.burger {
  display: none;
}
:deep(.n-menu--horizontal .n-menu-item) {
  height: 56px;
  display: flex;
  align-items: center;
}
.drawer-brand {
  font-weight: 700;
  letter-spacing: 0.5px;
}
.drawer-links {
  display: flex;
  flex-direction: column;
  gap: 4px;
}
.drawer-link {
  appearance: none;
  background: transparent;
  border: 0;
  color: inherit;
  font: inherit;
  text-align: left;
  padding: 12px 16px;
  border-radius: 8px;
  cursor: pointer;
  font-size: 16px;
}
.drawer-link:hover {
  background: rgba(255, 255, 255, 0.06);
}
.drawer-link.active {
  background: rgba(99, 226, 183, 0.15);
  color: #63e2b7;
}
@media (max-width: 768px) {
  .header-bar {
    padding: 0 12px;
    gap: 8px;
  }
  .burger {
    display: inline-flex;
  }
  .nav-desktop {
    display: none;
  }
}
</style>

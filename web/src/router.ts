import { createRouter, createWebHistory } from 'vue-router'
import Files from './views/Files.vue'
import Editor from './views/Editor.vue'
import Setup from './views/Setup.vue'

export const router = createRouter({
  history: createWebHistory(),
  routes: [
    { path: '/', redirect: '/files' },
    { path: '/files', name: 'files', component: Files },
    { path: '/edit/:file', name: 'edit', component: Editor, props: true },
    { path: '/setup', name: 'setup', component: Setup },
  ],
})

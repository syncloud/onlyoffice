import { createApp } from 'vue'
import naive from 'naive-ui'
import App from './App.vue'
import { router } from './router'

if (import.meta.env.VITE_STUB) {
  const { makeServer } = await import('./mirage/server')
  makeServer()
}

createApp(App).use(naive).use(router).mount('#app')

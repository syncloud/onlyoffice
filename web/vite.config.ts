import { defineConfig } from 'vite'
import vue from '@vitejs/plugin-vue'

export default defineConfig({
  plugins: [vue()],
  build: {
    outDir: 'dist',
    emptyOutDir: true,
    sourcemap: false,
  },
  server: {
    proxy: {
      '/api': 'http://localhost:8088',
      '/web-apps': 'http://localhost:8088',
      '/sdkjs': 'http://localhost:8088',
      '/fonts': 'http://localhost:8088',
      '/coauthoring': 'http://localhost:8088',
    },
  },
})

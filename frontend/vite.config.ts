import { defineConfig } from 'vite'
import vue from '@vitejs/plugin-vue'
import vuetify from 'vite-plugin-vuetify'
import { fileURLToPath, URL } from 'node:url'

export default defineConfig({
  plugins: [vue(), vuetify({ autoImport: true })],
  resolve: { alias: { '@': fileURLToPath(new URL('./src', import.meta.url)) } },
  define: { global: 'window' },
  server: {
    host: true,
    port: 5173,
    strictPort: true,
    proxy: { '/api': { target: process.env.VITE_API_TARGET ?? 'http://api:9111', changeOrigin: true } },
  },
})

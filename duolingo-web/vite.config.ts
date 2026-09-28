import { defineConfig } from 'vite'
import react from '@vitejs/plugin-react'

export default defineConfig(({ command }) => ({
  base: command === 'build' ? '/AYG/lingo/' : '/',
  plugins: [react()],
  build: {
    outDir: '../docs/lingo',
    emptyOutDir: true,
    sourcemap: false,
  },
  server: {
    host: '0.0.0.0',
    port: 5173,
  },
}))

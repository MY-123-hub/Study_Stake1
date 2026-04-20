import { defineConfig } from 'vite'
import react from '@vitejs/plugin-react'

export default defineConfig({
  plugins: [react()],
  base: '/StudyStake/', // GitHub Pages 子目录
  build: {
    outDir: 'dist',
  },
})

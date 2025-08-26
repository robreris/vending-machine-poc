import { defineConfig } from 'vite';
import react from '@vitejs/plugin-react';
import fs from 'fs';

export default defineConfig({
  plugins: [react()],
  server: {
    port: 5173,
    proxy: {
      '/api': {
        target: 'https://fortiflex.robs-fortinet-apps.com:8000',
        changeOrigin: true,
        secure: false, //self-signed certs
      },
    },
  }
});

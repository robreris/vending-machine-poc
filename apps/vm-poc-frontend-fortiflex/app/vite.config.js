import { defineConfig } from 'vite';
import react from '@vitejs/plugin-react';
import fs from 'fs';
import os from 'os';

FORTIFLEX_BACKEND_URL = os.environ.get("FORTIFLEX_BACKEND_URL", "http://vm-poc-backend-fortiflex:5000/") 

export default defineConfig({
  plugins: [react()],
  server: {
    port: 5173,
    proxy: {
      '/api': {
        target: FORTIFLEX_BACKEND_URL,
        changeOrigin: true,
        secure: false, //self-signed certs
      },
    },
  }
});

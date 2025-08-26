import { defineConfig } from 'vite';
import react from '@vitejs/plugin-react';
import fs from 'fs';

export default defineConfig({
  plugins: [react()],
  server: {
    https: {
      key: fs.readFileSync('./certs/key.pem'),
      cert: fs.readFileSync('./certs/cert.pem'),
    },
    port: 5173,
    proxy: {
      '/api': {
        target: 'https://ec2-52-43-126-239.us-west-2.compute.amazonaws.com:8000',
        changeOrigin: true,
        secure: false, //self-signed certs
      },
    },
  }
});

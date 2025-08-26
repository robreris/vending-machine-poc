FROM node:20-alpine
WORKDIR /app
COPY package*.json ./
RUN npm install
COPY . .

ENV SSL_CERT_FILE=/app/certs/cert.pem
ENV SSL_KEY_FILE=/app/certs/key.pem

RUN npm run build

CMD ["npx", "serve", "-s", "dist", "-l", "5173", "--ssl-cert", "/app/certs/cert.pem", "--ssl-key", "/app/certs/key.pem"]
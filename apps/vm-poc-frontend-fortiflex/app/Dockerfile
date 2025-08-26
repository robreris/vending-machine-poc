# --- build stage ---
FROM node:20-alpine AS build
WORKDIR /app
COPY package*.json ./
RUN npm install
COPY . .
RUN npm run build

# --- runtime stage ---
FROM nginx:alpine
# Template + entrypoint
COPY app.conf.template /etc/nginx/templates/app.conf.template
COPY docker-entrypoint.sh /docker-entrypoint.sh
RUN chmod +x /docker-entrypoint.sh

# Static site
COPY --from=build /app/dist /usr/share/nginx/html

EXPOSE 80
CMD ["/docker-entrypoint.sh"]


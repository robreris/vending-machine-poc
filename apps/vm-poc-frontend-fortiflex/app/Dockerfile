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

# Ensure envsubst is available and remove default config
RUN apk add --no-cache gettext && \
    rm -f /etc/nginx/conf.d/default.conf

# Static site
COPY --from=build /app/dist /usr/share/nginx/html

# Run as the non-root "nginx" user already created by the base image.
# nginx listens on an unprivileged port (see app.conf.template), so no
# elevated capability is needed to bind it as non-root.
RUN chown -R nginx:nginx /usr/share/nginx/html /var/cache/nginx /etc/nginx/conf.d /var/run \
    && touch /var/run/nginx.pid \
    && chown nginx:nginx /var/run/nginx.pid
USER nginx

EXPOSE 8080
CMD ["/docker-entrypoint.sh"]

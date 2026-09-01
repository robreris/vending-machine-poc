# --- build stage ---
FROM node:20-alpine@sha256:fb4cd12c85ee03686f6af5362a0b0d56d50c58a04632e6c0fb8363f609372293 AS build
WORKDIR /app
COPY package*.json ./
RUN npm install
COPY . .
RUN npm run build

# --- runtime stage ---
FROM nginx:alpine@sha256:db35bfc6b2951e7f8a72db5db120288c127ffaeeb4a6d4b95a26fead017d5913
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

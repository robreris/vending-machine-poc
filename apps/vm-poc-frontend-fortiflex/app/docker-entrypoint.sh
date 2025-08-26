#!/bin/sh
set -e

# Default for local testing if env is unset
: "${FORTIFLEX_BACKEND_URL:=http://vm-poc-backend-fortiflex:5000}"

# Render Nginx config from template using env var
envsubst '${FORTIFLEX_BACKEND_URL}' \
  </etc/nginx/templates/app.conf.template \
  >/etc/nginx/conf.d/app.conf

exec nginx -g 'daemon off;'

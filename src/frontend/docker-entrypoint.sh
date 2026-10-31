#!/bin/sh
set -e

# Generate runtime config.js from environment variables injected by ECS/Terraform
cat <<EOF > /usr/share/nginx/html/config.js
window.__APP_CONFIG__ = {
  VITE_COGNITO_USER_POOL_ID: "${VITE_COGNITO_USER_POOL_ID:-}",
  VITE_COGNITO_CLIENT_ID: "${VITE_COGNITO_CLIENT_ID:-}",
  VITE_AWS_REGION: "${VITE_AWS_REGION:-us-east-1}",
  VITE_API_BASE_URL: "${VITE_API_BASE_URL:-}"
};
EOF

# Execute container command (default: nginx -g "daemon off;")
exec "$@"


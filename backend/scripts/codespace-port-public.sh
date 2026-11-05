#!/usr/bin/env bash
# Makes this Codespace's port 3000 (the API) Public, so the app, the admin site, Netlify and PayFast can reach it.
# A Private port answers with a GitHub sign-in page (302 / 401 "tunnel") instead of JSON.
# Run it after `npm start` (Codespaces may set the port back to Private when the server restarts):
#   npm run port:public            # or: bash scripts/codespace-port-public.sh 3000
set -euo pipefail
PORT="${1:-3000}"
if [ -z "${CODESPACE_NAME:-}" ]; then
  echo "Not in a Codespace: nothing to do." ; exit 0
fi
gh codespace ports visibility "${PORT}:public" -c "$CODESPACE_NAME"
URL="https://${CODESPACE_NAME}-${PORT}.${GITHUB_CODESPACES_PORT_FORWARDING_DOMAIN:-app.github.dev}"
echo "Port $PORT is Public: $URL"
code=$(curl -s -o /dev/null -w '%{http_code}' "$URL/health" || true)
echo "GET $URL/health -> HTTP $code (200 = OK; 302/401 = still private or the server is not running)"

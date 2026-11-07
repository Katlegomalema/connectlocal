#!/usr/bin/env bash
# Build the Flutter web app (or the admin site) with Docker and serve it from this Codespace.
# Flutter is not installed in the Codespace; the ghcr.io/cirruslabs/flutter image is used instead.
#
#   tool/run_web_codespace.sh            # customer/provider app on port 8080
#   tool/run_web_codespace.sh admin      # admin website on port 8081
#
# Needs: backend running on port 3000 (cd backend && npm start) and port 3000 set to Public.
set -euo pipefail
cd "$(dirname "$0")/.."

TARGET=lib/main.dart; OUT=build/web; PORT=8080
if [ "${1:-}" = "admin" ]; then TARGET=lib/main_admin.dart; OUT=build/web_admin; PORT=8081; fi

if lsof -t -i:"$PORT" -sTCP:LISTEN >/dev/null 2>&1; then
  echo "Port $PORT is already in use (an earlier run?). Stop it with:  kill \$(lsof -t -i:$PORT)" >&2
  exit 1
fi
if ! curl -s -o /dev/null --max-time 3 http://localhost:3000/health; then
  echo "Note: the backend is not running on port 3000. Start it in ANOTHER terminal: cd backend && npm start" >&2
fi

if [ -n "${API_BASE_URL:-}" ]; then
  API="$API_BASE_URL"
elif [ -n "${CODESPACE_NAME:-}" ]; then
  API="https://${CODESPACE_NAME}-3000.${GITHUB_CODESPACES_PORT_FORWARDING_DOMAIN:-app.github.dev}"
else
  API="http://localhost:3000"
fi

# Maps: Esri street map by default (no key). With a free MapTiler key: MAPTILER_KEY=... tool/run_web_codespace.sh
MAP_DEFINE=""
if [ -n "${MAPTILER_KEY:-}" ]; then
  MAP_DEFINE="--dart-define=MAPTILER_KEY=$MAPTILER_KEY"
  echo "Maps: MapTiler"
else
  echo "Maps: Esri World Street Map (set MAPTILER_KEY to use MapTiler)"
fi

echo "API_BASE_URL = $API"
echo "Building $TARGET (takes 1-2 minutes)..."
docker run --rm -v flutter-pub-cache:/root/.pub-cache -v "$PWD":/app -w /app ghcr.io/cirruslabs/flutter:stable \
  bash -c "flutter pub get >/dev/null && flutter build web --release -t $TARGET -o $OUT --dart-define=API_BASE_URL=$API $MAP_DEFINE"
# The container writes files as root; give them back to you.
sudo chown -R "$(id -u):$(id -g)" . 2>/dev/null || true

if [ -n "${CODESPACE_NAME:-}" ]; then
  echo
  echo "Open: https://${CODESPACE_NAME}-${PORT}.${GITHUB_CODESPACES_PORT_FORWARDING_DOMAIN:-app.github.dev}"
fi
echo "Serving $OUT on port $PORT (Ctrl+C to stop)"
exec python3 -m http.server "$PORT" --bind 0.0.0.0 --directory "$OUT"

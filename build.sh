#!/usr/bin/env bash
# Builds the website and the admin panel into the places the server serves them from:
#   website  source/web   ->  repository root  (abvpconnect.org = public_html)
#   admin    source/admin ->  admin/           (admin.abvpconnect.org = public_html/admin)
# Run it on your computer after changing anything in source/, then commit and push to main.
#
#   ./build.sh                      # uses https://api.abvpconnect.org/api/v1
#   VITE_GOOGLE_CLIENT_ID=xxx ./build.sh
set -euo pipefail
cd "$(dirname "$0")"
ROOT="$(pwd)"
export VITE_API_URL="${VITE_API_URL:-https://api.abvpconnect.org/api/v1}"
export VITE_GOOGLE_CLIENT_ID="${VITE_GOOGLE_CLIENT_ID:-}"

build() { (cd "$ROOT/source/$1" && npm ci --no-audit --no-fund && npm run build); }

echo "== Website"
build web
# Replace only what the build owns; api/, admin/, source/ and docs/ are left alone.
rm -rf "$ROOT/assets" "$ROOT/fonts" "$ROOT/img"
rm -f "$ROOT/index.html" "$ROOT/favicon.svg" "$ROOT/.htaccess"
cp -R "$ROOT/source/web/dist/." "$ROOT/"

echo "== Admin panel"
build admin
rm -rf "$ROOT/admin"
mkdir -p "$ROOT/admin"
cp -R "$ROOT/source/admin/dist/." "$ROOT/admin/"

echo "Done. Website and admin built against $VITE_API_URL. Commit and push to main."

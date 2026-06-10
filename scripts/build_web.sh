#!/usr/bin/env bash
# Build web de release carimbando o identificador do build em dois lugares que
# precisam bater: embutido no app (--dart-define=APP_BUILD) e gravado em
# build/web/app_build.json (servido no deploy). O app compara os dois para
# detectar quando uma nova versão foi publicada e oferecer o recarregamento.
#
# Uso: ./scripts/build_web.sh
set -euo pipefail
cd "$(dirname "$0")/.."

BUILD_ID="$(date +%Y%m%d%H%M%S)"

flutter build web --release --no-tree-shake-icons --dart-define=APP_BUILD="$BUILD_ID"

printf '{"build":"%s"}\n' "$BUILD_ID" > build/web/app_build.json
echo "✅ Build carimbado: APP_BUILD=$BUILD_ID (build/web/app_build.json)"

#!/usr/bin/env bash
#
# Gate de testes dos 3 runtimes do Villamor CRM, em um comando.
# Uso (a partir de qualquer lugar):  bash scripts/testar_tudo.sh
#
# - Dart/Flutter: flutter test --exclude-tags bug-aberto  (exclui guardas de bug aberto)
# - Cloud Functions: node --test (offline)
# - Firestore Rules: emulador (requer Java) + @firebase/rules-unit-testing
#
# Sai com código != 0 se qualquer runtime falhar. As guardas `bug-aberto`
# (testes vermelhos de bug ainda não corrigido) NÃO entram no gate:
# - Dart: via `--exclude-tags bug-aberto`.
# - Rules: via `GATE_DEPLOY=1` (lido em firestore-tests/setup.js → `{skip}`).

set -uo pipefail

# Raiz do repo = diretório-pai deste script.
RAIZ="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$RAIZ"

# Garante Java no PATH para o emulador (openjdk@21 via Homebrew, se existir).
if [ -d /opt/homebrew/opt/openjdk@21/bin ]; then
  export PATH="/opt/homebrew/opt/openjdk@21/bin:$PATH"
fi

falhas=()

echo "──────────────────────────────────────────────"
echo "1/3  Dart/Flutter  (flutter test --exclude-tags bug-aberto)"
echo "──────────────────────────────────────────────"
if flutter test --exclude-tags bug-aberto; then
  echo "✔ Dart/Flutter OK"
else
  falhas+=("Dart/Flutter")
fi

echo ""
echo "──────────────────────────────────────────────"
echo "2/3  Cloud Functions  (node --test)"
echo "──────────────────────────────────────────────"
if npm --prefix functions test; then
  echo "✔ Functions OK"
else
  falhas+=("Functions")
fi

echo ""
echo "──────────────────────────────────────────────"
echo "3/3  Firestore Rules  (emulador — requer Java)"
echo "──────────────────────────────────────────────"
if GATE_DEPLOY=1 firebase emulators:exec --only firestore --project=demo-villamor \
     "GATE_DEPLOY=1 npm --prefix '$RAIZ/firestore-tests' test"; then
  echo "✔ Rules OK"
else
  falhas+=("Rules")
fi

echo ""
echo "══════════════════════════════════════════════"
if [ ${#falhas[@]} -eq 0 ]; then
  echo "✅ GATE VERDE — todos os runtimes passaram. Liberado para deploy."
  exit 0
else
  echo "❌ GATE VERMELHO — falhou em: ${falhas[*]}. Deploy bloqueado."
  exit 1
fi

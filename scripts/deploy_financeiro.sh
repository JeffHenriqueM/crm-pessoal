#!/bin/bash
# deploy_financeiro.sh
# Publicação da feature Financeiro com os gates obrigatórios do projeto.
# Rodar em: /Users/jeffersonhenrique/Documents/Projetos/crm_pessoal
#
# Ordem: gate de testes Dart -> suíte de Rules -> (confirmação) criar usuários
# -> (confirmação) deploy rules/indexes -> deploy de PREVIEW (nunca produção
# direto). Ver CLAUDE.md / TESTING.md.

set -euo pipefail
cd "$(dirname "$0")/.."

confirmar() {
  read -r -p "$1 [s/N] " resp
  case "$resp" in
    s|S|sim|SIM) return 0 ;;
    *) echo "Cancelado."; exit 1 ;;
  esac
}

echo ""
echo "=== 1/5 — Gate de testes (flutter test) ==="
flutter test --exclude-tags bug-aberto

echo ""
echo "=== 2/5 — Suíte de Firestore Rules (emulador + Java) ==="
( cd firestore-tests && npm test )

echo ""
echo "=== 3/5 — Criar usuários financeiro (PRODUÇÃO) ==="
confirmar "Isso cria/atualiza usuários reais em produção. Continuar?"
NODE_PATH=./functions/node_modules node scripts/criar_usuarios_financeiro.cjs

echo ""
echo "=== 4/5 — Deploy Firestore rules + indexes (PRODUÇÃO) ==="
confirmar "Deployar Rules + indexes para produção?"
firebase deploy --only firestore:rules,firestore:indexes --project crm-pessoal-d993d

echo ""
echo "=== 5/5 — Deploy de PREVIEW (hosting) ==="
firebase hosting:channel:deploy preview_financeiro --expires 7d --project crm-pessoal-d993d

echo ""
echo "✅ Concluído. Produção (hosting) é deploy manual separado, após validar o preview."

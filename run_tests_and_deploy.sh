#!/bin/zsh
# run_tests_and_deploy.sh
# Gate de testes + deploy. Por padrão deploya SOMENTE hosting.
# Rules/indexes só são deployados com DEPLOY_RULES=1 e exigem a suíte de Rules
# verde (emulador + Java) — política do projeto (ver CLAUDE.md / TESTING.md).
source ~/.zshrc 2>/dev/null || true
source ~/.zprofile 2>/dev/null || true

LOG="/tmp/villamor_test_deploy.log"
echo "=== INÍCIO: $(date) ===" > "$LOG"

cd /Users/jeffersonhenrique/Documents/Projetos/crm_pessoal

echo "--- flutter test (gate obrigatório) ---" >> "$LOG"
flutter test --exclude-tags bug-aberto 2>&1 | tee -a "$LOG"
TEST_EXIT=${PIPESTATUS[0]}
echo "--- TEST_EXIT=$TEST_EXIT ---" >> "$LOG"

if [ "$TEST_EXIT" -ne 0 ]; then
  echo "TESTES FALHARAM — deploy abortado." | tee -a "$LOG"
  echo "RESULTADO: FALHA_TESTES" >> "$LOG"
  exit 1
fi

# Alvos de deploy: hosting sempre; rules/indexes só sob demanda e com gate próprio.
DEPLOY_TARGETS="hosting"

if [ "${DEPLOY_RULES:-0}" = "1" ]; then
  echo "--- suíte de Rules (obrigatória antes de deployar rules) ---" | tee -a "$LOG"
  ( cd firestore-tests && npm test ) 2>&1 | tee -a "$LOG"
  RULES_EXIT=${PIPESTATUS[0]}
  if [ "$RULES_EXIT" -ne 0 ]; then
    echo "TESTES DE RULES FALHARAM — deploy abortado." | tee -a "$LOG"
    echo "RESULTADO: FALHA_RULES" >> "$LOG"
    exit 1
  fi
  DEPLOY_TARGETS="$DEPLOY_TARGETS,firestore:rules,firestore:indexes"
fi

echo "--- firebase deploy --only $DEPLOY_TARGETS ---" | tee -a "$LOG"
firebase deploy --only "$DEPLOY_TARGETS" --project crm-pessoal-d993d 2>&1 | tee -a "$LOG"
DEPLOY_EXIT=${PIPESTATUS[0]}

if [ "$DEPLOY_EXIT" -eq 0 ]; then
  echo "RESULTADO: DEPLOY_OK ($DEPLOY_TARGETS)" >> "$LOG"
else
  echo "RESULTADO: DEPLOY_FALHOU" >> "$LOG"
fi

echo "=== FIM: $(date) ===" >> "$LOG"

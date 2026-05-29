# TESTING.md — Estratégia de Testes do Villamor CRM

> Cobertura inicial: **zero**. Esta suíte está sendo construída de forma
> **incremental**, um risco por vez, em ordem de prioridade. Cada item é
> escrito, rodado e revisado antes do próximo.

## 🧪 Os três comandos de teste

O projeto tem **três runtimes distintos**, cada um com seu harness:

| Runtime | O que cobre | Comando |
|---|---|---|
| **Dart / Flutter** | Models, lógica de negócio, services, widgets | `flutter test` |
| **Firestore Rules** | Regras de segurança (`firestore.rules`) | `firebase emulators:exec --only firestore --project=demo-villamor "cd firestore-tests && npm test"` |
| **Cloud Functions** | Triggers FCM (`functions/src/index.ts`) | `cd functions && npm test` (offline — `firebase-functions-test` + fakes; **não** precisa de emulador/Java) |

> O scaffolding de cada harness é criado no item correspondente do backlog
> abaixo — ainda não existe tudo de uma vez.

### Pré-requisito do emulador: Java

Os testes de **Rules** e **Functions** rodam contra o **Firebase Emulator**,
que **exige Java instalado** (JDK 11+). Sem Java, esses dois comandos falham.

```bash
brew install --cask temurin   # macOS — ou: brew install openjdk@21
```

Os testes **Dart/Flutter** NÃO precisam de Java nem do emulador.

## 📐 Convenções

### 1. Testar comportamento, não implementação
Os testes descrevem o **comportamento esperado** do sistema, não congelam o
código atual. Em particular:
- **Não** escreva testes que apenas reproduzem o estado atual incluindo bugs.
- Se o código atual está errado, o teste deve afirmar o comportamento
  **correto** e falhar — então corrigimos o código (TDD).
- Prefira asserções sobre o efeito observável (o que ficou gravado, o que foi
  bloqueado, o que foi retornado) e não sobre o passo a passo interno.

### 2. TDD sempre que possível
1. Escreva o teste do comportamento desejado.
2. Rode e **confirme que falha** (e por quê).
3. Ajuste o código até passar.
4. Rode a suíte inteira de novo.

### 3. Sempre rodar a suíte
Após qualquer alteração de teste **ou** de código, rode a suíte do runtime
afetado **e** mostre o resultado antes de seguir adiante. Não marque um item
como concluído sem ver verde.

### 4. Idioma
Seguindo o CLAUDE.md: nomes de teste, descrições e comentários em
**Português**; APIs de framework (`test`, `expect`, `describe`, `group`) em
**Inglês**.

### 5. Guardas de bug (`bug-aberto`) e gate de deploy
Testes que afirmam o comportamento correto de um bug **ainda não corrigido**
ficam VERMELHOS de propósito (guarda de regressão) e recebem a tag
`tags: 'bug-aberto'` (declarada em `dart_test.yaml`), sempre atrelados a um
ticket. Eles documentam o esperado sem bloquear o deploy:

- **Gate de deploy:** `flutter test --exclude-tags bug-aberto` deve estar verde
  antes de qualquer build/deploy (ver CLAUDE.md).
- **Suíte completa:** `flutter test` mostra as guardas vermelhas — é o estado
  esperado enquanto o bug não foi resolvido.
- Ao corrigir o bug, **remover a tag** `bug-aberto` para o teste virar guarda
  viva (e aí ele passa a rodar no gate).

**Rules (Node, sem tags):** o runner `node:test` não tem tags, então a guarda
de bug ainda não corrigido recebe `{ skip: PULAR_BUG_ABERTO }` (exportado de
`firestore-tests/setup.js`). Sem `GATE_DEPLOY` ela roda e fica vermelha; com
`GATE_DEPLOY=1` é pulada — é assim que o gate único (`scripts/testar_tudo.sh`)
roda o passo de Rules. Ao corrigir, remover o `{ skip }` para virar guarda viva.

### Gate único dos 3 runtimes
`bash scripts/testar_tudo.sh` roda Dart + Functions + Rules em sequência,
excluindo as guardas `bug-aberto` de cada runtime, e só sai verde se todos
passarem. É o comando a rodar **antes de qualquer deploy**.

## 🗂️ Estrutura de diretórios (alvo)

```
test/                 # Testes Dart/Flutter (flutter test)
firestore-tests/      # Testes de Security Rules (Node + @firebase/rules-unit-testing)
functions/test/       # Testes de Cloud Functions (Node + firebase-functions-test)
```

## 🪓 Backlog de testes (ordem de prioridade)

| # | Risco | Runtime | Status |
|---|---|---|---|
| 1 | **CRÍTICO** — Rules permitem read/write a qualquer autenticado em todas as coleções; vendedor altera lead alheio e reescreve `audit_log` | Rules | ✅ testes (8 pass / 7 red) · ticket #16 |
| 2 | **CRÍTICO** — soft-delete não atômico em `deletarCliente`: se o `audit_log` falhar, o cliente some sem rastro | Dart | ✅ teste red `test/services/firestore_service_soft_delete_test.dart` · ticket #17 |
| 3 | **ALTO** — `StatusAprovacao`/`StatusNegociacao` sem validação de transição de estado | Dart | ✅ testes (3 green / 3 red `bug-aberto`) `test/services/negociacao_transicao_status_test.dart` · ticket #19 |
| 4 | **ALTO** — Functions `onNegociacaoAtualizada`/`onCampanhaPublicada` disparam FCM sem retry/fallback e sem testes | Functions | ✅ 6 testes de disparo (green) `functions/test/notificacoes.test.js` · ticket #20 (retry/fallback) |
| 5 | **MODERADO** — `auth_service` edge cases do campo `ativo` (usuário sem doc, race condition) | Dart | ✅ testes (2 green / 1 red `bug-aberto`) `test/services/auth_service_ativo_test.dart` · ticket #21 |

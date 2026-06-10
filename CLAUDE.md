# CLAUDE.md — Villamor CRM (`crm_pessoal`)

## 🛠️ Comandos de Execução e Deploy
- Rodar Web Local: `flutter run -d chrome --web-port 5173`
- Build Release: `./scripts/build_web.sh` (carimba `APP_BUILD` no app e em `build/web/app_build.json` para o aviso de "nova versão disponível"). O `flutter build web --release --no-tree-shake-icons` puro ainda funciona, mas sem o carimbo o aviso de atualização fica desligado.
- Deploy Preview: `firebase hosting:channel:deploy preview_nome --project crm-pessoal-d993d`
- Deploy Produção: `firebase deploy --only hosting --project crm-pessoal-d993d`
- Build Functions: `cd functions && npm run build`
- Deploy Functions: **nunca usar `--only functions` genérico** — especificar as funções pelo nome (ver aviso abaixo)

> ⚠️ **NUNCA deletar as funções `api`, `wppAutoLabel`, `wppReengage` do projeto `crm-pessoal-d993d`.**
> Essas 3 são do NeuroCRM (também deployado em `crm-pessoal-d993d`) e não existem no código local deste repositório.
> Se o CLI perguntar se pode deletá-las, a resposta é **NÃO**.
> O deploy de functions deve sempre nomear explicitamente apenas as funções deste repo:
> ```
> firebase deploy \
>   --only functions:onNegociacaoAtualizada,functions:onCampanhaPublicada,functions:onTicketAtualizado,functions:onComentarioAdicionado,functions:lembreteProximoContato \
>   --project crm-pessoal-d993d
> ```

> ⚠️ **Antes de QUALQUER deploy (preview ou produção, hosting ou functions): rodar a suíte de testes e só prosseguir se estiver verde.** Gate obrigatório: `flutter test --exclude-tags bug-aberto` (exclui as guardas de bug ainda não corrigido — ver abaixo). Se o deploy tocar Rules ou Functions, rodar também a suíte correspondente (ver TESTING.md). Falha no gate = deploy bloqueado.

## 🧪 Testes
Estratégia, comandos e backlog de testes em **[TESTING.md](TESTING.md)**. Três runtimes:
- Dart/Flutter: `flutter test`
- Firestore Rules: emulador + `@firebase/rules-unit-testing` (requer Java)
- Cloud Functions: emulador + `firebase-functions-test` (requer Java)

Convenção: **testar comportamento, não implementação** (não congelar bugs); usar TDD; sempre rodar a suíte e mostrar o resultado antes de seguir.

**Guardas de bug (`bug-aberto`):** testes que afirmam o comportamento correto de um bug ainda **não** corrigido ficam propositalmente VERMELHOS e levam a tag `tags: 'bug-aberto'` (declarada em `dart_test.yaml`), atrelados a um ticket. Eles documentam o esperado sem bloquear deploy. O gate roda `flutter test --exclude-tags bug-aberto`; ao corrigir o bug, **remover a tag** para o teste virar guarda viva. Backlog em TESTING.md.

## 📐 Diretrizes de Arquitetura e Código
- Idioma: Código de negócio, variáveis, métodos, comentários e Firestore em **Português**. Widgets Flutter e padrões de framework em **Inglês**.
- Camada de Dados: Widgets NUNCA chamam o Firestore diretamente. Toda comunicação deve passar obrigatoriamente por `lib/services/firestore_service.dart` ou `auth_service.dart`.
- Logs: Use `debugPrint()` em vez de `print()`.
- Convenção de Commits: Seguir rigidamente o Conventional Commits (ex: `feat(escopo): descrição`, `fix(escopo): descrição`). Nunca comitar em `main`.

## 🔒 Regras Críticas de Negócio e Auditoria
- Soft-Delete Obrigatório: NUNCA usar `.delete()` em documentos da coleção `clientes/`. Use `deletado = true` e grave a operação em `/audit_log`.
- Histórico de Modificações: Toda alteração de fase ou save de cliente deve gerar um snapshot parcial na subcoleção `clientes/{id}/historico/`.
- Permissões de Escopo:
  * Perfis `admin`, `pós-venda`, `financeiro`, `super admin` veem TODOS os clientes.
  * Perfis `vendedor`, `captador` veem APENAS os seus próprios leads (onde são donos/criadores).

## 🗺️ Mapa de Telas e Responsabilidades

Use este mapa para ir direto ao arquivo correto sem grep:

| Tela / Widget | Arquivo | Responsabilidade |
|---|---|---|
| Login (produção) | `lib/screens/tela_login_screen.dart` | Autenticação e roteamento por perfil |
| Login (staging) | `lib/screens/staging_login_screen.dart` | Login com mocks para ambiente de testes |
| Dashboard admin | `lib/screens/dashboard_screen.dart` | Shell das abas do dashboard |
| Aba Equipe (admin) | `lib/widgets/aba_admin_overview.dart` | Ranking, filtro por vendedor, contagem de leads |
| Aba Financeiro | `lib/widgets/aba_financeiro.dart` | KPIs e gráfico de fechamentos |
| Aba Captação | `lib/widgets/aba_captacao.dart` | Ranking de captadores |
| Aba Estatísticas | `lib/widgets/aba_estatisticas.dart` | Funil de conversão |
| Aba Relatórios | `lib/widgets/aba_relatorios.dart` | Saúde da carteira e leads esquecidos |
| Aba Perdas | `lib/widgets/aba_motivos_perda.dart` | Motivos de não-venda |
| Home vendedor | `lib/screens/vendedor_home_screen.dart` | Dashboard pessoal + meta do vendedor |
| Pipeline (lista/kanban) | `lib/screens/lista_clientes_screen.dart` | Listagem e filtros de leads |
| Kanban board | `lib/widgets/kanban_view.dart` | Drag-and-drop de fases, modal de mudança de fase |
| Ficha do lead | `lib/screens/ficha_cliente_screen.dart` | Dados, timeline e negociações do lead |
| Negociações | `lib/screens/negociacoes_screen.dart` | Lista de propostas; `lib/widgets/aba_negociacoes.dart` dentro da ficha |
| Recepção | `lib/screens/recepcao_screen.dart` | Cadastro de atendimento e promoção para lead |
| Tickets | `lib/screens/tickets_screen.dart` + `lib/screens/ficha_ticket_screen.dart` | Pós-venda |
| Campanhas | `lib/screens/campanhas_screen.dart` | Gestão de campanhas |
| Gerenciar usuários | `lib/screens/gerenciar_usuarios_screen.dart` | CRUD de usuários (admin) |
| Configurações | `lib/screens/configuracoes_screen.dart` | Preferências do usuário logado |
| PDF da ficha | `lib/services/ficha_pdf.dart` | Geração e impressão da ficha do cliente |
| PDF de proposta | `lib/services/proposta_pdf.dart` | Exportação de proposta comercial |
| Notificações push | `lib/services/push_notification_service.dart` | FCM |
| Detecção de ambiente | `lib/utils/env.dart` | Flag `isTeste` (staging vs produção) |

---

## 🎫 Criar Ticket via Script (sem abrir o app)

Útil para registrar tickets durante sessões de code review, auditorias ou quando o app não está aberto.
O script usa a Firestore REST API com o token salvo pelo `firebase login`.

```bash
node -e "
const path = require('path'), os = require('os'), fs = require('fs'), https = require('https');
const token = JSON.parse(fs.readFileSync(path.join(os.homedir(), '.config/configstore/firebase-tools.json'), 'utf8')).tokens.access_token;
const project = 'crm-pessoal-d993d';
const base = '/v1/projects/' + project + '/databases/(default)/documents';

function r(method, url, body) {
  return new Promise((res, rej) => {
    const data = body ? JSON.stringify(body) : null;
    const req = https.request({ hostname: 'firestore.googleapis.com', path: url, method, headers: { 'Authorization': 'Bearer ' + token, ...(data ? { 'Content-Type': 'application/json', 'Content-Length': Buffer.byteLength(data) } : {}) } }, resp => { let d = ''; resp.on('data', c => d += c); resp.on('end', () => res({ status: resp.statusCode, body: JSON.parse(d) })); });
    r.on('error', rej); if (data) req.write(data); req.end();
  });
}

// ── PREENCHA AQUI ──────────────────────────────────────────────
const TITULO    = 'Título do ticket';
const DESCRICAO = 'Descrição detalhada';
const TIPO      = 'melhoria'; // bug | melhoria | funcionalidade
const PRIORIDADE = 'media';   // baixa | media | alta
// ───────────────────────────────────────────────────────────────

async function main() {
  const counter = await r('GET', base + '/_contadores/tickets');
  let maxNum = parseInt(counter.body?.fields?.tickets?.integerValue || '0');

  // fallback: varrer tickets para achar o maior número
  if (!maxNum) {
    const list = await r('GET', base + '/tickets?pageSize=300');
    (list.body.documents || []).forEach(d => { const n = parseInt(d.fields?.numero?.integerValue || '0'); if (n > maxNum) maxNum = n; });
  }

  const num = maxNum + 1;
  const now = new Date().toISOString();
  const doc = { fields: {
    numero: { integerValue: String(num) }, titulo: { stringValue: TITULO },
    descricao: { stringValue: DESCRICAO }, status: { stringValue: 'aberto' },
    prioridade: { stringValue: PRIORIDADE }, tipo: { stringValue: TIPO },
    criadoPorId: { stringValue: 'claude-assistant' }, criadoPorNome: { stringValue: 'Claude (Assistant)' },
    criadoPorPerfil: { stringValue: 'super admin' }, contexto: { nullValue: null },
    atribuidoParaId: { nullValue: null }, atribuidoParaNome: { nullValue: null },
    dataCriacao: { timestampValue: now }, dataAtualizacao: { timestampValue: now },
    clienteId: { nullValue: null }, clienteNome: { nullValue: null }, totalComentarios: { integerValue: '0' },
  }};

  const create = await r('POST', base + '/tickets', doc);
  if (create.status === 200) {
    await r('PATCH', base + '/_contadores/tickets?updateMask.fieldPaths=tickets', { fields: { tickets: { integerValue: String(num) } } });
    console.log('✅ Ticket #' + num + ' criado — ID: ' + create.body.name.split('/').pop());
  } else { console.error('Erro:', create.status, JSON.stringify(create.body)); }
}
main().catch(console.error);
"
```

**Campos obrigatórios para preencher:** `TITULO`, `DESCRICAO`, `TIPO` e `PRIORIDADE`.
O número é atribuído automaticamente em sequência.

---

## 🪓 Contexto para Resolução de Backlog Ativo
Ao atuar nos tickets abertos do sistema, consulte os seguintes arquivos-alvo para evitar buscas globais (grep) desnecessárias:

1. **Bug do Filtro no Dashboard Admin (Contagem de Leads Geral vs Selecionado):**
   - *Arquivo-alvo:* `lib/widgets/aba_admin_overview.dart` e `lib/screens/dashboard_screen.dart`.
   - *Ação:* Garantir que a recontagem de leads aplique o filtro do UID do vendedor selecionado e não o tamanho total do snapshot.

2. **Erro na Impressão de Ficha no Ambiente de Teste:**
   - *Arquivo-alvo:* `lib/services/ficha_pdf.dart` e o gatilho de chamada em `lib/screens/ficha_cliente_screen.dart`.

3. **Sumisso/Aparecimento de Negociações no Perfil Vendedor:**
   - *Arquivo-alvo:* `lib/screens/negociacoes_screen.dart` e `lib/widgets/aba_negociacoes.dart`.
   - *Ação:* Validar se a query do Firestore na coleção raiz `/negociacoes` está filtrando corretamente pelo `vendedorId` ou se está aplicando regras restritivas demais.

4. **Campo de Motivo de Perda Obrigatório:**
   - *Arquivo-alvo:* `lib/models/fase_enum.dart` (validação), `lib/widgets/kanban_view.dart` (modal de mudança de fase) e `lib/widgets/aba_motivos_perda.dart`.

5. **Erro ao Exportar PDF da Proposta:**
   - *Arquivo-alvo:* `lib/services/proposta_pdf.dart` e a chamada do botão de exportação.

6. **Vendedor Desassociando ao Reabrir Lead Criado na Recepção:**
   - *Arquivo-alvo:* `lib/screens/recepcao_screen.dart` ao promover o atendimento para o funil, e o mapeamento de campos em `lib/models/cliente_model.dart`.
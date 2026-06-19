# STACK ANALYSIS — Villamor CRM (`crm_pessoal`)

> Sistema de gestão comercial do **Villamor Tambaba Resort**. App web (Flutter) + backend serverless (Firebase).
> Versão atual: `1.1.0+2` · Documento gerado em **2026-06-18**.
>
> 📘 **Regras de negócio** (funil, permissões, auditoria, fila, metas etc.): ver **[REGRAS_NEGOCIO.md](REGRAS_NEGOCIO.md)**.

---

## 📱 FRONTEND

| Item | Detalhe |
|---|---|
| **Framework** | Flutter (SDK Dart `^3.9.2`), Material Design |
| **Linguagem** | Dart — ~43.800 linhas em `lib/` |
| **Styling** | Material 3 / `ColorScheme` (tema em `lib/theme/`), sem CSS — UI 100% em widgets |
| **Build Tool** | `flutter build web --release` via `scripts/build_web.sh` (carimba `APP_BUILD` para o aviso de "nova versão disponível") |
| **Arquitetura** | StatefulWidget + StreamBuilder, reatividade com **rxdart** (`Rx.combineLatest`). Widgets **nunca** falam com Firestore direto — só via `firestore_service.dart` / `auth_service.dart` |
| **Organização** | 21 screens · 32 widgets · 17 services · 25 models |

**Bibliotecas principais:** `cloud_firestore`, `firebase_auth`, `firebase_core`, `firebase_messaging` (FCM), `fl_chart` (gráficos), `table_calendar` (agenda), `rxdart` (streams), `pdf` + `printing` (ficha/propostas), `csv` + `excel` + `archive` (exportações), `intl` (pt-BR), `url_launcher`, `font_awesome_flutter`, `shared_preferences`, `add_2_calendar`.

---

## 🔧 BACKEND

| Item | Detalhe |
|---|---|
| **Runtime** | Node.js 20 (Cloud Functions) + TypeScript `^5.3.3` |
| **Framework** | `firebase-functions ^5.0.0`, `firebase-admin ^12.0.0`, `googleapis` (Drive/backup) |
| **Banco de Dados** | Cloud Firestore (NoSQL documental) — ~25 coleções |
| **ORM/Query Builder** | Nenhum — SDK nativo. Mapeamento manual `toFirestore`/`fromFirestore` nos models |
| **Autenticação** | Firebase Auth (e-mail/senha), roteamento por perfil |
| **API Type** | Sem REST/GraphQL próprio — acesso direto ao Firestore (Rules = autorização) + 5 Cloud Functions reativas |

**Cloud Functions (486 linhas, `functions/src/index.ts`):**
`onNegociacaoAtualizada` · `onCampanhaPublicada` · `onTicketAtualizado` · `onComentarioAdicionado` · `lembreteProximoContato`

> ⚠️ No mesmo projeto Firebase convivem `api`, `wppAutoLabel`, `wppReengage` — **do NeuroCRM, não deste repo**. Nunca deletar; deploy sempre nomeando funções explicitamente.

**Perfis de usuário:** `super admin`, `admin`, `financeiro`, `pós-venda`, `recepcao`, `vendedor`, `captador`.
`perfisComVisaoTotal` (admin/super admin/financeiro/pós-venda/recepcao) veem tudo; `vendedor`/`captador` só os próprios leads.

---

## ☁️ INFRAESTRUTURA

| Item | Detalhe |
|---|---|
| **Hosting** | Firebase Hosting (SPA, rewrite `**` → `/index.html`). Produção: **crm-pessoal-d993d.web.app** |
| **Containerização** | Nenhuma — serverless puro |
| **CI/CD** | ❌ **Não há** (`.github/workflows` ausente). Deploy 100% manual com gate de testes obrigatório |
| **Banco Produção** | Firestore em `crm-pessoal-d993d` (8 índices compostos: `clientes`, `interacoes`, `negociacoes`, `tickets`) |
| **Backup** | Automatizado via `launchd` (`com.villamor.crm.backup.plist` + `scripts/backup_firestore.cjs`) → Google Drive (`setup_drive.cjs`) |
| **Ambientes** | Produção (`crm-pessoal-d993d.web.app`) e Staging (`loja-virtual-943d7.web.app`) — detecção por hostname em runtime (`lib/utils/env.dart`, `kIsStaging`) |

**Fluxo de deploy (manual, com gate):**
`flutter test --exclude-tags bug-aberto` → `build_web.sh` → preview channel → validação → produção (`firebase deploy --only hosting`). Functions/Rules só após suíte correspondente verde.

---

## 📱 MOBILE

Web-first (Flutter web / PWA). Plataformas Firebase configuradas para Android, iOS, macOS e Windows, mas o uso real e os deploys são **web**. Não há app nativo publicado em lojas.

---

## 🔐 SEGURANÇA

| Item | Detalhe |
|---|---|
| **Environment vars** | Sem `.env`. Config Firebase em `lib/firebase_options.dart` (chaves web públicas). Ambiente por hostname em runtime |
| **HTTPS** | Sim, nativo do Firebase Hosting (TLS automático) |
| **Auth flow** | Firebase Auth → perfil em `usuarios/{uid}` → roteamento de telas + **Firestore Security Rules** (241 linhas) como autorização real no servidor |
| **Auditoria** | Soft-delete obrigatório em `clientes/` (`deletado=true`, nunca `.delete()`) + trilha em `audit_log` + snapshots em `clientes/{id}/historico/` |

---

## 📊 DADOS REAIS EM PRODUÇÃO (medido em 2026-06-18)

### Usuários — 9 contas ativas
| Perfil | Qtd |
|---|---|
| vendedor | 3 |
| super admin | 2 |
| pós-venda | 1 |
| recepcao | 1 |
| captador | 1 |
| reserva | 1 |

> É uma equipe pequena e fechada (núcleo do resort), não um produto multi-tenant.

### Volume de coleções
| Coleção | Documentos |
|---|---|
| contratos | 1.188 |
| clientes | 338 (318 ativos · 20 soft-deletados) |
| tickets | 118 |
| contatos_embaixador | 112 |
| negociacoes | 35 |
| audit_log | 16 |
| agendamentos | 1 (feature nova) |
| campanhas / cotas / fila_atendimento | 0 |

> `interacoes`, `notificacoes` e `historico` são **subcoleções** de `clientes/{id}/` — por isso aparecem como 0 na raiz; os dados existem por cliente.

### Clientes por fase do funil
`perdido` 74 · `fechamento` 65 · `atendimento` 60 · `negociacao` 42 · `prospeccao` 30 · `fechado` 25 · `contato` 24 · `visita` 16 · `sondagem` 2.

---

## 🔗 INTEGRAÇÃO NeuroCRM ↔ Villamor (banco unificado)

**Estado atual (migração concluída em 2026-05-29):** NeuroCRM e Villamor CRM **compartilham o mesmo Firestore** (`crm-pessoal-d993d`). Não há mais import/sync entre os sistemas — ambos leem/escrevem no mesmo banco.

- **Banco único:** `crm-pessoal-d993d`.
- **Hosting/Functions do NeuroCRM:** continuam em `servicopronto-e6e5e` (o Firestore desse projeto ficou vazio).
- **Coleção compartilhada:** `clientes/` — campos do NeuroCRM (`behavioral_profile`, `main_desire`, etc.) são extras que o Flutter simplesmente ignora.
- **Subcoleções:** `clientes/{id}/historico` e `clientes/{id}/interacoes` são do Villamor; `clientes/{id}/neuro_interacoes` é do NeuroCRM.
- **Coleções exclusivas do NeuroCRM:** `neuro_users` (auth JWT — renomeado de `users/` p/ não colidir com `usuarios/`), `wpp_conversations`, `commissions`, `daily_entries`, `recurring_tasks`, `rotina_knowledge`, `ideas`, `push_subscriptions`, `media_albums`.
- **Tickets:** unificados — vistos por ambos os sistemas.

**Mapeamento de campos (clientes/ ↔ Lead NeuroCRM):**
`full_name`↔`nome` · `status`↔`fase` · `phone_whatsapp`↔`telefoneContato` · `partner_name`↔`nomeEsposa` · `marital_status`↔`tipo` · `next_contact_datetime`↔`proximoContato` · `next_visit_date`↔`dataVisita` · `loss_reason`↔`motivoNaoVenda` · DELETE no NeuroCRM → soft-delete (`deletado:true`).

---

## 📝 OBSERVAÇÕES GERAIS

- **Status:** em produção e ativo. Backlog gerenciado por tickets no próprio Firestore.
- **Histórico:** 1º commit **17/12/2025**; **208 commits**, ~20 branches de feature, versão `1.1.0+2`. ~6 meses de desenvolvimento.
  - ⚠️ A data do **primeiro deploy em produção** não está versionada (não consta no repo). A confirmar com o time.
- **Testes:** TDD por convenção. 3 runtimes — Dart/Flutter (`flutter test`, ~359 testes verdes), Firestore Rules (emulador + `@firebase/rules-unit-testing`), Cloud Functions (emulador + `firebase-functions-test`). Tag `bug-aberto` marca guardas de bug não corrigido (vermelhas, fora do gate de deploy).
- **Dependências críticas:** Firebase (Auth/Firestore/Hosting/Functions/Messaging) — vendor lock-in total; `rxdart` (reatividade); `pdf`/`printing` (documentos comerciais); SDK Dart 3.9.2.

### Tech debt conhecido
- **Sem CI/CD** — gate de testes e deploy dependem de disciplina manual.
- Acoplamento forte ao Firebase (sem camada de abstração para troca de provedor).
- `firestore_service.dart` monolítico (**1.942 linhas**) — candidato a quebra por domínio.
- Dois apps (Villamor + NeuroCRM) no mesmo projeto Firebase → cuidado manual em todo deploy de functions.
- Alguns `deprecated_member_use` pré-existentes (ex.: `DropdownButtonFormField.value`).

### Custos
Não há dados de billing no repositório. O custo depende do plano **Firebase Blaze** (Firestore + Hosting + Functions Node 20 + FCM) e do volume de leituras/escritas/invocações — consultável apenas no console de billing do Firebase. Para uma equipe de 9 usuários e o volume atual, tende a ser baixo.

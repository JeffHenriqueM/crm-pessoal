# Villamor CRM

CRM comercial interno desenvolvido em Flutter Web + Firebase para a equipe de vendas da Villamor. Gerencia o pipeline de leads, negociações, metas de vendedores e acompanhamento pós-visita.

---

## Stack

| Camada | Tecnologia |
|---|---|
| Frontend | Flutter 3.35.7 / Dart 3.9.2 |
| UI | Material Design 3 |
| Autenticação | Firebase Authentication (e-mail/senha) |
| Banco de dados | Cloud Firestore |
| Hospedagem | Firebase Hosting |
| Gráficos | fl_chart |
| PDF | pdf + printing |
| Notificações | Firebase Cloud Messaging |

---

## Funcionalidades

### Pipeline de Leads
- Kanban e lista com filtro por fase, vendedor e nome
- Fases: Atendimento → Prospecção → 1° Contato → Negociação → Visita → Fechado / Perdido
- Ficha completa do lead: dados, timeline de interações e negociações

### Dashboard
- **Aba Equipe** — visão geral da equipe com ranking de fechamentos e alertas de contatos atrasados
- **Aba Financeiro** — KPIs do pipeline por período (Hoje / Semana / Mês / Tudo) e gráfico de fechamentos por mês
- **Aba Captação** — distribuição de captações por dia da semana e ranking de captadores
- **Aba Estatísticas** — funil de conversão por fase
- **Aba Relatórios** — painel executivo com saúde da carteira e leads esquecidos
- **Aba Perdas** — motivos de não-venda

### Negociações
- Propostas com valores, parcelas, aprovação especial e histórico de versões
- Fluxo de aprovação: Pendente → Aprovado / Negado / Aguardando atualização

### Tickets de Pós-Venda
- Registro e acompanhamento de ocorrências por cliente
- Ficha individual com histórico de ações

### Recepção
- Cadastro rápido de atendimento com número sequencial automático
- Promoção do atendimento para lead no funil

### Auditoria
- **Soft-delete**: clientes removidos ficam marcados como `deletado=true` — nunca apagados do Firestore
- **audit_log**: toda exclusão grava um registro em `/audit_log` com autor, timestamp e nome do cliente
- **Histórico de modificações**: cada save e cada mudança de fase grava um snapshot parcial em `clientes/{id}/historico/`

---

## Perfis de Usuário

| Perfil | Acesso |
|---|---|
| `super admin` | Igual ao admin (acesso total) |
| `admin` | Tudo — visão global, gerenciamento de usuários, aprovações |
| `vendedor` | Apenas seus próprios leads; dashboard pessoal com meta |
| `captador` | Leads que captou + tela de recepção |
| `recepção` | Tela de recepção |
| `pós-venda` | Visão global (leitura) |
| `financeiro` | Visão global (leitura) |

---

## Estrutura do Projeto

```
lib/
├── main.dart
├── firebase_options.dart          # Produção (gerado pelo FlutterFire CLI, não commitar)
├── firebase_options_staging.dart  # Staging (gerado pelo FlutterFire CLI, não commitar)
├── models/
│   ├── campanha_model.dart
│   ├── cliente_model.dart         # Modelo principal de lead/cliente
│   ├── fase_enum.dart             # Enum das fases do funil
│   ├── interacao_model.dart       # Interações / timeline
│   ├── negociacao_model.dart      # Propostas comerciais
│   ├── ticket_model.dart          # Tickets de pós-venda
│   └── usuario_model.dart         # Perfis e metaMensal
├── screens/
│   ├── apresentacao_screen.dart   # Tela inicial / splash
│   ├── campanhas_screen.dart      # Gestão de campanhas
│   ├── configuracoes_screen.dart  # Configurações do usuário
│   ├── dashboard_screen.dart      # Dashboard principal (admin/global)
│   ├── ficha_cliente_screen.dart  # Ficha detalhada do lead
│   ├── ficha_ticket_screen.dart   # Ficha detalhada do ticket
│   ├── gerenciar_usuarios_screen.dart
│   ├── lista_clientes_screen.dart # Pipeline em lista/kanban
│   ├── negociacoes_screen.dart    # Tela de negociações/propostas
│   ├── recepcao_screen.dart       # Recepção de atendimentos
│   ├── staging_login_screen.dart  # Login exclusivo do ambiente de testes
│   ├── tela_login_screen.dart     # Login de produção
│   ├── tickets_screen.dart        # Lista de tickets de pós-venda
│   └── vendedor_home_screen.dart  # Home do perfil vendedor
├── services/
│   ├── auth_service.dart
│   ├── ficha_pdf.dart             # Geração de PDF da ficha do cliente
│   ├── firestore_service.dart     # ÚNICA camada de acesso ao Firestore
│   ├── proposta_pdf.dart          # Geração de PDF de proposta comercial
│   └── push_notification_service.dart
├── theme/
│   ├── app_theme.dart
│   └── theme_controller.dart
├── utils/
│   ├── env.dart                   # Detecção de ambiente (prod/staging)
│   └── url_launcher_service.dart
└── widgets/
    ├── aba_admin_overview.dart    # Aba "Equipe" do dashboard admin
    ├── aba_agenda.dart
    ├── aba_captacao.dart
    ├── aba_estatisticas.dart
    ├── aba_financeiro.dart
    ├── aba_motivos_perda.dart
    ├── aba_negociacoes.dart
    ├── aba_relatorios.dart
    ├── app_bar.dart
    ├── cliente_list_filtered.dart
    ├── kanban_view.dart           # Board Kanban do pipeline
    ├── main_shell.dart            # Shell de navegação principal
    ├── meta_mensal_card.dart
    └── notificacao_bell.dart
```

---

## Coleções no Firestore

```
clientes/                   # Leads e clientes
  {clienteId}/
    interacoes/             # Timeline de interações do lead
    historico/              # Snapshots de cada edição

negociacoes/                # Propostas (coleção raiz, vinculada por clienteId)
tickets/                    # Tickets de pós-venda
usuarios/                   # Perfis de usuário
campanhas/                  # Campanhas de vendas
config/
  contadores                # Número sequencial de atendimentos
audit_log/                  # Registro de operações críticas (exclusões)
```

---

## Configuração do Ambiente

### Pré-requisitos
- Flutter SDK ≥ 3.35.7
- Dart ≥ 3.9.2
- Firebase CLI (`npm install -g firebase-tools`)
- Projeto Firebase com Authentication e Firestore habilitados

### 1. Clone e instale dependências
```bash
git clone <repo>
cd crm_pessoal
flutter pub get
```

### 2. Configure o Firebase
Os arquivos `lib/firebase_options.dart` e `lib/firebase_options_staging.dart` são gerados pelo FlutterFire CLI e **não devem ser commitados**. Para regenerar:

```bash
dart pub global activate flutterfire_cli
flutterfire configure --project=crm-pessoal-d993d
```

### 3. Rode localmente
```bash
flutter run -d chrome --web-port 5173
```

---

## Deploy

```bash
# Build de produção
flutter build web --release --no-tree-shake-icons

# Deploy para Firebase Hosting
firebase deploy --only hosting --project crm-pessoal-d993d

# Deploy de preview (para testes)
firebase hosting:channel:deploy preview_nome --project crm-pessoal-d993d
```

**URL de produção:** https://crm-pessoal-d993d.web.app

---

## Criação de Usuários

Usuários **não se auto-cadastram**. O fluxo é:

1. Admin cria a conta no **Firebase Authentication** (console ou SDK Admin)
2. Admin cria o documento correspondente na coleção `usuarios/{uid}`:

```json
{
  "nome": "Nome Completo",
  "email": "email@exemplo.com",
  "perfil": "vendedor",
  "ativo": true
}
```

3. No próximo login, o sistema reconhece o perfil automaticamente.

> Perfis válidos: `admin`, `vendedor`, `captador`, `recepção`, `pós-venda`, `financeiro`, `super admin`

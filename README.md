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

### Metas por Vendedor (#12)
- Cada vendedor define sua própria meta mensal de fechamentos
- Anel de progresso + barra linear no dashboard do vendedor
- Admin vê a meta de cada vendedor na aba Equipe

### Negociações
- Propostas com valores, parcelas, aprovação especial e histórico de versões
- Fluxo de aprovação: Pendente → Aprovado / Negado / Aguardando atualização

### Rastreamento de Mensagens (#16)
- Ao reagendar "Próximo Contato", modal pergunta se a mensagem anterior foi enviada
- Badges visuais no Kanban e na lista indicam mensagens pendentes

### Recepção
- Cadastro rápido de atendimento com número sequencial automático
- Promoção do atendimento para lead no funil

### Auditoria (#19)
- **Soft-delete**: clientes removidos ficam marcados como `deletado=true` — nunca apagados do Firestore
- **audit_log**: toda exclusão grava um registro em `/audit_log` com autor, timestamp e nome do cliente
- **Histórico de modificações**: cada save e cada mudança de fase grava um snapshot parcial em `clientes/{id}/historico/` com os campos alterados, autor e timestamp

---

## Perfis de Usuário

| Perfil | Acesso |
|---|---|
| `admin` | Tudo — visão global, gerenciamento de usuários, aprovações |
| `vendedor` | Apenas seus próprios leads; dashboard pessoal com meta |
| `captador` | Leads que captou + tela de recepção |
| `recepção` | Tela de recepção |
| `pós-venda` | Visão global (leitura) |
| `financeiro` | Visão global (leitura) |
| `super admin` | Igual ao admin |

---

## Estrutura do Projeto

```
lib/
├── main.dart
├── models/
│   ├── campanha_model.dart
│   ├── cliente_model.dart       # Modelo principal de lead/cliente
│   ├── fase_enum.dart           # Fases do funil
│   ├── interacao_model.dart     # Interações / timeline
│   ├── negociacao_model.dart    # Propostas comerciais
│   └── usuario_model.dart       # Perfis e metaMensal
├── screens/
│   ├── dashboard_screen.dart
│   ├── ficha_cliente_screen.dart
│   ├── gerenciar_usuarios_screen.dart
│   ├── lista_clientes_screen.dart
│   ├── login_screen.dart
│   └── recepcao_screen.dart
├── services/
│   ├── auth_service.dart
│   └── firestore_service.dart   # Toda comunicação com Firestore
├── utils/
│   └── url_launcher_service.dart
└── widgets/
    ├── aba_admin_overview.dart
    ├── aba_captacao.dart
    ├── aba_estatisticas.dart
    ├── aba_financeiro.dart
    ├── aba_motivos_perda.dart
    ├── aba_negociacoes.dart
    ├── aba_relatorios.dart
    ├── cliente_list_filtered.dart
    ├── ficha/
    │   ├── ficha_dados_tab.dart      # Aba de dados do lead (formulário)
    │   └── ficha_timeline_tab.dart   # Aba de interações (timeline visual)
    ├── kanban_view.dart
    └── meta_mensal_card.dart
```

---

## Coleções no Firestore

```
clientes/                   # Leads e clientes
  {clienteId}/
    interacoes/             # Timeline de interações do lead
    historico/              # Snapshots de cada edição (#19)

negociacoes/                # Propostas (coleção raiz, vinculada por clienteId)
usuarios/                   # Perfis de usuário (criados via Firebase Console)
campanhas/                  # Campanhas de vendas
config/
  contadores                # Número sequencial de atendimentos
audit_log/                  # Registro de operações críticas (exclusões) (#19)
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
O arquivo `lib/firebase_options.dart` é gerado pelo FlutterFire CLI e **não deve ser commitado**. Para regenerar:

```bash
dart pub global activate flutterfire_cli
flutterfire configure --project=crm-pessoal-d993d
```

### 3. Rode localmente
```bash
flutter run -d chrome
```

> **Nota:** A porta padrão é aleatória. Para porta fixa:
> ```bash
> flutter run -d chrome --web-port 5173
> ```

---

## Deploy

```bash
# 1. Build de produção
flutter build web --release --no-tree-shake-icons

# 2. Deploy para Firebase Hosting
firebase deploy --only hosting
```

**URL de produção:** https://crm-pessoal-d993d.web.app

---

## Regras do Firestore

As regras de segurança estão em `firestore.rules`. Resumo:

- Usuários autenticados podem ler e escrever em `clientes`, `negociacoes` e `interacoes`
- Apenas admins podem acessar `usuarios` para escrita
- `audit_log` é append-only para usuários autenticados

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

---

## Convenções de Código

- **Português** para nomes de variáveis, métodos e comentários de negócio
- **Inglês** para nomes de widgets Flutter puros e padrões de framework
- Serviços de dados sempre em `FirestoreService` — widgets não chamam Firestore diretamente
- Soft-delete obrigatório: nunca chamar `.delete()` em documentos de cliente
- Snapshots de histórico gerados automaticamente pelo `FirestoreService` a cada save

---

## Backlog Pendente

| # | Feature | Prioridade |
|---|---|---|
| #11 | Exportação CSV | Média |
| #18 | Importação CSV em lote | Baixa |
| #19 ✅ | Audit Trail | Alta |

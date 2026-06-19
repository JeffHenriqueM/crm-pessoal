# REGRAS DE NEGÓCIO — Villamor CRM (`crm_pessoal`)

> Fonte de verdade das regras de negócio do sistema. Levantado **direto do código** em 2026-06-18 (com `arquivo:linha`).
> Documento de produto/negócio — para a parte técnica (stack, infra, deploy) ver [STACK.md](STACK.md).
> ⚠️ Ao mudar uma regra no código, atualize aqui também.

---

## 1. Perfis e escopo de visibilidade

Perfis existentes: `super admin`, `admin`, `financeiro`, `pós-venda`, `recepcao`, `vendedor`, `captador` (+ `reserva`).

### 1.1 Gestores veem tudo
**Regra:** os perfis em `perfisComVisaoTotal` veem **todos** os clientes; os demais veem **apenas os seus**.
- `perfisComVisaoTotal = ['admin', 'pós-venda', 'financeiro', 'super admin', 'recepcao']` — `firestore_service.dart:262`
- No Firestore Rules, a função `isGestor()` repete essa lista — `firestore.rules:16-19`

### 1.2 "Dono" de um lead (vendedor/captador)
**Regra:** quem **não** é gestor (vendedor, captador) só enxerga leads em que aparece como dono. É dono quem está em qualquer um dos campos:
`vendedorId` (closer), `linerId` (apresentador), `criadoPorId` (quem criou), `captadorId` (quem captou).
- App combina os streams por uid e deduplica — `firestore_service.dart:250-314`
- Rules `isDono()` — `firestore.rules:40-45`

### 1.3 Visibilidade na Recepção (fase `atendimento`)
- **Admin / super admin:** veem todos os atendimentos, **inclusive os excluídos** (para auditoria/restauração — ticket #43).
- **Recepção:** vê todos os atendimentos, **menos** os excluídos.
- **Vendedor / captador:** só os atendimentos em que é criador, captador ou liner.
- Ordenação: por `dataEntradaSala` desc (cai para `dataCadastro`). — `firestore_service.dart:319-392`

### 1.4 Negociações
**Regra:** qualquer usuário autenticado pode ler negociações (sem soft-delete; podem ser deletadas de fato). Pendentes de aprovação são ordenadas por `dataSolicitacaoAprovacao` asc (mais urgentes primeiro). — `firestore_service.dart:947-985`, `firestore.rules:65-68`

---

## 2. Auditoria obrigatória (soft-delete, histórico, audit_log)

### 2.1 Nunca apagar cliente de verdade
**Regra:** clientes **nunca** são removidos do banco. Exclusão = `deletado = true`. O Firestore **bloqueia** delete permanente (`allow delete: if false`). — `firestore.rules:49-54`

### 2.2 Exclusão e restauração são transacionais + auditadas
**Regra:** excluir/restaurar cliente grava, **na mesma transação**, o estado no cliente **e** um registro em `audit_log`. Se a auditoria falhar, a operação não persiste.
- `deletarCliente()` grava no cliente `deletado, excluidoPorId, excluidoPorNome, dataExclusao` + audit `tipo: 'exclusao_cliente'` — `firestore_service.dart:646-677`
- `restaurarCliente()` grava `deletado=false, restauradoPorId, restauradoPorNome, dataRestauracao` + audit `tipo: 'restauracao_cliente'` (só admin/super admin) — `firestore_service.dart:680-708`

### 2.3 Histórico de toda edição/mudança de fase
**Regra:** toda edição de cliente e toda mudança de fase grava um **snapshot** em `clientes/{id}/historico/` (`tipo: 'edicao'` ou `'mudanca_fase'`, autor, timestamp, campos alterados). — `firestore_service.dart:610-624` (fase) e `636-644` (edição), snapshot em `872-894`

### 2.4 audit_log é imutável
**Regra:** `audit_log` aceita create (qualquer autenticado, via app) e read só de gestor; **update e delete bloqueados**. — `firestore.rules:113-121`

---

## 3. Funil de fases

### 3.1 Fases (ordem)
`atendimento` → `prospeccao` → `contato` → `negociacao` → `visita` → `fechado` (ou `perdido`). — `models/fase_enum.dart`

- `atendimento` só aparece na **tela de Recepção**; não entra no Kanban/pipeline.
- Da fase `prospeccao` em diante, o lead aparece no Kanban/pipeline do vendedor.

### 3.2 Motivo de perda obrigatório
**Regra:** ao mover um lead para **`perdido`**, o motivo (`motivoNaoVenda`, texto livre) é **obrigatório** — o diálogo valida e não confirma vazio. — `widgets/kanban_view.dart:140-189`

### 3.3 Fechamento oferece vínculo com contrato
**Regra:** ao mover para **`fechado`**, o sistema abre diálogo oferecendo vincular o lead a um contrato (`vincularContratoACliente()`). — `widgets/kanban_view.dart:115-138`

---

## 4. Numeração de atendimento

**Regra:** o número do atendimento é **sequencial e atômico**, via transação no contador `config/contadores:atendimentos`.
- Gerado **apenas** ao criar um **atendimento presencial** (`fase = atendimento`). — `firestore_service.dart:599-608`, uso em `recepcao_screen.dart:315`
- **Agendamento NÃO toca o contador** (ainda não é lead). — `firestore_service.dart:430-440`
- Na **conversão agendamento → atendimento** (`marcarCompareceu`), aí sim gera um número novo. — `recepcao_screen.dart:358-369`

---

## 5. Recepção → promoção para lead

- **Campos obrigatórios** ao registrar atendimento: `nome` (titular), `captador`, e `vendedor` (obrigatório no presencial; opcional no agendamento). — `recepcao_screen.dart:579-745`
- Ao criar, grava `criadoPorId`, `vendedorId`, `linerId`, `captadorId` e `dataEntradaSala = agora`.
- **Não existe botão "promover"**: o lead sai da Recepção quando muda de fase (`atualizar­FaseCliente`) — ao virar `prospeccao`+, some da aba de atendimentos e aparece no Kanban. O dono (`vendedorId`) é preservado. — `ficha_cliente_screen.dart:703-728`

---

## 6. Agendamento e remarcação

**Regra (ticket #63):** um agendamento pode ser remarcado até **2 vezes**; atingido o limite, **só um admin libera** uma remarcação extra.
- `limiteRemarcacoes = 2` (default), contador `remarcacoes`; `podeRemarcar = remarcacoes < limiteRemarcacoes`. — `models/agendamento_model.dart:45-49, 84-85, 100`
- Cada remarcação exige **motivo** e registra `{de, para, motivo, em, porId, porNome}` em `historicoRemarcacoes`. — `firestore_service.dart:481-510`
- Admin libera com `liberarRemarcacaoAgendamento` (incrementa `limiteRemarcacoes` em +1); botão visível só para admin. — `firestore_service.dart:513-520`, `recepcao_screen.dart:1445-1450`

---

## 7. Fila de atendimento (sala de vendas)

**Regra:** vendedores disponíveis formam uma fila **FIFO** por tempo de espera. Coleção `fila_atendimento` (doc id = `vendedorId`).
- Vendedor entra marcando **"Disponível"** → `posicaoEm = agora` (vai para o fim). — `firestore_service.dart:542-558`, UI `vendedor_home_screen.dart:133-189`
- Ao **atender** (ou marcar **atrasado**), re-timestampa `posicaoEm = agora` → volta para o **fim** da fila. — `firestore_service.dart:560-570`, `recepcao_screen.dart:360-364`
- Ordenação por `posicaoEm` asc; indisponíveis vão para o fim. Recepção pode reordenar manualmente trocando posições. — `firestore_service.dart:525-540, 572-584`

---

## 8. Alerta de tempo sem contato

**Regra (ticket #48):** leads **ativos** (não fechado/perdido/atendimento) recebem alerta visual conforme dias desde o último contato:

| Faixa | Dias | Cor | Label |
|---|---|---|---|
| Em dia | < 15 | — | (nenhum) |
| Atenção | 15–19 | amarelo | "Atenção" |
| Alerta | 20–29 | laranja | "Alerta" |
| Crítico | ≥ 30 | vermelho | "Crítico" |

Constantes `kDiasAtencao=15`, `kDiasAlerta=20`, `kDiasCritico=30`. Fallback: se não há `ultimoContato`, usa `dataAtualizacao`. — `services/tempo_sem_contato.dart:37-39, 77-117`

---

## 9. Ranking de fechamento

**Regra (ticket #60):** o ranking conta **somente** perfis de venda — `{'vendedor', 'captador'}`. Admin, financeiro, pós-venda, recepção e "sem vendedor" ficam de fora. Ordena desc por nº de fechados.
- `perfisVendas = {'vendedor', 'captador'}`, `ehPerfilVendas()` — `utils/perfis.dart:9-13`
- Filtro aplicado no ranking — `widgets/aba_admin_overview.dart:148-156`

---

## 10. Metas mensais

**Regra:** cada vendedor/captador/pós-venda pode ter metas mensais, individuais e múltiplas. Tipos: `fechamentos`, `valorVendido`, `novosLeads`, `mensagensEnviadas`.
- Armazenamento: `metas` (Map<String,double>) + campo legado `metaMensal` (int) para retrocompatibilidade. — `models/usuario_model.dart:10-21`
- Progresso no mês por tipo; cores: verde ≥100%, amarelo 50–99%, vermelho <50%. — `widgets/aba_metas.dart:228-249`
- Meta padrão de pós-venda: `_kMetaPadraoPosVenda = 80.0`.

---

## 11. Financeiro — importação de baixas

**Regra:** os dados financeiros vivem numa coleção única, `financeiro_baixas`.
- Acesso restrito a perfis financeiros (`admin`, `financeiro`, `super admin`) — leitura, criação e update. `vendedor`/`captador` não acessam. — `firestore.rules` (match `financeiro_baixas`)
- **Cada importação substitui o conjunto ativo** sem apagar dados: grava as novas baixas, marca as anteriores como `deletado: true` (soft-delete) e registra `tipo: 'importacao_baixas'` em `/audit_log`. **Nunca há delete físico** (`allow delete: if false`). — `firestore_service.dart` (`importarBaixasFinanceiras`)
- Todas as leituras/agregações e o "último pagamento por cliente" ignoram `deletado`. Vínculo pagamento→cliente é por nome normalizado em MAIÚSCULAS.

---

## Resumo das restrições no Firestore Rules

| Coleção | Read | Create | Update | Delete |
|---|---|---|---|---|
| `clientes` | gestor ou dono | gestor ou dono | gestor ou dono | **false** (soft-delete) |
| `negociacoes` | autenticado | autenticado | autenticado | autenticado |
| `agendamentos` | autenticado | autenticado | autenticado | **false** |
| `usuarios` | autenticado | próprio ou gestor | gestor (ou próprio só campos de meta) | **false** |
| `audit_log` | gestor | autenticado | **false** | **false** |
| `clientes/{id}/historico` | autenticado | autenticado | autenticado | autenticado |

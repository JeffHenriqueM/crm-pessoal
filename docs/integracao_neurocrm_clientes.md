# Integração NeuroCRM → Villamor CRM — Contrato da coleção `clientes`

**Para:** equipe/dev do NeuroCRM
**Projeto Firestore:** `crm-pessoal-d993d` (mesmo projeto dos dois apps)
**Coleção:** `clientes`
**Última revisão:** 2026-06-09

---

## 1. O problema que motivou este documento

Um lead criado pelo NeuroCRM (ex.: "Alan", `source = neurocrm`, criado em 09/06) **não apareceu** no app Villamor para os perfis administrativos.

A causa **não** foi permissão nem soft-delete. Foi **nome de campo errado**. O NeuroCRM gravou:

- `criadoEm` em vez de **`dataCadastro`**
- `atualizadoEm` em vez de **`dataAtualizacao`**
- `captador_id` / `captador_name` em vez de **`captadorId`** / **`captadorNome`**
- não gravou **`vendedorNome`**

### Por que isso some o lead inteiro (e não só "um campo vazio")

A query principal do Villamor para admin / pós-venda / financeiro / super admin é:

```dart
query.orderBy('dataAtualizacao', descending: true)
```

⚠️ **Regra do Firestore:** um documento que **não possui** o campo usado no `orderBy` é **silenciosamente excluído** do resultado da query. Sem erro, sem aviso — o lead simplesmente não existe para aquela tela.

Como o doc do Alan tinha `atualizadoEm` (e não `dataAtualizacao`), ele **nunca entrou** na lista nem no kanban dos perfis administrativos.

> **Regra de ouro:** todo lead gravado em `clientes/` **precisa** ter os campos `dataCadastro` e `dataAtualizacao` como **Timestamp**, com **exatamente** esses nomes.

---

## 2. Contrato de campos — o que o app Villamor LÊ

O app lê os campos abaixo (definidos em `lib/models/cliente_model.dart`). Os nomes são **case-sensitive** e quase todos em **camelCase**. Gravar com outro nome = o app ignora.

### 2.1 Obrigatórios para o lead aparecer

| Campo | Tipo | Observação |
|---|---|---|
| `nome` | string | Nome do lead. |
| `tipo` | string | `"Individual"` ou `"Casal"`. |
| `fase` | string | **Um dos valores exatos** da seção 3. |
| `dataCadastro` | **Timestamp** | Data de criação. **Obrigatório.** |
| `dataAtualizacao` | **Timestamp** | 🔴 **CRÍTICO** — é o campo do `orderBy`. Sem ele, o lead **some** para admins. |
| `deletado` | bool | Use `false` (ou omita). `true` = soft-deleted, some do app. |
| `isTeste` | bool | `false` em produção. `true` só aparece no ambiente de testes. |

### 2.2 Atribuição / escopo (quem enxerga o lead)

| Campo | Tipo | Observação |
|---|---|---|
| `vendedorId` | string | UID do vendedor dono. Perfil vendedor só vê leads onde é `vendedorId` ou `linerId`. |
| `vendedorNome` | string | **Grave junto** — sem ele o nome do vendedor fica em branco na UI. |
| `captadorId` | string | UID do captador. ⚠️ camelCase — **não** `captador_id`. |
| `captadorNome` | string | ⚠️ camelCase — **não** `captador_name`. |
| `criadoPorId` | string | UID de quem criou. |
| `criadoPorNome` | string | Nome de quem criou. |

> Se o lead é do agente de WhatsApp sem dono humano definido, ainda assim use um `vendedorId` válido (UID de um usuário real da coleção `usuarios`) ou deixe para o fluxo de atribuição do Villamor. Não invente UID.

### 2.3 Demais campos lidos (opcionais, mas use o nome certo)

| Campo | Tipo | Observação |
|---|---|---|
| `nomeEsposa` | string | |
| `origem` | string | |
| `telefoneContato` | string | |
| `telefone2` | string | |
| `proximoContato` | **Timestamp** | |
| `dataVisita` | **Timestamp** | |
| `dataFechamento` | **Timestamp** | |
| `valorVendido` | number | |
| `motivoNaoVenda` | string | |
| `motivoNaoVendaDropdown` | string | |
| `observacao` | string | |
| `idade` / `profissao` | string | |
| `idadeConjuge` / `profissaoConjuge` | string | |
| `interaction_count` | number | ⚠️ **snake_case** (exceção — esse o app lê em snake_case). |
| `no_response_count` | number | ⚠️ **snake_case** (exceção). |
| `ultimoContato` | **Timestamp** | Data do último contato real. |
| `statusMensagem` | string | `null` \| `"nao_enviada"` \| `"enviada_sem_resposta"` \| `"enviada_com_resposta"`. |

> Campos extras do NeuroCRM (`behavioral_profile`, `source`, `neuro_created_at`, `neuro_updated_at`, `main_desire`, etc.) **podem continuar** no doc — o app simplesmente os ignora. Não há problema em mantê-los.

---

## 3. Valores válidos de `fase` (string, exata)

O Villamor usa estes literais. Qualquer outro valor cai em `prospeccao` por fallback.

| Valor a gravar | Significado |
|---|---|
| `atendimento` | Só recepção. **Não aparece** no pipeline principal. |
| `prospeccao` | Lead novo, sem contato efetivo. |
| `contato` | Primeiro contato feito. |
| `negociacao` | Proposta enviada / em discussão. |
| `visita` | |
| `fechado` | Venda concluída. |
| `perdido` | Não avançou. |

> ⚠️ Sem acento e em minúsculas: é `negociacao`, **não** `Negociação`.
> ⚠️ Lead com `fase = atendimento` **só** aparece na tela de Recepção, nunca no pipeline. Para um lead de venda use `prospeccao`/`contato`/`negociacao`.

---

## 4. Exemplo concreto — antes (errado) × depois (certo)

### ❌ Como o Alan foi gravado (some para admin)
```jsonc
{
  "nome": "Alan",
  "tipo": "Casal",
  "fase": "negociacao",
  "criadoEm":   "2026-06-09T14:54:57Z",   // ← nome errado
  "atualizadoEm": "2026-06-09T14:57:02Z", // ← nome errado (campo do orderBy!)
  "vendedorId": "leeMDnfgbXYRs5WdSx2nuLrfHAj2",
  // sem vendedorNome
  "captador_id": "bUk7VtsqHVPInqFPJieE",  // ← snake_case, ignorado
  "captador_name": "Jeff",                // ← snake_case, ignorado
  "deletado": false,
  "isTeste": false
}
```

### ✅ Como deveria ser gravado
```jsonc
{
  "nome": "Alan",
  "tipo": "Casal",
  "fase": "negociacao",
  "dataCadastro":    Timestamp(2026-06-09T14:54:57Z),  // camelCase + Timestamp
  "dataAtualizacao": Timestamp(2026-06-09T14:57:02Z),  // camelCase + Timestamp
  "vendedorId":   "leeMDnfgbXYRs5WdSx2nuLrfHAj2",
  "vendedorNome": "Jefferson Henrique de Melo",        // grave junto
  "captadorId":   "bUk7VtsqHVPInqFPJieE",              // camelCase
  "captadorNome": "Jeff",                               // camelCase
  "telefoneContato": "(11) 99675-8512",
  "nomeEsposa": "Cristine",
  "deletado": false,
  "isTeste": false
  // campos extras do NeuroCRM podem permanecer
}
```

> Os valores de data devem ser **Timestamp do Firestore**, não string ISO.
> - Admin SDK (Node): `admin.firestore.Timestamp.fromDate(new Date(...))` ou `FieldValue.serverTimestamp()`.
> - Firestore client SDK: `Timestamp.fromDate(...)` / `serverTimestamp()`.

---

## 5. Checklist de gravação (cada lead novo)

- [ ] `dataCadastro` presente, **camelCase**, tipo **Timestamp**
- [ ] `dataAtualizacao` presente, **camelCase**, tipo **Timestamp** ← sem isso o lead some
- [ ] `fase` é um dos 7 literais válidos (sem acento, minúsculo)
- [ ] `vendedorId` aponta para um UID real de `usuarios` **e** `vendedorNome` gravado
- [ ] captador (se houver) em `captadorId` / `captadorNome` (**camelCase**, não snake_case)
- [ ] `deletado` ausente ou `false`
- [ ] `isTeste = false` em produção
- [ ] datas como **Timestamp**, não string ISO

---

## 6. Resumo de mapeamento (de → para)

| NeuroCRM está gravando | Deve gravar (Villamor) |
|---|---|
| `criadoEm` | `dataCadastro` |
| `atualizadoEm` | `dataAtualizacao` |
| `captador_id` | `captadorId` |
| `captador_name` | `captadorNome` |
| *(ausente)* | `vendedorNome` |

Mantém igual (já corretos): `interaction_count`, `no_response_count` (estes **são** snake_case de propósito no Villamor).

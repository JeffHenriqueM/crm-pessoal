# Integração NeuroCRM → Villamor CRM — Contrato da coleção `clientes`

**Para:** equipe/dev do NeuroCRM
**Projeto Firestore:** `crm-pessoal-d993d` (mesmo projeto dos dois apps)
**Coleção:** `clientes`
**Última revisão:** 2026-06-10

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

---

## 7. Registrar interação (e fazer o lead sair do "em atraso") — *opcional*

> 🟢 **Atualização (2026-06-10):** a atualização de contato passou a ser feita **só pelo app Villamor (CRM_PESSOAL)**. Ao registrar uma interação na tela do lead, o próprio app já agenda o `proximoContato` (+3 dias úteis) e tira o lead do "em atraso". **O NeuroCRM não precisa mais implementar esta seção.** Ela fica como referência caso um dia volte a registrar contato pelo NeuroCRM. O que continua valendo e é importante é a **seção 8 (evitar duplicados)**.

> Esta seção resolve o problema: *"registrei a interação no NeuroCRM, mas no Villamor o lead continua em atraso / não conta como contato."*

### 7.1 Onde gravar a interação

Cada contato (mensagem enviada, ligação, resposta do cliente) é **um documento** na subcoleção:

```
clientes/{leadId}/interacoes/{idAuto}
```

🔴 **`{leadId}` tem que ser o ID do lead que JÁ EXISTE no Villamor** — não crie um lead novo para anexar a interação (ver seção 8, duplicados). Se o NeuroCRM gravar a interação num lead duplicado, ela aparece numa ficha "fantasma" e o lead real continua atrasado.

Campos do documento de interação (mesma estrutura que o app usa):

| Campo | Tipo | Observação |
|---|---|---|
| `titulo` | string | Ex.: `"⏰ Retomar contato"`, `"Conversa"`. |
| `nota` | string | Texto do que foi dito / enviado. |
| `canal` | string | `"whatsapp"`, `"ligacao"`, etc. |
| `modalidade` | string | `"online"` / `"presencial"`. |
| `houveResposta` | bool | `true` se o cliente respondeu; `false` se foi só envio nosso. |
| `dataInteracao` | **Timestamp** | Quando o contato ocorreu. |
| `criadoEm` | **Timestamp** | `serverTimestamp()`. |
| `autorId` | string | UID de quem registrou (pode ser o do bot/captador). |
| `autorNome` | string | Nome correspondente. |

### 7.2 🔴 O passo que está faltando: atualizar o LEAD PAI

Criar o documento na subcoleção **não basta**. O app calcula "em atraso", "contato enviado" e os contadores **a partir de campos no documento pai** `clientes/{leadId}`. Quando você cria uma interação, atualize **na mesma operação** o lead pai:

| Campo no lead pai | Valor a gravar | Para quê |
|---|---|---|
| `ultimoContato` | `serverTimestamp()` (ou `dataInteracao`) | Marca que houve contato real. |
| `interaction_count` | `FieldValue.increment(1)` | Conta como mensagem enviada (metas / lead score). |
| `no_response_count` | `increment(1)` se `houveResposta=false`; **`0`** se `houveResposta=true` | Sequência sem resposta (zera quando o cliente responde). |
| `statusMensagem` | `"enviada_sem_resposta"` ao enviar e aguardar; `"enviada_com_resposta"` se o cliente respondeu | Tira o badge vermelho "Msg. não enviada". |
| `proximoContato` | **hoje + 3 dias úteis** às 12:00 (ver 7.3) | 🔴 **É ISTO que tira o "em atraso".** |
| `dataAtualizacao` | `serverTimestamp()` | Mantém o lead visível e fora dos "esquecidos". |

> ⚠️ **A regra do "em atraso" no Villamor é simples:** o lead aparece atrasado **enquanto `proximoContato` estiver no passado**. Registrar interação **sem** empurrar o `proximoContato` mantém o lead atrasado para sempre. Por isso o passo do `proximoContato` é obrigatório.

### 7.3 Regra do `proximoContato`: +3 dias úteis

Ao registrar um contato, agende o próximo para **3 dias úteis à frente** (pula sábado e domingo), às 12:00 UTC:

```js
function add3DiasUteis(base = new Date()) {
  const d = new Date(base);
  let add = 0;
  while (add < 3) {
    d.setUTCDate(d.getUTCDate() + 1);
    const wd = d.getUTCDay();          // 0=Dom, 6=Sáb
    if (wd !== 0 && wd !== 6) add++;
  }
  d.setUTCHours(12, 0, 0, 0);
  return d;                            // grave como Timestamp
}
```

### 7.4 Exemplo (Admin SDK / Node) — interação + reconciliação atômica

Faça as duas escritas no **mesmo batch** (ou transação) para não deixar o lead num estado inconsistente:

```js
const admin = require('firebase-admin');
const db = admin.firestore();
const { FieldValue, Timestamp } = admin.firestore;

async function registrarInteracao(leadId, { titulo, nota, canal, houveResposta }) {
  const leadRef = db.collection('clientes').doc(leadId);
  const interacaoRef = leadRef.collection('interacoes').doc();   // id automático

  const batch = db.batch();

  // 1) a interação em si
  batch.set(interacaoRef, {
    titulo, nota, canal, modalidade: 'online',
    houveResposta: !!houveResposta,
    dataInteracao: FieldValue.serverTimestamp(),
    criadoEm: FieldValue.serverTimestamp(),
    autorId: '<uid-do-bot-ou-captador>',
    autorNome: '<nome>',
  });

  // 2) reconcilia o lead pai (sem isso, o app ignora o contato)
  batch.update(leadRef, {
    ultimoContato: FieldValue.serverTimestamp(),
    interaction_count: FieldValue.increment(1),
    no_response_count: houveResposta ? 0 : FieldValue.increment(1),
    statusMensagem: houveResposta ? 'enviada_com_resposta' : 'enviada_sem_resposta',
    proximoContato: Timestamp.fromDate(add3DiasUteis()),   // tira do "em atraso"
    dataAtualizacao: FieldValue.serverTimestamp(),
  });

  await batch.commit();
}
```

### 7.5 Checklist por interação criada

- [ ] Interação gravada em `clientes/{leadId}/interacoes` **do lead que já existe** (não um duplicado)
- [ ] `ultimoContato` atualizado no lead pai
- [ ] `interaction_count` incrementado
- [ ] `no_response_count` incrementado (envio sem resposta) **ou** zerado (cliente respondeu)
- [ ] `statusMensagem` atualizado (`enviada_sem_resposta` / `enviada_com_resposta`)
- [ ] `proximoContato` empurrado para **+3 dias úteis** ← sem isso o lead **continua em atraso**
- [ ] `dataAtualizacao` atualizado

---

## 8. Evitar duplicados — escrever no lead que já existe

O sintoma "o lead apareceu duplicado" e "registrei interação mas continua atrasado" têm a **mesma raiz**: o NeuroCRM cria um lead novo em vez de localizar o que já existe.

**Antes de criar um lead novo**, procure por um lead ativo com o mesmo telefone:

```js
const tel = '(21) 97220-0133';
const existentes = await db.collection('clientes')
  .where('telefoneContato', '==', tel)
  .where('deletado', '==', false)
  .limit(1).get();

if (!existentes.empty) {
  const leadId = existentes.docs[0].id;   // use ESTE id (interação, updates…)
} else {
  // só então crie um lead novo (com os campos da seção 2)
}
```

> Normalize o telefone de forma consistente nos dois lados (mesmo formato/máscara) para o match funcionar. Se possível, padronize só dígitos (`5521972200133`) num campo dedicado para a busca.

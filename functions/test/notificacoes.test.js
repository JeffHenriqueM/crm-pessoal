'use strict';

/**
 * Risco #4 — testes de COMPORTAMENTO dos helpers de envio FCM e dos triggers.
 *
 * Não dependem de emulador: admin.firestore() e admin.messaging() são
 * substituídos por fakes em memória antes de carregar as functions.
 *
 * Cobre:
 *  - QUANDO uma notificação é (ou não é) enviada (triggers)
 *  - Token permanentemente inválido → campo fcmToken removido do usuário
 *  - Falha transitória em envio único → re-lança (trigger retentará)
 *  - Token inválido em batch → removido; falha catastrófica no batch → absorvida
 *  - onTicketAtualizado: notifica criador quando status muda; notifica atribuído
 *  - onComentarioAdicionado: notifica criador e atribuído de novos comentários
 *  - lembreteProximoContato: lembrete do dia + mensagens atrasadas por vendedor
 *
 * Roda com: `npm test` (dentro de functions/) ou `node --test`.
 */

const test = require('node:test');
const assert = require('node:assert/strict');

process.env.GCLOUD_PROJECT = process.env.GCLOUD_PROJECT || 'demo-villamor';

const admin = require('firebase-admin');

// ── Stores em memória (uma por coleção) ──────────────────────────────────────
const usuarios = {};
const clientes = {};
const tickets  = {};
const subcollections = {};  // chave: 'colecao/docId/subcolecao' → { autoId: data }

const STORES = { usuarios, clientes, tickets };

let enviados = [];
let fcmSendError = null;        // faz messaging.send() lançar este erro
let fcmMulticastError = null;   // faz sendEachForMulticast() lançar este erro
let fcmBatchResponses = null;   // resposta customizada para sendEachForMulticast

// Converte Timestamp Firestore, Date ou millis para número comparável
function toMs(v) {
  if (v == null) return null;
  if (typeof v.toMillis === 'function') return v.toMillis();
  if (v instanceof Date) return v.getTime();
  if (typeof v === 'number') return v;
  return null;
}

function matchFiltro(doc, campo, op, valor) {
  const docVal = doc[campo];
  if (docVal === undefined || docVal === null) return false;

  // Tenta comparação de timestamp para campos de data
  const msDoc = toMs(docVal);
  const msVal = toMs(valor);
  if (msDoc !== null && msVal !== null) {
    switch (op) {
      case '==': return msDoc === msVal;
      case '!=': return msDoc !== msVal;
      case '>=': return msDoc >= msVal;
      case '<=': return msDoc <= msVal;
      case '>':  return msDoc >  msVal;
      case '<':  return msDoc <  msVal;
    }
  }
  // Fallback: comparação direta (strings, booleans, etc.)
  switch (op) {
    case '==': return docVal === valor;
    case '!=': return docVal !== valor;
    default:   return false;
  }
}

function criarQueryFake(store, filtros) {
  const q = {
    where(campo, op, valor) {
      return criarQueryFake(store, [...filtros, [campo, op, valor]]);
    },
    limit(_n) { return q; },
    async get() {
      const matched = Object.entries(store)
        .filter(([, d]) => filtros.every(([c, op, v]) => matchFiltro(d, c, op, v)))
        .map(([id, d]) => ({
          data: () => d,
          ref: criarDocRefNamed(id, store),
        }));
      return {
        empty: matched.length === 0,
        forEach: (cb) => matched.forEach(cb),
        docs: matched,
      };
    },
  };
  return q;
}

function criarDocRefNamed(id, store) {
  return {
    async update(data) {
      if (!store[id]) return;
      for (const [k, v] of Object.entries(data)) {
        if (v === null || v === undefined ||
            (typeof v === 'object' && !Array.isArray(v) && !(v instanceof Date)
             && typeof v.toMillis !== 'function')) {
          delete store[id][k];
        } else {
          store[id][k] = v;
        }
      }
    },
  };
}

// Mantido para compat com testes legados que usam criarDocRef(id) → usuarios
function criarDocRef(id) {
  return criarDocRefNamed(id, usuarios);
}

const firestoreFake = {
  collection(nome) {
    const store = STORES[nome] ?? usuarios;
    return {
      doc(id) {
        return {
          async get() {
            const dados = store[id];
            return { exists: !!dados, data: () => dados };
          },
          async update(data) {
            return criarDocRefNamed(id, store).update(data);
          },
          collection(subNome) {
            const key = `${nome}/${id}/${subNome}`;
            if (!subcollections[key]) subcollections[key] = {};
            const ss = subcollections[key];
            return {
              async add(data) {
                const autoId = `auto_${Date.now()}_${Math.random().toString(36).slice(2)}`;
                ss[autoId] = data;
                return { id: autoId };
              },
              where(campo, op, valor) {
                return criarQueryFake(ss, [[campo, op, valor]]);
              },
            };
          },
        };
      },
      where(campo, op, valor) {
        return criarQueryFake(store, [[campo, op, valor]]);
      },
    };
  },
};

const messagingFake = {
  async send(msg) {
    if (fcmSendError) throw fcmSendError;
    enviados.push({ tipo: 'send', msg });
    return 'mock-message-id';
  },
  async sendEachForMulticast(msg) {
    if (fcmMulticastError) throw fcmMulticastError;
    enviados.push({ tipo: 'multicast', msg });
    if (fcmBatchResponses) return fcmBatchResponses;
    return {
      successCount: msg.tokens.length,
      failureCount: 0,
      responses: msg.tokens.map(() => ({ success: true })),
    };
  },
};

const fft = require('firebase-functions-test')();
// Carrega as functions: dispara admin.initializeApp() e captura db/messaging.
const fns = require('../lib/index.js');

// admin.firestore()/admin.messaging() são getters (não reatribuíveis), então
// injetamos os fakes nas instâncias REAIS que as functions já capturaram.
const dbReal = admin.firestore();
dbReal.collection = (nome) => firestoreFake.collection(nome);
const messagingReal = admin.messaging();
messagingReal.send = messagingFake.send;
messagingReal.sendEachForMulticast = messagingFake.sendEachForMulticast;

function resetar() {
  for (const k of Object.keys(usuarios))       delete usuarios[k];
  for (const k of Object.keys(clientes))       delete clientes[k];
  for (const k of Object.keys(tickets))        delete tickets[k];
  for (const k of Object.keys(subcollections)) delete subcollections[k];
  enviados = [];
  fcmSendError = null;
  fcmMulticastError = null;
  fcmBatchResponses = null;
}

function snapNegociacao(dados) {
  return fft.firestore.makeDocumentSnapshot(dados, 'negociacoes/n1');
}

function snapCampanha(dados) {
  return fft.firestore.makeDocumentSnapshot(dados, 'campanhas/c1');
}

// ── onNegociacaoAtualizada ──────────────────────────────────────────────────
test.describe('onNegociacaoAtualizada', () => {
  const wrapped = fft.wrap(fns.onNegociacaoAtualizada);

  test.beforeEach(resetar);

  test('notifica o embaixador quando a proposta é aprovada (pendente → aprovada)',
    async () => {
      usuarios['emb1'] = { fcmToken: 'tok-emb1', ativo: true };
      const change = fft.makeChange(
        snapNegociacao({ statusAprovacao: 'pendente', embaixadorId: 'emb1', titulo: 'Casa 12' }),
        snapNegociacao({ statusAprovacao: 'aprovada', embaixadorId: 'emb1', titulo: 'Casa 12' }),
      );

      await wrapped(change, { params: { negId: 'n1' } });

      assert.equal(enviados.length, 1);
      assert.equal(enviados[0].msg.token, 'tok-emb1');
      assert.match(enviados[0].msg.notification.body, /aprovada/i);
    });

  test('NÃO notifica quando o status não muda (aprovada → aprovada)', async () => {
    usuarios['emb1'] = { fcmToken: 'tok-emb1', ativo: true };
    const change = fft.makeChange(
      snapNegociacao({ statusAprovacao: 'aprovada', embaixadorId: 'emb1', titulo: 'X' }),
      snapNegociacao({ statusAprovacao: 'aprovada', embaixadorId: 'emb1', titulo: 'X' }),
    );

    await wrapped(change, { params: { negId: 'n1' } });

    assert.equal(enviados.length, 0);
  });

  test('NÃO notifica quando a negociação não tem embaixador', async () => {
    const change = fft.makeChange(
      snapNegociacao({ statusAprovacao: 'pendente', titulo: 'X' }),
      snapNegociacao({ statusAprovacao: 'aprovada', titulo: 'X' }),
    );

    await wrapped(change, { params: { negId: 'n1' } });

    assert.equal(enviados.length, 0);
  });

  test('NÃO notifica em transição para status sem mensagem (pendente)', async () => {
    usuarios['emb1'] = { fcmToken: 'tok-emb1', ativo: true };
    const change = fft.makeChange(
      snapNegociacao({ statusAprovacao: 'semSolicitacao', embaixadorId: 'emb1', titulo: 'X' }),
      snapNegociacao({ statusAprovacao: 'pendente', embaixadorId: 'emb1', titulo: 'X' }),
    );

    await wrapped(change, { params: { negId: 'n1' } });

    assert.equal(enviados.length, 0);
  });

  test('token permanentemente inválido: remove fcmToken do usuário e NÃO relança',
    async () => {
      usuarios['emb1'] = { fcmToken: 'tok-invalido', ativo: true };
      fcmSendError = { errorInfo: { code: 'messaging/registration-token-not-registered' } };

      const change = fft.makeChange(
        snapNegociacao({ statusAprovacao: 'pendente', embaixadorId: 'emb1', titulo: 'Casa 12' }),
        snapNegociacao({ statusAprovacao: 'aprovada', embaixadorId: 'emb1', titulo: 'Casa 12' }),
      );

      await assert.doesNotReject(() => wrapped(change, { params: { negId: 'n1' } }));

      assert.equal(enviados.length, 0, 'nenhuma entrega deve ter sido registrada');
      assert.equal(usuarios['emb1'].fcmToken, undefined, 'fcmToken deve ter sido removido');
    });

  test('falha transitória do FCM: re-lança para o runtime reprocessar', async () => {
    usuarios['emb1'] = { fcmToken: 'tok-emb1', ativo: true };
    fcmSendError = { errorInfo: { code: 'messaging/internal-error' } };

    const change = fft.makeChange(
      snapNegociacao({ statusAprovacao: 'pendente', embaixadorId: 'emb1', titulo: 'Casa 12' }),
      snapNegociacao({ statusAprovacao: 'aprovada', embaixadorId: 'emb1', titulo: 'Casa 12' }),
    );

    await assert.rejects(() => wrapped(change, { params: { negId: 'n1' } }));

    // token NÃO deve ter sido removido (erro era transitório)
    assert.equal(usuarios['emb1'].fcmToken, 'tok-emb1');
  });
});

// ── onCampanhaPublicada ─────────────────────────────────────────────────────
test.describe('onCampanhaPublicada', () => {
  const wrapped = fft.wrap(fns.onCampanhaPublicada);

  test.beforeEach(resetar);

  test('notifica todos os usuários ativos quando a campanha é ativada (false → true)',
    async () => {
      usuarios['u1'] = { fcmToken: 'tok-1', ativo: true };
      usuarios['u2'] = { fcmToken: 'tok-2', ativo: true };
      usuarios['u3'] = { fcmToken: 'tok-3', ativo: false }; // inativo: não recebe
      const change = fft.makeChange(
        snapCampanha({ ativa: false, nome: 'Promo' }),
        snapCampanha({ ativa: true, nome: 'Promo', valorDesconto: 10 }),
      );

      await wrapped(change, { params: { campanhaId: 'c1' } });

      assert.equal(enviados.length, 1);
      assert.equal(enviados[0].tipo, 'multicast');
      assert.deepEqual(enviados[0].msg.tokens.sort(), ['tok-1', 'tok-2']);
    });

  test('NÃO notifica quando a campanha já estava ativa (true → true)', async () => {
    usuarios['u1'] = { fcmToken: 'tok-1', ativo: true };
    const change = fft.makeChange(
      snapCampanha({ ativa: true, nome: 'Promo' }),
      snapCampanha({ ativa: true, nome: 'Promo' }),
    );

    await wrapped(change, { params: { campanhaId: 'c1' } });

    assert.equal(enviados.length, 0);
  });

  test('tokens permanentemente inválidos no batch são removidos do Firestore',
    async () => {
      usuarios['u1'] = { fcmToken: 'tok-valido', ativo: true };
      usuarios['u2'] = { fcmToken: 'tok-invalido', ativo: true };

      fcmBatchResponses = {
        successCount: 1,
        failureCount: 1,
        responses: [
          { success: true },
          { success: false, error: { code: 'messaging/registration-token-not-registered' } },
        ],
      };

      const change = fft.makeChange(
        snapCampanha({ ativa: false, nome: 'Promo' }),
        snapCampanha({ ativa: true, nome: 'Promo' }),
      );

      await wrapped(change, { params: { campanhaId: 'c1' } });

      assert.equal(usuarios['u2'].fcmToken, undefined, 'token inválido deve ser removido');
      assert.equal(usuarios['u1'].fcmToken, 'tok-valido', 'token válido não deve ser afetado');
    });

  test('falha catastrófica no batch FCM NÃO relança (evita duplicatas em retry)',
    async () => {
      usuarios['u1'] = { fcmToken: 'tok-1', ativo: true };
      fcmMulticastError = new Error('FCM server unavailable');

      const change = fft.makeChange(
        snapCampanha({ ativa: false, nome: 'Promo' }),
        snapCampanha({ ativa: true, nome: 'Promo' }),
      );

      await assert.doesNotReject(() => wrapped(change, { params: { campanhaId: 'c1' } }));
    });
});

// ── onTicketAtualizado ──────────────────────────────────────────────────────
test.describe('onTicketAtualizado', () => {
  const wrapped = fft.wrap(fns.onTicketAtualizado);

  function snapTicket(dados) {
    return fft.firestore.makeDocumentSnapshot(dados, 'tickets/t1');
  }

  test.beforeEach(resetar);

  test('notifica criador quando o status muda', async () => {
    usuarios['criador1'] = { fcmToken: 'tok-criador', ativo: true };
    const change = fft.makeChange(
      snapTicket({ titulo: 'Bug X', numero: 5, status: 'aberto', criadoPorId: 'criador1' }),
      snapTicket({ titulo: 'Bug X', numero: 5, status: 'emAndamento', criadoPorId: 'criador1' }),
    );

    await wrapped(change, { params: { ticketId: 't1' } });

    assert.equal(enviados.length, 1);
    assert.equal(enviados[0].msg.token, 'tok-criador');
    assert.match(enviados[0].msg.notification.body, /#5/);
    assert.match(enviados[0].msg.notification.body, /andamento/i);
  });

  test('NÃO notifica quando o status não muda', async () => {
    usuarios['criador1'] = { fcmToken: 'tok-criador', ativo: true };
    const change = fft.makeChange(
      snapTicket({ titulo: 'Bug X', numero: 5, status: 'aberto', criadoPorId: 'criador1' }),
      snapTicket({ titulo: 'Bug X', numero: 5, status: 'aberto', criadoPorId: 'criador1' }),
    );

    await wrapped(change, { params: { ticketId: 't1' } });

    assert.equal(enviados.length, 0);
  });

  test('notifica novo atribuído quando atribuição muda', async () => {
    usuarios['criador1'] = { fcmToken: 'tok-criador', ativo: true };
    usuarios['dev1']     = { fcmToken: 'tok-dev',     ativo: true };
    const change = fft.makeChange(
      snapTicket({ titulo: 'Bug X', numero: 2, status: 'aberto', criadoPorId: 'criador1' }),
      snapTicket({ titulo: 'Bug X', numero: 2, status: 'aberto', criadoPorId: 'criador1', atribuidoParaId: 'dev1' }),
    );

    await wrapped(change, { params: { ticketId: 't1' } });

    assert.equal(enviados.length, 1);
    assert.equal(enviados[0].msg.token, 'tok-dev');
    assert.match(enviados[0].msg.notification.body, /atribuído/i);
  });

  test('NÃO notifica atribuído se é o mesmo que antes', async () => {
    usuarios['criador1'] = { fcmToken: 'tok-criador', ativo: true };
    usuarios['dev1']     = { fcmToken: 'tok-dev',     ativo: true };
    const change = fft.makeChange(
      snapTicket({ titulo: 'Bug X', numero: 2, status: 'aberto', criadoPorId: 'criador1', atribuidoParaId: 'dev1' }),
      snapTicket({ titulo: 'Bug X', numero: 2, status: 'aberto', criadoPorId: 'criador1', atribuidoParaId: 'dev1' }),
    );

    await wrapped(change, { params: { ticketId: 't1' } });

    assert.equal(enviados.length, 0);
  });

  test('grava notificação in-app para o criador quando status muda', async () => {
    usuarios['criador1'] = { fcmToken: 'tok-criador', ativo: true };
    const change = fft.makeChange(
      snapTicket({ titulo: 'Bug X', numero: 5, status: 'aberto', criadoPorId: 'criador1' }),
      snapTicket({ titulo: 'Bug X', numero: 5, status: 'emAndamento', criadoPorId: 'criador1' }),
    );

    await wrapped(change, { params: { ticketId: 't1' } });

    const itens = Object.values(subcollections['notificacoes/criador1/itens'] ?? {});
    assert.equal(itens.length, 1);
    assert.equal(itens[0].tipo, 'ticket_status');
    assert.equal(itens[0].ticketId, 't1');
    assert.equal(itens[0].ticketNumero, 5);
    assert.strictEqual(itens[0].lida, false);
  });

  test('grava notificação in-app para o atribuído quando atribuição muda', async () => {
    usuarios['criador1'] = { fcmToken: 'tok-criador', ativo: true };
    usuarios['dev1']     = { fcmToken: 'tok-dev',     ativo: true };
    const change = fft.makeChange(
      snapTicket({ titulo: 'Bug X', numero: 2, status: 'aberto', criadoPorId: 'criador1' }),
      snapTicket({ titulo: 'Bug X', numero: 2, status: 'aberto', criadoPorId: 'criador1', atribuidoParaId: 'dev1' }),
    );

    await wrapped(change, { params: { ticketId: 't1' } });

    const itens = Object.values(subcollections['notificacoes/dev1/itens'] ?? {});
    assert.equal(itens.length, 1);
    assert.equal(itens[0].tipo, 'ticket_atribuido');
    assert.equal(itens[0].ticketId, 't1');
    assert.strictEqual(itens[0].lida, false);
  });
});

// ── onComentarioAdicionado ──────────────────────────────────────────────────
test.describe('onComentarioAdicionado', () => {
  const wrapped = fft.wrap(fns.onComentarioAdicionado);

  function snapComentario(dados) {
    return fft.firestore.makeDocumentSnapshot(dados, 'tickets/t1/comentarios/c1');
  }

  test.beforeEach(resetar);

  test('notifica o criador do ticket quando outro usuário comenta', async () => {
    usuarios['criador1'] = { fcmToken: 'tok-criador', ativo: true };
    tickets['t1'] = { titulo: 'Falha Z', numero: 7, criadoPorId: 'criador1' };

    const snap = snapComentario({ texto: 'Investigando...', autorId: 'dev1', autorNome: 'Dev' });
    await wrapped(snap, { params: { ticketId: 't1', comentarioId: 'c1' } });

    assert.equal(enviados.length, 1);
    assert.equal(enviados[0].msg.token, 'tok-criador');
    assert.match(enviados[0].msg.notification.body, /Investigando/);
  });

  test('NÃO notifica o criador se ele mesmo comenta', async () => {
    usuarios['criador1'] = { fcmToken: 'tok-criador', ativo: true };
    tickets['t1'] = { titulo: 'Falha Z', numero: 7, criadoPorId: 'criador1' };

    const snap = snapComentario({ texto: 'Meu próprio comentário', autorId: 'criador1', autorNome: 'Criador' });
    await wrapped(snap, { params: { ticketId: 't1', comentarioId: 'c1' } });

    assert.equal(enviados.length, 0);
  });

  test('notifica atribuído além do criador quando são pessoas diferentes', async () => {
    usuarios['criador1'] = { fcmToken: 'tok-criador', ativo: true };
    usuarios['dev1']     = { fcmToken: 'tok-dev',     ativo: true };
    tickets['t1'] = { titulo: 'Bug Y', numero: 3, criadoPorId: 'criador1', atribuidoParaId: 'dev1' };

    const snap = snapComentario({ texto: 'Novo update', autorId: 'outro', autorNome: 'Outro' });
    await wrapped(snap, { params: { ticketId: 't1', comentarioId: 'c1' } });

    assert.equal(enviados.length, 2);
    const tokens = enviados.map(e => e.msg.token).sort();
    assert.deepEqual(tokens, ['tok-criador', 'tok-dev']);
  });

  test('NÃO notifica se o ticket não existe', async () => {
    const snap = snapComentario({ texto: 'Texto', autorId: 'u1', autorNome: 'U1' });
    await wrapped(snap, { params: { ticketId: 'nao-existe', comentarioId: 'c1' } });

    assert.equal(enviados.length, 0);
  });

  test('grava notificação in-app para o criador quando outro usuário comenta', async () => {
    usuarios['criador1'] = { fcmToken: 'tok-criador', ativo: true };
    tickets['t1'] = { titulo: 'Falha Z', numero: 7, criadoPorId: 'criador1' };

    const snap = snapComentario({ texto: 'Investigando...', autorId: 'dev1', autorNome: 'Dev' });
    await wrapped(snap, { params: { ticketId: 't1', comentarioId: 'c1' } });

    const itens = Object.values(subcollections['notificacoes/criador1/itens'] ?? {});
    assert.equal(itens.length, 1);
    assert.equal(itens[0].tipo, 'ticket_comentario');
    assert.equal(itens[0].ticketId, 't1');
    assert.equal(itens[0].ticketNumero, 7);
    assert.strictEqual(itens[0].lida, false);
  });

  test('grava notificação in-app para criador e atribuído quando são pessoas diferentes', async () => {
    usuarios['criador1'] = { fcmToken: 'tok-criador', ativo: true };
    usuarios['dev1']     = { fcmToken: 'tok-dev',     ativo: true };
    tickets['t1'] = { titulo: 'Bug Y', numero: 3, criadoPorId: 'criador1', atribuidoParaId: 'dev1' };

    const snap = snapComentario({ texto: 'Novo update', autorId: 'outro', autorNome: 'Outro' });
    await wrapped(snap, { params: { ticketId: 't1', comentarioId: 'c1' } });

    const itensCriador = Object.values(subcollections['notificacoes/criador1/itens'] ?? {});
    const itensDev     = Object.values(subcollections['notificacoes/dev1/itens']     ?? {});
    assert.equal(itensCriador.length, 1);
    assert.equal(itensDev.length, 1);
    assert.equal(itensCriador[0].tipo, 'ticket_comentario');
    assert.equal(itensDev[0].tipo, 'ticket_comentario');
  });
});

// ── lembreteProximoContato ──────────────────────────────────────────────────
test.describe('lembreteProximoContato', () => {
  const wrapped = fft.wrap(fns.lembreteProximoContato);

  // Produz um Timestamp Firestore compatível (tem toMillis() e toDate())
  function tsFromDate(date) {
    return admin.firestore.Timestamp.fromDate(date);
  }

  test.beforeEach(resetar);

  test('envia lembrete do dia para vendedor com contato agendado para hoje', async () => {
    usuarios['v1'] = { fcmToken: 'tok-v1', ativo: true };
    const agora = new Date();
    const hoje = new Date(agora.getFullYear(), agora.getMonth(), agora.getDate(), 10, 0, 0);
    clientes['c1'] = { nome: 'Ana', vendedorId: 'v1', proximoContato: tsFromDate(hoje) };

    await wrapped({});

    const lembretes = enviados.filter(e => e.msg.data?.tipo === 'lembrete_contato');
    assert.equal(lembretes.length, 1);
    assert.equal(lembretes[0].msg.token, 'tok-v1');
    assert.match(lembretes[0].msg.notification.body, /Ana/);
  });

  test('NÃO envia lembrete do dia quando não há contatos agendados para hoje', async () => {
    usuarios['v1'] = { fcmToken: 'tok-v1', ativo: true };
    const ontem = new Date();
    ontem.setDate(ontem.getDate() - 1);
    clientes['c1'] = { nome: 'Ana', vendedorId: 'v1', proximoContato: tsFromDate(ontem), statusMensagem: 'enviada_com_resposta' };

    await wrapped({});

    const lembretes = enviados.filter(e => e.msg.data?.tipo === 'lembrete_contato');
    assert.equal(lembretes.length, 0);
  });

  test('envia notificação de atrasado para vendedor com mensagem não enviada no passado', async () => {
    usuarios['v1'] = { fcmToken: 'tok-v1', ativo: true };
    const ontem = new Date();
    ontem.setDate(ontem.getDate() - 1);
    clientes['c1'] = { nome: 'Bruno', vendedorId: 'v1', proximoContato: tsFromDate(ontem), statusMensagem: 'nao_enviada' };

    await wrapped({});

    const atrasados = enviados.filter(e => e.msg.data?.tipo === 'mensagem_atrasada');
    assert.equal(atrasados.length, 1);
    assert.equal(atrasados[0].msg.token, 'tok-v1');
    assert.match(atrasados[0].msg.notification.body, /Bruno/);
  });

  test('NÃO envia atrasado quando mensagem já foi enviada', async () => {
    usuarios['v1'] = { fcmToken: 'tok-v1', ativo: true };
    const ontem = new Date();
    ontem.setDate(ontem.getDate() - 1);
    clientes['c1'] = { nome: 'Carlos', vendedorId: 'v1', proximoContato: tsFromDate(ontem), statusMensagem: 'enviada_com_resposta' };

    await wrapped({});

    const atrasados = enviados.filter(e => e.msg.data?.tipo === 'mensagem_atrasada');
    assert.equal(atrasados.length, 0);
  });

  test('agrupa múltiplos leads atrasados em uma única notificação por vendedor', async () => {
    usuarios['v1'] = { fcmToken: 'tok-v1', ativo: true };
    const ontem = new Date();
    ontem.setDate(ontem.getDate() - 1);
    clientes['c1'] = { nome: 'D1', vendedorId: 'v1', proximoContato: tsFromDate(ontem), statusMensagem: 'nao_enviada' };
    clientes['c2'] = { nome: 'D2', vendedorId: 'v1', proximoContato: tsFromDate(ontem), statusMensagem: 'nao_enviada' };
    clientes['c3'] = { nome: 'D3', vendedorId: 'v1', proximoContato: tsFromDate(ontem), statusMensagem: 'nao_enviada' };

    await wrapped({});

    const atrasados = enviados.filter(e => e.msg.data?.tipo === 'mensagem_atrasada');
    assert.equal(atrasados.length, 1, 'deve agrupar em 1 notificação');
    assert.match(atrasados[0].msg.notification.body, /3/);
  });

  test('ignora leads deletados ao calcular lembretes do dia', async () => {
    usuarios['v1'] = { fcmToken: 'tok-v1', ativo: true };
    const agora = new Date();
    const hoje = new Date(agora.getFullYear(), agora.getMonth(), agora.getDate(), 10, 0, 0);
    clientes['c1'] = { nome: 'Excluído', vendedorId: 'v1', proximoContato: tsFromDate(hoje), deletado: true };

    await wrapped({});

    assert.equal(enviados.length, 0);
  });
});

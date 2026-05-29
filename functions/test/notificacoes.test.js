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
 *
 * Roda com: `npm test` (dentro de functions/) ou `node --test`.
 */

const test = require('node:test');
const assert = require('node:assert/strict');

process.env.GCLOUD_PROJECT = process.env.GCLOUD_PROJECT || 'demo-villamor';

const admin = require('firebase-admin');

// ── Fakes em memória ────────────────────────────────────────────────────────
const usuarios = {};
let enviados = [];
let fcmSendError = null;        // faz messaging.send() lançar este erro
let fcmMulticastError = null;   // faz sendEachForMulticast() lançar este erro
let fcmBatchResponses = null;   // resposta customizada para sendEachForMulticast

// Cria uma referência de documento fake com suporte a update()
function criarDocRef(id) {
  return {
    async update(data) {
      if (!usuarios[id]) return;
      for (const [k, v] of Object.entries(data)) {
        // Detecta FieldValue.delete() (objeto não-primitivo) e remove o campo
        if (v === null || v === undefined ||
            (typeof v === 'object' && !Array.isArray(v) && !(v instanceof Date))) {
          delete usuarios[id][k];
        } else {
          usuarios[id][k] = v;
        }
      }
    },
  };
}

const firestoreFake = {
  collection(_nome) {
    return {
      doc(id) {
        return {
          async get() {
            const dados = usuarios[id];
            return { exists: !!dados, data: () => dados };
          },
          async update(data) {
            return criarDocRef(id).update(data);
          },
        };
      },
      where(campo, _op, valor) {
        const self = {
          limit(_n) { return self; },
          async get() {
            const matched = Object.entries(usuarios)
              .filter(([, d]) => d[campo] === valor)
              .map(([id, d]) => ({
                data: () => d,
                ref: criarDocRef(id),
              }));
            return {
              empty: matched.length === 0,
              forEach: (cb) => matched.forEach(cb),
              docs: matched,
            };
          },
        };
        return self;
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
  for (const k of Object.keys(usuarios)) delete usuarios[k];
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

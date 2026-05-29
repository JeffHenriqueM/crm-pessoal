'use strict';

/**
 * Risco #4 — testes de COMPORTAMENTO de disparo dos triggers FCM.
 *
 * Não dependem de emulador: o `admin.firestore()` e o `admin.messaging()` são
 * substituídos por fakes em memória antes de carregar as functions. Assim
 * verificamos QUANDO uma notificação é (ou não é) enviada, sem tocar a rede.
 *
 * Roda com: `npm test` (dentro de functions/) ou `node --test`.
 */

const test = require('node:test');
const assert = require('node:assert/strict');

process.env.GCLOUD_PROJECT = process.env.GCLOUD_PROJECT || 'demo-villamor';

const admin = require('firebase-admin');

// ── Fakes em memória ────────────────────────────────────────────────────────
const usuarios = {}; // id -> dados
let enviados = []; // registros de envio capturados

const firestoreFake = {
  collection(_nome) {
    return {
      doc(id) {
        return {
          async get() {
            const dados = usuarios[id];
            return { exists: !!dados, data: () => dados };
          },
        };
      },
      where(campo, _op, valor) {
        return {
          async get() {
            const docs = Object.values(usuarios)
              .filter((d) => d[campo] === valor)
              .map((d) => ({ data: () => d }));
            return { forEach: (cb) => docs.forEach(cb), docs };
          },
        };
      },
    };
  },
};

const messagingFake = {
  async send(msg) {
    enviados.push({ tipo: 'send', msg });
    return 'mock-message-id';
  },
  async sendEachForMulticast(msg) {
    enviados.push({ tipo: 'multicast', msg });
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

// `admin.firestore`/`admin.messaging` são getters (não reatribuíveis), então
// injetamos os fakes nas instâncias REAIS que as functions já capturaram.
const dbReal = admin.firestore();
dbReal.collection = (nome) => firestoreFake.collection(nome);
const messagingReal = admin.messaging();
messagingReal.send = messagingFake.send;
messagingReal.sendEachForMulticast = messagingFake.sendEachForMulticast;

function resetar() {
  for (const k of Object.keys(usuarios)) delete usuarios[k];
  enviados = [];
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
});

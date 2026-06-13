import { test, before, after } from 'node:test';
import { assertSucceeds, assertFails } from '@firebase/rules-unit-testing';
import { setDoc, getDoc, updateDoc, deleteDoc, doc } from 'firebase/firestore';
import {
  criarAmbienteTeste,
  contextoAutenticado,
  contextoAnonimo,
  semRegras,
} from './setup.js';

// Contratos e suas interações (subcoleção). Regras NÃO cascateiam: a
// subcoleção contratos/{id}/interacoes precisa do próprio match.
// Comportamento: qualquer autenticado lê/escreve; anônimo não.

let env;

before(async () => {
  env = await criarAmbienteTeste();
});

after(async () => {
  await env.cleanup();
});

test('autenticado cria interação de contrato', async () => {
  const db = contextoAutenticado(env, 'pv1');
  await assertSucceeds(
    setDoc(doc(db, 'contratos/LOC1/interacoes/i1'), {
      nota: 'Liguei',
      houveResposta: false,
    }),
  );
});

test('autenticado atualiza interação (registrar resposta depois)', async () => {
  await semRegras(env, async (db) => {
    await setDoc(doc(db, 'contratos/LOC1/interacoes/i2'), {
      nota: 'Mandei proposta',
      houveResposta: false,
    });
  });
  const db = contextoAutenticado(env, 'pv1');
  await assertSucceeds(
    updateDoc(doc(db, 'contratos/LOC1/interacoes/i2'), {
      respostaCliente: 'Topo',
      houveResposta: true,
    }),
  );
});

test('autenticado lê e exclui interação de contrato', async () => {
  await semRegras(env, async (db) => {
    await setDoc(doc(db, 'contratos/LOC1/interacoes/i3'), { nota: 'x' });
  });
  const db = contextoAutenticado(env, 'pv1');
  await assertSucceeds(getDoc(doc(db, 'contratos/LOC1/interacoes/i3')));
  await assertSucceeds(deleteDoc(doc(db, 'contratos/LOC1/interacoes/i3')));
});

test('anônimo NÃO escreve interação de contrato', async () => {
  const db = contextoAnonimo(env);
  await assertFails(
    setDoc(doc(db, 'contratos/LOC1/interacoes/i9'), { nota: 'x' }),
  );
});

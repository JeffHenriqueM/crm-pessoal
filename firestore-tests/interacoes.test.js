import { test, before, after } from 'node:test';
import { assertSucceeds, assertFails } from '@firebase/rules-unit-testing';
import {
  setDoc,
  getDocs,
  collectionGroup,
  query,
  where,
  doc,
} from 'firebase/firestore';
import {
  criarAmbienteTeste,
  contextoAutenticado,
  contextoAnonimo,
  semRegras,
} from './setup.js';

// Relatório do dashboard lê as interações via query collection-group.
// Um match aninhado NÃO autoriza collectionGroup: as Rules precisam do
// wildcard recursivo `/{caminho=**}/interacoes/{docId}` com leitura liberada.
// Comportamento: autenticado roda a query; anônimo é negado.

let env;

before(async () => {
  env = await criarAmbienteTeste();
  await semRegras(env, async (db) => {
    await setDoc(doc(db, 'clientes/c1/interacoes/i1'), {
      nota: 'oi',
      canal: 'whatsapp',
      autorId: 'u1',
    });
    await setDoc(doc(db, 'contratos/LOC1/interacoes/i2'), {
      nota: 'x',
      canal: 'whatsapp',
    });
  });
});

after(async () => {
  await env.cleanup();
});

test('autenticado roda query collection-group de interações', async () => {
  const db = contextoAutenticado(env, 'u1');
  await assertSucceeds(getDocs(collectionGroup(db, 'interacoes')));
});

test('autenticado filtra collection-group por autorId', async () => {
  const db = contextoAutenticado(env, 'u1');
  await assertSucceeds(
    getDocs(
      query(collectionGroup(db, 'interacoes'), where('autorId', '==', 'u1')),
    ),
  );
});

test('anônimo NÃO roda query collection-group de interações', async () => {
  const db = contextoAnonimo(env);
  await assertFails(getDocs(collectionGroup(db, 'interacoes')));
});

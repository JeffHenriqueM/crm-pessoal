import { test, before, beforeEach, after } from 'node:test';
import { assertSucceeds, assertFails } from '@firebase/rules-unit-testing';
import { getDoc, setDoc, updateDoc, doc } from 'firebase/firestore';
import { criarAmbienteTeste, contextoAutenticado, semRegras } from './setup.js';

// Itens de notificação in-app (central do sino) — ticket #11.
// As regras não cascateiam: a subcoleção notificacoes/{uid}/itens precisa do
// seu próprio match. Cada usuário lê/atualiza SÓ os seus itens.

let env;

before(async () => {
  env = await criarAmbienteTeste();
});

after(async () => {
  await env.cleanup();
});

beforeEach(async () => {
  await env.clearFirestore();
  await semRegras(env, async (db) => {
    await setDoc(doc(db, 'usuarios/ana'), { perfil: 'vendedor', nome: 'Ana' });
    await setDoc(doc(db, 'usuarios/beto'), { perfil: 'vendedor', nome: 'Beto' });
    await setDoc(doc(db, 'notificacoes/ana/itens/n1'), {
      tipo: 'ticket',
      titulo: 'Seu ticket foi atualizado',
      corpo: 'Status mudou para resolvido',
      lida: false,
    });
  });
});

test('dono lê seus próprios itens de notificação', async () => {
  const db = contextoAutenticado(env, 'ana');
  await assertSucceeds(getDoc(doc(db, 'notificacoes/ana/itens/n1')));
});

test('dono marca seu item como lido', async () => {
  const db = contextoAutenticado(env, 'ana');
  await assertSucceeds(
    updateDoc(doc(db, 'notificacoes/ana/itens/n1'), { lida: true }),
  );
});

test('outro usuário NÃO lê itens alheios', async () => {
  const db = contextoAutenticado(env, 'beto');
  await assertFails(getDoc(doc(db, 'notificacoes/ana/itens/n1')));
});

test('outro usuário NÃO altera itens alheios', async () => {
  const db = contextoAutenticado(env, 'beto');
  await assertFails(
    updateDoc(doc(db, 'notificacoes/ana/itens/n1'), { lida: true }),
  );
});

test('anônimo NÃO lê itens de notificação', async () => {
  const db = env.unauthenticatedContext().firestore();
  await assertFails(getDoc(doc(db, 'notificacoes/ana/itens/n1')));
});

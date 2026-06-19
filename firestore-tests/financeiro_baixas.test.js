import { test, before, beforeEach, after } from 'node:test';
import { assertSucceeds, assertFails } from '@firebase/rules-unit-testing';
import { getDoc, setDoc, updateDoc, deleteDoc, doc } from 'firebase/firestore';
import {
  criarAmbienteTeste,
  contextoAutenticado,
  semRegras,
} from './setup.js';

// Escopo de `financeiro_baixas` (dados financeiros):
// - admin / financeiro / super admin: leem, criam e atualizam (o update cobre
//   o soft-delete da substituição de importação).
// - vendedor / captador / demais: sem acesso.
// - delete físico SEMPRE bloqueado (substituição é via campo `deletado`).

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
    await setDoc(doc(db, 'usuarios/fin'), { perfil: 'financeiro', nome: 'Fin' });
    await setDoc(doc(db, 'usuarios/admin'), { perfil: 'admin', nome: 'Admin' });
    await setDoc(doc(db, 'usuarios/super'), { perfil: 'super admin', nome: 'Super' });
    await setDoc(doc(db, 'usuarios/vend'), { perfil: 'vendedor', nome: 'Vend' });
    await setDoc(doc(db, 'financeiro_baixas/b1'), {
      cliente: 'X',
      valorPago: 10,
    });
  });
});

test('financeiro lê baixas', async () => {
  const db = contextoAutenticado(env, 'fin');
  await assertSucceeds(getDoc(doc(db, 'financeiro_baixas/b1')));
});

test('financeiro cria baixa', async () => {
  const db = contextoAutenticado(env, 'fin');
  await assertSucceeds(
    setDoc(doc(db, 'financeiro_baixas/b2'), { cliente: 'Y', valorPago: 5 }),
  );
});

test('financeiro faz soft-delete (update deletado=true)', async () => {
  const db = contextoAutenticado(env, 'fin');
  await assertSucceeds(
    updateDoc(doc(db, 'financeiro_baixas/b1'), { deletado: true }),
  );
});

test('vendedor NÃO lê baixas', async () => {
  const db = contextoAutenticado(env, 'vend');
  await assertFails(getDoc(doc(db, 'financeiro_baixas/b1')));
});

test('vendedor NÃO cria baixa', async () => {
  const db = contextoAutenticado(env, 'vend');
  await assertFails(
    setDoc(doc(db, 'financeiro_baixas/b3'), { cliente: 'Z' }),
  );
});

test('delete físico é sempre bloqueado, mesmo para super admin', async () => {
  const db = contextoAutenticado(env, 'super');
  await assertFails(deleteDoc(doc(db, 'financeiro_baixas/b1')));
});

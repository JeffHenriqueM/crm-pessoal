import { test, before, beforeEach, after } from 'node:test';
import { assertSucceeds, assertFails } from '@firebase/rules-unit-testing';
import { setDoc, updateDoc, doc } from 'firebase/firestore';
import {
  criarAmbienteTeste,
  contextoAutenticado,
  semRegras,
  PULAR_BUG_ABERTO,
} from './setup.js';

// Escalonamento de privilégio: o campo `perfil` controla o escopo de acesso.
// Comportamento desejado: SOMENTE super admin modifica documentos de usuários.
// Ninguém promove a si mesmo; nem mesmo admin comum altera usuários.

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
    await setDoc(doc(db, 'usuarios/super'), {
      perfil: 'super admin',
      nome: 'Super',
    });
    await setDoc(doc(db, 'usuarios/admin'), { perfil: 'admin', nome: 'Admin' });
    await setDoc(doc(db, 'usuarios/vendedor_a'), {
      perfil: 'vendedor',
      nome: 'A',
    });
  });
});

test('vendedor NÃO promove a si mesmo a admin', { skip: PULAR_BUG_ABERTO }, async () => {
  const db = contextoAutenticado(env, 'vendedor_a');
  await assertFails(
    updateDoc(doc(db, 'usuarios/vendedor_a'), { perfil: 'admin' }),
  );
});

test('admin comum NÃO altera usuários', { skip: PULAR_BUG_ABERTO }, async () => {
  const db = contextoAutenticado(env, 'admin');
  await assertFails(
    updateDoc(doc(db, 'usuarios/vendedor_a'), { perfil: 'pós-venda' }),
  );
});

test('super admin altera perfil de outro usuário', async () => {
  const db = contextoAutenticado(env, 'super');
  await assertSucceeds(
    updateDoc(doc(db, 'usuarios/vendedor_a'), { perfil: 'pós-venda' }),
  );
});

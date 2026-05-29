import { test, before, beforeEach, after } from 'node:test';
import { assertSucceeds, assertFails } from '@firebase/rules-unit-testing';
import { setDoc, updateDoc, doc } from 'firebase/firestore';
import {
  criarAmbienteTeste,
  contextoAutenticado,
  semRegras,
} from './setup.js';

// Escalonamento de privilégio: o campo `perfil` controla o escopo de acesso.
// Comportamento desejado: gestores (admin e acima) podem editar usuários.
// Vendedor/captador não podem modificar nenhum doc de usuário (incluindo autopromover).

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

test('vendedor NÃO promove a si mesmo a admin', async () => {
  const db = contextoAutenticado(env, 'vendedor_a');
  await assertFails(
    updateDoc(doc(db, 'usuarios/vendedor_a'), { perfil: 'admin' }),
  );
});

test('admin altera perfil de outro usuário', async () => {
  const db = contextoAutenticado(env, 'admin');
  await assertSucceeds(
    updateDoc(doc(db, 'usuarios/vendedor_a'), { perfil: 'pós-venda' }),
  );
});

test('super admin altera perfil de outro usuário', async () => {
  const db = contextoAutenticado(env, 'super');
  await assertSucceeds(
    updateDoc(doc(db, 'usuarios/vendedor_a'), { perfil: 'pós-venda' }),
  );
});

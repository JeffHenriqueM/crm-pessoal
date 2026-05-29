import { test, before, beforeEach, after } from 'node:test';
import { assertSucceeds, assertFails } from '@firebase/rules-unit-testing';
import { getDoc, setDoc, updateDoc, doc } from 'firebase/firestore';
import {
  criarAmbienteTeste,
  contextoAutenticado,
  semRegras,
  PULAR_BUG_ABERTO,
} from './setup.js';

// Escopo de acesso a clientes (CLAUDE.md):
// - vendedor/captador veem APENAS os próprios leads (onde são donos/criadores).
// - admin/pós-venda/financeiro/super admin veem TODOS.
// Dono = uid presente em vendedorId, linerId, criadoPorId ou captadorId.

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
    await setDoc(doc(db, 'usuarios/admin'), { perfil: 'admin', nome: 'Admin' });
    await setDoc(doc(db, 'usuarios/vendedor_a'), { perfil: 'vendedor', nome: 'A' });
    await setDoc(doc(db, 'usuarios/vendedor_b'), { perfil: 'vendedor', nome: 'B' });
    await setDoc(doc(db, 'clientes/lead_de_a'), {
      nome: 'Lead do A',
      vendedorId: 'vendedor_a',
    });
  });
});

test('vendedor lê o próprio lead', async () => {
  const db = contextoAutenticado(env, 'vendedor_a');
  await assertSucceeds(getDoc(doc(db, 'clientes/lead_de_a')));
});

test('vendedor NÃO lê lead de outro vendedor', { skip: PULAR_BUG_ABERTO }, async () => {
  const db = contextoAutenticado(env, 'vendedor_b');
  await assertFails(getDoc(doc(db, 'clientes/lead_de_a')));
});

test('vendedor NÃO altera lead de outro vendedor', { skip: PULAR_BUG_ABERTO }, async () => {
  const db = contextoAutenticado(env, 'vendedor_b');
  await assertFails(
    updateDoc(doc(db, 'clientes/lead_de_a'), { nome: 'sequestrado' }),
  );
});

test('vendedor altera o próprio lead', async () => {
  const db = contextoAutenticado(env, 'vendedor_a');
  await assertSucceeds(
    updateDoc(doc(db, 'clientes/lead_de_a'), { nome: 'atualizado' }),
  );
});

test('admin lê lead de qualquer vendedor', async () => {
  const db = contextoAutenticado(env, 'admin');
  await assertSucceeds(getDoc(doc(db, 'clientes/lead_de_a')));
});

test('vendedor cria lead atribuído a si mesmo', async () => {
  const db = contextoAutenticado(env, 'vendedor_a');
  await assertSucceeds(
    setDoc(doc(db, 'clientes/novo_de_a'), {
      nome: 'Novo',
      vendedorId: 'vendedor_a',
    }),
  );
});

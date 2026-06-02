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

// ── Meta própria (#editar-meta) ───────────────────────────────────────────────
// Comportamento desejado: o próprio usuário pode editar SOMENTE os campos de
// meta no seu doc (tipoMeta/valorMeta/metaMensal/interacoesPorMes), sem poder
// escalar privilégio nem mexer no doc de outro usuário.

test('vendedor edita a própria meta (tipoMeta + valorMeta)', async () => {
  const db = contextoAutenticado(env, 'vendedor_a');
  await assertSucceeds(
    updateDoc(doc(db, 'usuarios/vendedor_a'), {
      tipoMeta: 'fechamentos',
      valorMeta: 5,
    }),
  );
});

test('vendedor NÃO edita a meta de outro usuário', async () => {
  const db = contextoAutenticado(env, 'vendedor_a');
  await assertFails(
    updateDoc(doc(db, 'usuarios/admin'), {
      tipoMeta: 'fechamentos',
      valorMeta: 5,
    }),
  );
});

test('vendedor NÃO escala privilégio junto com a meta', async () => {
  const db = contextoAutenticado(env, 'vendedor_a');
  await assertFails(
    updateDoc(doc(db, 'usuarios/vendedor_a'), {
      valorMeta: 5,
      perfil: 'admin',
    }),
  );
});

test('vendedor incrementa o próprio contador de interações', async () => {
  const db = contextoAutenticado(env, 'vendedor_a');
  await assertSucceeds(
    updateDoc(doc(db, 'usuarios/vendedor_a'), {
      interacoesPorMes: { '2026-6': 1 },
    }),
  );
});

test('vendedor define várias metas próprias (mapa metas)', async () => {
  const db = contextoAutenticado(env, 'vendedor_a');
  await assertSucceeds(
    updateDoc(doc(db, 'usuarios/vendedor_a'), {
      metas: { valorVendido: 50000, mensagensEnviadas: 300 },
    }),
  );
});

test('vendedor NÃO define metas de outro usuário', async () => {
  const db = contextoAutenticado(env, 'vendedor_a');
  await assertFails(
    updateDoc(doc(db, 'usuarios/admin'), {
      metas: { valorVendido: 50000 },
    }),
  );
});

import { test, before, beforeEach, after } from 'node:test';
import { assertSucceeds, assertFails } from '@firebase/rules-unit-testing';
import { getDoc, setDoc, updateDoc, deleteDoc, doc } from 'firebase/firestore';
import {
  criarAmbienteTeste,
  contextoAutenticado,
  semRegras,
} from './setup.js';

// Escopo de `agendamentos` (atendimento futuro, ainda não é lead):
// - TODOS os autenticados leem, criam e operam qualquer agendamento (ticket
//   #62): a recepção lança e o vendedor precisa ver/converter mesmo sem ser o
//   dono. Delete sempre bloqueado (soft-delete/auditoria).

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
    await setDoc(doc(db, 'usuarios/recep'), { perfil: 'recepcao', nome: 'Recep' });
    await setDoc(doc(db, 'usuarios/vendedor_a'), { perfil: 'vendedor', nome: 'A' });
    await setDoc(doc(db, 'usuarios/vendedor_b'), { perfil: 'vendedor', nome: 'B' });
    await setDoc(doc(db, 'agendamentos/ag_de_a'), {
      nome: 'Agendado do A',
      captadorId: 'vendedor_a',
      status: 'agendado',
    });
  });
});

test('recepção lê qualquer agendamento', async () => {
  const db = contextoAutenticado(env, 'recep');
  await assertSucceeds(getDoc(doc(db, 'agendamentos/ag_de_a')));
});

test('recepção cria agendamento de qualquer dono', async () => {
  const db = contextoAutenticado(env, 'recep');
  await assertSucceeds(
    setDoc(doc(db, 'agendamentos/novo'), {
      nome: 'Novo',
      captadorId: 'vendedor_b',
      status: 'agendado',
    }),
  );
});

test('vendedor lê o próprio agendamento', async () => {
  const db = contextoAutenticado(env, 'vendedor_a');
  await assertSucceeds(getDoc(doc(db, 'agendamentos/ag_de_a')));
});

test('vendedor lê agendamento de outro (ticket #62)', async () => {
  const db = contextoAutenticado(env, 'vendedor_b');
  await assertSucceeds(getDoc(doc(db, 'agendamentos/ag_de_a')));
});

test('vendedor altera agendamento de outro (ticket #62)', async () => {
  const db = contextoAutenticado(env, 'vendedor_b');
  await assertSucceeds(
    updateDoc(doc(db, 'agendamentos/ag_de_a'), { status: 'cancelado' }),
  );
});

test('vendedor altera o próprio agendamento', async () => {
  const db = contextoAutenticado(env, 'vendedor_a');
  await assertSucceeds(
    updateDoc(doc(db, 'agendamentos/ag_de_a'), { status: 'compareceu' }),
  );
});

test('vendedor cria agendamento atribuído a si', async () => {
  const db = contextoAutenticado(env, 'vendedor_a');
  await assertSucceeds(
    setDoc(doc(db, 'agendamentos/novo_a'), {
      nome: 'Novo do A',
      captadorId: 'vendedor_a',
      status: 'agendado',
    }),
  );
});

test('delete é sempre bloqueado, mesmo para recepção', async () => {
  const db = contextoAutenticado(env, 'recep');
  await assertFails(deleteDoc(doc(db, 'agendamentos/ag_de_a')));
});

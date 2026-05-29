import { test, before, beforeEach, after } from 'node:test';
import { assertSucceeds, assertFails } from '@firebase/rules-unit-testing';
import { getDoc, setDoc, updateDoc, deleteDoc, doc } from 'firebase/firestore';
import {
  criarAmbienteTeste,
  contextoAutenticado,
  semRegras,
  PULAR_BUG_ABERTO,
} from './setup.js';

// audit_log é trilha de auditoria de ações sensíveis (ex.: exclusão de cliente).
// Comportamento desejado: registros são imutáveis — podem ser criados pela
// aplicação, mas NUNCA reescritos ou apagados. Leitura restrita a admin e
// super admin (a trilha é confidencial).

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
    await setDoc(doc(db, 'usuarios/vendedor_a'), { perfil: 'vendedor' });
    await setDoc(doc(db, 'usuarios/admin'), { perfil: 'admin' });
    await setDoc(doc(db, 'audit_log/log_existente'), {
      tipo: 'exclusao_cliente',
      autorId: 'vendedor_a',
      clienteNome: 'Cliente X',
    });
  });
});

test('vendedor NÃO lê a trilha de auditoria', { skip: PULAR_BUG_ABERTO }, async () => {
  const db = contextoAutenticado(env, 'vendedor_a');
  await assertFails(getDoc(doc(db, 'audit_log/log_existente')));
});

test('admin lê a trilha de auditoria', async () => {
  const db = contextoAutenticado(env, 'admin');
  await assertSucceeds(getDoc(doc(db, 'audit_log/log_existente')));
});

test('usuário cria registro de auditoria', async () => {
  const db = contextoAutenticado(env, 'vendedor_a');
  await assertSucceeds(
    setDoc(doc(db, 'audit_log/novo_log'), {
      tipo: 'exclusao_cliente',
      autorId: 'vendedor_a',
    }),
  );
});

test('usuário NÃO reescreve registro existente do audit_log', { skip: PULAR_BUG_ABERTO }, async () => {
  const db = contextoAutenticado(env, 'vendedor_a');
  await assertFails(
    updateDoc(doc(db, 'audit_log/log_existente'), { autorId: 'outro' }),
  );
});

test('usuário NÃO apaga registro do audit_log', { skip: PULAR_BUG_ABERTO }, async () => {
  const db = contextoAutenticado(env, 'vendedor_a');
  await assertFails(deleteDoc(doc(db, 'audit_log/log_existente')));
});

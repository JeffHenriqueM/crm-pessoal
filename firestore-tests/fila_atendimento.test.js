import { test, before, beforeEach, after } from 'node:test';
import { assertSucceeds, assertFails } from '@firebase/rules-unit-testing';
import { getDoc, setDoc, updateDoc, deleteDoc, doc } from 'firebase/firestore';
import { criarAmbienteTeste, contextoAutenticado, semRegras } from './setup.js';

// Linha de atendimento (fila da sala de vendas):
// - todos autenticados leem;
// - recepção/gestor opera qualquer doc (reordenar, mandar pro fim);
// - vendedor escreve só o PRÓPRIO doc (sua disponibilidade);
// - delete sempre bloqueado.

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
    await setDoc(doc(db, 'usuarios/vend_a'), { perfil: 'vendedor', nome: 'A' });
    await setDoc(doc(db, 'usuarios/vend_b'), { perfil: 'vendedor', nome: 'B' });
    await setDoc(doc(db, 'fila_atendimento/vend_a'), {
      vendedorNome: 'A',
      disponivel: true,
    });
  });
});

test('vendedor lê a fila', async () => {
  const db = contextoAutenticado(env, 'vend_b');
  await assertSucceeds(getDoc(doc(db, 'fila_atendimento/vend_a')));
});

test('vendedor marca a PRÓPRIA disponibilidade', async () => {
  const db = contextoAutenticado(env, 'vend_b');
  await assertSucceeds(
    setDoc(doc(db, 'fila_atendimento/vend_b'), {
      vendedorNome: 'B',
      disponivel: true,
    }),
  );
});

test('vendedor NÃO mexe na disponibilidade de outro', async () => {
  const db = contextoAutenticado(env, 'vend_b');
  await assertFails(
    updateDoc(doc(db, 'fila_atendimento/vend_a'), { disponivel: false }),
  );
});

test('recepção opera qualquer doc da fila (reordenar/mandar pro fim)', async () => {
  const db = contextoAutenticado(env, 'recep');
  await assertSucceeds(
    updateDoc(doc(db, 'fila_atendimento/vend_a'), { disponivel: false }),
  );
});

test('delete é sempre bloqueado', async () => {
  const db = contextoAutenticado(env, 'recep');
  await assertFails(deleteDoc(doc(db, 'fila_atendimento/vend_a')));
});

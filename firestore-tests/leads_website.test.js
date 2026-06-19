import { test, before, beforeEach, after } from 'node:test';
import { assertSucceeds, assertFails } from '@firebase/rules-unit-testing';
import { setDoc, addDoc, getDoc, getDocs, doc, collection, serverTimestamp } from 'firebase/firestore';
import {
  criarAmbienteTeste,
  contextoAutenticado,
  contextoAnonimo,
  semRegras,
} from './setup.js';

// Leads do site/quiosque (leads_website). Comportamento desejado:
// - Páginas públicas (anônimas) podem CRIAR um lead, mas só com payload válido
//   (nome/whatsapp/origem coerentes, status 'novo', createdAt == request.time).
// - Anônimos e vendedores NÃO leem; gestores leem.

let env;

const leadValido = () => ({
  nome: 'Fulano de Tal',
  whatsapp: '83 99999-0000',
  email: 'fulano@email.com',
  aceiteEmail: true,
  origem: 'quiosque',
  status: 'novo',
  pagina: '/tambaba/quiosque.html',
  createdAt: serverTimestamp(),
});

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
  });
});

test('anônimo cria lead válido (site/quiosque público)', async () => {
  const db = contextoAnonimo(env);
  await assertSucceeds(addDoc(collection(db, 'leads_website'), leadValido()));
});

test('anônimo NÃO cria lead com nome curto', async () => {
  const db = contextoAnonimo(env);
  await assertFails(addDoc(collection(db, 'leads_website'), { ...leadValido(), nome: 'A' }));
});

test('anônimo NÃO cria lead com status diferente de "novo"', async () => {
  const db = contextoAnonimo(env);
  await assertFails(addDoc(collection(db, 'leads_website'), { ...leadValido(), status: 'ganho' }));
});

test('anônimo NÃO cria lead com createdAt forjado (não serverTimestamp)', async () => {
  const db = contextoAnonimo(env);
  await assertFails(
    addDoc(collection(db, 'leads_website'), { ...leadValido(), createdAt: new Date('2020-01-01') }),
  );
});

test('anônimo NÃO lê os leads', async () => {
  await semRegras(env, async (db) => {
    await setDoc(doc(db, 'leads_website/L1'), { nome: 'X', whatsapp: '83 90000-0000', origem: 'quiosque', status: 'novo' });
  });
  const db = contextoAnonimo(env);
  await assertFails(getDocs(collection(db, 'leads_website')));
});

test('vendedor NÃO lê os leads (só gestor)', async () => {
  await semRegras(env, async (db) => {
    await setDoc(doc(db, 'leads_website/L1'), { nome: 'X', whatsapp: '83 90000-0000', origem: 'quiosque', status: 'novo' });
  });
  const db = contextoAutenticado(env, 'vendedor_a');
  await assertFails(getDoc(doc(db, 'leads_website/L1')));
});

test('gestor (admin) lê os leads', async () => {
  await semRegras(env, async (db) => {
    await setDoc(doc(db, 'leads_website/L1'), { nome: 'X', whatsapp: '83 90000-0000', origem: 'quiosque', status: 'novo' });
  });
  const db = contextoAutenticado(env, 'admin');
  await assertSucceeds(getDoc(doc(db, 'leads_website/L1')));
});

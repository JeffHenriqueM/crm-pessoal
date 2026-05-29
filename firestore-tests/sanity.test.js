import { test, before, after } from 'node:test';
import { assertSucceeds } from '@firebase/rules-unit-testing';
import { setDoc, doc } from 'firebase/firestore';
import { criarAmbienteTeste, contextoAutenticado } from './setup.js';

let env;

before(async () => {
  env = await criarAmbienteTeste();
});

after(async () => {
  await env.cleanup();
});

// Teste sanity: valida que Java + emulador + harness + carregamento do
// firestore.rules estão funcionando. Contra as regras permissivas atuais,
// um usuário autenticado consegue escrever em clientes — então este teste
// passa hoje. Ele NÃO descreve o comportamento desejado; serve só de
// smoke test do pipeline e será removido quando o item #1 estiver fechado.
test('pipeline: usuário autenticado consegue escrever em clientes (regras atuais)', async () => {
  const db = contextoAutenticado(env, 'vendedor_a');
  await assertSucceeds(setDoc(doc(db, 'clientes/c1'), { nome: 'Lead Teste' }));
});

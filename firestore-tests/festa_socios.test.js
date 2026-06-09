import { test, before, beforeEach, after } from 'node:test';
import { assertSucceeds, assertFails } from '@firebase/rules-unit-testing';
import { setDoc, getDoc, doc } from 'firebase/firestore';
import {
  criarAmbienteTeste,
  contextoAutenticado,
  contextoAnonimo,
  semRegras,
} from './setup.js';

// Festa dos Sócios → validação de trocas de quarto (festa_socios_validacoes).
// Comportamento desejado: apenas gestores (admin/super admin/pós-venda/
// financeiro/recepção) leem e escrevem. Vendedor/captador e anônimos não.

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
    await setDoc(doc(db, 'usuarios/posvenda'), {
      perfil: 'pós-venda',
      nome: 'Pós',
    });
    await setDoc(doc(db, 'usuarios/vendedor_a'), {
      perfil: 'vendedor',
      nome: 'A',
    });
  });
});

test('pós-venda registra validação de troca', async () => {
  const db = contextoAutenticado(env, 'posvenda');
  await assertSucceeds(
    setDoc(doc(db, 'festa_socios_validacoes/151'), {
      status: 'aprovada',
      validadoPorNome: 'Pós',
    }),
  );
});

test('admin registra validação de troca', async () => {
  const db = contextoAutenticado(env, 'admin');
  await assertSucceeds(
    setDoc(doc(db, 'festa_socios_validacoes/201'), { status: 'recusada' }),
  );
});

test('vendedor NÃO escreve validação', async () => {
  const db = contextoAutenticado(env, 'vendedor_a');
  await assertFails(
    setDoc(doc(db, 'festa_socios_validacoes/151'), { status: 'aprovada' }),
  );
});

test('vendedor NÃO lê validação', async () => {
  await semRegras(env, async (db) => {
    await setDoc(doc(db, 'festa_socios_validacoes/151'), { status: 'aprovada' });
  });
  const db = contextoAutenticado(env, 'vendedor_a');
  await assertFails(getDoc(doc(db, 'festa_socios_validacoes/151')));
});

test('anônimo NÃO escreve validação', async () => {
  const db = contextoAnonimo(env);
  await assertFails(
    setDoc(doc(db, 'festa_socios_validacoes/151'), { status: 'aprovada' }),
  );
});

test('pós-venda associa quarto a contrato', async () => {
  const db = contextoAutenticado(env, 'posvenda');
  await assertSucceeds(
    setDoc(doc(db, 'festa_socios_associacoes/135'), {
      contratoId: 'abc',
      ocupante: 'Fulano',
      tier: 'ouro',
      pct: 40,
    }),
  );
});

test('vendedor NÃO associa quarto a contrato', async () => {
  const db = contextoAutenticado(env, 'vendedor_a');
  await assertFails(
    setDoc(doc(db, 'festa_socios_associacoes/135'), { contratoId: 'abc' }),
  );
});

test('pós-venda adiciona hóspede na lista de espera', async () => {
  const db = contextoAutenticado(env, 'posvenda');
  await assertSucceeds(
    setDoc(doc(db, 'festa_socios_espera/abc123'), {
      ocupante: 'Fulano',
      categoria: 'comfort',
      tier: 'prata',
      pct: 30,
    }),
  );
});

test('vendedor NÃO escreve na lista de espera', async () => {
  const db = contextoAutenticado(env, 'vendedor_a');
  await assertFails(
    setDoc(doc(db, 'festa_socios_espera/abc123'), {
      ocupante: 'Fulano',
      categoria: 'comfort',
    }),
  );
});

test('vendedor NÃO lê a lista de espera', async () => {
  await semRegras(env, async (db) => {
    await setDoc(doc(db, 'festa_socios_espera/abc123'), {
      ocupante: 'Fulano',
      categoria: 'comfort',
    });
  });
  const db = contextoAutenticado(env, 'vendedor_a');
  await assertFails(getDoc(doc(db, 'festa_socios_espera/abc123')));
});

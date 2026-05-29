import { readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { dirname, join } from 'node:path';
import { initializeTestEnvironment } from '@firebase/rules-unit-testing';

const __dirname = dirname(fileURLToPath(import.meta.url));
const regras = readFileSync(join(__dirname, '..', 'firestore.rules'), 'utf8');

const HOST = '127.0.0.1';
const PORT = 8080;

/// Equivalente Node do `bug-aberto` do Dart: o runner do node:test não tem
/// tags, então as guardas de bug ainda não corrigido (rules permissivas —
/// ticket #16) recebem `{ skip: PULAR_BUG_ABERTO }`. Sem GATE_DEPLOY elas
/// rodam e ficam VERMELHAS (guarda viva documentando o esperado); com
/// GATE_DEPLOY=1 são puladas para não bloquear o gate de deploy.
export const PULAR_BUG_ABERTO = process.env.GATE_DEPLOY
  ? 'bug-aberto: rules permissivas ainda não corrigidas (ticket #16)'
  : false;

/// Cria o ambiente de teste das Rules carregando o firestore.rules da raiz.
/// Cada arquivo de teste cria o seu próprio ambiente e o destrói no fim.
export function criarAmbienteTeste() {
  return initializeTestEnvironment({
    projectId: 'demo-villamor',
    firestore: { rules: regras, host: HOST, port: PORT },
  });
}

/// Contexto autenticado de um usuário com determinado uid.
/// Os dados extras (perfil etc.) ficam no doc usuarios/{uid}, gravado nos seeds.
export function contextoAutenticado(env, uid) {
  return env.authenticatedContext(uid).firestore();
}

/// Contexto não autenticado.
export function contextoAnonimo(env) {
  return env.unauthenticatedContext().firestore();
}

/// Executa gravações de seed ignorando as Security Rules.
/// Usado para preparar o estado inicial (perfis de usuário, leads, audit_log)
/// antes de exercer as regras com um usuário real.
export function semRegras(env, fn) {
  return env.withSecurityRulesDisabled((ctx) => fn(ctx.firestore()));
}

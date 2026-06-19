/**
 * Cria 2 usuários com perfil "financeiro" no Firebase Auth + Firestore.
 *
 * Pré-requisitos:
 *   - serviceAccount.json na raiz do projeto (gitignored).
 *
 * Uso (a partir da raiz do projeto):
 *   NODE_PATH=./functions/node_modules node scripts/criar_usuarios_financeiro.cjs
 */

const admin = require('firebase-admin');
const path = require('path');
const crypto = require('crypto');

const serviceAccount = require(path.join(__dirname, '..', 'serviceAccount.json'));

/** Senha temporária aleatória e forte — descartada; o usuário define a sua
 *  via link de redefinição. Nunca há senha fixa versionada no repositório. */
function senhaTemporaria() {
  return crypto.randomBytes(18).toString('base64').replace(/[^A-Za-z0-9]/g, '') + 'Aa1!';
}

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
  projectId: 'crm-pessoal-d993d',
});

const auth = admin.auth();
const db = admin.firestore();

const USUARIOS = [
  {
    email: 'financeiro@incorporadorarsm.com',
    nome: 'Financeiro RSM',
    perfil: 'financeiro',
  },
  {
    email: 'simone.marinho@incorporadorarsm.com',
    nome: 'Simone Marinho',
    perfil: 'financeiro',
  },
];

async function criarUsuario({ email, nome, perfil }) {
  console.log(`\n→ Processando: ${email}`);

  // 1. Cria (ou recupera) o usuário no Firebase Auth com senha temporária
  //    aleatória (nunca fixa). O acesso é definido via link de redefinição.
  let authUser;
  try {
    authUser = await auth.createUser({
      email,
      password: senhaTemporaria(),
      displayName: nome,
      emailVerified: false,
    });
    console.log(`  ✅ Auth criado — UID: ${authUser.uid}`);
  } catch (err) {
    if (err.code === 'auth/email-already-exists') {
      authUser = await auth.getUserByEmail(email);
      console.log(`  ⚠️  Auth já existe — UID: ${authUser.uid} (senha mantida)`);
    } else {
      throw err;
    }
  }

  // 1b. Gera um link de definição de senha para enviar ao usuário.
  try {
    const link = await auth.generatePasswordResetLink(email);
    console.log(`  🔑 Link de definição de senha: ${link}`);
  } catch (err) {
    console.log(`  ⚠️  Não foi possível gerar link de senha: ${err.message}`);
  }

  const uid = authUser.uid;

  // 2. Cria (ou garante) o documento na coleção `usuarios`
  //    Segue o mesmo padrão de auth_service.dart: apenas nome, email e perfil
  //    O campo `ativo` é omitido intencionalmente — fromMap() faz default true
  const ref = db.collection('usuarios').doc(uid);
  const snap = await ref.get();

  if (snap.exists) {
    console.log(`  ⚠️  Documento Firestore já existe — nenhuma alteração feita.`);
    console.log(`       Perfil atual: ${snap.data()?.perfil}`);
  } else {
    await ref.set({
      nome,
      email,
      perfil,
    });
    console.log(`  ✅ Documento Firestore criado — perfil: ${perfil}`);
  }

  return uid;
}

async function main() {
  console.log('=== Criação de usuários financeiro ===');
  console.log(`Projeto: crm-pessoal-d993d`);
  console.log(`Total a criar: ${USUARIOS.length}`);

  const resultados = [];

  for (const u of USUARIOS) {
    try {
      const uid = await criarUsuario(u);
      resultados.push({ email: u.email, uid, status: 'ok' });
    } catch (err) {
      console.error(`  ❌ Erro em ${u.email}: ${err.message}`);
      resultados.push({ email: u.email, uid: null, status: 'erro', erro: err.message });
    }
  }

  console.log('\n=== Resumo ===');
  for (const r of resultados) {
    if (r.status === 'ok') {
      console.log(`✅ ${r.email} — UID: ${r.uid}`);
    } else {
      console.log(`❌ ${r.email} — ${r.erro}`);
    }
  }

  console.log('\n=== Próximos passos ===');
  console.log('1. Envie a cada usuário o "Link de definição de senha" exibido acima');
  console.log('   (a senha inicial é aleatória e descartável — ninguém a conhece).');
  console.log('2. Para verificar: Firebase Console > Authentication > Users');
  console.log('   e Firestore > coleção `usuarios` > documento com o UID listado acima.');

  process.exit(0);
}

main().catch((err) => {
  console.error('Erro fatal:', err);
  process.exit(1);
});

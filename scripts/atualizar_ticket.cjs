/**
 * Atualiza um ticket para "aguardandoValidacao" e grava um comentário com o
 * resumo da correção.
 *
 * Pré-requisitos:
 *   - serviceAccount.json na raiz do projeto (gitignored).
 *
 * Uso (a partir da raiz):
 *   NODE_PATH=./functions/node_modules node scripts/atualizar_ticket.cjs \
 *     --numero 25 \
 *     --comentario "Normalização de CRLF implementada em contrato_csv_parser.dart"
 *
 * Flags:
 *   --numero     Número do ticket (ex: 25)
 *   --comentario Texto do comentário a gravar (entre aspas)
 *   --status     Status destino (padrão: aguardandoValidacao)
 */

const admin = require('firebase-admin');
const path  = require('path');

// ── Parse de argumentos simples ─────────────────────────────────────────────
const args = process.argv.slice(2);
function argVal(flag) {
  const i = args.indexOf(flag);
  return i !== -1 ? args[i + 1] : null;
}

const numero     = parseInt(argVal('--numero'), 10);
const comentario = argVal('--comentario');
const status     = argVal('--status') ?? 'aguardandoValidacao';

if (!numero || isNaN(numero)) {
  console.error('Erro: --numero é obrigatório (ex: --numero 25)');
  process.exit(1);
}
if (!comentario) {
  console.error('Erro: --comentario é obrigatório');
  process.exit(1);
}

// ── Firebase ─────────────────────────────────────────────────────────────────
const serviceAccount = require(path.join(__dirname, '..', 'serviceAccount.json'));
admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
  projectId: 'crm-pessoal-d993d',
});
const db = admin.firestore();

async function main() {
  // Busca o ticket pelo número
  const snap = await db.collection('tickets')
    .where('numero', '==', numero)
    .limit(1)
    .get();

  if (snap.empty) {
    console.error(`✖ Ticket #${numero} não encontrado.`);
    process.exit(1);
  }

  const docRef  = snap.docs[0].ref;
  const agora   = admin.firestore.Timestamp.now();

  // Atualiza status + dataAtualizacao
  await docRef.update({
    status: status,
    dataAtualizacao: agora,
  });

  // Grava o comentário na subcoleção
  const comentRef = await docRef.collection('comentarios').add({
    texto: comentario,
    autorId:    'claude-code',
    autorNome:  'Claude Code (automação)',
    autorPerfil: 'sistema',
    dataCriacao: agora,
  });

  // Incrementa totalComentarios
  await docRef.update({
    totalComentarios: admin.firestore.FieldValue.increment(1),
  });

  console.log(`✔ Ticket #${numero} → status: ${status}`);
  console.log(`  Comentário gravado: comentarios/${comentRef.id}`);
  console.log(`  Texto: "${comentario}"`);
}

main()
  .then(() => process.exit(0))
  .catch((e) => {
    console.error('✖ Falha:', e.message);
    process.exit(1);
  });

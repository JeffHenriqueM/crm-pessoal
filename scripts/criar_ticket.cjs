/**
 * Cria um ticket na coleção `tickets` de produção a partir de um arquivo JSON
 * de payload. Usado pela automação de testes para abrir os tickets do backlog.
 *
 * Pré-requisitos:
 *   - serviceAccount.json na raiz do projeto (gitignored).
 * Uso (a partir da raiz):
 *   NODE_PATH=./functions/node_modules node scripts/criar_ticket.cjs scripts/tickets/<arquivo>.json
 *
 * O JSON aceita: titulo, descricao, prioridade (baixa|media|alta),
 * tipo (bug|melhoria|funcionalidade), contexto.
 */

const admin = require('firebase-admin');
const path = require('path');
const fs = require('fs');

const arquivo = process.argv[2];
if (!arquivo) {
  console.error('Uso: node scripts/criar_ticket.cjs <arquivo.json>');
  process.exit(1);
}

const payload = JSON.parse(fs.readFileSync(path.resolve(arquivo), 'utf8'));
const serviceAccount = require(path.join(__dirname, '..', 'serviceAccount.json'));

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
  projectId: 'crm-pessoal-d993d',
});

const db = admin.firestore();

async function proximoNumeroTicket() {
  const ref = db.collection('config').doc('contadores');
  return db.runTransaction(async (tx) => {
    const snap = await tx.get(ref);
    const atual = snap.data()?.tickets ?? 0;
    const proximo = atual + 1;
    tx.set(ref, { tickets: proximo }, { merge: true });
    return proximo;
  });
}

async function main() {
  const numero = await proximoNumeroTicket();
  const agora = admin.firestore.Timestamp.now();
  const ref = await db.collection('tickets').add({
    titulo: payload.titulo,
    descricao: payload.descricao,
    status: 'aberto',
    prioridade: payload.prioridade ?? 'media',
    tipo: payload.tipo ?? 'bug',
    criadoPorId: 'automacao-testes',
    criadoPorNome: 'Automação de Testes',
    criadoPorPerfil: 'super admin',
    contexto: payload.contexto ?? null,
    atribuidoParaId: null,
    atribuidoParaNome: null,
    clienteId: null,
    clienteNome: null,
    totalComentarios: 0,
    numero,
    dataCriacao: agora,
    dataAtualizacao: agora,
  });
  console.log(`✔ Ticket #${numero} criado: tickets/${ref.id}`);
  console.log(`  Título: ${payload.titulo}`);
}

main()
  .then(() => process.exit(0))
  .catch((e) => {
    console.error('✖ Falha ao criar ticket:', e.message);
    process.exit(1);
  });

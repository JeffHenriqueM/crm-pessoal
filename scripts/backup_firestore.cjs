/**
 * Backup diário do Firestore → Google Drive
 *
 * Pré-requisitos (configurar uma vez):
 *   NODE_PATH=./functions/node_modules node scripts/setup_drive.cjs
 *
 * Uso manual (a partir da raiz do projeto):
 *   NODE_PATH=./functions/node_modules node scripts/backup_firestore.cjs
 *
 * Agendamento automático (launchd — já configurado em com.villamor.crm.backup.plist):
 *   cp scripts/com.villamor.crm.backup.plist ~/Library/LaunchAgents/
 *   launchctl load ~/Library/LaunchAgents/com.villamor.crm.backup.plist
 *
 * Salva em: Google Drive → Backups/CRM/crm_backup_YYYY-MM-DD.json
 * Retenção: últimos 30 dias (arquivos mais antigos são removidos automaticamente)
 */

const admin          = require('firebase-admin');
const path           = require('path');
const fs             = require('fs');
const { Readable }   = require('stream');
const { google }     = require('googleapis');

const ROOT             = path.resolve(__dirname, '..');
const SERVICE_ACCOUNT  = path.join(ROOT, 'serviceAccount.json');
const CREDENTIALS_FILE = path.join(__dirname, '.drive_credentials.json');
const COLECOES         = ['clientes', 'negociacoes', 'tickets', 'usuarios', 'campanhas', '_contadores', 'audit_log'];
const DIAS_RETENCAO    = 30;

// ── Inicialização ────────────────────────────────────────────────────────────

admin.initializeApp({ credential: admin.credential.cert(SERVICE_ACCOUNT) });
const db = admin.firestore();

// ── Serialização (Timestamp, GeoPoint, DocumentReference → JSON puro) ────────

function serializarValor(valor) {
  if (valor === null || valor === undefined) return valor;
  if (typeof valor.toDate === 'function') return valor.toDate().toISOString();
  if (typeof valor.latitude === 'number' && typeof valor.longitude === 'number') {
    return { latitude: valor.latitude, longitude: valor.longitude };
  }
  if (typeof valor.path === 'string' && typeof valor.id === 'string') return valor.path;
  if (Array.isArray(valor)) return valor.map(serializarValor);
  if (typeof valor === 'object') return serializarDoc(valor);
  return valor;
}

function serializarDoc(data) {
  const resultado = {};
  for (const [chave, valor] of Object.entries(data)) {
    resultado[chave] = serializarValor(valor);
  }
  return resultado;
}

// ── Exportação do Firestore ──────────────────────────────────────────────────

async function exportarFirestore() {
  const dados = {};
  await Promise.all(
    COLECOES.map(async (colecao) => {
      try {
        const snap = await db.collection(colecao).get();
        dados[colecao] = snap.docs.map((doc) => ({ _id: doc.id, ...serializarDoc(doc.data()) }));
        console.log(`  ✓ ${colecao}: ${dados[colecao].length} documento(s)`);
      } catch (e) {
        console.warn(`  ⚠ ${colecao}: erro ao ler (${e.message})`);
        dados[colecao] = [];
      }
    })
  );
  return dados;
}

// ── Google Drive ─────────────────────────────────────────────────────────────

function criarDriveClient() {
  if (!fs.existsSync(CREDENTIALS_FILE)) {
    console.error('❌ Credenciais do Google Drive não encontradas.');
    console.error('   Execute primeiro: NODE_PATH=./functions/node_modules node scripts/setup_drive.cjs');
    process.exit(1);
  }
  const creds = JSON.parse(fs.readFileSync(CREDENTIALS_FILE, 'utf8'));
  const auth  = new google.auth.OAuth2(creds.client_id, creds.client_secret);
  auth.setCredentials({ refresh_token: creds.refresh_token });
  return google.drive({ version: 'v3', auth });
}

async function obterOuCriarPasta(drive, nome, paiId = 'root') {
  const res = await drive.files.list({
    q: `name='${nome}' and mimeType='application/vnd.google-apps.folder' and '${paiId}' in parents and trashed=false`,
    fields: 'files(id)',
  });
  if (res.data.files.length > 0) return res.data.files[0].id;

  const criada = await drive.files.create({
    requestBody: { name, mimeType: 'application/vnd.google-apps.folder', parents: [paiId] },
    fields: 'id',
  });
  console.log(`  ✓ Pasta "${nome}" criada no Drive`);
  return criada.data.id;
}

async function uploadArquivo(drive, pastaId, nomeArquivo, conteudo) {
  await drive.files.create({
    requestBody: { name: nomeArquivo, parents: [pastaId] },
    media: { mimeType: 'application/json', body: Readable.from([conteudo]) },
    fields: 'id',
  });
  console.log(`  ✓ "${nomeArquivo}" enviado ao Drive`);
}

async function limparBackupsAntigos(drive, pastaId) {
  const limite = new Date();
  limite.setDate(limite.getDate() - DIAS_RETENCAO);

  const res = await drive.files.list({
    q: `'${pastaId}' in parents and trashed=false and name contains 'crm_backup_'`,
    fields: 'files(id,name,createdTime)',
    orderBy: 'createdTime',
  });

  for (const arquivo of res.data.files) {
    if (new Date(arquivo.createdTime) < limite) {
      await drive.files.delete({ fileId: arquivo.id });
      console.log(`  🗑 Removido: ${arquivo.name}`);
    }
  }
}

// ── Main ─────────────────────────────────────────────────────────────────────

async function main() {
  console.log('🔄 Exportando Firestore...');
  const dados    = await exportarFirestore();
  const total    = Object.values(dados).reduce((acc, docs) => acc + docs.length, 0);
  console.log(`\n📦 ${total} documentos exportados`);

  const dataStr      = new Date().toISOString().split('T')[0];
  const nomeArquivo  = `crm_backup_${dataStr}.json`;
  const json         = JSON.stringify(dados, null, 2);

  console.log('\n☁️  Enviando para o Google Drive...');
  const drive = criarDriveClient();

  const pastaBackupsId = await obterOuCriarPasta(drive, 'Backups');
  const pastaCrmId     = await obterOuCriarPasta(drive, 'CRM', pastaBackupsId);

  await uploadArquivo(drive, pastaCrmId, nomeArquivo, json);
  await limparBackupsAntigos(drive, pastaCrmId);

  console.log(`\n✅ Backup concluído → Drive/Backups/CRM/${nomeArquivo}`);
  process.exit(0);
}

main().catch((e) => {
  console.error('\n❌ Erro no backup:', e.message);
  process.exit(1);
});

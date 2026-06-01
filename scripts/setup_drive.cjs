/**
 * Configuração inicial do acesso ao Google Drive (executar UMA única vez).
 *
 * Passo a passo:
 *   1. Acesse: console.cloud.google.com → projeto crm-pessoal-d993d
 *   2. "APIs e Serviços" → "Biblioteca" → pesquise "Google Drive API" → Ativar
 *   3. "APIs e Serviços" → "Credenciais" → "Criar Credencial" → "ID do cliente OAuth 2.0"
 *      - Tipo: "Aplicativo para computador (Desktop)"
 *      - Baixe o JSON gerado
 *   4. Salve o JSON baixado como: scripts/client_secret.json
 *   5. Execute a partir da raiz do projeto:
 *      NODE_PATH=./functions/node_modules node scripts/setup_drive.cjs
 *
 * O script abrirá o navegador, pedirá que você faça login e autorize,
 * e salvará o refresh token em scripts/.drive_credentials.json (gitignored).
 */

const { google } = require('googleapis');
const http       = require('http');
const path       = require('path');
const fs         = require('fs');
const url        = require('url');
const { exec }   = require('child_process');

const ROOT               = path.resolve(__dirname, '..');
const CLIENT_SECRET_FILE = path.join(__dirname, 'client_secret.json');
const CREDENTIALS_FILE   = path.join(__dirname, '.drive_credentials.json');
const SCOPES             = ['https://www.googleapis.com/auth/drive.file'];
const REDIRECT_URI       = 'http://localhost:3000/oauth2callback';

async function main() {
  if (!fs.existsSync(CLIENT_SECRET_FILE)) {
    console.error('❌ Arquivo não encontrado: scripts/client_secret.json');
    console.error('   Siga o passo a passo no cabeçalho deste arquivo.');
    process.exit(1);
  }

  const secret = JSON.parse(fs.readFileSync(CLIENT_SECRET_FILE, 'utf8'));
  const { client_id, client_secret } = secret.installed || secret.web;

  const auth = new google.auth.OAuth2(client_id, client_secret, REDIRECT_URI);
  const authUrl = auth.generateAuthUrl({
    access_type: 'offline',
    scope: SCOPES,
    prompt: 'consent',
  });

  console.log('🔐 Abrindo navegador para autorização do Google Drive...\n');
  exec(`open "${authUrl}"`);

  const code = await new Promise((resolve, reject) => {
    const server = http.createServer((req, res) => {
      const params = new url.URL(req.url, 'http://localhost:3000').searchParams;
      const code   = params.get('code');
      if (code) {
        res.writeHead(200, { 'Content-Type': 'text/html; charset=utf-8' });
        res.end('<h2>✅ Autorização concluída! Pode fechar esta aba e voltar ao terminal.</h2>');
        server.close();
        resolve(code);
      } else {
        res.writeHead(400);
        res.end('Código não recebido.');
        reject(new Error('Código de autorização não recebido'));
      }
    });
    server.listen(3000, () => console.log('⏳ Aguardando autorização no navegador (localhost:3000)...'));
    server.on('error', reject);
  });

  const { tokens } = await auth.getToken(code);

  fs.writeFileSync(CREDENTIALS_FILE, JSON.stringify({
    client_id,
    client_secret,
    refresh_token: tokens.refresh_token,
  }, null, 2));

  console.log('\n✅ Credenciais salvas em scripts/.drive_credentials.json');
  console.log('   Agora rode o backup: NODE_PATH=./functions/node_modules node scripts/backup_firestore.cjs');
}

main().catch((e) => {
  console.error('❌ Erro:', e.message);
  process.exit(1);
});

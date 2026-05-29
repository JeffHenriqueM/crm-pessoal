/**
 * Villamor CRM — Cloud Functions
 *
 * ⚠️ ANTES DE DEPLOYAR:
 * 1. Migre o projeto para o plano Firebase Blaze (pay-as-you-go)
 * 2. cd functions && npm install
 * 3. firebase deploy --only functions
 * 4. No console Firebase > Project Settings > Cloud Messaging > Web Push certificates:
 *    Gere uma VAPID key e substitua 'SUBSTITUA_PELA_SUA_VAPID_KEY' em push_notification_service.dart
 *
 * Funções implementadas:
 * - onNegociacaoAprovada: notifica o embaixador quando o admin aprova/nega/pede atualização
 * - onCampanhaPublicada: notifica todos os usuários quando uma campanha é publicada
 * - notificarAniversariantes: diariamente às 08:00 BRT, notifica perfis pós-venda sobre aniversariantes
 */

import * as functions from 'firebase-functions';
import * as admin from 'firebase-admin';

admin.initializeApp();

const db = admin.firestore();
const messaging = admin.messaging();

// ── Helper: busca token FCM de um usuário ─────────────────────────────────────
async function getToken(userId: string): Promise<string | null> {
  const doc = await db.collection('usuarios').doc(userId).get();
  return doc.exists ? (doc.data()?.fcmToken ?? null) : null;
}

// ── Helper: busca todos os tokens FCM ativos ──────────────────────────────────
async function getAllTokens(): Promise<string[]> {
  const snap = await db.collection('usuarios')
    .where('ativo', '==', true)
    .get();
  const tokens: string[] = [];
  snap.forEach((doc) => {
    const token = doc.data().fcmToken;
    if (token && typeof token === 'string') tokens.push(token);
  });
  return tokens;
}

// ── Helper: envia notificação para um token ───────────────────────────────────
async function enviarParaToken(
  token: string,
  titulo: string,
  corpo: string,
  dados?: Record<string, string>
): Promise<void> {
  try {
    await messaging.send({
      token,
      notification: { title: titulo, body: corpo },
      webpush: {
        notification: {
          title: titulo,
          body: corpo,
          icon: '/icons/Icon-192.png',
          badge: '/favicon.png',
          requireInteraction: false,
        },
        fcmOptions: { link: '/' },
      },
      data: dados ?? {},
    });
  } catch (e) {
    functions.logger.warn(`Erro ao enviar para token: ${e}`);
  }
}

// ── Helper: envia para múltiplos tokens ──────────────────────────────────────
async function enviarParaTokens(
  tokens: string[],
  titulo: string,
  corpo: string,
  dados?: Record<string, string>
): Promise<void> {
  if (tokens.length === 0) return;
  // FCM aceita no máximo 500 tokens por batch
  const batches = [];
  for (let i = 0; i < tokens.length; i += 500) {
    batches.push(tokens.slice(i, i + 500));
  }
  for (const batch of batches) {
    try {
      await messaging.sendEachForMulticast({
        tokens: batch,
        notification: { title: titulo, body: corpo },
        webpush: {
          notification: {
            title: titulo,
            body: corpo,
            icon: '/icons/Icon-192.png',
            badge: '/favicon.png',
          },
          fcmOptions: { link: '/' },
        },
        data: dados ?? {},
      });
    } catch (e) {
      functions.logger.warn(`Erro no batch FCM: ${e}`);
    }
  }
}

// ── Função 1: Notifica embaixador quando negociação é avaliada ────────────────
export const onNegociacaoAtualizada = functions
  .region('us-central1')
  .firestore
  .document('negociacoes/{negId}')
  .onUpdate(async (change, context) => {
    const antes = change.before.data();
    const depois = change.after.data();

    const statusAntes = antes.statusAprovacao as string;
    const statusDepois = depois.statusAprovacao as string;

    // Só dispara se o statusAprovacao mudou
    if (statusAntes === statusDepois) return null;

    const embaixadorId = depois.embaixadorId as string | undefined;
    if (!embaixadorId) return null;

    const titulo = depois.titulo as string ?? 'Proposta';
    let mensagem = '';

    switch (statusDepois) {
      case 'aprovada':
        mensagem = `✅ Sua proposta "${titulo}" foi aprovada pela gerência!`;
        break;
      case 'negada':
        mensagem = `❌ Sua proposta "${titulo}" foi negada pela gerência.`;
        break;
      case 'aguardandoAtualizacao':
        mensagem = `📝 A gerência solicitou atualização na proposta "${titulo}".`;
        break;
      default:
        return null;
    }

    const token = await getToken(embaixadorId);
    if (!token) return null;

    await enviarParaToken(
      token,
      'Villamor CRM — Negociação',
      mensagem,
      { negociacaoId: context.params.negId, tipo: 'aprovacao' }
    );

    functions.logger.info(`Notificação enviada para embaixador ${embaixadorId}: ${statusDepois}`);
    return null;
  });

// ── Função 2: Notifica todos quando uma campanha é publicada ──────────────────
export const onCampanhaPublicada = functions
  .region('us-central1')
  .firestore
  .document('campanhas/{campanhaId}')
  .onWrite(async (change, context) => {
    const depois = change.after.data();
    if (!depois) return null; // deleção — ignora

    const antes = change.before.data();

    // Só dispara quando `ativa` muda de false/undefined para true
    const ativaAntes = antes?.ativa === true;
    const ativaDepois = depois.ativa === true;
    if (ativaAntes || !ativaDepois) return null;

    const nome = depois.nome as string ?? 'Nova campanha';
    const condicao = depois.condicao as string | undefined;
    const desconto = depois.valorDesconto as number | undefined;

    let corpo = `📢 Nova condição especial disponível: ${nome}.`;
    if (desconto) corpo += ` ${desconto}% de desconto.`;
    else if (condicao) corpo += ` ${condicao}`;

    const tokens = await getAllTokens();
    await enviarParaTokens(
      tokens,
      'Villamor CRM — Condição Especial',
      corpo,
      { campanhaId: context.params.campanhaId, tipo: 'campanha' }
    );

    functions.logger.info(`Campanha "${nome}" publicada — ${tokens.length} notificações enviadas`);
    return null;
  });

// ── Função 3: Notifica aniversariantes do dia para usuários pós-venda ─────────
export const notificarAniversariantes = functions
  .region('us-central1')
  .pubsub.schedule('0 8 * * *')
  .timeZone('America/Sao_Paulo')
  .onRun(async () => {
    const hoje = new Date();
    const dia = hoje.getDate();
    const mes = hoje.getMonth() + 1;

    // Busca compradores 1 e 2 com aniversário hoje (campos denormalizados)
    const [snap1, snap2] = await Promise.all([
      db.collection('contratos')
        .where('diaNascimentoComprador', '==', dia)
        .where('mesNascimentoComprador', '==', mes)
        .get(),
      db.collection('contratos')
        .where('diaNascimentoComprador2', '==', dia)
        .where('mesNascimentoComprador2', '==', mes)
        .get(),
    ]);

    // Coleta nomes deduplicados por nome
    const nomes = new Set<string>();
    snap1.forEach((doc) => {
      const nome = doc.data().nomeComprador as string | undefined;
      if (nome) nomes.add(nome);
    });
    snap2.forEach((doc) => {
      const nome = doc.data().nomeComprador2 as string | undefined;
      if (nome) nomes.add(nome);
    });

    if (nomes.size === 0) {
      functions.logger.info('Nenhum aniversariante hoje — notificação não enviada');
      return null;
    }

    const lista = [...nomes].join(', ');
    const titulo = 'Villamor CRM — Aniversariantes';
    const corpo = nomes.size === 1
      ? `🎂 Aniversariante de hoje: ${lista}`
      : `🎂 Aniversariantes de hoje (${nomes.size}): ${lista}`;

    // Busca tokens apenas dos usuários com perfil pós-venda
    const snapUsuarios = await db.collection('usuarios')
      .where('perfil', '==', 'pós-venda')
      .where('ativo', '==', true)
      .get();

    const tokens: string[] = [];
    snapUsuarios.forEach((doc) => {
      const token = doc.data().fcmToken;
      if (token && typeof token === 'string') tokens.push(token);
    });

    if (tokens.length === 0) {
      functions.logger.info('Nenhum usuário pós-venda com token FCM ativo');
      return null;
    }

    await enviarParaTokens(tokens, titulo, corpo, { tipo: 'aniversario' });

    functions.logger.info(
      `Aniversariantes notificados: ${lista} → ${tokens.length} usuário(s) pós-venda`
    );
    return null;
  });

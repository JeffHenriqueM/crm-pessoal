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
 * - onNegociacaoAtualizada: notifica o embaixador quando o admin aprova/nega/pede atualização
 * - onCampanhaPublicada: notifica todos os usuários quando uma campanha é publicada
 */

import * as functions from 'firebase-functions';
import * as admin from 'firebase-admin';

admin.initializeApp();

const db = admin.firestore();
const messaging = admin.messaging();

// Códigos FCM que indicam token permanentemente inválido — sem retry, só limpeza
const FCM_ERROS_PERMANENTES = new Set([
  'messaging/registration-token-not-registered',
  'messaging/invalid-registration-token',
]);

// ── Helper: busca token FCM de um usuário ─────────────────────────────────────
async function getToken(userId: string): Promise<string | null> {
  const doc = await db.collection('usuarios').doc(userId).get();
  return doc.exists ? (doc.data()?.fcmToken ?? null) : null;
}

// ── Helper: busca todos os tokens FCM de usuários ativos ─────────────────────
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

// ── Helper: apaga fcmToken de um usuário pelo userId ─────────────────────────
async function limparTokenDoUsuario(userId: string): Promise<void> {
  await db.collection('usuarios').doc(userId).update({
    fcmToken: admin.firestore.FieldValue.delete(),
  });
  functions.logger.info(`fcmToken limpo para usuário ${userId}`);
}

// ── Helper: apaga fcmToken inválido buscando pelo valor do token ──────────────
async function limparTokenPorValor(token: string): Promise<void> {
  const snap = await db.collection('usuarios')
    .where('fcmToken', '==', token)
    .limit(1)
    .get();
  if (!snap.empty) {
    await snap.docs[0].ref.update({ fcmToken: admin.firestore.FieldValue.delete() });
    functions.logger.info(`fcmToken inválido removido: ${token.substring(0, 16)}…`);
  }
}

// ── Helper: envia notificação para um único token ────────────────────────────
// Erro permanente (token inválido/expirado): limpa fcmToken e absorve.
// Erro transitório (rede, FCM fora): re-lança para o runtime reprocessar o trigger.
async function enviarParaToken(
  userId: string,
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
  } catch (e: any) {
    const codigo: string = e?.errorInfo?.code ?? '';
    if (FCM_ERROS_PERMANENTES.has(codigo)) {
      functions.logger.warn(`Token FCM inválido para ${userId} (${codigo}) — limpando.`);
      await limparTokenDoUsuario(userId);
    } else {
      functions.logger.error(`Falha transitória ao enviar FCM para ${userId} — reprocessando.`, { erro: String(e) });
      throw e;
    }
  }
}

// ── Helper: envia para múltiplos tokens (broadcast) ─────────────────────────
// Tokens permanentemente inválidos: limpos do Firestore via limpezas em paralelo.
// Falhas transitórias por token individual: logadas (não relança — evita duplicatas
// em retry, pois tokens já entregues seriam renotificados).
// Falha catastrófica no batch inteiro: logada com severidade error, sem rethrow.
async function enviarParaTokens(
  tokens: string[],
  titulo: string,
  corpo: string,
  dados?: Record<string, string>
): Promise<void> {
  if (tokens.length === 0) return;

  const batches: string[][] = [];
  for (let i = 0; i < tokens.length; i += 500) {
    batches.push(tokens.slice(i, i + 500));
  }

  for (const batch of batches) {
    try {
      const resultado = await messaging.sendEachForMulticast({
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

      functions.logger.info(`Batch FCM: ${resultado.successCount} entregues, ${resultado.failureCount} falhas de ${batch.length}`);

      if (resultado.failureCount > 0) {
        const limpezas: Promise<void>[] = [];
        resultado.responses.forEach((resp, j) => {
          if (!resp.success) {
            const codigo = resp.error?.code ?? '';
            if (FCM_ERROS_PERMANENTES.has(codigo)) {
              limpezas.push(limparTokenPorValor(batch[j]));
            } else {
              functions.logger.warn(`Falha transitória no batch FCM [token ${j}]: ${codigo}`);
            }
          }
        });
        await Promise.all(limpezas);
      }
    } catch (e) {
      functions.logger.error(`Falha catastrófica no batch FCM — entregas podem ter falhado.`, { erro: String(e) });
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
      embaixadorId,
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

    functions.logger.info(`Campanha "${nome}" publicada — ${tokens.length} notificações disparadas`);
    return null;
  });

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
 * ⚠️ lembreteProximoContato usa Cloud Scheduler — habilite a API em:
 *    console.cloud.google.com > Cloud Scheduler API
 *
 * Funções implementadas:
 * - onNegociacaoAtualizada: notifica o embaixador quando o admin aprova/nega/pede atualização
 * - onCampanhaPublicada: notifica todos os usuários quando uma campanha é publicada
 * - onTicketAtualizado: notifica criador quando status muda; notifica novo atribuído
 * - onComentarioAdicionado: notifica criador e atribuído quando alguém comenta no ticket
 * - lembreteProximoContato: cron diário — lembrete de contatos do dia + mensagens atrasadas
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

// ── Helper: persiste notificação na subcoleção in-app do usuário ─────────────
async function gravarNotificacaoInApp(
  userId: string,
  tipo: string,
  titulo: string,
  corpo: string,
  extra?: Record<string, unknown>
): Promise<void> {
  await db.collection('notificacoes').doc(userId).collection('itens').add({
    tipo,
    titulo,
    corpo,
    lida: false,
    criadoEm: admin.firestore.FieldValue.serverTimestamp(),
    ...extra,
  });
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

// ── Função 3: Notifica criador/atribuído quando ticket é atualizado ───────────
export const onTicketAtualizado = functions
  .region('us-central1')
  .firestore
  .document('tickets/{ticketId}')
  .onUpdate(async (change, context) => {
    const antes = change.before.data();
    const depois = change.after.data();

    const titulo = depois.titulo as string ?? 'Ticket';
    const numero = depois.numero as number ?? 0;
    const label = numero > 0 ? `#${numero} ${titulo}` : `"${titulo}"`;

    const criadoPorId = depois.criadoPorId as string;
    const atribuidoDepois = depois.atribuidoParaId as string | undefined;
    const atribuidoAntes = antes.atribuidoParaId as string | undefined;

    const notificacoes: Promise<void>[] = [];

    // Status mudou → notifica criador do ticket
    if (antes.status !== depois.status) {
      const displayStatus: Record<string, string> = {
        aberto:               'Aberto',
        emAndamento:          'Em andamento',
        aguardandoValidacao:  'Aguardando Validação',
        resolvido:            'Resolvido',
        fechado:              'Fechado',
      };
      const statusNovo = displayStatus[depois.status as string] ?? depois.status;
      const notifTitulo = 'Villamor CRM — Ticket';
      const notifCorpo  = `Seu ticket ${label} agora está: ${statusNovo}.`;
      const token = await getToken(criadoPorId);
      if (token) {
        notificacoes.push(enviarParaToken(
          criadoPorId, token, notifTitulo, notifCorpo,
          { ticketId: context.params.ticketId, tipo: 'ticket_status' },
        ));
      }
      notificacoes.push(gravarNotificacaoInApp(
        criadoPorId, 'ticket_status', notifTitulo, notifCorpo,
        { ticketId: context.params.ticketId, ticketNumero: numero, ticketTitulo: titulo },
      ));
    }

    // Atribuição mudou para alguém novo → notifica o novo atribuído
    if (atribuidoDepois && atribuidoDepois !== atribuidoAntes) {
      // Não re-notifica o criador se ele mesmo for o atribuído (já recebeu o status acima)
      const mesmoQueCriador = atribuidoDepois === criadoPorId && antes.status === depois.status;
      if (!mesmoQueCriador) {
        const notifTitulo = 'Villamor CRM — Ticket Atribuído';
        const notifCorpo  = `O ticket ${label} foi atribuído a você.`;
        const token = await getToken(atribuidoDepois);
        if (token) {
          notificacoes.push(enviarParaToken(
            atribuidoDepois, token, notifTitulo, notifCorpo,
            { ticketId: context.params.ticketId, tipo: 'ticket_atribuido' },
          ));
        }
        notificacoes.push(gravarNotificacaoInApp(
          atribuidoDepois, 'ticket_atribuido', notifTitulo, notifCorpo,
          { ticketId: context.params.ticketId, ticketNumero: numero, ticketTitulo: titulo },
        ));
      }
    }

    await Promise.all(notificacoes);
    return null;
  });

// ── Função 4: Notifica criador/atribuído quando um comentário é adicionado ────
export const onComentarioAdicionado = functions
  .region('us-central1')
  .firestore
  .document('tickets/{ticketId}/comentarios/{comentarioId}')
  .onCreate(async (snap, context) => {
    const comentario = snap.data();
    const autorId   = comentario.autorId   as string;
    const autorNome = comentario.autorNome as string ?? 'Alguém';
    const texto     = (comentario.texto    as string ?? '').substring(0, 80);

    const ticketDoc = await db.collection('tickets').doc(context.params.ticketId).get();
    if (!ticketDoc.exists) return null;

    const ticket = ticketDoc.data()!;
    const titulo  = ticket.titulo   as string ?? 'Ticket';
    const numero  = ticket.numero   as number ?? 0;
    const label   = numero > 0 ? `#${numero}` : `"${titulo}"`;
    const criadoPorId     = ticket.criadoPorId     as string;
    const atribuidoParaId = ticket.atribuidoParaId as string | undefined;

    const notificacoes: Promise<void>[] = [];
    const notificados   = new Set<string>();

    if (criadoPorId && criadoPorId !== autorId) {
      notificados.add(criadoPorId);
      const notifTitulo = `Villamor CRM — Ticket ${label}`;
      const notifCorpo  = `${autorNome}: ${texto}`;
      const token = await getToken(criadoPorId);
      if (token) {
        notificacoes.push(enviarParaToken(
          criadoPorId, token, notifTitulo, notifCorpo,
          { ticketId: context.params.ticketId, tipo: 'ticket_comentario' },
        ));
      }
      notificacoes.push(gravarNotificacaoInApp(
        criadoPorId, 'ticket_comentario', notifTitulo, notifCorpo,
        { ticketId: context.params.ticketId, ticketNumero: numero, ticketTitulo: titulo },
      ));
    }

    if (atribuidoParaId && !notificados.has(atribuidoParaId) && atribuidoParaId !== autorId) {
      const notifTitulo = `Villamor CRM — Ticket ${label}`;
      const notifCorpo  = `${autorNome}: ${texto}`;
      const token = await getToken(atribuidoParaId);
      if (token) {
        notificacoes.push(enviarParaToken(
          atribuidoParaId, token, notifTitulo, notifCorpo,
          { ticketId: context.params.ticketId, tipo: 'ticket_comentario' },
        ));
      }
      notificacoes.push(gravarNotificacaoInApp(
        atribuidoParaId, 'ticket_comentario', notifTitulo, notifCorpo,
        { ticketId: context.params.ticketId, ticketNumero: numero, ticketTitulo: titulo },
      ));
    }

    await Promise.all(notificacoes);
    return null;
  });

// ── Função 5: Lembrete diário de próximos contatos e mensagens atrasadas ──────
// Dispara às 08:00 BRT (11:00 UTC). Requer Cloud Scheduler API habilitada.
export const lembreteProximoContato = functions
  .region('us-central1')
  .pubsub.schedule('0 11 * * *')
  .timeZone('America/Sao_Paulo')
  .onRun(async () => {
    const agora = new Date();
    const inicioDia = new Date(agora.getFullYear(), agora.getMonth(), agora.getDate());
    const fimDia    = new Date(agora.getFullYear(), agora.getMonth(), agora.getDate() + 1);

    const [hojeSnap, atrasadosSnap] = await Promise.all([
      // Contatos agendados para hoje
      db.collection('clientes')
        .where('proximoContato', '>=', admin.firestore.Timestamp.fromDate(inicioDia))
        .where('proximoContato', '<',  admin.firestore.Timestamp.fromDate(fimDia))
        .get(),
      // Contatos atrasados (proximoContato no passado e mensagem ainda não enviada)
      db.collection('clientes')
        .where('proximoContato', '<', admin.firestore.Timestamp.fromDate(inicioDia))
        .where('statusMensagem', '==', 'nao_enviada')
        .get(),
    ]);

    // Agrupa nomes por vendedorId, ignorando leads deletados
    const agrupar = (snap: admin.firestore.QuerySnapshot) => {
      const mapa = new Map<string, string[]>();
      snap.forEach((doc) => {
        if (doc.data().deletado === true) return;
        const vendedorId = doc.data().vendedorId as string | undefined;
        const nome = doc.data().nome as string ?? 'Lead';
        if (!vendedorId) return;
        const lista = mapa.get(vendedorId) ?? [];
        lista.push(nome);
        mapa.set(vendedorId, lista);
      });
      return mapa;
    };

    const hojeMap      = agrupar(hojeSnap);
    const atrasadosMap = agrupar(atrasadosSnap);

    const envios: Promise<void>[] = [];

    for (const [vendedorId, nomes] of hojeMap) {
      const token = await getToken(vendedorId);
      if (!token) continue;
      const corpo = nomes.length === 1
        ? `Hoje é o dia de contatar ${nomes[0]}.`
        : `Hoje você tem ${nomes.length} contatos agendados.`;
      envios.push(enviarParaToken(
        vendedorId, token,
        'Villamor CRM — Lembrete de Contato',
        corpo,
        { tipo: 'lembrete_contato' },
      ));
    }

    for (const [vendedorId, nomes] of atrasadosMap) {
      const token = await getToken(vendedorId);
      if (!token) continue;
      const corpo = nomes.length === 1
        ? `Mensagem atrasada para ${nomes[0]}.`
        : `Você tem ${nomes.length} mensagens atrasadas para enviar.`;
      envios.push(enviarParaToken(
        vendedorId, token,
        'Villamor CRM — Mensagens Atrasadas',
        corpo,
        { tipo: 'mensagem_atrasada' },
      ));
    }

    await Promise.all(envios);
    functions.logger.info(
      `Lembretes: ${hojeMap.size} vendedor(es) hoje, ${atrasadosMap.size} vendedor(es) atrasados`
    );
    return null;
  });

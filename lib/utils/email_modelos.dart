import 'package:flutter/material.dart';

import '../models/modelo_mensagem_model.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';

/// Resultado da escolha de um modelo de e-mail (variáveis já aplicadas).
class EscolhaEmail {
  final String assunto;
  final String corpo;
  const EscolhaEmail(this.assunto, this.corpo);
}

/// Pergunta se o usuário quer abrir o e-mail **com um modelo pronto** (padrão ou
/// individual) ou **em branco**.
///
/// Retorna:
/// - `EscolhaEmail('', '')` para "em branco";
/// - `EscolhaEmail(assunto, corpo)` com as variáveis já aplicadas;
/// - `null` se o usuário cancelar (toca fora / volta) — o chamador deve abortar.
Future<EscolhaEmail?> escolherModeloEmail(
  BuildContext context, {
  required String nome,
  String? esposa,
  String? responsavel,
  String? contrato,
  String? cota,
  String? valorAtrasado,
  String? saldo,
  String? dataLimite,
  FirestoreService? fs,
}) async {
  final servico = fs ?? FirestoreService();
  final uid = AuthService().getCurrentUser()?.uid;

  List<ModeloMensagem> todos = [];
  try {
    todos = await servico.getModelosMensagem();
  } catch (_) {/* segue sem modelos */}

  // Só modelos de e-mail: padrão (de todos) + individuais do usuário logado.
  final disponiveis = todos
      .where((m) =>
          m.isEmail && (m.padrao || (uid != null && m.criadoPorId == uid)))
      .toList()
    ..sort((a, b) {
      if (a.padrao != b.padrao) return a.padrao ? -1 : 1;
      return a.titulo.toLowerCase().compareTo(b.titulo.toLowerCase());
    });

  if (!context.mounted) return null;

  return showModalBottomSheet<EscolhaEmail>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (ctx) {
      final cs = Theme.of(ctx).colorScheme;
      return SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(ctx).size.height * 0.7,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(20, 4, 20, 8),
                child: Text('Enviar e-mail',
                    style:
                        TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              ),
              ListTile(
                leading: const Icon(Icons.mail_outline),
                title: const Text('Em branco'),
                subtitle: const Text('Abre o e-mail só com o destinatário'),
                onTap: () => Navigator.pop(ctx, const EscolhaEmail('', '')),
              ),
              const Divider(height: 1),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
                child: Text(
                  disponiveis.isEmpty
                      ? 'Nenhum modelo de e-mail cadastrado'
                      : 'Com modelo pronto',
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: cs.onSurfaceVariant),
                ),
              ),
              if (disponiveis.isEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                  child: Text(
                    'Crie modelos em Configurações → Modelos de mensagem '
                    '(canal E-mail).',
                    style: TextStyle(fontSize: 12, color: cs.outline),
                  ),
                )
              else
                Flexible(
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: disponiveis.length,
                    itemBuilder: (_, i) {
                      final m = disponiveis[i];
                      final assunto = aplicarVariaveisMensagem(
                        m.assunto ?? '',
                        nome: nome,
                        esposa: esposa,
                        responsavel: responsavel,
                        contrato: contrato,
                        cota: cota,
                        valorAtrasado: valorAtrasado,
                        saldo: saldo,
                        dataLimite: dataLimite,
                      );
                      final corpo = aplicarVariaveisMensagem(
                        m.texto,
                        nome: nome,
                        esposa: esposa,
                        responsavel: responsavel,
                        contrato: contrato,
                        cota: cota,
                        valorAtrasado: valorAtrasado,
                        saldo: saldo,
                        dataLimite: dataLimite,
                      );
                      return ListTile(
                        leading: Icon(
                          m.padrao ? Icons.public : Icons.person_outline,
                          color: cs.primary,
                          size: 20,
                        ),
                        title: Text(m.titulo),
                        subtitle: Text(
                          assunto.isEmpty ? corpo : 'Assunto: $assunto',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        onTap: () =>
                            Navigator.pop(ctx, EscolhaEmail(assunto, corpo)),
                      );
                    },
                  ),
                ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      );
    },
  );
}

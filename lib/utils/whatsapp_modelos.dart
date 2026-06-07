import 'package:flutter/material.dart';

import '../models/modelo_mensagem_model.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';

/// Resultado da escolha do usuário ao abrir o WhatsApp.
class EscolhaMensagem {
  /// Texto final (variáveis já aplicadas). Vazio = "sem mensagem".
  final String texto;
  const EscolhaMensagem(this.texto);
}

/// Pergunta se o usuário quer ir ao WhatsApp **com uma mensagem pronta**
/// (escolhendo um modelo padrão ou individual) ou **sem mensagem**.
///
/// Retorna:
/// - `EscolhaMensagem('')` para "sem mensagem";
/// - `EscolhaMensagem(texto)` com as variáveis já aplicadas;
/// - `null` se o usuário cancelar (toca fora / volta) — o chamador deve abortar.
Future<EscolhaMensagem?> escolherMensagemWhatsApp(
  BuildContext context, {
  required String nome,
  String? esposa,
  String? responsavel,
  FirestoreService? fs,
}) async {
  final servico = fs ?? FirestoreService();
  final uid = AuthService().getCurrentUser()?.uid;

  List<ModeloMensagem> todos = [];
  try {
    todos = await servico.getModelosMensagem();
  } catch (_) {/* segue sem modelos */}

  // Disponíveis: padrão (de todos) + individuais do usuário logado.
  final disponiveis = todos
      .where((m) => m.padrao || (uid != null && m.criadoPorId == uid))
      .toList()
    ..sort((a, b) {
      // padrão primeiro, depois alfabético por título
      if (a.padrao != b.padrao) return a.padrao ? -1 : 1;
      return a.titulo.toLowerCase().compareTo(b.titulo.toLowerCase());
    });

  if (!context.mounted) return null;

  return showModalBottomSheet<EscolhaMensagem>(
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
                child: Text('Ir para o WhatsApp',
                    style: TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 16)),
              ),
              ListTile(
                leading: const Icon(Icons.chat_outlined),
                title: const Text('Sem mensagem'),
                subtitle: const Text('Abre o WhatsApp em branco'),
                onTap: () => Navigator.pop(ctx, const EscolhaMensagem('')),
              ),
              const Divider(height: 1),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
                child: Text(
                  disponiveis.isEmpty
                      ? 'Nenhum modelo cadastrado'
                      : 'Com mensagem pronta',
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
                    'Crie modelos em Configurações → Modelos de mensagem.',
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
                      final texto = aplicarVariaveisMensagem(
                        m.texto,
                        nome: nome,
                        esposa: esposa,
                        responsavel: responsavel,
                      );
                      return ListTile(
                        leading: Icon(
                          m.padrao ? Icons.public : Icons.person_outline,
                          color: cs.primary,
                          size: 20,
                        ),
                        title: Text(m.titulo),
                        subtitle: Text(
                          texto,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        onTap: () =>
                            Navigator.pop(ctx, EscolhaMensagem(texto)),
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

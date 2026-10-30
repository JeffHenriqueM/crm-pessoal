import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:crm_pessoal/models/contrato_model.dart';
import 'package:crm_pessoal/widgets/botoes_contato_contrato.dart';

void main() {
  group('BotoesContatoContrato', () {
    testWidgets('exibe 3 botões (WhatsApp, E-mail e Enviar Ambos)',
        (tester) async {
      const c = Contrato(
        localizador: 'LOC1',
        localizadorAtendimento: 'ATD1',
        nomeComprador: 'João Silva',
        telefoneComprador: '79999999999',
        emailComprador: 'joao@email.com',
      );

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: BotoesContatoContrato(contrato: c),
          ),
        ),
      );

      expect(find.byType(IconButton), findsNWidgets(3));
      // Verifica tooltips
      expect(find.byTooltip('WhatsApp (79999999999)'), findsOneWidget);
      expect(find.byTooltip('E-mail (joao@email.com)'), findsOneWidget);
      expect(
          find.byTooltip('Enviar WhatsApp e E-mail juntos'), findsOneWidget);
    });

    testWidgets('desabilita botões correspondentes quando faltam contatos',
        (tester) async {
      const cSemTel = Contrato(
        localizador: 'LOC2',
        localizadorAtendimento: 'ATD2',
        nomeComprador: 'Maria Sem Tel',
        telefoneComprador: '',
        emailComprador: 'maria@email.com',
      );

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: BotoesContatoContrato(contrato: cSemTel),
          ),
        ),
      );

      final iconButtons =
          tester.widgetList<IconButton>(find.byType(IconButton)).toList();
      expect(iconButtons.length, 3);
      expect(iconButtons[0].onPressed, isNull); // WhatsApp desabilitado
      expect(iconButtons[1].onPressed, isNotNull); // E-mail habilitado
      expect(iconButtons[2].onPressed, isNull); // Ambos desabilitado
    });

    testWidgets('clicar em Enviar Ambos abre o diálogo unificado',
        (tester) async {
      const c = Contrato(
        localizador: 'LOC3',
        localizadorAtendimento: 'ATD3',
        nomeComprador: 'Carlos Oliveira',
        telefoneComprador: '79988888888',
        emailComprador: 'carlos@email.com',
      );

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: BotoesContatoContrato(contrato: c),
          ),
        ),
      );

      // Clica no botão de enviar ambos
      final botaoAmbos = find.byTooltip('Enviar WhatsApp e E-mail juntos');
      await tester.tap(botaoAmbos);
      await tester.pumpAndSettle();

      // Verifica elementos do diálogo
      expect(find.text('Enviar WhatsApp e E-mail juntos'), findsOneWidget);
      expect(find.text('WhatsApp'), findsOneWidget);
      expect(find.text('E-mail (Gmail)'), findsOneWidget);
      expect(find.text('Enviar WhatsApp + E-mail'), findsOneWidget);

      // Fecha diálogo
      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();
    });

    testWidgets('exibe indicador e alerta de reenvio quando contrato ja foi notificado',
        (tester) async {
      final notificado = DateTime.now().subtract(const Duration(hours: 2));
      final cNotificado = Contrato(
        localizador: 'LOC_NOTIF',
        localizadorAtendimento: 'ATD_NOTIF',
        nomeComprador: 'Ana Notificada',
        telefoneComprador: '79977777777',
        emailComprador: 'ana@email.com',
        notificadoEm: notificado,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: BotoesContatoContrato(contrato: cNotificado),
          ),
        ),
      );

      // Tooltip contém a data do último envio
      expect(
        find.byWidgetPredicate((w) =>
            w is IconButton &&
            (w.tooltip?.contains('Último envio') ?? false)),
        findsOneWidget,
      );

      // Ícone de check de notificado visível no Stack
      expect(find.byIcon(Icons.check), findsOneWidget);

      // Abre diálogo
      final botaoAmbos = find.byWidgetPredicate((w) =>
          w is IconButton &&
          (w.tooltip?.contains('Último envio') ?? false));
      await tester.tap(botaoAmbos);
      await tester.pumpAndSettle();

      // Alerta de reenvio deve estar presente
      expect(find.text('Atenção: Mensagem já enviada anteriormente!'),
          findsOneWidget);
      expect(
          find.text(
              'Confirmo que desejo reenviar a mensagem (já enviada nas últimas 24h).'),
          findsOneWidget);

      // Botão deve mostrar 'Reenviar' e estar inicialmente desabilitado por não ter marcado o checkbox
      final filledButton =
          tester.widget<FilledButton>(find.bySubtype<FilledButton>());
      expect(filledButton.onPressed, isNull);
      expect(find.text('Reenviar WhatsApp + E-mail'), findsOneWidget);

      // Marca o checkbox de confirmação
      final checkbox = find.byWidgetPredicate(
        (w) => w is Checkbox && w.activeColor == const Color(0xFF856404),
      );
      await tester.tap(checkbox);
      await tester.pumpAndSettle();

      // Agora o botão deve estar habilitado
      final filledButtonHabilitado =
          tester.widget<FilledButton>(find.bySubtype<FilledButton>());
      expect(filledButtonHabilitado.onPressed, isNotNull);

      // Fecha diálogo
      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();
    });
  });

  group('Alinhamento dos botões em Contratos', () {
    testWidgets(
        'botoes ficam alinhados à direita independentemente do tamanho do nome',
        (tester) async {
      tester.view.physicalSize = const Size(1024, 768);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      const cCurto = Contrato(
        localizador: 'LOC_A',
        localizadorAtendimento: 'ATD_A',
        nomeComprador: 'ANA',
        telefoneComprador: '11999999999',
        emailComprador: 'ana@email.com',
      );

      const cLongo = Contrato(
        localizador: 'LOC_B',
        localizadorAtendimento: 'ATD_B',
        nomeComprador:
            'FRANCISCO DE ASSIS MOREIRA DE MEDEIROS ALBUQUERQUE JUNIOR',
        telefoneComprador: '11988888888',
        emailComprador: 'francisco@email.com',
        valorAtrasado: 5000, // temAtrasos = true
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                _buildCardTest(cCurto),
                _buildCardTest(cLongo),
              ],
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Pega as posições dos dois grupos de botões
      final botoesFinder = find.byType(BotoesContatoContrato);
      expect(botoesFinder, findsNWidgets(2));

      final pos1 = tester.getTopRight(botoesFinder.at(0));
      final pos2 = tester.getTopRight(botoesFinder.at(1));

      // As coordenadas X da direita de ambos os botões devem ser exatamente iguais!
      expect(pos1.dx, equals(pos2.dx));
    });
  });
}

Widget _buildCardTest(Contrato c) {
  return Card(
    margin: const EdgeInsets.symmetric(vertical: 5, horizontal: 12),
    child: Padding(
      padding: const EdgeInsets.all(14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Row(
              children: [
                Flexible(
                  child: Text(
                    c.nomeComprador,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                    ),
                  ),
                ),
                if (c.temAtrasos) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    child: const Text('Em atraso'),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          BotoesContatoContrato(contrato: c, iconSize: 18),
        ],
      ),
    ),
  );
}

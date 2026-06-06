import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:crm_pessoal/models/cliente_model.dart';
import 'package:crm_pessoal/models/fase_enum.dart';

/// Guarda do mapeamento de fases legadas (importadas do NeuroCRM) em
/// `Cliente.fromFirestore`.
///
/// Auditoria de 2026-06-06 (docs/bigquery_calibracao.md §4) encontrou na base
/// de produção fases fora do enum caindo silenciosamente em `prospeccao` por
/// causa do `orElse: prospeccao`:
///   • 'fechamento' → 66 docs (vendas GANHAS, confirmado pelo usuário) virando
///     prospecção — subestima a conversão pela metade.
///   • 'sondagem'   → 2 docs (estágio inicial) — cair em prospecção é aceitável.
///
/// Comportamento CORRETO esperado (ainda não implementado → tag bug-aberto):
///   'fechamento' deve mapear para FaseCliente.fechado.
/// Ver ticket de correção do alias em fromFirestore + fallback logado.

void main() {
  late FakeFirebaseFirestore db;

  setUp(() => db = FakeFirebaseFirestore());

  Future<Cliente> lerCom(String fase) async {
    await db.collection('clientes').doc('x').set({
      'nome': 'Lead Legado',
      'tipo': 'pf',
      'fase': fase,
    });
    final doc = await db.collection('clientes').doc('x').get();
    return Cliente.fromFirestore(doc);
  }

  test(
    "'fechamento' (venda ganha legada) deve mapear para fechado",
    () async {
      final c = await lerCom('fechamento');
      expect(
        c.fase,
        FaseCliente.fechado,
        reason: 'Fase legada "fechamento" são vendas ganhas; cair em '
            'prospeccao subestima a conversão e tira 66 ganhos das métricas.',
      );
    },
    tags: 'bug-aberto',
  );

  test("fase válida do enum é preservada", () async {
    final c = await lerCom('negociacao');
    expect(c.fase, FaseCliente.negociacao);
  });

  test("'sondagem' (estágio inicial) cai em prospeccao — aceitável", () async {
    final c = await lerCom('sondagem');
    expect(c.fase, FaseCliente.prospeccao);
  });
}

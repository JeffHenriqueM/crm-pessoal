// lib/widgets/aba_verificacao_mp.dart
//
// Aba "Verificação" do módulo Hotel: roda a auditoria do calendário de rodízio
// e lista as inconsistências encontradas (duração, encaixe/sobreposição,
// semanas por ano). Só leitura.
import 'package:flutter/material.dart';

import '../models/auditoria_mp.dart';
import '../services/firestore_service.dart';

class AbaVerificacaoMP extends StatefulWidget {
  final FirestoreService? firestoreService;
  const AbaVerificacaoMP({super.key, this.firestoreService});

  @override
  State<AbaVerificacaoMP> createState() => _AbaVerificacaoMPState();
}

class _AbaVerificacaoMPState extends State<AbaVerificacaoMP> {
  late final FirestoreService _fs =
      widget.firestoreService ?? FirestoreService();
  bool _carregando = true;
  String? _erro;
  AuditoriaMP? _res;

  @override
  void initState() {
    super.initState();
    _rodar();
  }

  Future<void> _rodar() async {
    setState(() {
      _carregando = true;
      _erro = null;
    });
    try {
      final r = await _fs.auditarCalendarioMP();
      if (!mounted) return;
      setState(() {
        _res = r;
        _carregando = false;
      });
    } catch (e) {
      debugPrint('AbaVerificacaoMP._rodar: $e');
      if (!mounted) return;
      setState(() {
        _carregando = false;
        _erro = 'Não consegui rodar a verificação. Tente de novo.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(children: [
          Icon(Icons.fact_check_outlined, color: cs.primary),
          const SizedBox(width: 8),
          const Expanded(
            child: Text('Verificação do calendário',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ),
          IconButton(
            tooltip: 'Rodar de novo',
            onPressed: _carregando ? null : _rodar,
            icon: const Icon(Icons.refresh),
          ),
        ]),
        const SizedBox(height: 4),
        Text(
          'Procura inconsistências no rodízio: duração das semanas (devem ser '
          '7 dias, entra e sai no mesmo dia), semanas divididas por duas cotas '
          'e nº de semanas por ano (Ouro 4, Prata 2, Bronze 1).',
          style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13),
        ),
        const SizedBox(height: 6),
        Text(
          'Regra: uso começa em ${FirestoreService.anoInicioUsoMP}. '
          'Cotas reservadas ao hotel/manutenção: Ouro 13, Prata 26, Bronze 52.',
          style: TextStyle(
              color: cs.onSurfaceVariant,
              fontSize: 12,
              fontStyle: FontStyle.italic),
        ),
        const SizedBox(height: 16),
        if (_carregando)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 40),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (_erro != null)
          _aviso(cs, _erro!, cs.error, Icons.error_outline)
        else ...[
          _resumo(cs, _res!),
          const SizedBox(height: 12),
          if (_res!.tudoOk)
            _aviso(cs, 'Nenhuma inconsistência encontrada. ✅',
                const Color(0xFF16A34A), Icons.check_circle_outline)
          else
            for (final a in _res!.achados) _cardAchado(cs, a),
        ],
      ],
    );
  }

  Widget _resumo(ColorScheme cs, AuditoriaMP r) {
    final cor = r.tudoOk ? const Color(0xFF16A34A) : const Color(0xFFD97706);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cor.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cor.withValues(alpha: 0.4)),
      ),
      child: Row(children: [
        Icon(r.tudoOk ? Icons.verified_outlined : Icons.report_outlined,
            color: cor),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            '${r.totalSemanas} semanas verificadas · '
            '${r.achados.length} ${r.achados.length == 1 ? 'achado' : 'achados'}.',
            style: TextStyle(fontSize: 13, color: cs.onSurface),
          ),
        ),
      ]),
    );
  }

  Widget _cardAchado(ColorScheme cs, AchadoAuditoria a) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFD97706).withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: const Color(0xFFD97706).withValues(alpha: 0.16),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(a.categoria,
                  style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFFB45309))),
            ),
            const SizedBox(width: 8),
            Text(a.chave,
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: cs.onSurfaceVariant)),
          ]),
          const SizedBox(height: 6),
          Text(a.descricao, style: const TextStyle(fontSize: 13)),
        ],
      ),
    );
  }

  Widget _aviso(ColorScheme cs, String msg, Color cor, IconData icone) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cor.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cor.withValues(alpha: 0.4)),
      ),
      child: Row(children: [
        Icon(icone, color: cor),
        const SizedBox(width: 10),
        Expanded(child: Text(msg, style: const TextStyle(fontSize: 14))),
      ]),
    );
  }
}

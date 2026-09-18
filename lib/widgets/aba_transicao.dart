import 'package:flutter/material.dart';

import '../services/analise_imoveis.dart';
import '../services/firestore_service.dart';

/// Aba "Transição" (exclusiva do super admin): projeta a futura migração dos
/// contratos do resort para o novo Hotel Villamor.
///
/// Primeira entrega: contar quantos apartamentos estão vendidos por linha de
/// produto — LUXO (blocos A/B/D/E) × VILLAMOR (bloco C) — para dimensionar a
/// transição. Dados carregados sob demanda (não lê o Firestore ao abrir).
class AbaTransicao extends StatefulWidget {
  const AbaTransicao({super.key});

  @override
  State<AbaTransicao> createState() => _AbaTransicaoState();
}

class _LinhaStats {
  int totalUnidades = 0;
  int unidadesVendidas = 0; // com ao menos 1 cota vendida
  int esgotadas = 0;
  int parciais = 0;
  int cotasVendidas = 0;
}

class _AbaTransicaoState extends State<AbaTransicao> {
  final _fs = FirestoreService();
  bool _carregando = false;
  bool _carregado = false;
  Map<String, _LinhaStats> _stats = {};

  Future<void> _carregar() async {
    setState(() => _carregando = true);
    try {
      final imoveis = await _fs.getImoveis();
      final contratos = contratosEfetivos(await _fs.getContratos());
      final resumo = analisarEmpreendimento(imoveis, contratos);

      final map = <String, _LinhaStats>{};
      for (final a in resumo.imoveis) {
        final linha = linhaProduto(a.imovel.tipo);
        final s = map.putIfAbsent(linha, () => _LinhaStats());
        s.totalUnidades++;
        s.cotasVendidas += a.cotasVendidas;
        if (a.situacao != SituacaoImovel.indefinido) {
          s.unidadesVendidas++;
          if (a.situacao == SituacaoImovel.esgotado) {
            s.esgotadas++;
          } else {
            s.parciais++;
          }
        }
      }
      if (!mounted) return;
      setState(() {
        _stats = map;
        _carregado = true;
        _carregando = false;
      });
    } catch (e) {
      debugPrint('AbaTransicao._carregar: $e');
      if (!mounted) return;
      setState(() => _carregando = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Erro ao carregar a transição.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    if (_carregando) {
      return const Center(child: CircularProgressIndicator());
    }
    if (!_carregado) {
      return _prompt(cs);
    }

    final luxo = _stats['LUXO'] ?? _LinhaStats();
    final villamor = _stats['VILLAMOR'] ?? _LinhaStats();
    final bangalo = _stats['BANGALÔ'];

    return RefreshIndicator(
      onRefresh: _carregar,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _cabecalho(cs),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: _cardLinha(cs, 'LUXO', luxo, cs.primary)),
              const SizedBox(width: 12),
              Expanded(
                  child: _cardLinha(
                      cs, 'VILLAMOR', villamor, Colors.teal.shade700)),
            ],
          ),
          if (bangalo != null) ...[
            const SizedBox(height: 12),
            _cardLinha(cs, 'BANGALÔ', bangalo, Colors.brown.shade600),
          ],
          const SizedBox(height: 16),
          _rodape(cs),
        ],
      ),
    );
  }

  Widget _cabecalho(ColorScheme cs) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.swap_horiz_rounded, color: cs.primary),
            const SizedBox(width: 8),
            const Text('Transição para o Hotel Villamor',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          'Projeção da migração dos contratos do resort para o novo hotel. '
          'Comece pelos apartamentos vendidos em cada linha de produto.',
          style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant),
        ),
      ],
    );
  }

  Widget _cardLinha(
      ColorScheme cs, String titulo, _LinhaStats s, Color cor) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cor.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: cor.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(titulo,
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: cor,
                  letterSpacing: 0.5)),
          const SizedBox(height: 8),
          Text('${s.unidadesVendidas}',
              style: TextStyle(
                  fontSize: 40, fontWeight: FontWeight.bold, color: cor)),
          Text('apartamentos vendidos',
              style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
          const Divider(height: 20),
          _linhaInfo('Totalmente vendidos', '${s.esgotadas}', cs),
          _linhaInfo('Parcialmente vendidos', '${s.parciais}', cs),
          _linhaInfo('Cotas vendidas', '${s.cotasVendidas}', cs),
          _linhaInfo('Unidades no bloco', '${s.totalUnidades}', cs),
        ],
      ),
    );
  }

  Widget _linhaInfo(String label, String valor, ColorScheme cs) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
          Text(valor,
              style:
                  const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _rodape(ColorScheme cs) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        '"Vendido" = apartamento com ao menos 1 cota vendida (contrato ativo). '
        'LUXO reúne os blocos A, B, D e E; VILLAMOR é o bloco C.',
        style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant),
      ),
    );
  }

  Widget _prompt(ColorScheme cs) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.swap_horiz_rounded, size: 48, color: cs.primary),
            const SizedBox(height: 12),
            const Text('Transição para o Hotel Villamor',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text(
              'Carregue os dados para ver quantos apartamentos LUXO e VILLAMOR '
              'estão vendidos.',
              style: TextStyle(color: cs.onSurfaceVariant),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: _carregar,
              icon: const Icon(Icons.download_outlined),
              label: const Text('Carregar'),
            ),
          ],
        ),
      ),
    );
  }
}

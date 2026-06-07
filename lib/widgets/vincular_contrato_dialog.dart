import 'package:flutter/material.dart';

import '../models/contrato_model.dart';
import '../services/firestore_service.dart';
import '../utils/match_contrato.dart';

/// Diálogo que ajuda a vincular um lead recém-fechado ao seu contrato.
/// Mostra sugestões (auto-match por telefone/nome) e permite busca manual.
/// Retorna o [Contrato] escolhido, ou `null` se cancelado.
class VincularContratoDialog extends StatefulWidget {
  final String nome;
  final String telefone;
  final FirestoreService? fs;

  const VincularContratoDialog({
    super.key,
    required this.nome,
    required this.telefone,
    this.fs,
  });

  /// Abre o diálogo e retorna o contrato escolhido (ou null).
  static Future<Contrato?> mostrar(
    BuildContext context, {
    required String nome,
    required String telefone,
    FirestoreService? fs,
  }) {
    return showDialog<Contrato>(
      context: context,
      builder: (_) =>
          VincularContratoDialog(nome: nome, telefone: telefone, fs: fs),
    );
  }

  @override
  State<VincularContratoDialog> createState() => _VincularContratoDialogState();
}

class _VincularContratoDialogState extends State<VincularContratoDialog> {
  final _busca = TextEditingController();
  String _filtro = '';
  List<Contrato> _contratos = [];
  bool _carregando = true;

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  Future<void> _carregar() async {
    final fs = widget.fs ?? FirestoreService();
    final cs = await fs.getContratos();
    if (mounted) {
      setState(() {
        _contratos = cs;
        _carregando = false;
      });
    }
  }

  @override
  void dispose() {
    _busca.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final sugestoes = sugerirContratos(
      nome: widget.nome,
      telefone: widget.telefone,
      contratos: _contratos,
    );

    List<Contrato> manuais = const [];
    if (_filtro.length >= 2) {
      final f = normalizarNome(_filtro);
      final fTel = normalizarTelefone(_filtro);
      manuais = _contratos.where((c) {
        final nomeOk = normalizarNome(c.nomeComprador).contains(f) ||
            normalizarNome(c.nomeComprador2).contains(f);
        final telOk = fTel.length >= 4 &&
            (normalizarTelefone(c.telefoneComprador).contains(fTel) ||
                normalizarTelefone(c.telefoneComprador2).contains(fTel));
        return nomeOk || telOk;
      }).take(20).toList();
    }

    return AlertDialog(
      title: Text('Vincular "${widget.nome}" a um contrato'),
      content: SizedBox(
        width: 440,
        child: _carregando
            ? const SizedBox(
                height: 120,
                child: Center(child: CircularProgressIndicator()),
              )
            : Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (sugestoes.isNotEmpty && _filtro.isEmpty) ...[
                    const Text('Sugestões',
                        style: TextStyle(
                            fontWeight: FontWeight.w600, fontSize: 13)),
                    const SizedBox(height: 4),
                    for (final s in sugestoes)
                      _tile(s.contrato, motivo: s.motivo),
                    const Divider(),
                  ],
                  TextField(
                    controller: _busca,
                    autofocus: sugestoes.isEmpty,
                    decoration: const InputDecoration(
                      isDense: true,
                      prefixIcon: Icon(Icons.search),
                      hintText: 'Buscar contrato por nome ou telefone…',
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (v) => setState(() => _filtro = v.trim()),
                  ),
                  const SizedBox(height: 8),
                  Flexible(
                    child: SingleChildScrollView(
                      child: Column(
                        children: [
                          if (_filtro.length >= 2 && manuais.isEmpty)
                            const Padding(
                              padding: EdgeInsets.all(8),
                              child: Text('Nenhum contrato encontrado.'),
                            ),
                          for (final c in manuais) _tile(c),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Agora não'),
        ),
      ],
    );
  }

  Widget _tile(Contrato c, {String? motivo}) {
    return ListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      leading: const Icon(Icons.description_outlined),
      title: Text(c.nomeComprador),
      subtitle: Text([
        c.localizador,
        if (c.telefoneComprador.isNotEmpty) c.telefoneComprador,
        if (motivo != null) '· $motivo',
      ].join(' · ')),
      onTap: () => Navigator.pop(context, c),
    );
  }
}

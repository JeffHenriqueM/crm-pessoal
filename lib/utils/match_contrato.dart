import '../models/contrato_model.dart';

/// Normaliza um telefone para apenas dígitos, sem o código do país (55) nem
/// zeros à esquerda. Usado no auto-match com contratos.
String normalizarTelefone(String? tel) {
  var d = (tel ?? '').replaceAll(RegExp(r'\D'), '');
  if (d.length > 11 && d.startsWith('55')) d = d.substring(2);
  while (d.startsWith('0')) {
    d = d.substring(1);
  }
  return d;
}

/// True se [tel] tem dígitos suficientes para ser um telefone brasileiro
/// válido (DDD + 8/9 dígitos = 10 ou 11 dígitos após normalização).
bool telefoneValido(String? tel) {
  final d = normalizarTelefone(tel);
  return d.length == 10 || d.length == 11;
}

/// Normaliza um nome para comparação: minúsculas, sem acentos, sem "*" e com
/// espaços colapsados.
String normalizarNome(String? nome) {
  var s = (nome ?? '').toLowerCase().trim();
  const acentos = {
    'á': 'a', 'à': 'a', 'ã': 'a', 'â': 'a', 'ä': 'a',
    'é': 'e', 'ê': 'e', 'è': 'e', 'ë': 'e',
    'í': 'i', 'î': 'i', 'ì': 'i', 'ï': 'i',
    'ó': 'o', 'ô': 'o', 'õ': 'o', 'ò': 'o', 'ö': 'o',
    'ú': 'u', 'û': 'u', 'ù': 'u', 'ü': 'u',
    'ç': 'c', 'ñ': 'n',
  };
  acentos.forEach((k, v) => s = s.replaceAll(k, v));
  s = s.replaceAll(RegExp(r'[^a-z0-9 ]'), ' ');
  return s.replaceAll(RegExp(r'\s+'), ' ').trim();
}

/// Sugestão (pontuada) de um contrato candidato. Quanto maior o [score], mais
/// forte o match.
class SugestaoContrato {
  final Contrato contrato;
  final int score;
  final String motivo;
  const SugestaoContrato(this.contrato, this.score, this.motivo);
}

/// Procura contratos que possam corresponder a uma pessoa identificada por
/// [nome] e [telefone], casando por telefone (mais forte) e por nome. Retorna
/// ordenado por score desc, limitado a [limite]. Lógica pura, testável.
List<SugestaoContrato> sugerirContratos({
  required String nome,
  required String telefone,
  required List<Contrato> contratos,
  int limite = 8,
}) {
  final telAlvo = normalizarTelefone(telefone);
  final nomeAlvo = normalizarNome(nome);
  final tokensAlvo = nomeAlvo.split(' ').where((t) => t.length >= 3).toSet();

  bool telCasa(String a, String b) {
    if (a.length < 8 || b.length < 8) return false;
    return a.substring(a.length - 8) == b.substring(b.length - 8);
  }

  final out = <SugestaoContrato>[];
  for (final c in contratos) {
    int score = 0;
    String motivo = '';

    final tels = [c.telefoneComprador, c.telefoneComprador2 ?? '']
        .map(normalizarTelefone)
        .where((t) => t.isNotEmpty);
    if (telAlvo.isNotEmpty && tels.any((t) => telCasa(t, telAlvo))) {
      score += 100;
      motivo = 'Telefone igual';
    }

    final nomes = [
      normalizarNome(c.nomeComprador),
      normalizarNome(c.nomeComprador2),
    ];
    for (final n in nomes) {
      if (n.isEmpty) continue;
      if (n == nomeAlvo) {
        score += 80;
        motivo = motivo.isEmpty ? 'Nome igual' : motivo;
        break;
      }
      if (nomeAlvo.isNotEmpty && (n.contains(nomeAlvo) || nomeAlvo.contains(n))) {
        score += 50;
        motivo = motivo.isEmpty ? 'Nome parecido' : motivo;
        break;
      }
      final tokensC = n.split(' ').where((t) => t.length >= 3).toSet();
      if (tokensC.intersection(tokensAlvo).length >= 2) {
        score += 30;
        motivo = motivo.isEmpty ? 'Nome parcial' : motivo;
        break;
      }
    }

    if (score > 0) out.add(SugestaoContrato(c, score, motivo));
  }

  out.sort((a, b) => b.score.compareTo(a.score));
  return out.take(limite).toList();
}

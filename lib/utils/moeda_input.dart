// lib/utils/moeda_input.dart
//
// Máscara de moeda (pt_BR) para campos de valor e parsing robusto (#51).
// A máscara trabalha em centavos: o usuário digita apenas dígitos e o campo
// formata da direita para a esquerda como "1.234,56".
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

final NumberFormat _fmtMoedaBR = NumberFormat('#,##0.00', 'pt_BR');

/// Formata um valor `double` no padrão brasileiro com separador de milhar e
/// duas casas decimais: `1234.5` → `"1.234,50"`.
String formatMoeda(double valor) => _fmtMoedaBR.format(valor);

/// Converte uma string de valor para `double`, aceitando tanto o formato
/// mascarado brasileiro (`"1.234,56"`) quanto entradas simples (`"1234.56"`,
/// `"1234,56"`, `"1234"`).
///
/// Regra: se houver vírgula, ela é o separador decimal e os pontos são
/// milhares. Sem vírgula, o ponto (se houver) é tratado como decimal —
/// preservando o comportamento legado de campos sem máscara.
double parseMoeda(String s) {
  if (s.trim().isEmpty) return 0;
  var t = s.replaceAll(RegExp(r'[^\d.,-]'), '');
  if (t.contains(',')) {
    t = t.replaceAll('.', '').replaceAll(',', '.');
  }
  return double.tryParse(t) ?? 0;
}

/// Input formatter de moeda em centavos. Mantém apenas dígitos e reformata
/// o texto inteiro a cada digitação, posicionando o cursor no fim.
class MoedaInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digitos = newValue.text.replaceAll(RegExp(r'[^\d]'), '');
    if (digitos.isEmpty) {
      return const TextEditingValue(text: '');
    }
    // Limita para evitar overflow em entradas absurdas.
    final centavos = int.tryParse(digitos) ?? 0;
    final texto = formatMoeda(centavos / 100);
    return TextEditingValue(
      text: texto,
      selection: TextSelection.collapsed(offset: texto.length),
    );
  }
}

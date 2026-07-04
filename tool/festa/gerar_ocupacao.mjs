// tool/festa/gerar_ocupacao.mjs
//
// Gera lib/models/festa_ocupacao_gerado.dart a partir da lista do café do
// Hospedin (tool/festa/cafe_hospedin.json). Ocupação-base = SÓ o nome do
// hóspede por quarto; tier/%/ação vêm depois, ao vivo, quando o gestor associa
// o quarto a um contrato na tela (ocupacaoEfetiva). Sem Firestore, sem matching.
//
// Uso:  node tool/festa/gerar_ocupacao.mjs
//
// Regras:
//  • emite APENAS quartos que existem no mapa físico (quarto_festa_socios.dart);
//    quartos do café fora do mapa (ex.: 301) são OMITIDOS e listados no resumo;
//  • quartos do mapa físico ausentes no café ficam VAGOS (listados no resumo).
import { readFileSync, writeFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { dirname, join } from 'node:path';

const __dirname = dirname(fileURLToPath(import.meta.url));
const raiz = join(__dirname, '..', '..');

const DATA_CAFE = '21/07/2026';
const entrada = JSON.parse(
  readFileSync(join(__dirname, 'cafe_hospedin.json'), 'utf8'),
);
const cafe = entrada.quartos;

// Números dos quartos do mapa físico, extraídos direto do fonte Dart para não
// duplicar o dado (QuartoFestaSocios('NN', ...)).
const fonteMapa = readFileSync(
  join(raiz, 'lib', 'models', 'quarto_festa_socios.dart'),
  'utf8',
);
const fisico = new Set(
  [...fonteMapa.matchAll(/QuartoFestaSocios\('(\w+)'/g)].map((m) => m[1]),
);

const emitidos = [];
const foraDoMapa = []; // no café, mas não existe no mapa físico → omitido
const vistos = new Set();
for (const { quarto, nome } of cafe) {
  if (!fisico.has(quarto)) {
    foraDoMapa.push(quarto);
    continue;
  }
  emitidos.push({ quarto, nome });
  vistos.add(quarto);
}

// Quartos do mapa físico que não aparecem no café → ficam vagos.
const vagos = [...fisico].filter((q) => !vistos.has(q));

const esc = (s) => s.replace(/\\/g, '\\\\').replace(/'/g, "\\'");
const linhas = emitidos
  .map(
    ({ quarto, nome }) =>
      `  '${esc(quarto)}': OcupacaoQuarto(ocupante: '${esc(nome)}', tier: null, ` +
      `pct: null, atrasado: false, acao: 'semContrato', recomendada: null, ` +
      `confianca: 'sem', flags: []),`,
  )
  .join('\n');

const saida = `// GERADO AUTOMATICAMENTE — não editar à mão.
// Fonte: tool/festa/gerar_ocupacao.mjs a partir de tool/festa/cafe_hospedin.json
// Ocupação da Festa dos Sócios: lista do café do Hospedin (${DATA_CAFE}).
// Base = só o nome do hóspede por quarto; tier/%/ação (sobe|desce|mantem) vêm da
// associação manual do contrato na tela (ocupacaoEfetiva). acao inicial:
// 'semContrato' até o gestor associar.
class OcupacaoQuarto {
  final String ocupante;
  final String? tier;
  final int? pct;
  final bool atrasado;
  final String acao;
  final String? recomendada;
  final String confianca; // ok | fuzzy | sem
  final List<String> flags;
  const OcupacaoQuarto({required this.ocupante, this.tier, this.pct, required this.atrasado, required this.acao, this.recomendada, required this.confianca, this.flags = const []});
  bool get deveTrocar => acao == 'sobe' || acao == 'desce';
}

const Map<String, OcupacaoQuarto> ocupacaoFesta = {
${linhas}
};
`;

const destino = join(raiz, 'lib', 'models', 'festa_ocupacao_gerado.dart');
writeFileSync(destino, saida);

console.log('✅ Gerado: lib/models/festa_ocupacao_gerado.dart');
console.log(`   Café (${DATA_CAFE}): ${cafe.length} quartos`);
console.log(`   Emitidos (no mapa físico): ${emitidos.length}`);
console.log(
  `   Omitidos (no café, fora do mapa): ${foraDoMapa.length ? foraDoMapa.join(', ') : '—'}`,
);
console.log(
  `   Vagos (no mapa, ausentes no café): ${vagos.length ? vagos.sort((a, b) => (+a || 0) - (+b || 0)).join(', ') : '—'}`,
);

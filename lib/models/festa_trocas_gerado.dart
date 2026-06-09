// GERADO AUTOMATICAMENTE — não editar à mão.
// Realocação da Festa dos Sócios: trocas executadas (ANTIGA → NOVA),
// lista de quem ficou sem quarto (<10% integralizado) e overflow (sem vaga).
class TrocaQuarto {
  final String antiga, nova, ocupante, de, para, tier;
  final int pct;
  final bool transbordo;
  const TrocaQuarto({required this.antiga, required this.nova, required this.ocupante, required this.de, required this.para, required this.tier, required this.pct, this.transbordo = false});
}

class SemQuartoFesta {
  final String quartoAntigo, ocupante, tier;
  final int pct;
  final String? categoriaAlvo; // preenchido quando é overflow (sem vaga)
  const SemQuartoFesta({required this.quartoAntigo, required this.ocupante, required this.tier, required this.pct, this.categoriaAlvo});
}

const List<TrocaQuarto> trocasFesta = [
  TrocaQuarto(antiga: '148', nova: '51', ocupante: '*DANILO DOS SANTOS CA...', de: 'Comfort', para: 'Luxo', tier: 'bronze', pct: 23, transbordo: false),
  TrocaQuarto(antiga: '155', nova: '55', ocupante: '*CLAUDIO DANIEL ALBERTI', de: 'Comfort', para: 'Luxo', tier: 'bronze', pct: 23, transbordo: false),
  TrocaQuarto(antiga: '202', nova: '58', ocupante: '*GIULIANO MARCELO VARIS', de: 'Master', para: 'Luxo', tier: 'bronze', pct: 22, transbordo: false),
  TrocaQuarto(antiga: '147', nova: '71', ocupante: '*JOSE ADINAN ORTOLAN', de: 'Comfort', para: 'Estúdio', tier: 'bronze', pct: 20, transbordo: true),
  TrocaQuarto(antiga: '138', nova: '72', ocupante: '*MARCIO RODRIGUES CER...', de: 'Comfort', para: 'Estúdio', tier: 'bronze', pct: 16, transbordo: true),
  TrocaQuarto(antiga: '170', nova: '102', ocupante: '*Lenise Vargas Flores...', de: 'Comfort', para: 'Luxo', tier: 'prata', pct: 18, transbordo: false),
  TrocaQuarto(antiga: '105', nova: '104', ocupante: '*Sergio Henrique More...', de: 'Triplo', para: 'Luxo', tier: 'prata', pct: 15, transbordo: false),
  TrocaQuarto(antiga: '160', nova: '105', ocupante: '*NILSON LUZ CANGUSSU', de: 'Comfort', para: 'Triplo', tier: 'bronze', pct: 13, transbordo: true),
  TrocaQuarto(antiga: '137', nova: '108', ocupante: '*SILVIO GABRIEL FREIRE', de: 'Comfort', para: 'Luxo', tier: 'prata', pct: 15, transbordo: false),
  TrocaQuarto(antiga: '156', nova: '109', ocupante: '*José Virgílio Lima', de: 'Comfort', para: 'Luxo', tier: 'prata', pct: 15, transbordo: false),
  TrocaQuarto(antiga: '167', nova: '110', ocupante: '*GUTEMBERGUE DANTAS', de: 'Comfort', para: 'Luxo', tier: 'prata', pct: 13, transbordo: false),
  TrocaQuarto(antiga: '146', nova: '111', ocupante: '*SERGIO OLIVEIRA', de: 'Comfort', para: 'Luxo', tier: 'prata', pct: 10, transbordo: false),
  TrocaQuarto(antiga: '133', nova: '115', ocupante: '*Paulo Porto de Carva...', de: 'Comfort', para: 'Luxo', tier: 'prata', pct: 9, transbordo: false),
  TrocaQuarto(antiga: '142', nova: '116', ocupante: '*ARTHUR CESAR TAVARES', de: 'Comfort', para: 'Luxo', tier: 'bronze', pct: 50, transbordo: false),
  TrocaQuarto(antiga: '201', nova: '117', ocupante: '*DOUGLAS ORTIZ', de: 'Master', para: 'Luxo', tier: 'bronze', pct: 25, transbordo: false),
  TrocaQuarto(antiga: '110', nova: '126', ocupante: '*Djeane do Socorro Si...', de: 'Luxo', para: 'Comfort', tier: 'ouro', pct: 49, transbordo: false),
  TrocaQuarto(antiga: '151', nova: '131', ocupante: '*Victor Sbisa Bremer', de: 'Suíte Duplex', para: 'Comfort', tier: 'ouro', pct: 15, transbordo: false),
  TrocaQuarto(antiga: '208', nova: '133', ocupante: '*Karoline Fernandes S...', de: 'Master', para: 'Comfort', tier: 'ouro', pct: 14, transbordo: false),
  TrocaQuarto(antiga: '109', nova: '137', ocupante: '*RITA SIBELLY CAETANO...', de: 'Luxo', para: 'Comfort', tier: 'ouro', pct: 10, transbordo: false),
  TrocaQuarto(antiga: '71', nova: '138', ocupante: '*DÉCIO DE SOUZA FELIX', de: 'Estúdio', para: 'Comfort', tier: 'prata', pct: 100, transbordo: false),
  TrocaQuarto(antiga: '108', nova: '142', ocupante: '*Ronaldo Fernandes', de: 'Luxo', para: 'Comfort', tier: 'prata', pct: 47, transbordo: false),
  TrocaQuarto(antiga: '51', nova: '144', ocupante: '*LUCIANO ALASMAR', de: 'Luxo', para: 'Suíte Duplex', tier: 'integral', pct: 62, transbordo: true),
  TrocaQuarto(antiga: '115', nova: '146', ocupante: '*JULIO CESAR FONSECA', de: 'Luxo', para: 'Comfort', tier: 'prata', pct: 41, transbordo: false),
  TrocaQuarto(antiga: '205', nova: '147', ocupante: '*DILSON KOSSOSKI', de: 'Master', para: 'Comfort', tier: 'prata', pct: 35, transbordo: false),
  TrocaQuarto(antiga: '207', nova: '148', ocupante: '*RENATO NEWTON RAMLOW', de: 'Master', para: 'Comfort', tier: 'prata', pct: 32, transbordo: false),
  TrocaQuarto(antiga: '111', nova: '149', ocupante: '*SECUNDINO DOS SANTOS...', de: 'Luxo', para: 'Comfort', tier: 'prata', pct: 28, transbordo: false),
  TrocaQuarto(antiga: '117', nova: '155', ocupante: '*Juan Kempen', de: 'Luxo', para: 'Comfort', tier: 'prata', pct: 28, transbordo: false),
  TrocaQuarto(antiga: '72', nova: '156', ocupante: '*ELAINE DURVAL SILVA...', de: 'Estúdio', para: 'Comfort', tier: 'prata', pct: 26, transbordo: false),
  TrocaQuarto(antiga: '58', nova: '160', ocupante: '*Alexandre Rocha Duarte', de: 'Luxo', para: 'Comfort', tier: 'prata', pct: 24, transbordo: false),
  TrocaQuarto(antiga: '144', nova: '164', ocupante: '*GLEICY KELLY MARQUE...', de: 'Suíte Duplex', para: 'Comfort', tier: 'prata', pct: 23, transbordo: false),
  TrocaQuarto(antiga: '104', nova: '167', ocupante: '*MARINALDO DA SILVA D...', de: 'Luxo', para: 'Comfort', tier: 'prata', pct: 21, transbordo: false),
  TrocaQuarto(antiga: '102', nova: '170', ocupante: '*HIROSHI SUGIYA', de: 'Luxo', para: 'Comfort', tier: 'bronze', pct: 100, transbordo: false),
];

const List<SemQuartoFesta> semQuartoFesta = [
  SemQuartoFesta(quartoAntigo: '203', ocupante: '*ADILSON AFONSO TAVARES', tier: 'ouro', pct: 0),
  SemQuartoFesta(quartoAntigo: '204', ocupante: '*ADILSON AFONSO TAVARES', tier: 'ouro', pct: 0),
  SemQuartoFesta(quartoAntigo: '131', ocupante: '*HARLEY MENEZES MORAE...', tier: 'ouro', pct: 0),
  SemQuartoFesta(quartoAntigo: '149', ocupante: '*Renato Cosmo Garcia', tier: 'ouro', pct: 0),
  SemQuartoFesta(quartoAntigo: '164', ocupante: '*EUDES DOS SANTOS MENDES', tier: 'ouro', pct: 8),
  SemQuartoFesta(quartoAntigo: '116', ocupante: '*GRAZIELE KELLY DA SI...', tier: 'prata', pct: 8),
  SemQuartoFesta(quartoAntigo: '126', ocupante: '*MARCOS LUIZ RIBEIRO', tier: 'prata', pct: 5),
  SemQuartoFesta(quartoAntigo: '55', ocupante: '*CRISTINA DE ARRUDA C...', tier: 'prata', pct: 0),
  SemQuartoFesta(quartoAntigo: '210', ocupante: '*FABIO PEREIRA DA SILVA', tier: 'bronze', pct: 5),
];

const List<SemQuartoFesta> overflowFesta = [

];

// GERADO AUTOMATICAMENTE — não editar à mão.
// Fonte: tool/festa/gerar_ocupacao.mjs a partir de tool/festa/cafe_hospedin.json
// Ocupação da Festa dos Sócios: lista do café do Hospedin (21/07/2026).
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
  '105': OcupacaoQuarto(ocupante: '*Sergio Henrique More...', tier: null, pct: null, atrasado: false, acao: 'semContrato', recomendada: null, confianca: 'sem', flags: []),
  '101': OcupacaoQuarto(ocupante: 'Cassio Coutinho de O...', tier: null, pct: null, atrasado: false, acao: 'semContrato', recomendada: null, confianca: 'sem', flags: []),
  '102': OcupacaoQuarto(ocupante: '*Vinicius Barbosa Mar...', tier: null, pct: null, atrasado: false, acao: 'semContrato', recomendada: null, confianca: 'sem', flags: []),
  '103': OcupacaoQuarto(ocupante: '*JOSÉ DIONISIO JUNIOR', tier: null, pct: null, atrasado: false, acao: 'semContrato', recomendada: null, confianca: 'sem', flags: []),
  '104': OcupacaoQuarto(ocupante: '*MARINALDO DA SILVA D...', tier: null, pct: null, atrasado: false, acao: 'semContrato', recomendada: null, confianca: 'sem', flags: []),
  '106': OcupacaoQuarto(ocupante: '*MARCIO CRISTIANO LIM...', tier: null, pct: null, atrasado: false, acao: 'semContrato', recomendada: null, confianca: 'sem', flags: []),
  '107': OcupacaoQuarto(ocupante: '*Ronaldo Fernandes', tier: null, pct: null, atrasado: false, acao: 'semContrato', recomendada: null, confianca: 'sem', flags: []),
  '108': OcupacaoQuarto(ocupante: '*Thales Gutierie Gome...', tier: null, pct: null, atrasado: false, acao: 'semContrato', recomendada: null, confianca: 'sem', flags: []),
  '109': OcupacaoQuarto(ocupante: '*RITA SIBELLY CAETANO...', tier: null, pct: null, atrasado: false, acao: 'semContrato', recomendada: null, confianca: 'sem', flags: []),
  '110': OcupacaoQuarto(ocupante: '*JAILSON BLASIUS FERN...', tier: null, pct: null, atrasado: false, acao: 'semContrato', recomendada: null, confianca: 'sem', flags: []),
  '111': OcupacaoQuarto(ocupante: '*EDMILSON FRANCISCO D...', tier: null, pct: null, atrasado: false, acao: 'semContrato', recomendada: null, confianca: 'sem', flags: []),
  '112': OcupacaoQuarto(ocupante: '*Carlos Assumpção Tsc...', tier: null, pct: null, atrasado: false, acao: 'semContrato', recomendada: null, confianca: 'sem', flags: []),
  '114': OcupacaoQuarto(ocupante: '*ZILMEDSON DE ARAUJO...', tier: null, pct: null, atrasado: false, acao: 'semContrato', recomendada: null, confianca: 'sem', flags: []),
  '115': OcupacaoQuarto(ocupante: '*JULIO CESAR FONSECA', tier: null, pct: null, atrasado: false, acao: 'semContrato', recomendada: null, confianca: 'sem', flags: []),
  '116': OcupacaoQuarto(ocupante: '*GRAZIELE KELLY DA SI...', tier: null, pct: null, atrasado: false, acao: 'semContrato', recomendada: null, confianca: 'sem', flags: []),
  '117': OcupacaoQuarto(ocupante: '*Juan Kempen', tier: null, pct: null, atrasado: false, acao: 'semContrato', recomendada: null, confianca: 'sem', flags: []),
  '71': OcupacaoQuarto(ocupante: '*DÉCIO DE SOUZA FELIX', tier: null, pct: null, atrasado: false, acao: 'semContrato', recomendada: null, confianca: 'sem', flags: []),
  '72': OcupacaoQuarto(ocupante: '*ELAINE DURVAL SILVA...', tier: null, pct: null, atrasado: false, acao: 'semContrato', recomendada: null, confianca: 'sem', flags: []),
  '73': OcupacaoQuarto(ocupante: 'RAFAEL DE FRANÇA LIRA.', tier: null, pct: null, atrasado: false, acao: 'semContrato', recomendada: null, confianca: 'sem', flags: []),
  '201': OcupacaoQuarto(ocupante: '*DOUGLAS ORTIZ', tier: null, pct: null, atrasado: false, acao: 'semContrato', recomendada: null, confianca: 'sem', flags: []),
  '202': OcupacaoQuarto(ocupante: '*GIULIANO MARCELO VARIS', tier: null, pct: null, atrasado: false, acao: 'semContrato', recomendada: null, confianca: 'sem', flags: []),
  '203': OcupacaoQuarto(ocupante: '*ADILSON AFONSO TAVARES.', tier: null, pct: null, atrasado: false, acao: 'semContrato', recomendada: null, confianca: 'sem', flags: []),
  '204': OcupacaoQuarto(ocupante: 'ITAMAR CATRINACHO', tier: null, pct: null, atrasado: false, acao: 'semContrato', recomendada: null, confianca: 'sem', flags: []),
  '205': OcupacaoQuarto(ocupante: '*DILSON KOSSOSKI', tier: null, pct: null, atrasado: false, acao: 'semContrato', recomendada: null, confianca: 'sem', flags: []),
  '206': OcupacaoQuarto(ocupante: 'Elizabeth Reis', tier: null, pct: null, atrasado: false, acao: 'semContrato', recomendada: null, confianca: 'sem', flags: []),
  '207': OcupacaoQuarto(ocupante: '*RENATO NEWTON RAMLOW', tier: null, pct: null, atrasado: false, acao: 'semContrato', recomendada: null, confianca: 'sem', flags: []),
  '208': OcupacaoQuarto(ocupante: '*Karoline Fernandes S...', tier: null, pct: null, atrasado: false, acao: 'semContrato', recomendada: null, confianca: 'sem', flags: []),
  '209': OcupacaoQuarto(ocupante: '*Estela Ribas Ferezin', tier: null, pct: null, atrasado: false, acao: 'semContrato', recomendada: null, confianca: 'sem', flags: []),
  '210': OcupacaoQuarto(ocupante: '*FABIO PEREIRA DA SILVA', tier: null, pct: null, atrasado: false, acao: 'semContrato', recomendada: null, confianca: 'sem', flags: []),
  '143': OcupacaoQuarto(ocupante: 'Lucas Kotleski Carvalho', tier: null, pct: null, atrasado: false, acao: 'semContrato', recomendada: null, confianca: 'sem', flags: []),
  '128': OcupacaoQuarto(ocupante: '*SECUNDINO DOS SANTOS...', tier: null, pct: null, atrasado: false, acao: 'semContrato', recomendada: null, confianca: 'sem', flags: []),
  '130': OcupacaoQuarto(ocupante: 'AGNALDO APARECIDO MAR...', tier: null, pct: null, atrasado: false, acao: 'semContrato', recomendada: null, confianca: 'sem', flags: []),
  '121': OcupacaoQuarto(ocupante: '*Disraeli Silva', tier: null, pct: null, atrasado: false, acao: 'semContrato', recomendada: null, confianca: 'sem', flags: []),
  '122': OcupacaoQuarto(ocupante: 'Antônio Martins Seque...', tier: null, pct: null, atrasado: false, acao: 'semContrato', recomendada: null, confianca: 'sem', flags: []),
  '123': OcupacaoQuarto(ocupante: 'José Donizete Daniel...', tier: null, pct: null, atrasado: false, acao: 'semContrato', recomendada: null, confianca: 'sem', flags: []),
  '124': OcupacaoQuarto(ocupante: 'George El-Khouri', tier: null, pct: null, atrasado: false, acao: 'semContrato', recomendada: null, confianca: 'sem', flags: []),
  '125': OcupacaoQuarto(ocupante: '*Melin Karla Nobrega/...', tier: null, pct: null, atrasado: false, acao: 'semContrato', recomendada: null, confianca: 'sem', flags: []),
  '126': OcupacaoQuarto(ocupante: '*MARCOS LUIZ RIBEIRO', tier: null, pct: null, atrasado: false, acao: 'semContrato', recomendada: null, confianca: 'sem', flags: []),
  '127': OcupacaoQuarto(ocupante: '*Aldelvan Meneses Costa.', tier: null, pct: null, atrasado: false, acao: 'semContrato', recomendada: null, confianca: 'sem', flags: []),
  '129': OcupacaoQuarto(ocupante: '*Marcelo Tedesco da R...', tier: null, pct: null, atrasado: false, acao: 'semContrato', recomendada: null, confianca: 'sem', flags: []),
  '131': OcupacaoQuarto(ocupante: '*HARLEY MENEZES MORAE...', tier: null, pct: null, atrasado: false, acao: 'semContrato', recomendada: null, confianca: 'sem', flags: []),
  '132': OcupacaoQuarto(ocupante: '*FABRICIO APARECIDO S...', tier: null, pct: null, atrasado: false, acao: 'semContrato', recomendada: null, confianca: 'sem', flags: []),
  '133': OcupacaoQuarto(ocupante: '*Paulo Porto de Carva...', tier: null, pct: null, atrasado: false, acao: 'semContrato', recomendada: null, confianca: 'sem', flags: []),
  '134': OcupacaoQuarto(ocupante: '*Alexandre Rocha Duarte*', tier: null, pct: null, atrasado: false, acao: 'semContrato', recomendada: null, confianca: 'sem', flags: []),
  '136': OcupacaoQuarto(ocupante: '*Renato Vital.', tier: null, pct: null, atrasado: false, acao: 'semContrato', recomendada: null, confianca: 'sem', flags: []),
  '137': OcupacaoQuarto(ocupante: '*HIROSHI SUGIYA', tier: null, pct: null, atrasado: false, acao: 'semContrato', recomendada: null, confianca: 'sem', flags: []),
  '138': OcupacaoQuarto(ocupante: '*MARCIO RODRIGUES CER...', tier: null, pct: null, atrasado: false, acao: 'semContrato', recomendada: null, confianca: 'sem', flags: []),
  '139': OcupacaoQuarto(ocupante: '*Alessandro Rodrigues...', tier: null, pct: null, atrasado: false, acao: 'semContrato', recomendada: null, confianca: 'sem', flags: []),
  '140': OcupacaoQuarto(ocupante: '*ALESSANDRO CARRER GODIM', tier: null, pct: null, atrasado: false, acao: 'semContrato', recomendada: null, confianca: 'sem', flags: []),
  '141': OcupacaoQuarto(ocupante: '*Agnaldo Castro', tier: null, pct: null, atrasado: false, acao: 'semContrato', recomendada: null, confianca: 'sem', flags: []),
  '142': OcupacaoQuarto(ocupante: '*Victor Sbisa Bremer.', tier: null, pct: null, atrasado: false, acao: 'semContrato', recomendada: null, confianca: 'sem', flags: []),
  '144': OcupacaoQuarto(ocupante: '*GLEICY KELLY MARQUE...', tier: null, pct: null, atrasado: false, acao: 'semContrato', recomendada: null, confianca: 'sem', flags: []),
  '145': OcupacaoQuarto(ocupante: '*AIRTON MATRICARDI*', tier: null, pct: null, atrasado: false, acao: 'semContrato', recomendada: null, confianca: 'sem', flags: []),
  '146': OcupacaoQuarto(ocupante: '*SERGIO DAUTO OLIVEIRA', tier: null, pct: null, atrasado: false, acao: 'semContrato', recomendada: null, confianca: 'sem', flags: []),
  '147': OcupacaoQuarto(ocupante: '*JOSE ADINAN ORTOLAN', tier: null, pct: null, atrasado: false, acao: 'semContrato', recomendada: null, confianca: 'sem', flags: []),
  '148': OcupacaoQuarto(ocupante: '*DANILO DOS SANTOS CA...', tier: null, pct: null, atrasado: false, acao: 'semContrato', recomendada: null, confianca: 'sem', flags: []),
  '149': OcupacaoQuarto(ocupante: '*Renato Cosmo Garcia', tier: null, pct: null, atrasado: false, acao: 'semContrato', recomendada: null, confianca: 'sem', flags: []),
  '150': OcupacaoQuarto(ocupante: '*CARMEM LUCIA RODRIGU...', tier: null, pct: null, atrasado: false, acao: 'semContrato', recomendada: null, confianca: 'sem', flags: []),
  '151': OcupacaoQuarto(ocupante: '*Djeane do Socorro Si...', tier: null, pct: null, atrasado: false, acao: 'semContrato', recomendada: null, confianca: 'sem', flags: []),
  '152': OcupacaoQuarto(ocupante: '*LUCIANO ALASMAR', tier: null, pct: null, atrasado: false, acao: 'semContrato', recomendada: null, confianca: 'sem', flags: []),
  '153': OcupacaoQuarto(ocupante: '*JOSE DOMICIO DA SILVA', tier: null, pct: null, atrasado: false, acao: 'semContrato', recomendada: null, confianca: 'sem', flags: []),
  '154': OcupacaoQuarto(ocupante: '*Thiago de Lima Araújo', tier: null, pct: null, atrasado: false, acao: 'semContrato', recomendada: null, confianca: 'sem', flags: []),
  '155': OcupacaoQuarto(ocupante: '*CLAUDIO DANIEL ALBERTI*', tier: null, pct: null, atrasado: false, acao: 'semContrato', recomendada: null, confianca: 'sem', flags: []),
  '156': OcupacaoQuarto(ocupante: '*José Virgílio Lima', tier: null, pct: null, atrasado: false, acao: 'semContrato', recomendada: null, confianca: 'sem', flags: []),
  '157': OcupacaoQuarto(ocupante: '*Murillo Amorim da Silva', tier: null, pct: null, atrasado: false, acao: 'semContrato', recomendada: null, confianca: 'sem', flags: []),
  '158': OcupacaoQuarto(ocupante: '*Mario Augusto Pacheco', tier: null, pct: null, atrasado: false, acao: 'semContrato', recomendada: null, confianca: 'sem', flags: []),
  '159': OcupacaoQuarto(ocupante: '*CARLOS ROBERTO PAIXA...', tier: null, pct: null, atrasado: false, acao: 'semContrato', recomendada: null, confianca: 'sem', flags: []),
  '160': OcupacaoQuarto(ocupante: 'Hector Oscar Martinez', tier: null, pct: null, atrasado: false, acao: 'semContrato', recomendada: null, confianca: 'sem', flags: []),
  '162': OcupacaoQuarto(ocupante: '*SILVIO ATTILA LYRA A...', tier: null, pct: null, atrasado: false, acao: 'semContrato', recomendada: null, confianca: 'sem', flags: []),
  '163': OcupacaoQuarto(ocupante: '*ARTHUR CESAR TAVARES', tier: null, pct: null, atrasado: false, acao: 'semContrato', recomendada: null, confianca: 'sem', flags: []),
  '164': OcupacaoQuarto(ocupante: '*EUDES DOS SANTOS MENDES', tier: null, pct: null, atrasado: false, acao: 'semContrato', recomendada: null, confianca: 'sem', flags: []),
  '165': OcupacaoQuarto(ocupante: '*OZANEIDE CAVALCANTI...', tier: null, pct: null, atrasado: false, acao: 'semContrato', recomendada: null, confianca: 'sem', flags: []),
  '166': OcupacaoQuarto(ocupante: '*RICARDO LOPES DANIEL', tier: null, pct: null, atrasado: false, acao: 'semContrato', recomendada: null, confianca: 'sem', flags: []),
  '167': OcupacaoQuarto(ocupante: '*GUTEMBERGUE DANTAS', tier: null, pct: null, atrasado: false, acao: 'semContrato', recomendada: null, confianca: 'sem', flags: []),
  '168': OcupacaoQuarto(ocupante: '*ADRIANO CICERO DOS S...', tier: null, pct: null, atrasado: false, acao: 'semContrato', recomendada: null, confianca: 'sem', flags: []),
  '169': OcupacaoQuarto(ocupante: 'ALESSANDRO TRANSCOURIER', tier: null, pct: null, atrasado: false, acao: 'semContrato', recomendada: null, confianca: 'sem', flags: []),
  '170': OcupacaoQuarto(ocupante: '*Lenise Vargas Flores...', tier: null, pct: null, atrasado: false, acao: 'semContrato', recomendada: null, confianca: 'sem', flags: []),
  '51': OcupacaoQuarto(ocupante: '*NILSON LUZ CANGUSSU', tier: null, pct: null, atrasado: false, acao: 'semContrato', recomendada: null, confianca: 'sem', flags: []),
  '52': OcupacaoQuarto(ocupante: '*Clenildo Xavier De S...', tier: null, pct: null, atrasado: false, acao: 'semContrato', recomendada: null, confianca: 'sem', flags: []),
  '53': OcupacaoQuarto(ocupante: '*VALERIA GOMES DA SILVA', tier: null, pct: null, atrasado: false, acao: 'semContrato', recomendada: null, confianca: 'sem', flags: []),
  '54': OcupacaoQuarto(ocupante: '*KEYLLA ALMEIDA DE SO...', tier: null, pct: null, atrasado: false, acao: 'semContrato', recomendada: null, confianca: 'sem', flags: []),
  '56': OcupacaoQuarto(ocupante: '*GEOMARCIO BARROS TAV...', tier: null, pct: null, atrasado: false, acao: 'semContrato', recomendada: null, confianca: 'sem', flags: []),
  '57': OcupacaoQuarto(ocupante: '*Katia Aline de Oliveira', tier: null, pct: null, atrasado: false, acao: 'semContrato', recomendada: null, confianca: 'sem', flags: []),
  '58': OcupacaoQuarto(ocupante: 'Renata Pereira Gonçalves', tier: null, pct: null, atrasado: false, acao: 'semContrato', recomendada: null, confianca: 'sem', flags: []),
  '59': OcupacaoQuarto(ocupante: '*EDMILSON FRANCISCO D...', tier: null, pct: null, atrasado: false, acao: 'semContrato', recomendada: null, confianca: 'sem', flags: []),
};

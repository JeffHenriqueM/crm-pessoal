# Graph Report - .  (2026-07-08)

## Corpus Check
- 121 files · ~142,782 words
- Verdict: corpus is large enough that graph structure adds value.

## Summary
- 3264 nodes · 4300 edges · 134 communities (118 shown, 16 thin omitted)
- Extraction: 100% EXTRACTED · 0% INFERRED · 0% AMBIGUOUS
- Token cost: 0 input · 0 output

## Community Hubs (Navigation)
- Camada de Dados (FirestoreService)
- Hospedagem Screen
- Analise de Imoveis (Espelho)
- Aba Negociacoes
- Modelo de Contrato
- UI Analise de Imoveis
- Ficha do Cliente
- Recepcao / Atendimento
- Aba Analise Imoveis
- Ficha Contrato Screen
- Analise de Vendas
- Distrato / Cobranca
- Fluxo Cliente Screen
- Fases do Cliente + Modelo
- Aba Financeiro
- Tela de Negociacoes
- Contatos Embaixador Tab
- Modelo de Negociacao
- Ficha Dados Tab
- Campanhas
- Desempenho do Vendedor
- Ficha Cliente Screen
- Ficha Contrato Screen
- Tickets / Pos-venda
- Meta Mensal Card
- Grupo Notificacao Colapsavel
- Apresentacao Screen
- Aba Agenda
- Agendamento Model
- Ticket Model
- Overview Admin (Equipe)
- PDF da Ficha
- Ficha Ticket Screen
- Aba Pos Venda
- Parser Excel Financeiro
- _BotaoTipo
- Tema / ThemeController
- Aba Metas
- Aba Relatorios
- Contato Embaixador Model
- Gerenciar Produtos Screen
- Kanban View
- Usuario Model
- _abrirDetalhe
- Modelos Mensagem Screen
- Festa Pdf
- Calibracao
- Email Modelos
- Festa Regras
- Interacao Model
- Dashboard Screen
- Aba Risco Silencio
- Baixa Financeira Model
- Vendedor Home Screen
- Aba Lead Score
- Tela Login Screen
- Aba Tempo Sem Contato
- Modelo Mensagem Model
- Gerenciar Usuarios Screen
- Proposta Pdf
- Match Contrato
- Contrato Csv Parser
- ApresentacaoScreen
- Interacao Form Dialog
- Imovel Model
- Firebase Options
- Contrato Import Diff
- Vincular Contrato Dialog
- Email Modelos
- Tempo Sem Contato
- Festa Associacao
- Lead Score
- Risco Silencio
- Aba Estatisticas
- Imovel Model
- Atualizacao Service
- Filtro Periodo
- Index
- Aba Captacao
- Analise Distrato
- Auth Service
- Festa Espera
- Staging Login Screen
- Grupo Notificacao Colapsavel
- App Bar
- Filtro Periodo
- Aba Calibracao
- Produto Model
- Notificacao Inapp Model
- Push Notification Service
- Aba Desempenho Vendedor
- Festa Validacao
- Firebase Options
- Festa Ocupacao Gerado
- Configuracoes Screen
- Tutorial Screen
- Chip Tempo Sem Contato
- Quarto Festa Socios
- Fila Atendimento Model
- Festa Trocas Gerado
- Financeiro Screen
- Acoes Lead
- Interacao Model
- Aniversariantes Pos Venda
- Datas Uteis
- Moeda Input
- Ficha Timeline Tab
- Festa Mapa2 Gerado
- Botoes Contato Contrato
- Chip Tempo Sem Contato
- Url Launcher Service
- Esolution Button
- Perfis
- @Deprecated
- AutomaticKeepAliveClientMixin
- Fase Enum
- FichaClienteScreen
- FichaContratoScreen
- _PhoneFormatter
- _InteracoesTab
- FluxoClienteScreen
- _FestaSociosView
- _SeletorContrato
- _SeletorQuartoDestino
- ListaClientesScreen
- _ListaNegociacoes
- NegociacoesBody
- _PainelAprovacao
- PosVendaScreen
- AbaMetas
- _BuscaLeadDialog
- _FormularioNegociacao
- ContatosEmbaixadorTab
- _FormContatoDialog

## God Nodes (most connected - your core abstractions)
1. `StatelessWidget` - 72 edges
2. `FirestoreService` - 12 edges
3. `Cliente` - 10 edges
4. `Contrato` - 10 edges
5. `FaseCliente` - 7 edges
6. `Usuario` - 7 edges
7. `Canal` - 6 edges
8. `AuthService` - 6 edges
9. `Modalidade` - 4 edges
10. `Produto` - 4 edges

## Surprising Connections (you probably didn't know these)
- `VillamorCrmApp` --inherits--> `StatelessWidget`  [EXTRACTED]
  lib/main.dart → lib/widgets/app_bar.dart
- `_LoadingScreen` --inherits--> `StatelessWidget`  [EXTRACTED]
  lib/main.dart → lib/widgets/app_bar.dart
- `CampanhasScreen` --inherits--> `StatelessWidget`  [EXTRACTED]
  lib/screens/campanhas_screen.dart → lib/widgets/app_bar.dart
- `_CampanhaCard` --inherits--> `StatelessWidget`  [EXTRACTED]
  lib/screens/campanhas_screen.dart → lib/widgets/app_bar.dart
- `ConfiguracoesScreen` --inherits--> `StatelessWidget`  [EXTRACTED]
  lib/screens/configuracoes_screen.dart → lib/widgets/app_bar.dart

## Import Cycles
- None detected.

## Communities (134 total, 16 thin omitted)

### Community 0 - "Camada de Dados (FirestoreService)"
Cohesion: 0.01
Nodes (164): analise_imoveis.dart, adicionarAgendamento, adicionarCliente, adicionarComentario, adicionarInteracao, _adicionarInteracaoAutomatica, adicionarInteracaoContrato, adicionarNegociacao (+156 more)

### Community 1 - "Hospedagem Screen"
Cohesion: 0.02
Nodes (95): Future, a, _abrirMoverEspera, _abrirWhatsApp, acao, associacoes, associado, ativo (+87 more)

### Community 2 - "Analise de Imoveis (Espelho)"
Cohesion: 0.02
Nodes (95): analisarEmpreendimento, analisarReversao, analises, andares, ativo, avulsos, b, bloco (+87 more)

### Community 3 - "Aba Negociacoes"
Cohesion: 0.02
Nodes (93): _abrirBuscaLead, _abrirDialogInativacao, _abrirEscolhaProduto, abrirFormularioNegociacao, _aprovacaoChip, _aprovacaoCores, _atualizandoEntrada, _atualizandoParcela (+85 more)

### Community 4 - "Modelo de Contrato"
Cohesion: 0.02
Nodes (81): emNegociacao,
  marcado,
  notificado,
  distratoEnviado,, atualizadoEm, bairro, bloco, captador, cidade, codigoContrato, complemento (+73 more)

### Community 5 - "UI Analise de Imoveis"
Cohesion: 0.03
Nodes (69): EdgeInsetsGeometry, AnaliseImovel, AnaliseReversao, ResumoAnalise, ResumoBloco, ResumoTier, analise, _blocoView (+61 more)

### Community 6 - "Ficha do Cliente"
Cohesion: 0.03
Nodes (66): _abrirWhatsApp, _adicionarAgenda, _apagarClienteDialog, _atualizarFasePorOrigem, _authService, _bannerTempoSemContato, _brindeCtrl, build (+58 more)

### Community 7 - "Recepcao / Atendimento"
Cohesion: 0.04
Nodes (56): _acharUsuario, agendamento, agendamentoOrigem, _agendamentoOrigemId, _brinde, _brindes, _busca, _captador (+48 more)

### Community 8 - "Aba Analise Imoveis"
Cohesion: 0.04
Nodes (55): aba_analise_imoveis.dart, aba_distratar.dart, aba_pos_venda.dart, activeIcon, _apresentacaoItem, build, _buildAtualizacaoBanner, _buildMobileAppBar (+47 more)

### Community 9 - "Ficha Contrato Screen"
Cohesion: 0.04
Nodes (53): BuildContext, ficha_contrato_screen.dart, _abrirFiltros, _abrirImportDialog, _atual, _busca, _carregando, _carregarUltimosPagamentos (+45 more)

### Community 10 - "Analise de Vendas"
Cohesion: 0.04
Nodes (52): 0, ano, atual, ClassificacaoReversao, classificarReversao, contratos, contratosPermuta, contratosSemPagamento (+44 more)

### Community 11 - "Distrato / Cobranca"
Cohesion: 0.04
Nodes (51): botoes_contato_contrato.dart, SituacaoDistrato, AbaDistratar, _AbaDistratarState, _alternarDistrato, _analise, _atualizarSituacao, _baixas (+43 more)

### Community 12 - "Fluxo Cliente Screen"
Cohesion: 0.04
Nodes (51): ColorScheme, _acento, _alternarPlay, _animDur, _anterior, _aoTeclar, _arrowW, _auto (+43 more)

### Community 13 - "Fases do Cliente + Modelo"
Cohesion: 0.04
Nodes (51): fase_enum.dart, _aliasesFaseLegada, atualizadoPorId, atualizadoPorNome, brinde, captadorId, captadorNome, contratoVinculadoId (+43 more)

### Community 14 - "Aba Financeiro"
Cohesion: 0.04
Nodes (49): dart:html, AbaFinanceiro, _AbaFinanceiroState, _abrirUpload, _baixas, build, _buildEmptyState, _buildFiltroMes (+41 more)

### Community 15 - "Tela de Negociacoes"
Cohesion: 0.04
Nodes (46): _abrirCliente, _abrirDialogInativacao, _abrirPainelAprovacao, _acao, _aprovacaoCores, _authService, build, _buildVazio (+38 more)

### Community 16 - "Contatos Embaixador Tab"
Cohesion: 0.04
Nodes (46): build, _busca, _CardContato, _confirmarExcluir, contato, createState, dispose, _esposa (+38 more)

### Community 17 - "Modelo de Negociacao"
Cohesion: 0.05
Nodes (44): aprovadoPorId, aprovadoPorNome, clienteId, clienteNome, comentarioAprovacao, condicaoEspecial, copyWith, criadoPorId (+36 more)

### Community 18 - "Ficha Dados Tab"
Cohesion: 0.05
Nodes (43): GlobalKey, brindeCtrl, build, _buildDateTile, captador, carregandoUsuarios, dataCaptacao, dataVisita (+35 more)

### Community 19 - "Campanhas"
Cohesion: 0.05
Nodes (42): ativa, Campanha, condicao, criadoEm, criadoPorId, criadoPorNome, dataFim, dataInicio (+34 more)

### Community 20 - "Desempenho do Vendedor"
Cohesion: 0.05
Nodes (42): amostraSuficiente, ativos, avaliarEquipe, bench, BenchmarkEquipe, cicloMedioDias, de, decididos (+34 more)

### Community 21 - "Ficha Cliente Screen"
Cohesion: 0.05
Nodes (41): DateTimeRange?, ficha_cliente_screen.dart, _abrirFiltros, _aplicarFiltros, _authService, build, _buildBody, _buildSearchResults (+33 more)

### Community 22 - "Ficha Contrato Screen"
Cohesion: 0.05
Nodes (40): StatusAssinatura, _abrirPdf, _alterarAssinatura, _auth, build, _campo, _carregarUltimoPagamento, _confirmarExcluirInteracao (+32 more)

### Community 23 - "Tickets / Pos-venda"
Cohesion: 0.05
Nodes (39): _atribuidoPara, _authService, build, _buildBolhaComentario, _buildComentarios, _buildForm, _carregarUsuarios, _comentarioCtrl (+31 more)

### Community 24 - "Meta Mensal Card"
Cohesion: 0.05
Nodes (39): build, _calcularProgresso, _carregando, _carregarDados, clientes, _clientesCaptados, _contratosContatados, _contratosTotal (+31 more)

### Community 25 - "Grupo Notificacao Colapsavel"
Cohesion: 0.05
Nodes (38): dart:math, grupo_notificacao_colapsavel.dart, build, _buildCategoria, _buildCategoriaCampanha, _buildCategoriaLembretes, _buildCategoriaTickets, _buildItemCampanha (+30 more)

### Community 26 - "Apresentacao Screen"
Cohesion: 0.05
Nodes (38): build, _buildCardBase, _buildCenario1, _buildCenario2, _buildEconomia, _buildPlaceholder, _buildResultados, _campoDiaria (+30 more)

### Community 27 - "Aba Agenda"
Cohesion: 0.05
Nodes (38): AbaAgenda, _AbaAgendaState, addRange, _agendamentoCard, agendamentos, build, _buildVendedorChip, _clienteCard (+30 more)

### Community 28 - "Agendamento Model"
Cohesion: 0.05
Nodes (37): DateTime get, Agendamento, brinde, captadorId, captadorNome, clienteVinculadoId, criadoEm, criadoPorId (+29 more)

### Community 29 - "Ticket Model"
Cohesion: 0.06
Nodes (37): atribuidoParaId, atribuidoParaNome, autorId, autorNome, clienteId, clienteNome, ComentarioTicket, contexto (+29 more)

### Community 30 - "Overview Admin (Equipe)"
Cohesion: 0.06
Nodes (34): AbaAdminOverview, _AbaAdminOverviewState, _alertaAtrasados, _alertaVendedorRow, ativos, atrasados, _avatarVendedor, build (+26 more)

### Community 31 - "PDF da Ficha"
Cohesion: 0.06
Nodes (32): brinde, _buildPage, _buildPainelDireito, _buildPainelEsquerdo, captadorNome, _checkbox, _cinzaClaro, conjuge (+24 more)

### Community 32 - "Ficha Ticket Screen"
Cohesion: 0.06
Nodes (31): ficha_ticket_screen.dart, _aplicarFiltros, _authService, build, _buildCard, _buildFiltros, _buildLista, _buildVazio (+23 more)

### Community 33 - "Aba Pos Venda"
Cohesion: 0.06
Nodes (31): AbaPosVenda, _abrirBottomSheet, aniversariantes, _AssinaturaCard, _BotaoAniversariantes, build, _buildConteudo, _buildSecaoTitulo (+23 more)

### Community 34 - "Parser Excel Financeiro"
Cohesion: 0.08
Nodes (29): @visibleForTesting, dart:convert, _abaAlvo, _colunasPadrao, _dataOuErro, FinanceiroExcelParser, _palavrasChave, _parseDataString (+21 more)

### Community 35 - "_BotaoTipo"
Cohesion: 0.06
Nodes (31): _BotaoTipo, _CategoriaSection, HospedagemScreen, _PainelEspera, _QuartoCard, _SeletorCategoria, _TrocasView, _AnalisandoDialog (+23 more)

### Community 36 - "Tema / ThemeController"
Cohesion: 0.07
Nodes (28): ChangeNotifier, initialize, instance, isDark, _key, _mode, setMode, ThemeController (+20 more)

### Community 37 - "Aba Metas"
Cohesion: 0.07
Nodes (29): _alvoPosVenda, _avatar, build, _cardInatividade, _cardMeta, _cardPosVenda, _carregandoContratos, _carregarContratos (+21 more)

### Community 38 - "Aba Relatorios"
Cohesion: 0.07
Nodes (29): AbaRelatorios, _AbaRelatoriosState, _ativas, build, _buildCanais, _buildFiltroVendedor, _buildFunil, _buildPainelPeriodo (+21 more)

### Community 39 - "Contato Embaixador Model"
Cohesion: 0.07
Nodes (28): bool?, canaisDisponiveis, canal, ContatoEmbaixador, copyWith, criadoEm, criadoPorId, criadoPorNome (+20 more)

### Community 40 - "Gerenciar Produtos Screen"
Cohesion: 0.07
Nodes (28): _abrirFormProduto, build, _buildEstadoVazio, _categoria, _categorias, _confirmarArquivar, createState, dispose (+20 more)

### Community 41 - "Kanban View"
Cohesion: 0.08
Nodes (25): build, _buildCardList, _buildCardWidget, _buildHeader, cliente, clientes, _columnGap, _columnWidth (+17 more)

### Community 42 - "Usuario Model"
Cohesion: 0.08
Nodes (24): assinaturasMesAtual, assinaturasPorMes, assinaturasTotal, ativo, email, fromMap, hashCode, id (+16 more)

### Community 43 - "_abrirDetalhe"
Cohesion: 0.08
Nodes (25): _abrirDetalhe, _abrirFicha, build, build, _registrarAtendimento, _abrirNovoTicket, _abrirTicket, _csvEscape (+17 more)

### Community 44 - "Modelos Mensagem Screen"
Cohesion: 0.09
Nodes (23): _abrirForm, _assunto, build, _canal, _canalHeader, _confirmarExcluir, createState, dispose (+15 more)

### Community 45 - "Festa Pdf"
Cohesion: 0.08
Nodes (23): _ambar, _cabecalho, _cel, _celHospede, _celTipo, _cinzaTexto, _dataHoraFmt, _divisor (+15 more)

### Community 46 - "Calibracao"
Cohesion: 0.09
Nodes (22): double get, amostra, amostraSuficiente, calibrarSinais, comSinal, confiavel, decididos, fechados (+14 more)

### Community 47 - "Email Modelos"
Cohesion: 0.09
Nodes (20): email_modelos.dart, AppTheme, _buildTheme, seedColor, abrirWhatsAppContrato, _dataFmt, enviarEmailContrato, escolha (+12 more)

### Community 48 - "Festa Regras"
Cohesion: 0.09
Nodes (22): acaoFesta, categoria, categoriaKey, combinarContratosFesta, contarCasais, false, flags, naoVem (+14 more)

### Community 49 - "Interacao Model"
Cohesion: 0.09
Nodes (22): autorId, autorNome, Canal, CanalExt, copyWith, dataInteracao, fromFirestore, fromString (+14 more)

### Community 50 - "Dashboard Screen"
Cohesion: 0.09
Nodes (22): _authService, build, _buildAdminDashboard, _buildVendedorDashboard, _carregarDadosIniciais, createState, _firestoreService, initState (+14 more)

### Community 51 - "Aba Risco Silencio"
Cohesion: 0.09
Nodes (22): AbaRiscoSilencio, _AbaRiscoSilencioState, avaliacao, build, _cardRisco, cliente, clientes, _corNivel (+14 more)

### Community 52 - "Baixa Financeira Model"
Cohesion: 0.09
Nodes (21): BaixaFinanceira, buildMesKey, cliente, copyWith, dataBaixa, dataCredito, documentoCar, fromFirestore (+13 more)

### Community 53 - "Vendedor Home Screen"
Cohesion: 0.10
Nodes (20): _abrirCliente, build, _buildDisponibilidadeToggle, _buildHojeStrip, createState, currentUserId, _eventoChip, _firestoreService (+12 more)

### Community 54 - "Aba Lead Score"
Cohesion: 0.10
Nodes (21): AbaLeadScore, _AbaLeadScoreState, build, _cardScore, cliente, clientes, _corTemp, createState (+13 more)

### Community 55 - "Tela Login Screen"
Cohesion: 0.10
Nodes (20): FormState, _authService, _brandFeature, build, _buildBrandPanel, _buildForm, _buildFormPanel, _buildNarrowLayout (+12 more)

### Community 56 - "Aba Tempo Sem Contato"
Cohesion: 0.10
Nodes (20): Cliente, AbaTempoSemContato, _AbaTempoSemContatoState, avaliacao, build, _cardItem, cliente, clientes (+12 more)

### Community 57 - "Modelo Mensagem Model"
Cohesion: 0.10
Nodes (20): aplicarVariaveisMensagem, assunto, canal, capitalizarNome, _conectivosNome, copyWith, criadoEm, criadoPorId (+12 more)

### Community 58 - "Gerenciar Usuarios Screen"
Cohesion: 0.10
Nodes (20): _authService, build, _capitalize, _chipPerfil, _confirmarAlterarStatus, _confirmarResetSenha, _corDePerfil, createState (+12 more)

### Community 59 - "Proposta Pdf"
Cohesion: 0.10
Nodes (20): _azulEscuro, _azulMedio, _buildPage, _cinzaTexto, _dataFmt, _dataHoraFmt, _divisor, _fundo (+12 more)

### Community 60 - "Match Contrato"
Cohesion: 0.10
Nodes (20): acentos, contrato, d, limite, motivo, nomeAlvo, normalizarNome, normalizarTelefone (+12 more)

### Community 61 - "Contrato Csv Parser"
Cohesion: 0.10
Nodes (19): dart:typed_data, aba, cabecalho, _celulaParaValor, contratos, idx, idxExato, iLoc (+11 more)

### Community 62 - "ApresentacaoScreen"
Cohesion: 0.14
Nodes (20): ApresentacaoScreen, _ApresentacaoScreenState, _FormularioCampanha, _FormularioCampanhaState, DashboardScreen, _DashboardScreenState, _FormProduto, _FormProdutoState (+12 more)

### Community 63 - "Interacao Form Dialog"
Cohesion: 0.11
Nodes (19): build, _canal, canalInicial, _combinamosCtrl, createState, ctrl, dispose, _houveResposta (+11 more)

### Community 64 - "Imovel Model"
Cohesion: 0.11
Nodes (18): bronze,
  prata,
  ouro,
  diamante,, bloco, blocoNome, ehBangalo, etapa, fromFirestore, fromString, id (+10 more)

### Community 65 - "Firebase Options"
Cohesion: 0.11
Nodes (18): firebase_options.dart, _authService, AuthWrapper, _AuthWrapperState, build, _carregandoPerfil, createState, _currentUserName (+10 more)

### Community 66 - "Contrato Import Diff"
Cohesion: 0.11
Nodes (18): a, alterados, analisarImportContratos, campos, _camposAlterados, contrato, ContratoAlterado, criados (+10 more)

### Community 67 - "Vincular Contrato Dialog"
Cohesion: 0.11
Nodes (18): FirestoreService, build, _busca, _carregando, _carregar, _contratos, createState, dispose (+10 more)

### Community 68 - "Email Modelos"
Cohesion: 0.11
Nodes (17): assunto, corpo, disponiveis, EscolhaEmail, escolherModeloEmail, servico, todos, uid (+9 more)

### Community 69 - "Tempo Sem Contato"
Cohesion: 0.12
Nodes (17): int get, agora, AlertaTempoContato, AlertaTempoContatoX, avaliarTempoSemContato, avaliarTempoSemContatoCliente, dias, diasNorm (+9 more)

### Community 70 - "Festa Associacao"
Cohesion: 0.11
Nodes (17): associadoPorNome, atrasado, categoriaManual, contratoId, contratosIds, ehManual, FestaAssociacao, fromMap (+9 more)

### Community 71 - "Lead Score"
Cohesion: 0.12
Nodes (17): agora, ativo, avaliarLeadScore, avaliarLeadScoreCliente, dias, _faseAtiva, noResponseCount, pontos (+9 more)

### Community 72 - "Risco Silencio"
Cohesion: 0.12
Nodes (17): agora, atrasado, AvaliacaoRisco, avaliarRiscoCliente, avaliarRiscoSilencio, contatoAtrasado, dias, diasSemContato (+9 more)

### Community 73 - "Aba Estatisticas"
Cohesion: 0.12
Nodes (17): AbaEstatisticas, _AbaEstatisticasState, build, _buildBarChartMotivos, clientes, _corDeFase, createState, _filtro (+9 more)

### Community 74 - "Imovel Model"
Cohesion: 0.12
Nodes (16): imovel_model.dart, clienteNome, contratoId, Cota, cpfComprador, dataContrato, estaQuitada, fromFirestore (+8 more)

### Community 75 - "Atualizacao Service"
Cohesion: 0.12
Nodes (15): dart:async, dart:js_interop, AtualizacaoService, _checar, disponivel, _iniciado, iniciar, instance (+7 more)

### Community 76 - "Filtro Periodo"
Cohesion: 0.13
Nodes (15): filtro_periodo.dart, AbaMotivosPerda, _AbaMotivosPerdaState, build, _categoriaExpandida, _categorizar, clientes, _clienteTile (+7 more)

### Community 77 - "Index"
Cohesion: 0.16
Nodes (12): db, enviarParaToken(), enviarParaTokens(), FCM_ERROS_PERMANENTES, lembreteProximoContato, limparTokenDoUsuario(), limparTokenPorValor(), messaging (+4 more)

### Community 78 - "Aba Captacao"
Cohesion: 0.13
Nodes (15): AbaCaptacao, _AbaCaptacaoState, _base, build, _buildFiltroCaptador, _buildGraficoDias, clientes, createState (+7 more)

### Community 79 - "Analise Distrato"
Cohesion: 0.13
Nodes (14): DateTime? hoje,
  int, agora, analisarDistrato, AnaliseDistrato, corte, inadimplentes, maioresAtrasos, maxPorCodigo (+6 more)

### Community 80 - "Auth Service"
Cohesion: 0.13
Nodes (14): FirebaseAuth, FirebaseFirestore, adminEnviarResetSenha, _auth, authStateChanges, criarNovoUsuario, _db, enviarEmailRedefinicaoSenha (+6 more)

### Community 81 - "Festa Espera"
Cohesion: 0.13
Nodes (14): adicionadoPorNome, atrasado, categoria, categoriaManual, contratoId, FestaEspera, fromMap, id (+6 more)

### Community 82 - "Staging Login Screen"
Cohesion: 0.13
Nodes (14): build, cor, descricao, _entrar, icone, id, _MockUser, nome (+6 more)

### Community 83 - "Grupo Notificacao Colapsavel"
Cohesion: 0.15
Nodes (13): class, _aberto, _alternar, build, children, contador, cor, createState (+5 more)

### Community 84 - "App Bar"
Cohesion: 0.14
Nodes (13): class ListaClientesAppBar extends, build, estaPesquisando, filtrosAtivos, ListaClientesAppBar, onFiltroTap, onToggleView, searchController (+5 more)

### Community 85 - "Filtro Periodo"
Cohesion: 0.14
Nodes (13): build, contem, _dateFmt, filtro, FiltroPeriodoBar, fim, inicio, legenda (+5 more)

### Community 86 - "Aba Calibracao"
Cohesion: 0.15
Nodes (12): Color, AbaCalibracao, _amostraCard, _avisoAmostra, build, _div, _ladoBarra, _sinalCard (+4 more)

### Community 87 - "Produto Model"
Cohesion: 0.15
Nodes (12): double?, ativo, categoria, copyWith, fromFirestore, id, limiteEspecial, nome (+4 more)

### Community 88 - "Notificacao Inapp Model"
Cohesion: 0.15
Nodes (12): clienteId, corpo, criadoEm, fromFirestore, id, lida, NotificacaoInApp, ticketId (+4 more)

### Community 89 - "Push Notification Service"
Cohesion: 0.15
Nodes (12): _auth, _db, initialize, _instance, _messaging, PushNotificationService, removerToken, _salvarToken (+4 more)

### Community 90 - "Aba Desempenho Vendedor"
Cohesion: 0.15
Nodes (12): AbaDesempenhoVendedor, _avatar, _benchItem, _benchmarkCard, build, _dimensaoRow, todosClientes, todosVendedores (+4 more)

### Community 91 - "Festa Validacao"
Cohesion: 0.17
Nodes (10): bool get, aprovada, FestaValidacao, fromMap, recusada, status, validadoEm, validadoPorNome (+2 more)

### Community 92 - "Firebase Options"
Cohesion: 0.18
Nodes (10): android, DefaultFirebaseOptions, ios, macos, StagingFirebaseOptions, web, web, windows (+2 more)

### Community 93 - "Festa Ocupacao Gerado"
Cohesion: 0.17
Nodes (11): acao, atrasado, confianca, deveTrocar, flags, ocupacaoFesta, OcupacaoQuarto, ocupante (+3 more)

### Community 94 - "Configuracoes Screen"
Cohesion: 0.17
Nodes (11): active, build, ConfiguracoesScreen, icon, label, _ModeCard, onTap, _secaoTitulo (+3 more)

### Community 95 - "Tutorial Screen"
Cohesion: 0.18
Nodes (10): IconData?, build, icone, passos, titulo, _tutoriais, _Tutorial, _TutorialCard (+2 more)

### Community 96 - "Chip Tempo Sem Contato"
Cohesion: 0.20
Nodes (9): chip_tempo_sem_contato.dart, _badge, build, _buildClienteCard, ClienteListFiltered, clientes, _confirmarExclusao, filtroNome (+1 more)

### Community 97 - "Quarto Festa Socios"
Cohesion: 0.22
Nodes (9): Color get, categoria, CategoriaQuarto, CategoriaQuartoX, corTexto, numero, QuartoFestaSocios, quartosFestaSocios (+1 more)

### Community 98 - "Fila Atendimento Model"
Cohesion: 0.20
Nodes (9): DateTime?, atualizadoEm, disponivel, FilaAtendimento, fromFirestore, posicaoEm, toFirestore, vendedorId (+1 more)

### Community 99 - "Festa Trocas Gerado"
Cohesion: 0.20
Nodes (9): categoriaAlvo, overflowFesta, pct, SemQuartoFesta, tier, transbordo, TrocaQuarto, trocasFesta (+1 more)

### Community 100 - "Financeiro Screen"
Cohesion: 0.22
Nodes (9): _authService, build, createState, FinanceiroScreen, _FinanceiroScreenState, initState, userProfile, AuthService (+1 more)

### Community 101 - "Acoes Lead"
Cohesion: 0.20
Nodes (9): cs, _enviarWhatsApp, escolha, mostrarAcoesLead, tel, temTelefone, userProfile, ../models/cliente_model.dart (+1 more)

### Community 102 - "Interacao Model"
Cohesion: 0.22
Nodes (8): interacao_model.dart, AtividadeInteracao, autorId, canal, clienteId, dataInteracao, houveResposta, String?

### Community 103 - "Aniversariantes Pos Venda"
Cohesion: 0.22
Nodes (8): Aniversariante, aniversariantesEm, d, m, resultado, vistos, ../models/contrato_model.dart, typedef

### Community 104 - "Datas Uteis"
Cohesion: 0.22
Nodes (7): adicionados, adicionarDiasUteis, data, 80, limiteParcelasNormais, nome, return

### Community 105 - "Moeda Input"
Cohesion: 0.22
Nodes (8): _fmtMoedaBR, formatEditUpdate, formatMoeda, parseMoeda, t, tryParse, NumberFormat, package:flutter/services.dart

### Community 106 - "Ficha Timeline Tab"
Cohesion: 0.22
Nodes (8): build, _buildManualItem, _buildSistemaItem, _buildTimelineItem, FichaTimelineTab, interacoes, isNovo, package:intl/intl.dart

### Community 107 - "Festa Mapa2 Gerado"
Cohesion: 0.25
Nodes (7): int?, OcupacaoNova, pct, tier, veioDe, Map, String ocupante,

### Community 108 - "Botoes Contato Contrato"
Cohesion: 0.25
Nodes (7): Contrato, BotoesContatoContrato, build, contrato, iconSize, package:font_awesome_flutter/font_awesome_flutter.dart, ../utils/contato_contrato.dart

### Community 109 - "Chip Tempo Sem Contato"
Cohesion: 0.29
Nodes (6): AvaliacaoTempoContato, avaliacao, build, ChipTempoSemContato, compacto, ../services/tempo_sem_contato.dart

### Community 110 - "Url Launcher Service"
Cohesion: 0.29
Nodes (6): abrirEmail, abrirUrl, abrirWhatsApp, UrlLauncherService, package:flutter/foundation.dart, package:url_launcher/url_launcher.dart

### Community 111 - "Esolution Button"
Cohesion: 0.29
Nodes (6): _abrir, build, EsolutionButton, _url, static const, ../utils/url_launcher_service.dart

### Community 112 - "Perfis"
Cohesion: 0.50
Nodes (3): ehPerfilVendas, perfisVendas, Set

### Community 113 - "@Deprecated"
Cohesion: 0.67
Nodes (3): @Deprecated, atualizarMetaMensal, getMetaMensal

### Community 114 - "AutomaticKeepAliveClientMixin"
Cohesion: 0.67
Nodes (3): AutomaticKeepAliveClientMixin, AbaNegociacoes, _AbaNegociacoesState

### Community 116 - "FichaClienteScreen"
Cohesion: 0.67
Nodes (3): FichaClienteScreen, _FichaClienteScreenState, TickerProviderStateMixin

### Community 117 - "FichaContratoScreen"
Cohesion: 0.67
Nodes (3): FichaContratoScreen, _FichaContratoScreenState, SingleTickerProviderStateMixin

### Community 118 - "_PhoneFormatter"
Cohesion: 0.67
Nodes (3): _PhoneFormatter, MoedaInputFormatter, TextInputFormatter

## Knowledge Gaps
- **2610 isolated node(s):** `DefaultFirebaseOptions`, `web`, `android`, `ios`, `macos` (+2605 more)
  These have ≤1 connection - possible missing edges or undocumented components.
- **16 thin communities (<3 nodes) omitted from report** — run `graphify query` to explore isolated nodes.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **Why does `FirestoreService` connect `Vincular Contrato Dialog` to `Camada de Dados (FirestoreService)`, `Hospedagem Screen`, `Aba Negociacoes`, `Gerenciar Produtos Screen`, `Modelos Mensagem Screen`, `Tela de Negociacoes`, `Contatos Embaixador Tab`, `Dashboard Screen`, `Campanhas`, `Ficha Cliente Screen`, `Gerenciar Usuarios Screen`?**
  _High betweenness centrality (0.008) - this node is a cross-community bridge._
- **Why does `Contrato` connect `Botoes Contato Contrato` to `Contrato Import Diff`, `Vincular Contrato Dialog`, `Modelo de Contrato`, `UI Analise de Imoveis`, `Ficha Contrato Screen`, `Analise de Vendas`, `Distrato / Cobranca`, `Ficha Contrato Screen`, `Match Contrato`?**
  _High betweenness centrality (0.006) - this node is a cross-community bridge._
- **Why does `Cliente` connect `Aba Tempo Sem Contato` to `Camada de Dados (FirestoreService)`, `Aba Negociacoes`, `Ficha do Cliente`, `Kanban View`, `Fases do Cliente + Modelo`, `Aba Risco Silencio`, `Aba Lead Score`, `Grupo Notificacao Colapsavel`, `Aba Agenda`?**
  _High betweenness centrality (0.005) - this node is a cross-community bridge._
- **What connects `DefaultFirebaseOptions`, `web`, `android` to the rest of the system?**
  _2610 weakly-connected nodes found - possible documentation gaps or missing edges._
- **Should `Camada de Dados (FirestoreService)` be split into smaller, more focused modules?**
  _Cohesion score 0.012121212121212121 - nodes in this community are weakly interconnected._
- **Should `Hospedagem Screen` be split into smaller, more focused modules?**
  _Cohesion score 0.020833333333333332 - nodes in this community are weakly interconnected._
- **Should `Analise de Imoveis (Espelho)` be split into smaller, more focused modules?**
  _Cohesion score 0.020833333333333332 - nodes in this community are weakly interconnected._
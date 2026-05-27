// lib/screens/staging_login_screen.dart
// Tela de seleção de usuário para o ambiente de STAGING.
// Não usa Firebase Authentication — qualquer clique entra direto no app.
import 'package:flutter/material.dart';
import 'recepcao_screen.dart';
import '../widgets/main_shell.dart';

// ── Usuários de teste ─────────────────────────────────────────────────────────
class _MockUser {
  final String nome;
  final String perfil;
  final String id;
  final Color cor;
  final IconData icone;
  final String descricao;

  const _MockUser({
    required this.nome,
    required this.perfil,
    required this.id,
    required this.cor,
    required this.icone,
    required this.descricao,
  });
}

const _usuarios = [
  _MockUser(
    nome: 'Eduardo',
    perfil: 'admin',
    id: 'mock_eduardo',
    cor: Color(0xFF1565C0),
    icone: Icons.admin_panel_settings_outlined,
    descricao: 'Acesso total ao sistema',
  ),
  _MockUser(
    nome: 'Jorge',
    perfil: 'vendedor',
    id: 'mock_jorge',
    cor: Color(0xFF2E7D32),
    icone: Icons.handshake_outlined,
    descricao: 'Agenda, Funil e Negociações',
  ),
  _MockUser(
    nome: 'Valquiria',
    perfil: 'recepcao',
    id: 'mock_valquiria',
    cor: Color(0xFF6A1B9A),
    icone: Icons.how_to_reg_outlined,
    descricao: 'Tela de recepção de visitantes',
  ),
  _MockUser(
    nome: 'Ana',
    perfil: 'captador',
    id: 'mock_ana',
    cor: Color(0xFFE65100),
    icone: Icons.directions_walk_outlined,
    descricao: 'Captação de leads',
  ),
  _MockUser(
    nome: 'Roberto',
    perfil: 'pós-venda',
    id: 'mock_roberto',
    cor: Color(0xFF00695C),
    icone: Icons.support_agent_outlined,
    descricao: 'Pós-venda e acompanhamento',
  ),
  _MockUser(
    nome: 'Fernanda',
    perfil: 'financeiro',
    id: 'mock_fernanda',
    cor: Color(0xFF4527A0),
    icone: Icons.account_balance_outlined,
    descricao: 'Visão financeira e relatórios',
  ),
];

// ── Tela principal ────────────────────────────────────────────────────────────
class StagingLoginScreen extends StatelessWidget {
  const StagingLoginScreen({super.key});

  void _entrar(BuildContext context, _MockUser user) {
    Widget destino;
    if (user.perfil == 'recepcao') {
      destino = RecepcaoShell(currentUserId: user.id);
    } else {
      destino = MainShell(
        userProfile: user.perfil,
        currentUserId: user.id,
      );
    }

    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => destino),
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isMobile = MediaQuery.of(context).size.width < 600;

    return Scaffold(
      backgroundColor: cs.surfaceContainerLowest,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 8),

                  // ── Cabeçalho ──────────────────────────────────────────
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.orange.shade700,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text(
                          'STAGING',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 11,
                            letterSpacing: 1.2,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        'Villamor CRM',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: cs.onSurface,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 8),

                  // ── Aviso staging ──────────────────────────────────────
                  Container(
                    margin: const EdgeInsets.only(bottom: 24),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.orange.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                          color: Colors.orange.shade300, width: 1),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.science_outlined,
                            size: 18, color: Colors.orange.shade800),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Ambiente de testes — dados aqui não afetam a produção.',
                            style: TextStyle(
                                fontSize: 13,
                                color: Colors.orange.shade900),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // ── Instrução ──────────────────────────────────────────
                  Text(
                    'Selecione o perfil que deseja testar:',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: cs.onSurface,
                    ),
                  ),
                  const SizedBox(height: 14),

                  // ── Grade de usuários ──────────────────────────────────
                  Expanded(
                    child: GridView.builder(
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: isMobile ? 2 : 3,
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                        childAspectRatio: 1.15,
                      ),
                      itemCount: _usuarios.length,
                      itemBuilder: (context, i) =>
                          _UserCard(user: _usuarios[i], onTap: _entrar),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Card de usuário ───────────────────────────────────────────────────────────
class _UserCard extends StatelessWidget {
  final _MockUser user;
  final void Function(BuildContext, _MockUser) onTap;

  const _UserCard({required this.user, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: cs.outlineVariant, width: 1),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => onTap(context, user),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // ── Avatar ─────────────────────────────────────────────────
              CircleAvatar(
                radius: 26,
                backgroundColor: user.cor.withValues(alpha: 0.12),
                child: Icon(user.icone, color: user.cor, size: 26),
              ),
              const SizedBox(height: 10),

              // ── Nome ───────────────────────────────────────────────────
              Text(
                user.nome,
                style: const TextStyle(
                    fontWeight: FontWeight.bold, fontSize: 15),
              ),
              const SizedBox(height: 4),

              // ── Chip de perfil ─────────────────────────────────────────
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: user.cor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  user.perfil,
                  style: TextStyle(
                    fontSize: 11,
                    color: user.cor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(height: 6),

              // ── Descrição ──────────────────────────────────────────────
              Text(
                user.descricao,
                style: TextStyle(
                    fontSize: 11, color: cs.onSurfaceVariant),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

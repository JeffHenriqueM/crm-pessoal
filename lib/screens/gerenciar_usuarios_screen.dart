import 'package:flutter/material.dart';
import '../models/usuario_model.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';

class GerenciarUsuariosScreen extends StatefulWidget {
  /// Perfil do usuário logado — determina o que pode ser alterado.
  final String currentUserPerfil;

  const GerenciarUsuariosScreen({
    super.key,
    required this.currentUserPerfil,
  });

  @override
  State<GerenciarUsuariosScreen> createState() =>
      _GerenciarUsuariosScreenState();
}

class _GerenciarUsuariosScreenState extends State<GerenciarUsuariosScreen> {
  final FirestoreService _firestoreService = FirestoreService();
  final AuthService _authService = AuthService();

  bool get _isSuperAdmin => widget.currentUserPerfil == 'super admin';

  // Super admin pode atribuir qualquer perfil; admin vê todos exceto super admin
  List<String> get _perfisDisponiveis => _isSuperAdmin
      ? ['super admin', 'admin', 'captador', 'vendedor', 'pós-venda', 'financeiro', 'recepcao']
      : ['admin', 'captador', 'vendedor', 'pós-venda', 'financeiro', 'recepcao'];

  // ── Build principal ───────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Gerenciar Usuários')),
      body: StreamBuilder<List<Usuario>>(
        stream: _firestoreService.getTodosUsuariosStream(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Text('Erro ao carregar usuários: ${snapshot.error}'),
            );
          }

          final todos = snapshot.data ?? [];
          final ativos = todos.where((u) => u.ativo).toList();
          final inativos = todos.where((u) => !u.ativo).toList();

          if (todos.isEmpty) {
            return const Center(child: Text('Nenhum usuário cadastrado.'));
          }

          return ListView(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 100),
            children: [
              // ── Seção: Usuários ativos ───────────────────────────────
              _sectionHeader(context, 'Ativos', ativos.length, ativo: true),
              ...ativos.map((u) => _usuarioCard(context, u)),

              // ── Seção: Usuários inativos (se houver) ─────────────────
              if (inativos.isNotEmpty) ...[
                const SizedBox(height: 8),
                _sectionHeader(context, 'Inativos', inativos.length,
                    ativo: false),
                ...inativos.map((u) => _usuarioCard(context, u)),
              ],
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _mostrarDialogoCriarUsuario(context),
        icon: const Icon(Icons.person_add_outlined),
        label: const Text('Novo Usuário'),
      ),
    );
  }

  // ── Header de seção ───────────────────────────────────────────────────────
  Widget _sectionHeader(BuildContext context, String titulo, int count,
      {required bool ativo}) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      child: Row(
        children: [
          Icon(
            ativo ? Icons.check_circle_outline : Icons.block_outlined,
            size: 16,
            color: ativo ? Colors.green.shade700 : cs.outline,
          ),
          const SizedBox(width: 6),
          Text(
            '$titulo ($count)',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: ativo ? Colors.green.shade700 : cs.outline,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }

  // ── Card de usuário ───────────────────────────────────────────────────────
  Widget _usuarioCard(BuildContext context, Usuario u) {
    final cs = Theme.of(context).colorScheme;
    final cor = _corDePerfil(u.perfil, cs);
    final inativo = !u.ativo;

    return Opacity(
      opacity: inativo ? 0.55 : 1.0,
      child: Card(
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => _mostrarOpcoesUsuario(context, u),
          child: Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                // Avatar
                Stack(
                  children: [
                    CircleAvatar(
                      radius: 22,
                      backgroundColor: cor.withValues(alpha: 0.15),
                      child: Text(
                        u.nome.isNotEmpty
                            ? u.nome[0].toUpperCase()
                            : '?',
                        style: TextStyle(
                          color: cor,
                          fontWeight: FontWeight.bold,
                          fontSize: 17,
                        ),
                      ),
                    ),
                    if (inativo)
                      Positioned(
                        right: 0,
                        bottom: 0,
                        child: Container(
                          width: 14,
                          height: 14,
                          decoration: BoxDecoration(
                            color: cs.outline,
                            shape: BoxShape.circle,
                            border: Border.all(
                                color: cs.surface, width: 2),
                          ),
                          child: const Icon(Icons.block,
                              size: 8, color: Colors.white),
                        ),
                      ),
                  ],
                ),
                const SizedBox(width: 14),

                // Dados
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        u.nome,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: cs.onSurface,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        u.email,
                        style: TextStyle(
                            fontSize: 12, color: cs.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),

                // Chip de perfil
                _chipPerfil(u.perfil, cor),
                const SizedBox(width: 4),
                Icon(Icons.chevron_right, size: 18, color: cs.outline),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _chipPerfil(String perfil, Color cor) {
    final isSuperAdmin = perfil.toLowerCase() == 'super admin';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: cor.withValues(alpha: 0.12),
        border: Border.all(color: cor.withValues(alpha: 0.35)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isSuperAdmin) ...[
            Icon(Icons.workspace_premium_rounded, size: 12, color: cor),
            const SizedBox(width: 4),
          ],
          Text(
            _capitalize(perfil),
            style: TextStyle(
              color: cor,
              fontWeight: FontWeight.w700,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }

  // ── Bottom sheet de opções ────────────────────────────────────────────────
  void _mostrarOpcoesUsuario(BuildContext context, Usuario u) {
    final cs = Theme.of(context).colorScheme;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(0, 8, 0, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: cs.outlineVariant,
                borderRadius: BorderRadius.circular(2),
              ),
            ),

            // Cabeçalho
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
              child: Row(
                children: [
                  CircleAvatar(
                    backgroundColor:
                        _corDePerfil(u.perfil, cs).withValues(alpha: 0.15),
                    child: Text(
                      u.nome[0].toUpperCase(),
                      style: TextStyle(
                        color: _corDePerfil(u.perfil, cs),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(u.nome,
                            style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 15)),
                        Text(u.email,
                            style: TextStyle(
                                fontSize: 12,
                                color: cs.onSurfaceVariant)),
                      ],
                    ),
                  ),
                  _chipPerfil(u.perfil, _corDePerfil(u.perfil, cs)),
                ],
              ),
            ),

            const Divider(height: 24),

            // Opções
            ListTile(
              leading: const Icon(Icons.edit_outlined),
              title: Text(_isSuperAdmin ? 'Editar Usuário (nome + perfil)' : 'Editar Usuário'),
              subtitle: _isSuperAdmin
                  ? null
                  : Text(
                      'Somente Super Admin pode alterar perfis',
                      style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant),
                    ),
              onTap: () {
                Navigator.of(ctx).pop();
                _mostrarDialogoEditarUsuario(context, u);
              },
            ),
            ListTile(
              leading: const Icon(Icons.lock_reset_outlined),
              title: const Text('Enviar link de redefinição de senha'),
              subtitle: Text(
                'Envia e-mail para ${u.email}',
                style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant),
              ),
              onTap: () {
                Navigator.of(ctx).pop();
                _confirmarResetSenha(context, u);
              },
            ),
            if (u.ativo)
              ListTile(
                leading: Icon(Icons.block_outlined, color: cs.error),
                title: Text('Desativar acesso',
                    style: TextStyle(color: cs.error)),
                subtitle: Text(
                  'Impede o login deste usuário',
                  style:
                      TextStyle(fontSize: 11, color: cs.onSurfaceVariant),
                ),
                onTap: () {
                  Navigator.of(ctx).pop();
                  _confirmarAlterarStatus(context, u, ativar: false);
                },
              )
            else
              ListTile(
                leading: Icon(Icons.check_circle_outline,
                    color: Colors.green.shade700),
                title: Text('Reativar acesso',
                    style: TextStyle(color: Colors.green.shade700)),
                onTap: () {
                  Navigator.of(ctx).pop();
                  _confirmarAlterarStatus(context, u, ativar: true);
                },
              ),
          ],
        ),
      ),
    );
  }

  // ── Diálogo: Criar usuário ────────────────────────────────────────────────
  void _mostrarDialogoCriarUsuario(BuildContext context) {
    final formKey = GlobalKey<FormState>();
    final nomeCtrl = TextEditingController();
    final emailCtrl = TextEditingController();
    final senhaCtrl = TextEditingController();
    String perfilSelecionado = 'vendedor';
    bool senhaVisivel = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Row(
            children: [
              Icon(Icons.person_add_outlined,
                  color: Theme.of(ctx).colorScheme.primary),
              const SizedBox(width: 10),
              const Text('Novo Usuário'),
            ],
          ),
          content: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: nomeCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Nome Completo',
                      prefixIcon: Icon(Icons.person_outlined),
                    ),
                    textCapitalization: TextCapitalization.words,
                    validator: (v) => (v?.trim().isEmpty ?? true)
                        ? 'Nome é obrigatório'
                        : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: emailCtrl,
                    decoration: const InputDecoration(
                      labelText: 'E-mail',
                      prefixIcon: Icon(Icons.email_outlined),
                    ),
                    keyboardType: TextInputType.emailAddress,
                    validator: (v) => (v?.contains('@') != true)
                        ? 'E-mail inválido'
                        : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: senhaCtrl,
                    decoration: InputDecoration(
                      labelText: 'Senha inicial (mín. 6 caracteres)',
                      prefixIcon: const Icon(Icons.lock_outlined),
                      suffixIcon: IconButton(
                        icon: Icon(senhaVisivel
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined),
                        onPressed: () => setDialogState(
                            () => senhaVisivel = !senhaVisivel),
                      ),
                    ),
                    obscureText: !senhaVisivel,
                    validator: (v) => ((v?.length ?? 0) < 6)
                        ? 'Mínimo 6 caracteres'
                        : null,
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: perfilSelecionado,
                    decoration: const InputDecoration(
                      labelText: 'Perfil',
                      prefixIcon: Icon(Icons.badge_outlined),
                    ),
                    items: _perfisDisponiveis
                        .map((p) => DropdownMenuItem(
                              value: p,
                              child: Text(_capitalize(p)),
                            ))
                        .toList(),
                    onChanged: (v) {
                      if (v != null) {
                        setDialogState(() => perfilSelecionado = v);
                      }
                    },
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancelar'),
            ),
            FilledButton.icon(
              icon: const Icon(Icons.person_add_outlined, size: 18),
              label: const Text('Criar'),
              onPressed: () async {
                if (!formKey.currentState!.validate()) return;
                Navigator.of(ctx).pop();
                await _runWithLoading(
                  context,
                  () => _authService.criarNovoUsuario(
                    email: emailCtrl.text.trim(),
                    senha: senhaCtrl.text.trim(),
                    nome: nomeCtrl.text.trim(),
                    perfil: perfilSelecionado,
                  ),
                  successMsg: 'Usuário criado com sucesso!',
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  // ── Diálogo: Editar usuário ────────────────────────────────────────────────
  void _mostrarDialogoEditarUsuario(BuildContext context, Usuario usuario) {
    final formKey = GlobalKey<FormState>();
    final nomeCtrl = TextEditingController(text: usuario.nome);
    String perfilSelecionado = usuario.perfil;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Row(
            children: [
              Icon(Icons.edit_outlined,
                  color: Theme.of(ctx).colorScheme.primary),
              const SizedBox(width: 10),
              const Text('Editar Usuário'),
            ],
          ),
          content: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: nomeCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Nome Completo',
                      prefixIcon: Icon(Icons.person_outlined),
                    ),
                    textCapitalization: TextCapitalization.words,
                    validator: (v) => (v?.trim().isEmpty ?? true)
                        ? 'Campo obrigatório'
                        : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    initialValue: usuario.email,
                    decoration: InputDecoration(
                      labelText: 'E-mail',
                      prefixIcon: const Icon(Icons.email_outlined),
                      suffixIcon: Tooltip(
                        message: 'E-mail não pode ser alterado',
                        child: Icon(Icons.info_outline,
                            size: 18,
                            color: Theme.of(ctx)
                                .colorScheme
                                .onSurfaceVariant),
                      ),
                    ),
                    readOnly: true,
                  ),
                  const SizedBox(height: 12),
                  // Perfil — editável só para super admin
                  if (_isSuperAdmin)
                    DropdownButtonFormField<String>(
                      value: perfilSelecionado,
                      decoration: const InputDecoration(
                        labelText: 'Perfil',
                        prefixIcon: Icon(Icons.badge_outlined),
                      ),
                      items: _perfisDisponiveis
                          .map((p) => DropdownMenuItem(
                                value: p,
                                child: Text(_capitalize(p)),
                              ))
                          .toList(),
                      onChanged: (v) {
                        if (v != null) {
                          setDialogState(() => perfilSelecionado = v);
                        }
                      },
                    )
                  else
                    InputDecorator(
                      decoration: InputDecoration(
                        labelText: 'Perfil',
                        prefixIcon: const Icon(Icons.badge_outlined),
                        suffixIcon: Tooltip(
                          message: 'Somente Super Admin pode alterar perfis',
                          child: Icon(Icons.lock_outline,
                              size: 18,
                              color: Theme.of(ctx).colorScheme.onSurfaceVariant),
                        ),
                      ),
                      child: Text(
                        _capitalize(perfilSelecionado),
                        style: TextStyle(
                          color: Theme.of(ctx).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancelar'),
            ),
            FilledButton.icon(
              icon: const Icon(Icons.save_outlined, size: 18),
              label: const Text('Salvar'),
              onPressed: () async {
                if (!formKey.currentState!.validate()) return;
                Navigator.of(ctx).pop();
                await _runWithLoading(
                  context,
                  () => _firestoreService.atualizarUsuario(
                    id: usuario.id,
                    nome: nomeCtrl.text.trim(),
                    perfil: perfilSelecionado,
                  ),
                  successMsg: 'Usuário atualizado com sucesso!',
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  // ── Confirmação: Redefinir senha ──────────────────────────────────────────
  void _confirmarResetSenha(BuildContext context, Usuario u) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.lock_reset_outlined),
            SizedBox(width: 10),
            Text('Redefinir Senha'),
          ],
        ),
        content: Text(
          'Um link de redefinição de senha será enviado para:\n\n${u.email}\n\nO usuário precisará acessar o e-mail para criar uma nova senha.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancelar'),
          ),
          FilledButton.icon(
            icon: const Icon(Icons.send_outlined, size: 18),
            label: const Text('Enviar link'),
            onPressed: () async {
              Navigator.of(ctx).pop();
              await _runWithLoading(
                context,
                () => _authService.adminEnviarResetSenha(u.email),
                successMsg: 'Link enviado para ${u.email}',
              );
            },
          ),
        ],
      ),
    );
  }

  // ── Confirmação: Ativar / Desativar ───────────────────────────────────────
  void _confirmarAlterarStatus(BuildContext context, Usuario u,
      {required bool ativar}) {
    final cs = Theme.of(context).colorScheme;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            Icon(
              ativar
                  ? Icons.check_circle_outline
                  : Icons.block_outlined,
              color: ativar ? Colors.green.shade700 : cs.error,
            ),
            const SizedBox(width: 10),
            Text(ativar ? 'Reativar Acesso' : 'Desativar Acesso'),
          ],
        ),
        content: Text(
          ativar
              ? '${u.nome} poderá fazer login novamente.'
              : '${u.nome} não conseguirá mais fazer login no sistema. Os dados do usuário serão mantidos.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: ativar
                ? FilledButton.styleFrom(
                    backgroundColor: Colors.green.shade700,
                    foregroundColor: Colors.white,
                  )
                : FilledButton.styleFrom(
                    backgroundColor: cs.error,
                    foregroundColor: cs.onError,
                  ),
            onPressed: () async {
              Navigator.of(ctx).pop();
              await _runWithLoading(
                context,
                () => _firestoreService.alterarStatusUsuario(
                  id: u.id,
                  ativo: ativar,
                ),
                successMsg: ativar
                    ? '${u.nome} foi reativado.'
                    : '${u.nome} foi desativado.',
              );
            },
            child: Text(ativar ? 'Reativar' : 'Desativar'),
          ),
        ],
      ),
    );
  }

  // ── Loading helper ─────────────────────────────────────────────────────────
  Future<void> _runWithLoading(
    BuildContext context,
    Future<void> Function() action, {
    required String successMsg,
  }) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );
    try {
      await action();
      if (context.mounted) {
        Navigator.of(context).pop(); // fecha loading
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(successMsg),
            backgroundColor: Colors.green.shade700,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.of(context).pop(); // fecha loading
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro: ${e.toString()}'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  // ── Helpers ───────────────────────────────────────────────────────────────
  Color _corDePerfil(String perfil, ColorScheme cs) {
    switch (perfil.toLowerCase()) {
      case 'super admin':
        return const Color(0xFFB8860B); // dourado
      case 'admin':
        return Colors.deepOrange.shade700;
      case 'captador':
        return Colors.green.shade600;
      case 'vendedor':
        return cs.primary;
      case 'pós-venda':
        return Colors.orange.shade700;
      case 'financeiro':
        return Colors.purple.shade600;
      case 'recepcao':
        return Colors.teal.shade600;
      default:
        return cs.outline;
    }
  }

  String _capitalize(String s) =>
      s.isNotEmpty ? s[0].toUpperCase() + s.substring(1) : s;
}

import 'package:flutter/material.dart';
import '../models/usuario_model.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';

class GerenciarUsuariosScreen extends StatefulWidget {
  const GerenciarUsuariosScreen({super.key});

  @override
  State<GerenciarUsuariosScreen> createState() =>
      _GerenciarUsuariosScreenState();
}

class _GerenciarUsuariosScreenState extends State<GerenciarUsuariosScreen> {
  final FirestoreService _firestoreService = FirestoreService();
  final AuthService _authService = AuthService();

  static const _perfisDisponiveis = [
    'admin',
    'captador',
    'vendedor',
    'pós-venda',
    'financeiro',
  ];

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Gerenciar Usuários')),
      body: FutureBuilder<List<Usuario>>(
        future: _firestoreService.getTodosUsuarios(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError ||
              !snapshot.hasData ||
              snapshot.data!.isEmpty) {
            return const Center(
                child: Text('Nenhum usuário encontrado.'));
          }

          final usuarios = snapshot.data!;
          return ListView.separated(
            padding: const EdgeInsets.all(12),
            itemCount: usuarios.length,
            separatorBuilder: (_, __) => const SizedBox(height: 4),
            itemBuilder: (context, index) {
              final u = usuarios[index];
              return Card(
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: _corDePerfil(u.perfil, cs).withValues(alpha: 0.15),
                    child: Icon(
                      _iconeDePerfil(u.perfil),
                      color: _corDePerfil(u.perfil, cs),
                      size: 20,
                    ),
                  ),
                  title: Text(u.nome,
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text(u.email,
                      style: TextStyle(color: cs.outline, fontSize: 12)),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Chip(
                        label: Text(_capitalize(u.perfil)),
                        backgroundColor:
                            _corDePerfil(u.perfil, cs).withValues(alpha: 0.15),
                        side: BorderSide(
                            color: _corDePerfil(u.perfil, cs).withValues(alpha: 0.4)),
                        labelStyle: TextStyle(
                          color: _corDePerfil(u.perfil, cs),
                          fontWeight: FontWeight.w600,
                          fontSize: 11,
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                      ),
                      const SizedBox(width: 4),
                      IconButton(
                        icon: const Icon(Icons.edit_outlined),
                        tooltip: 'Editar',
                        onPressed: () =>
                            _mostrarDialogoEditarUsuario(context, u),
                      ),
                    ],
                  ),
                ),
              );
            },
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

  Color _corDePerfil(String perfil, ColorScheme cs) {
    switch (perfil.toLowerCase()) {
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
      default:
        return cs.outline;
    }
  }

  IconData _iconeDePerfil(String perfil) {
    switch (perfil.toLowerCase()) {
      case 'admin':
        return Icons.admin_panel_settings_outlined;
      case 'captador':
        return Icons.person_add_alt_1_outlined;
      case 'vendedor':
        return Icons.store_outlined;
      case 'pós-venda':
        return Icons.support_agent_outlined;
      case 'financeiro':
        return Icons.account_balance_outlined;
      default:
        return Icons.person_outline;
    }
  }

  String _capitalize(String s) =>
      s.isNotEmpty ? s[0].toUpperCase() + s.substring(1) : s;

  void _mostrarDialogoCriarUsuario(BuildContext context) {
    final formKey = GlobalKey<FormState>();
    final nomeCtrl = TextEditingController();
    final emailCtrl = TextEditingController();
    final senhaCtrl = TextEditingController();
    String perfilSelecionado = 'vendedor';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Novo Usuário'),
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
                    validator: (v) =>
                        (v?.trim().isEmpty ?? true) ? 'Nome é obrigatório' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: emailCtrl,
                    decoration: const InputDecoration(
                      labelText: 'E-mail',
                      prefixIcon: Icon(Icons.email_outlined),
                    ),
                    keyboardType: TextInputType.emailAddress,
                    validator: (v) =>
                        (v?.contains('@') != true) ? 'E-mail inválido' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: senhaCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Senha (mín. 6 caracteres)',
                      prefixIcon: Icon(Icons.lock_outlined),
                    ),
                    obscureText: true,
                    validator: (v) =>
                        ((v?.length ?? 0) < 6) ? 'Senha muito curta' : null,
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
                      if (v != null) setDialogState(() => perfilSelecionado = v);
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
            FilledButton(
              onPressed: () async {
                if (!formKey.currentState!.validate()) return;
                Navigator.of(ctx).pop();
                await _runWithLoading(context, () async {
                  await _authService.criarNovoUsuario(
                    email: emailCtrl.text.trim(),
                    senha: senhaCtrl.text.trim(),
                    nome: nomeCtrl.text.trim(),
                    perfil: perfilSelecionado,
                  );
                  if (mounted) setState(() {});
                });
              },
              child: const Text('Criar'),
            ),
          ],
        ),
      ),
    );
  }

  void _mostrarDialogoEditarUsuario(BuildContext context, Usuario usuario) {
    final formKey = GlobalKey<FormState>();
    final nomeCtrl = TextEditingController(text: usuario.nome);
    String perfilSelecionado = usuario.perfil;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Editar Usuário'),
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
                    validator: (v) =>
                        (v?.trim().isEmpty ?? true) ? 'Campo obrigatório' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    initialValue: usuario.email,
                    decoration: const InputDecoration(
                      labelText: 'E-mail',
                      prefixIcon: Icon(Icons.email_outlined),
                    ),
                    readOnly: true,
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
                      if (v != null) setDialogState(() => perfilSelecionado = v);
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
            FilledButton(
              onPressed: () async {
                if (!formKey.currentState!.validate()) return;
                Navigator.of(ctx).pop();
                await _runWithLoading(context, () async {
                  await _firestoreService.atualizarUsuario(
                    id: usuario.id,
                    nome: nomeCtrl.text.trim(),
                    perfil: perfilSelecionado,
                  );
                  if (mounted) setState(() {});
                });
              },
              child: const Text('Salvar'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _runWithLoading(
      BuildContext context, Future<void> Function() action) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );
    try {
      await action();
      if (context.mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Operação concluída com sucesso!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro: ${e.toString()}'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }
}

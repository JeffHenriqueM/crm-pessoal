import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../theme/theme_controller.dart';

class TelaLoginScreen extends StatefulWidget {
  const TelaLoginScreen({super.key});

  @override
  State<TelaLoginScreen> createState() => _TelaLoginScreenState();
}

class _TelaLoginScreenState extends State<TelaLoginScreen> {
  final AuthService _authService = AuthService();
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _senhaVisivel = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    final error = await _authService.signIn(
      _emailController.text.trim(),
      _passwordController.text.trim(),
    );
    if (!mounted) return;
    setState(() => _isLoading = false);
    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    }
  }

  void _mostrarDialogoRedefinirSenha() {
    final emailCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Redefinir Senha'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Digite seu e-mail para receber o link de redefinição.'),
            const SizedBox(height: 16),
            TextField(
              controller: emailCtrl,
              decoration: const InputDecoration(
                labelText: 'E-mail',
                prefixIcon: Icon(Icons.email_outlined),
              ),
              keyboardType: TextInputType.emailAddress,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () async {
              final email = emailCtrl.text.trim();
              if (email.isEmpty || !email.contains('@')) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Digite um e-mail válido.'),
                    backgroundColor: Colors.orange,
                  ),
                );
                return;
              }
              Navigator.of(ctx).pop();
              setState(() => _isLoading = true);
              final erro = await _authService.enviarEmailRedefinicaoSenha(email);
              if (!mounted) return;
              setState(() => _isLoading = false);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(erro ?? 'Link enviado para o seu e-mail!'),
                  backgroundColor: erro != null
                      ? Theme.of(context).colorScheme.error
                      : Colors.green.shade700,
                ),
              );
            },
            child: const Text('Enviar'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final isWide = width >= 700;

    return Scaffold(
      body: isWide ? _buildWideLayout() : _buildNarrowLayout(),
    );
  }

  // ── Layout wide (desktop) ────────────────────────────────────────────────
  Widget _buildWideLayout() {
    return Row(
      children: [
        // Painel esquerdo — brand
        Expanded(
          flex: 5,
          child: _buildBrandPanel(),
        ),
        // Painel direito — formulário
        Expanded(
          flex: 4,
          child: _buildFormPanel(centered: true),
        ),
      ],
    );
  }

  // ── Layout narrow (mobile) ───────────────────────────────────────────────
  Widget _buildNarrowLayout() {
    final cs = Theme.of(context).colorScheme;
    final isDark = ThemeController.instance.isDark;

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: isDark
              ? [const Color(0xFF1F2937), const Color(0xFF111827)]
              : [const Color(0xFF1565C0), const Color(0xFF0D47A1)],
        ),
      ),
      child: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                child: Column(
                  children: [
                    const SizedBox(height: 24),
                    // Logo
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: Image.asset(
                        'assets/images/logo.png',
                        height: 80,
                        filterQuality: FilterQuality.high,
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'Villamor CRM',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.3,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Sistema de gestão comercial',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.75),
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 36),
                    // Card formulário
                    Card(
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: _buildForm(cs),
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Painel de marca (lado esquerdo no desktop) ───────────────────────────
  Widget _buildBrandPanel() {
    final isDark = ThemeController.instance.isDark;
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? [const Color(0xFF1F2937), const Color(0xFF111827)]
              : [const Color(0xFF1565C0), const Color(0xFF0D47A1)],
        ),
      ),
      child: SafeArea(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Logo com fundo circular suave
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Image.asset(
                'assets/images/logo.png',
                height: 100,
                filterQuality: FilterQuality.high,
              ),
            ),
            const SizedBox(height: 32),
            const Text(
              'Villamor CRM',
              style: TextStyle(
                color: Colors.white,
                fontSize: 34,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Sistema de gestão comercial',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.75),
                fontSize: 15,
                letterSpacing: 0.2,
              ),
            ),
            const SizedBox(height: 48),
            // Ícones decorativos
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 48),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _brandFeature(Icons.people_outline, 'Clientes'),
                  _brandFeature(Icons.bar_chart_rounded, 'Dashboard'),
                  _brandFeature(Icons.calendar_today_outlined, 'Agenda'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _brandFeature(IconData icon, String label) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(icon, color: Colors.white, size: 26),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.8),
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  // ── Painel do formulário (lado direito no desktop) ───────────────────────
  Widget _buildFormPanel({required bool centered}) {
    final cs = Theme.of(context).colorScheme;

    Widget content = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Cabeçalho
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Bem-vindo(a)',
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  color: cs.onSurface,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Faça login para continuar',
                style: TextStyle(fontSize: 14, color: cs.onSurfaceVariant),
              ),
            ],
          ),
          const SizedBox(height: 36),
          _buildForm(cs),
        ],
      ),
    );

    if (centered) {
      return Container(
        color: cs.surface,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: content,
          ),
        ),
      );
    }
    return content;
  }

  // ── Formulário ────────────────────────────────────────────────────────────
  Widget _buildForm(ColorScheme cs) {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextFormField(
            controller: _emailController,
            decoration: const InputDecoration(
              labelText: 'E-mail',
              prefixIcon: Icon(Icons.email_outlined),
            ),
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
            validator: (v) =>
                (v == null || !v.contains('@')) ? 'E-mail inválido.' : null,
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: _passwordController,
            decoration: InputDecoration(
              labelText: 'Senha',
              prefixIcon: const Icon(Icons.lock_outlined),
              suffixIcon: IconButton(
                icon: Icon(
                  _senhaVisivel
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                ),
                onPressed: () =>
                    setState(() => _senhaVisivel = !_senhaVisivel),
              ),
            ),
            obscureText: !_senhaVisivel,
            textInputAction: TextInputAction.done,
            onFieldSubmitted: (_) => _submit(),
            validator: (v) =>
                (v == null || v.length < 6) ? 'Mínimo 6 caracteres.' : null,
          ),
          const SizedBox(height: 24),
          if (_isLoading)
            const Center(child: CircularProgressIndicator())
          else
            FilledButton(
              onPressed: _submit,
              style: FilledButton.styleFrom(
                minimumSize: const Size(double.infinity, 52),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                'Entrar',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
            ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: _isLoading ? null : _mostrarDialogoRedefinirSenha,
            child: const Text('Esqueceu a senha?'),
          ),
        ],
      ),
    );
  }
}


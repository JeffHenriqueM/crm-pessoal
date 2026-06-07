import 'package:flutter/material.dart';
import '../theme/theme_controller.dart';
import 'modelos_mensagem_screen.dart';

class ConfiguracoesScreen extends StatelessWidget {
  const ConfiguracoesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Configurações'),
        centerTitle: false,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ── Aparência ─────────────────────────────────────────────────────
          _secaoTitulo(context, 'Aparência', Icons.palette_outlined),
          const SizedBox(height: 12),
          AnimatedBuilder(
            animation: ThemeController.instance,
            builder: (_, __) {
              final isDark = ThemeController.instance.isDark;

              return Row(
                children: [
                  // Card Light Mode
                  Expanded(
                    child: _ModeCard(
                      icon: Icons.light_mode_rounded,
                      label: 'Light Mode',
                      active: !isDark,
                      onTap: isDark ? ThemeController.instance.toggle : null,
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Card Dark Mode
                  Expanded(
                    child: _ModeCard(
                      icon: Icons.dark_mode_rounded,
                      label: 'Dark Mode',
                      active: isDark,
                      onTap: !isDark ? ThemeController.instance.toggle : null,
                    ),
                  ),
                ],
              );
            },
          ),

          const SizedBox(height: 32),

          // ── Mensagens (WhatsApp) ──────────────────────────────────────────
          _secaoTitulo(context, 'Mensagens', Icons.message_outlined),
          const SizedBox(height: 8),
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.5)),
            ),
            child: ListTile(
              leading: Icon(Icons.chat_outlined, color: cs.primary),
              title: const Text('Modelos de mensagem'),
              subtitle: const Text(
                  'Crie mensagens prontas para o WhatsApp (padrão e individuais)'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(
                    builder: (_) => const ModelosMensagemScreen()),
              ),
            ),
          ),

          const SizedBox(height: 32),

          // ── Placeholder para futuras configurações ────────────────────────
          _secaoTitulo(context, 'Notificações', Icons.notifications_outlined),
          const SizedBox(height: 8),
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.5)),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Icon(Icons.construction_outlined,
                      size: 18, color: cs.outline),
                  const SizedBox(width: 10),
                  Text(
                    'Configurações de notificação — em breve',
                    style: TextStyle(fontSize: 13, color: cs.outline),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 24),

          _secaoTitulo(context, 'Sistema', Icons.tune_outlined),
          const SizedBox(height: 8),
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.5)),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Icon(Icons.construction_outlined,
                      size: 18, color: cs.outline),
                  const SizedBox(width: 10),
                  Text(
                    'Preferências do sistema — em breve',
                    style: TextStyle(fontSize: 13, color: cs.outline),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _secaoTitulo(BuildContext context, String titulo, IconData icon) {
    final cs = Theme.of(context).colorScheme;
    return Row(
      children: [
        Icon(icon, size: 16, color: cs.primary),
        const SizedBox(width: 6),
        Text(
          titulo,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: cs.primary,
            letterSpacing: 0.5,
          ),
        ),
      ],
    );
  }
}

// ── Card de modo (Light / Dark) ───────────────────────────────────────────────
class _ModeCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback? onTap;

  const _ModeCard({
    required this.icon,
    required this.label,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
        decoration: BoxDecoration(
          color: active ? cs.primaryContainer : cs.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: active ? cs.primary : cs.outlineVariant,
            width: active ? 2 : 1,
          ),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              size: 36,
              color: active ? cs.primary : cs.onSurfaceVariant,
            ),
            const SizedBox(height: 10),
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: active ? cs.primary : cs.onSurfaceVariant,
              ),
            ),
            if (active) ...[
              const SizedBox(height: 6),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                decoration: BoxDecoration(
                  color: cs.primary,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  'Ativo',
                  style: TextStyle(
                    fontSize: 11,
                    color: cs.onPrimary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

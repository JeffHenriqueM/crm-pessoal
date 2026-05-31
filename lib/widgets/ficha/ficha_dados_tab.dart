import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/fase_enum.dart';
import '../../models/usuario_model.dart';

/// Aba "Dados" da ficha do cliente — puro formulário, sem lógica de serviço.
/// Todo o estado e callbacks ficam no [FichaClienteScreen].
class FichaDadosTab extends StatelessWidget {
  // ── Form key ──────────────────────────────────────────────────────────────────
  final GlobalKey<FormState> formKey;

  // ── Controllers ───────────────────────────────────────────────────────────────
  final TextEditingController nomeCtrl;
  final TextEditingController nomeParceiroCtrl;
  final TextEditingController telefone1Ctrl;
  final TextEditingController telefone2Ctrl;
  final TextEditingController motivoPerdaDescCtrl;
  final TextEditingController brindeCtrl;

  // ── Valores controlados ────────────────────────────────────────────────────────
  final String tipo;
  final FaseCliente fase;
  final String? origem;
  final String? motivoPerdaDropdown;
  final DateTime? dataCaptacao;
  final DateTime? proximoContato;
  final DateTime? dataVisita;
  final bool tentouSalvar;
  final bool salvandoDados;
  final bool carregandoUsuarios;
  final bool isNovo;

  // ── Listas e objetos ──────────────────────────────────────────────────────────
  final List<Usuario> usuarios;
  final Usuario? captador;
  final Usuario? vendedor;

  // ── Callbacks ─────────────────────────────────────────────────────────────────
  final ValueChanged<String> onTipoChanged;
  final ValueChanged<String?> onOrigemChanged;
  final ValueChanged<FaseCliente?> onFaseChanged;
  final ValueChanged<String?> onMotivoPerdaDropdownChanged;
  final ValueChanged<Usuario?> onCaptadorChanged;
  final ValueChanged<Usuario?> onVendedorChanged;
  final VoidCallback onSelectDataCaptacao;
  final VoidCallback onClearDataCaptacao;
  final VoidCallback onSelectProximoContato;
  final VoidCallback onClearProximoContato;
  final VoidCallback onSelectDataVisita;
  final VoidCallback onClearDataVisita;
  final VoidCallback onSalvar;
  final VoidCallback onNomeChanged; // para atualizar título do AppBar

  static const _origens = ['Presencial', 'WhatsApp', 'Instagram'];
  static const _motivos = [
    'Sem interesse',
    'Sem retorno',
    'Financeiro',
    'Vieram pelo brinde/voucher',
    'Não conhecem a Villamor',
    'Perfil Inadequado',
    'Quer decidir depois',
    'Proposta não aprovada',
    'Outro',
  ];

  const FichaDadosTab({
    super.key,
    required this.formKey,
    required this.nomeCtrl,
    required this.nomeParceiroCtrl,
    required this.telefone1Ctrl,
    required this.telefone2Ctrl,
    required this.motivoPerdaDescCtrl,
    required this.brindeCtrl,
    required this.tipo,
    required this.fase,
    required this.origem,
    required this.motivoPerdaDropdown,
    required this.dataCaptacao,
    required this.proximoContato,
    required this.dataVisita,
    required this.tentouSalvar,
    required this.salvandoDados,
    required this.carregandoUsuarios,
    required this.isNovo,
    required this.usuarios,
    required this.captador,
    required this.vendedor,
    required this.onTipoChanged,
    required this.onOrigemChanged,
    required this.onFaseChanged,
    required this.onMotivoPerdaDropdownChanged,
    required this.onCaptadorChanged,
    required this.onVendedorChanged,
    required this.onSelectDataCaptacao,
    required this.onClearDataCaptacao,
    required this.onSelectProximoContato,
    required this.onClearProximoContato,
    required this.onSelectDataVisita,
    required this.onClearDataVisita,
    required this.onSalvar,
    required this.onNomeChanged,
  });

  @override
  Widget build(BuildContext context) {
    if (carregandoUsuarios) {
      return const Center(child: CircularProgressIndicator());
    }
    final cs = Theme.of(context).colorScheme;

    return Form(
      key: formKey,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          // ── Dados Principais ──────────────────────────────────────────────────
          _sectionTitle(context, 'Dados Principais'),
          const SizedBox(height: 12),
          TextFormField(
            controller: nomeCtrl,
            decoration: const InputDecoration(
              labelText: 'Nome Completo *',
              prefixIcon: Icon(Icons.person_outlined),
            ),
            textCapitalization: TextCapitalization.words,
            onChanged: (_) => onNomeChanged(),
            validator: (v) =>
                (v?.trim().isEmpty ?? true) ? 'Nome é obrigatório.' : null,
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            value: tipo,
            decoration: const InputDecoration(
              labelText: 'Tipo de Cliente',
              prefixIcon: Icon(Icons.group_outlined),
            ),
            items: ['Individual', 'Casal']
                .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                .toList(),
            onChanged: (v) {
              if (v != null) onTipoChanged(v);
            },
          ),
          if (tipo == 'Casal') ...[
            const SizedBox(height: 12),
            TextFormField(
              controller: nomeParceiroCtrl,
              decoration: const InputDecoration(
                labelText: 'Nome do Cônjuge / Parceiro(a)',
                prefixIcon: Icon(Icons.favorite_border),
              ),
              textCapitalization: TextCapitalization.words,
            ),
          ],
          const SizedBox(height: 12),
          TextFormField(
            controller: telefone1Ctrl,
            decoration: const InputDecoration(
              labelText: 'Telefone 1',
              prefixIcon: Icon(Icons.phone_outlined),
              hintText: '(XX) XXXXX-XXXX ou +55 11 99999-9999',
            ),
            keyboardType: TextInputType.phone,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: telefone2Ctrl,
            decoration: const InputDecoration(
              labelText: 'Telefone 2 (opcional)',
              prefixIcon: Icon(Icons.phone_outlined),
              hintText: '(XX) XXXXX-XXXX ou +55 11 99999-9999',
            ),
            keyboardType: TextInputType.phone,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: brindeCtrl,
            decoration: const InputDecoration(
              labelText: 'Brinde (opcional)',
              prefixIcon: Icon(Icons.card_giftcard_outlined),
            ),
            textCapitalization: TextCapitalization.sentences,
          ),

          // ── Origem e Fase ─────────────────────────────────────────────────────
          const SizedBox(height: 24),
          _sectionTitle(context, 'Origem e Fase'),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            value: origem,
            isExpanded: true,
            decoration: const InputDecoration(
              labelText: 'Origem *',
              prefixIcon: Icon(Icons.public_outlined),
            ),
            hint: const Text('Selecione a origem'),
            validator: (v) => v == null ? 'A origem é obrigatória.' : null,
            items: _origens
                .map((o) => DropdownMenuItem(value: o, child: Text(o)))
                .toList(),
            onChanged: onOrigemChanged,
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<FaseCliente>(
            value: fase,
            decoration: const InputDecoration(
              labelText: 'Fase no Funil',
              prefixIcon: Icon(Icons.flag_outlined),
            ),
            items: FaseCliente.values
                .map((f) => DropdownMenuItem(value: f, child: Text(f.nomeDisplay)))
                .toList(),
            onChanged: onFaseChanged,
          ),
          if (fase == FaseCliente.perdido) ...[
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: motivoPerdaDropdown,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'Motivo da Perda *',
                prefixIcon: Icon(Icons.mood_bad_outlined),
              ),
              hint: const Text('Selecione o motivo'),
              validator: (v) => v == null ? 'Selecione o motivo da perda.' : null,
              items: _motivos
                  .map((m) => DropdownMenuItem(value: m, child: Text(m)))
                  .toList(),
              onChanged: onMotivoPerdaDropdownChanged,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: motivoPerdaDescCtrl,
              decoration: const InputDecoration(
                labelText: 'Detalhe do Motivo (opcional)',
                prefixIcon: Icon(Icons.notes_outlined),
              ),
              maxLines: 2,
            ),
          ],

          // ── Equipe Responsável ────────────────────────────────────────────────
          const SizedBox(height: 24),
          _sectionTitle(context, 'Equipe Responsável'),
          const SizedBox(height: 12),
          // Garante que o value passado ao Dropdown seja NULL quando o usuário
          // não existe na lista — evita assert do Flutter em release e o estado
          // inconsistente que impede edição.
          Builder(builder: (ctx) {
            final captadorSafe = usuarios.any((u) => u == captador) ? captador : null;
            return DropdownButtonFormField<Usuario>(
              // key força reconstrução completa quando o captador muda,
              // garantindo que o FormField interno reflita o novo valor.
              key: ValueKey('captador_${captadorSafe?.id ?? 'none'}'),
              value: captadorSafe,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'Captador *',
                prefixIcon: Icon(Icons.person_add_alt_1_outlined),
              ),
              hint: const Text('Quem captou o lead?'),
              validator: (v) => v == null ? 'Informe o captador.' : null,
              items: usuarios
                  .map((u) => DropdownMenuItem(value: u, child: Text(u.nome)))
                  .toList(),
              onChanged: onCaptadorChanged,
            );
          }),
          const SizedBox(height: 12),
          Builder(builder: (ctx) {
            final vendedorSafe = usuarios.any((u) => u == vendedor) ? vendedor : null;
            return DropdownButtonFormField<Usuario>(
              key: ValueKey('vendedor_${vendedorSafe?.id ?? 'none'}'),
              value: vendedorSafe,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'Vendedor Responsável *',
                prefixIcon: Icon(Icons.store_outlined),
              ),
              hint: const Text('Atribuir a...'),
              validator: (v) => v == null ? 'Selecione um vendedor.' : null,
              items: usuarios
                  .map((u) => DropdownMenuItem(value: u, child: Text(u.nome)))
                  .toList(),
              onChanged: onVendedorChanged,
            );
          }),

          // ── Datas ─────────────────────────────────────────────────────────────
          const SizedBox(height: 24),
          _sectionTitle(context, 'Datas'),
          const SizedBox(height: 8),
          _buildDateTile(
            context,
            'Data da Captação *',
            dataCaptacao,
            Icons.person_add_alt_1_outlined,
            onSelectDataCaptacao,
            onClearDataCaptacao,
            obrigatorio: true,
          ),
          if (tentouSalvar && dataCaptacao == null)
            Padding(
              padding: const EdgeInsets.only(left: 12, top: 4, bottom: 4),
              child: Text(
                'Data da Captação é obrigatória.',
                style: TextStyle(color: cs.error, fontSize: 12),
              ),
            ),
          const SizedBox(height: 8),
          _buildDateTile(
            context,
            'Próximo Contato',
            proximoContato,
            Icons.phone_in_talk_outlined,
            onSelectProximoContato,
            onClearProximoContato,
          ),
          const SizedBox(height: 8),
          _buildDateTile(
            context,
            'Data da Visita',
            dataVisita,
            Icons.location_on_outlined,
            onSelectDataVisita,
            onClearDataVisita,
          ),

          // ── Botão Salvar ──────────────────────────────────────────────────────
          const SizedBox(height: 32),
          FilledButton.icon(
            onPressed: salvandoDados ? null : onSalvar,
            icon: salvandoDados
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white),
                  )
                : const Icon(Icons.save_outlined),
            label: Text(
              isNovo ? 'Criar Cliente' : 'Salvar Alterações',
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
            ),
            style: FilledButton.styleFrom(
                minimumSize: const Size(double.infinity, 52)),
          ),
        ],
      ),
    );
  }

  // ── Helpers ───────────────────────────────────────────────────────────────────
  Widget _sectionTitle(BuildContext context, String title) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: Theme.of(context).colorScheme.primary,
        letterSpacing: 0.5,
      ),
    );
  }

  Widget _buildDateTile(
    BuildContext context,
    String label,
    DateTime? date,
    IconData icon,
    VoidCallback onTap,
    VoidCallback onClear, {
    bool obrigatorio = false,
  }) {
    final cs = Theme.of(context).colorScheme;
    final hasError = obrigatorio && tentouSalvar && date == null;
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: hasError
            ? BorderSide(color: cs.error, width: 1.5)
            : BorderSide.none,
      ),
      child: ListTile(
        leading: Icon(icon,
            color: hasError
                ? cs.error
                : (date != null ? cs.primary : cs.outline)),
        title: Text(
          date == null
              ? label
              : '$label: ${DateFormat('dd/MM/yyyy').format(date)}',
          style: TextStyle(
            fontWeight: date != null ? FontWeight.bold : FontWeight.normal,
            color: hasError ? cs.error : null,
          ),
        ),
        trailing: date != null
            ? IconButton(
                icon: Icon(Icons.clear, color: cs.outline),
                onPressed: onClear,
                tooltip: 'Limpar',
              )
            : null,
        onTap: onTap,
      ),
    );
  }
}

// lib/utils/perfis.dart
//
// Helpers de perfil de usuário. Mantém num único lugar a regra de quais
// perfis representam FORÇA DE VENDA (closer + captação), usada para filtrar
// rankings e métricas que só devem contar vendedores e captadores — e não
// admin/financeiro/pós-venda/recepção (ticket #60).

/// Perfis que entram em rankings/métricas de venda.
const Set<String> perfisVendas = {'vendedor', 'captador'};

/// Verdadeiro quando o perfil é de força de venda (vendedor ou captador).
bool ehPerfilVendas(String? perfil) =>
    perfil != null && perfisVendas.contains(perfil);

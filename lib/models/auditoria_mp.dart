// Resultado da verificação (auditoria) do calendário de rodízio da
// Multipropriedade: procura inconsistências (duração, encaixe/sobreposição,
// semanas por ano) nos dados importados.

/// Um achado da auditoria.
class AchadoAuditoria {
  final String categoria; // 'Duração' | 'Encaixe' | 'Semanas/ano'
  final String chave; // ex.: 'bronze|segunda' ou 'ouro'
  final String descricao; // texto legível
  final int ocorrencias;

  const AchadoAuditoria({
    required this.categoria,
    required this.chave,
    required this.descricao,
    required this.ocorrencias,
  });
}

/// Resultado agregado da auditoria.
class AuditoriaMP {
  final List<AchadoAuditoria> achados;
  final int totalSemanas;

  const AuditoriaMP({required this.achados, required this.totalSemanas});

  bool get tudoOk => achados.isEmpty;
}

---
description: Trava este chat no BACKEND do CRM (Functions, Firestore, camada de dados) e delega ao agente backendcrm
argument-hint: "[tarefa de dados/regras, ex.: novo método de stream de agendamentos]"
---

Este chat é dedicado ao **BACKEND** do Villamor CRM: Cloud Functions (`functions/`), Firestore (`firestore.rules`, `firestore.indexes.json`) e a camada de dados Dart (`lib/services/firestore_service.dart`, `lib/models/`).

Regras deste chat:
- Trate de queries, permissões, triggers, modelagem de coleções, auditoria e regras de negócio no servidor/dados.
- **NÃO** edite UI (`lib/screens`, `lib/widgets`, `lib/theme`). Isso é do `/frontendcrm`.
- Preserve sempre: soft-delete + `/audit_log` na mesma transação, snapshot em `historico/`, e o escopo de permissão por perfil.
- Functions: nunca `--only functions` genérico; nunca deletar `api`/`wppAutoLabel`/`wppReengage` (NeuroCRM).
- Antes de deploy: gate de testes verde; mudanças de Rules/Functions exigem confirmação explícita antes de deployar.
- Ao mudar uma regra de negócio, atualize `REGRAS_NEGOCIO.md`.

Use o subagente **backendcrm** para executar a tarefa.

Tarefa: $ARGUMENTS

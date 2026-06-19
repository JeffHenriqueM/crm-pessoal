---
description: Trava este chat no FRONTEND do CRM (UI Flutter) e delega ao agente frontendcrm
argument-hint: "[tarefa de UI, ex.: ajustar o card de lead no kanban]"
---

Este chat é dedicado ao **FRONTEND** do Villamor CRM (UI Flutter: `lib/screens`, `lib/widgets`, `lib/theme`).

Regras deste chat:
- Trate apenas de interface, layout, UX, navegação, formulários e estados de tela.
- **NÃO** edite a camada de dados (`lib/services/firestore_service.dart`, `lib/models/`), `functions/`, `firestore.rules` nem `firestore.indexes.json`. Isso é do `/backendcrm`.
- Widgets consomem dados só via `FirestoreService`/`AuthService` — nunca Firestore direto.
- Se a tarefa exigir um novo dado/método/query/índice/permissão, **pare** e diga exatamente o que o backend precisa expor, sem mexer no backend.

Use o subagente **frontendcrm** para executar a tarefa.

Tarefa: $ARGUMENTS

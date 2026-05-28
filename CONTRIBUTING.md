# Guia de Contribuição — Villamor CRM

> Convenções de commit e regras de código estão em `CLAUDE.md`. Este arquivo cobre apenas o fluxo Git.

---

## Fluxo de branches

```
main          → produção (protegida, nunca comitar direto)
develop       → integração e testes
feature/...   → novas funcionalidades
fix/...       → correções de bugs
hotfix/...    → correções urgentes em produção
```

### Exemplo de fluxo
```bash
git checkout develop
git checkout -b feature/nome-da-feature

# ... desenvolva ...

git push origin feature/nome-da-feature
# Abra um Pull Request: feature/... → develop
```

---

## Pull Requests

- Título do PR segue o mesmo padrão de commits (ver `CLAUDE.md`)
- Descreva brevemente **o que** e **por que** foi feito
- PRs em `main` exigem que o build passe
- Nunca fazer merge sem ao menos uma revisão (quando a equipe crescer)

---

## Arquivos sensíveis — nunca commitar

- `lib/firebase_options.dart`
- `lib/firebase_options_staging.dart`
- `.env` (se criado)

Todos já estão no `.gitignore`.

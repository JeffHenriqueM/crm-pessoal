# Guia de Contribuição — Villamor CRM

## Fluxo de branches

```
main          → produção (protegida, nunca comitar direto)
develop       → integração e testes
feature/...   → novas funcionalidades
fix/...       → correções de bugs
hotfix/...    → correções urgentes em produção
```

### Exemplo de fluxo:
```bash
git checkout develop
git checkout -b feature/nova-funcionalidade

# ... desenvolva ...

git push origin feature/nova-funcionalidade
# Abra um Pull Request de feature/... → develop
```

---

## Padrão de commits (Conventional Commits)

```
<tipo>(<escopo>): <descrição curta no imperativo>
```

### Tipos permitidos:

| Tipo       | Quando usar                                              |
|------------|----------------------------------------------------------|
| `feat`     | Nova funcionalidade                                      |
| `fix`      | Correção de bug                                          |
| `refactor` | Melhoria de código sem mudar comportamento               |
| `style`    | Ajuste de UI, cores, espaçamento (sem lógica)            |
| `chore`    | Atualização de dependências, config, scripts             |
| `docs`     | Documentação                                             |
| `test`     | Adição ou correção de testes                             |

### Exemplos:

```bash
git commit -m "feat(clientes): adicionar filtro por data de captação"
git commit -m "fix(busca): corrigir pesquisa que não retornava resultados"
git commit -m "style(login): aplicar identidade visual Villamor CRM"
git commit -m "refactor(firestore): substituir print por debugPrint"
git commit -m "chore(deps): atualizar fl_chart para 1.2.0"
```

---

## Pull Requests

- Todo PR deve ter título seguindo o padrão de commits
- Descreva brevemente **o que** e **por que** foi feito
- Nunca faça merge sem ao menos uma revisão (quando a equipe crescer)
- PRs em `main` exigem que o build passe

---

## Regras gerais

- **Nunca comitar diretamente em `main`**
- Não commitar arquivos sensíveis (`.env`, `firebase_options.dart` contém chaves — já está no `.gitignore` excluído? Verificar)
- Manter o `CHANGELOG.md` atualizado ao fazer releases
- Usar `debugPrint` em vez de `print` no código Dart

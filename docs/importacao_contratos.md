# Importação de Contratos — Central de Contratos → Firestore

Memória viva do processo de atualização da coleção `contratos`. Registra **de onde
vem o dado**, **o que sobrescrevemos**, **o que preservamos** e as **correções
manuais** que aplicamos porque o sistema de origem tem erros. Atualizar este arquivo
sempre que surgir uma nova regra/decisão.

## Fonte do dado
- Export da **Central de Contratos** (planilha `CentralContratos_<data>.xlsx`).
- Chave do documento = **`LOCALIZADOR`** (vira o `id` do doc em `contratos/`).
- Última importação de referência: `CentralContratos_12_06_2026_13_44_15` — 1188 contratos.

## Como rodar
Dois caminhos equivalentes (mesmo resultado, ambos por **merge** que preserva os campos nossos):

1. **In-app** (Pós-venda → importar): aceita **Excel (.xlsx)** direto **ou CSV**. O
   xlsx é o caminho recomendado — lê números e datas nativamente (datas como serial
   do Excel), igual ao script. O CSV continua funcionando ("Salvar como CSV").
2. **Script** (aceita **xlsx** direto, mais preciso com números/datas):
   ```bash
   python3 scripts/importar_contratos_central.py "<arquivo.xlsx>"            # dry-run (não grava)
   python3 scripts/importar_contratos_central.py "<arquivo.xlsx>" --only 4373 # grava só 1 (teste)
   python3 scripts/importar_contratos_central.py "<arquivo.xlsx>" --apply     # grava o lote
   ```
   > Toda gravação em produção exige confirmação (Firestore real). Rodar dry-run e
   > teste em 1 contrato antes do `--apply`.

## O que é ATUALIZADO (vem da planilha, sobrescrito a cada import)
Identificação e comercial: `nomeComprador`, `cpf/email/telefone` (1 e 2), endereço,
`sala/bloco/imovel/produto/cota`, `status`, `vendedorCloser/captador/vendedorLiner`,
`pontoCapatcao`, `revertido` + `origemReversao`, `dataContrato`, nascimentos.

**Financeiro (o foco da atualização):** `statusFinanceiro`, `dataQuitacao`, `entrada`,
`saldoRestante`, `valorFinanciado`, `valorIntegralizado`, `valorAtrasado`,
`percentualIntegralizado`, `valorTotalReajustado`, `dataProximoVencimento`.

## O que é PRESERVADO (nosso — NUNCA tocado pelo import)
Estes campos são mantidos só pelo CRM e **não** entram na máscara de escrita:
- **`statusAssinatura`** — status de formalização (assinado, projeto atualizado, etc.).
  É o campo das assinaturas; jamais sobrescrever via import.
- **`linkContratoDrive`** — link do PDF no Drive (preenchido à mão).
- **`codigoContrato`** — código tipo `LXO-63-309/Cota-10`. **Não vem nesta planilha**
  (não há coluna `CÓDIGO`), então fica preservado.
- **`interacoesPorMes`**, **`upgradeOferecidoEm`**, **`upgradeRealizadoEm`** — métricas
  de pós-venda.
- **`precisaReajuste`** / **`motivoReajuste`** — alerta interno de dados a corrigir.
- **`criadoEm`** — gravado só na criação; reimport preserva o original.

Garantia técnica: o `toFirestore()` do `Contrato` **não serializa** esses campos, e o
script usa `updateMask` só com os campos da planilha (`set(..., merge:true)`).

## Correções manuais (o sistema de origem erra — nós corrigimos)

### 1. Quitado com 0% integralizado → na verdade é 100%
A Central exporta alguns contratos **`Quitado`** com `percentualIntegralizado = 0` e
`valorIntegralizado = 0` (bug do sistema de origem). Eles estão **quitados = 100%**.
- **Como tratamos:** o getter `Contrato.percentualEfetivo` (em `lib/models/contrato_model.dart`)
  já retorna `100` quando `estaQuitado`, independente do número cru. Telas usam esse getter.
- **Por que não gravar 100 no dado cru:** `percentualIntegralizado` é sobrescrito a cada
  import (volta a 0 no próximo arquivo). A correção durável é o getter + esta nota.
- **Localizadores afetados (import 12/06/2026, 19 contratos):**
  `4373, 4294, 4276, 4251, 4219, 4205, 4184, 4167, 4036, 3997, 3914, 3887, 3880, 3826,
  3806, 3798, 3767, 3715, 3706`.
  > Lista muda a cada export; recalcular com o dry-run (seção "Quitados com 0%").

### 2. Colunas `*_EFETIVO` da planilha → ignoradas
A planilha tem `VALOR INTEGRALIZADO EFETIVO` / `PERCENTUAL INTEGRALIZADO EFETIVO`. São
uma métrica alternativa do sistema de origem (em geral **menor** que a base) e **não**
representam a correção do quitado. O import não usa essas colunas.

### 3. `revertido` / `origemReversao` — lidos da planilha (in-app e script)
Tanto o **script** quanto o **parser in-app** (`contrato_csv_parser.dart`, CSV e xlsx)
leem as colunas `REVERTIDO` / `ORIGEM REVERSÃO` (369 revertidos no import de 12/06).
Regra (igual nos dois): `revertido` é true quando a célula é `sim`/`true`/`1`/
`verdadeiro` (ou um booleano verdadeiro no xlsx); `origemReversao` só é gravada se
`revertido` e o valor não for vazio nem `0`.
> ✅ Resolvido: antes o parser in-app gravava `revertido = false` sempre e zerava os
> revertidos num import. Agora ambos os caminhos preservam a reversão.

## Observações de formato (xlsx vs CSV)
- No **xlsx**, dinheiro vem como número (`9084.43`) e datas como **serial do Excel**
  (`46179.0004` = dias desde 1899-12-30). O script converte nativamente.
- Datas de **nascimento** vêm como **string `DD/MM/YYYY`**.
- Alguns contratos têm `DATA` com serial inválido (negativo) → tratados como nulo.

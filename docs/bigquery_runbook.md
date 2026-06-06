# Runbook BigQuery — ativação e queries prontas

> Companheiro executável do `docs/bigquery_calibracao.md`. Aqui está o passo a
> passo de console + **SQL real** (ajustado ao schema da extensão e ao schema
> real das coleções `clientes`/`historico` deste projeto), com a normalização
> do ticket #47 (`fechamento`→`fechado`, `sondagem`→`prospeccao`) embutida em
> todas as queries — assim a análise já sai correta mesmo antes do fix no app.

Projeto: `crm-pessoal-d993d` · Dataset sugerido: `crm_analytics` ·
Região: `southamerica-east1`.

---

## 0. Pré-requisito
Plano **Blaze** (pay-as-you-go) no projeto. O volume deste CRM cabe no tier
gratuito do BigQuery (1 TB/mês de query) — custo esperado ≈ R$0.

## 1. Instalar a extensão (console, ~15 min)
1. Firebase Console → `crm-pessoal-d993d` → **Extensions** → **Explore**.
2. Instalar **"Stream Firestore to BigQuery"** (`firebase/firestore-bigquery-export`).
3. **Instância 1 — clientes:**
   - Collection path: `clientes`
   - Dataset ID: `crm_analytics`
   - Table ID: `clientes`
   - Região: `southamerica-east1`
   - **Import existing documents:** SIM (backfill).
4. **Instância 2 — historico (collection group):**
   - Collection path: `clientes/{clienteId}/historico`
   - Marcar **"Use Collection Group query"**.
   - Dataset ID: `crm_analytics` · Table ID: `historico`
   - **Import existing documents:** SIM.

Cada instância cria:
- `crm_analytics.clientes_raw_changelog` (append-only, toda mudança)
- `crm_analytics.clientes_raw_latest` (view: estado atual de cada doc)
- idem `historico_raw_changelog` / `historico_raw_latest`.

> No `_raw_latest`, o documento inteiro vem na coluna **`data`** (JSON em
> string). Campos se leem com `JSON_VALUE(data, '$.campo')`; mapas aninhados com
> `JSON_VALUE(data, '$.dados.fase')`. Timestamps do Firestore saem como
> ISO ("2026-05-29T04:13:52.254Z") → `TIMESTAMP(JSON_VALUE(...))`.

## 2. Conferir o schema antes de tudo
Rode e olhe uma linha crua para confirmar os nomes/formyatos:
```sql
SELECT data FROM `crm-pessoal-d993d.crm_analytics.clientes_raw_latest` LIMIT 1;
SELECT data FROM `crm-pessoal-d993d.crm_analytics.historico_raw_latest` LIMIT 1;
```

---

## 3. View base normalizada (rode 1×, reusada pelas demais)
```sql
CREATE OR REPLACE VIEW `crm-pessoal-d993d.crm_analytics.clientes_norm` AS
WITH base AS (
  SELECT
    document_id AS cliente_id,
    JSON_VALUE(data, '$.nome')               AS nome,
    JSON_VALUE(data, '$.fase')               AS fase_raw,
    JSON_VALUE(data, '$.vendedorId')         AS vendedor_id,
    JSON_VALUE(data, '$.vendedorNome')       AS vendedor_nome,
    JSON_VALUE(data, '$.origem')             AS origem,
    JSON_VALUE(data, '$.captadorNome')       AS captador_nome,
    JSON_VALUE(data, '$.statusMensagem')     AS status_mensagem,
    SAFE_CAST(JSON_VALUE(data, '$.valorVendido') AS FLOAT64) AS valor_vendido,
    JSON_VALUE(data, '$.dataVisita')         AS data_visita,
    JSON_VALUE(data, '$.dataEntradaSala')    AS data_entrada_sala,
    TIMESTAMP(JSON_VALUE(data, '$.dataCadastro'))   AS data_cadastro,
    SAFE.TIMESTAMP(JSON_VALUE(data, '$.dataFechamento')) AS data_fechamento,
    JSON_VALUE(data, '$.deletado')           AS deletado
  FROM `crm-pessoal-d993d.crm_analytics.clientes_raw_latest`
)
SELECT
  * EXCEPT (fase_raw),
  CASE fase_raw
    WHEN 'fechamento' THEN 'fechado'     -- ticket #47: venda ganha legada
    WHEN 'sondagem'   THEN 'prospeccao'
    ELSE fase_raw
  END AS fase
FROM base
WHERE deletado IS NULL OR deletado != 'true';
```

## 4. Sanidade — distribuição de fases (normalizada)
```sql
SELECT fase, COUNT(*) AS n
FROM `crm-pessoal-d993d.crm_analytics.clientes_norm`
GROUP BY fase ORDER BY n DESC;
-- Esperado: 'fechado' agora soma os 66 ex-'fechamento' (≈90), 'prospeccao' cai.
```

## 5. Conversão por vendedor (já corrigida)
```sql
SELECT
  vendedor_nome,
  COUNTIF(fase = 'fechado')                         AS fechados,
  COUNTIF(fase = 'perdido')                         AS perdidos,
  COUNTIF(fase IN ('fechado','perdido'))            AS decididos,
  ROUND(100 * SAFE_DIVIDE(
      COUNTIF(fase = 'fechado'),
      COUNTIF(fase IN ('fechado','perdido'))), 1)   AS conversao_pct,
  ROUND(AVG(IF(fase='fechado' AND data_fechamento IS NOT NULL,
      TIMESTAMP_DIFF(data_fechamento, data_cadastro, DAY), NULL)), 1) AS ciclo_medio_dias
FROM `crm-pessoal-d993d.crm_analytics.clientes_norm`
WHERE vendedor_id IS NOT NULL
GROUP BY vendedor_nome
HAVING decididos >= 3
ORDER BY conversao_pct DESC;
```

## 6. Calibração — lift por sinal (validação dos pesos do Lead Score)
```sql
WITH decididos AS (
  SELECT
    fase = 'fechado' AS ganhou,
    data_visita IS NOT NULL                       AS visitou,
    data_entrada_sala IS NOT NULL                 AS esteve_sala,
    status_mensagem = 'enviada_com_resposta'      AS respondeu,
    status_mensagem = 'enviada_sem_resposta'      AS sem_resposta
  FROM `crm-pessoal-d993d.crm_analytics.clientes_norm`
  WHERE fase IN ('fechado','perdido')
),
sinais AS (
  SELECT 'Visitou' AS sinal, visitou AS tem, ganhou FROM decididos
  UNION ALL SELECT 'Esteve na sala', esteve_sala, ganhou FROM decididos
  UNION ALL SELECT 'Respondeu',      respondeu,   ganhou FROM decididos
  UNION ALL SELECT 'Sem resposta',   sem_resposta, ganhou FROM decididos
)
SELECT
  sinal,
  COUNTIF(tem)                                              AS n_com,
  ROUND(100*SAFE_DIVIDE(COUNTIF(tem AND ganhou),COUNTIF(tem)),1)        AS fecha_com_pct,
  ROUND(100*SAFE_DIVIDE(COUNTIF(NOT tem AND ganhou),COUNTIF(NOT tem)),1) AS fecha_sem_pct,
  ROUND(
    100*SAFE_DIVIDE(COUNTIF(tem AND ganhou),COUNTIF(tem))
  - 100*SAFE_DIVIDE(COUNTIF(NOT tem AND ganhou),COUNTIF(NOT tem)),1)    AS lift_pts
FROM sinais
GROUP BY sinal
ORDER BY lift_pts DESC;
-- lift_pts alto → peso justificado no lead_score.dart; ~0 → ruído; <0 → invertido.
```

## 7. Funil por etapa (a partir do histórico)
`historico` tem `tipo` ∈ {`edicao`,`mudanca_fase`,...} e `dados.fase` (fase no
momento) + `timestamp`. "Alcançou a etapa X" = existe qualquer snapshot com essa
fase, OU a fase atual do lead.
```sql
WITH hist AS (
  SELECT
    REGEXP_EXTRACT(document_name, r'/clientes/([^/]+)/historico/') AS cliente_id,
    CASE JSON_VALUE(data, '$.dados.fase')
      WHEN 'fechamento' THEN 'fechado' WHEN 'sondagem' THEN 'prospeccao'
      ELSE JSON_VALUE(data, '$.dados.fase') END AS fase
  FROM `crm-pessoal-d993d.crm_analytics.historico_raw_latest`
  WHERE JSON_VALUE(data, '$.dados.fase') IS NOT NULL
),
fases_por_lead AS (
  SELECT cliente_id, fase FROM hist
  UNION DISTINCT
  SELECT cliente_id, fase FROM `crm-pessoal-d993d.crm_analytics.clientes_norm`
),
alc AS (
  SELECT cliente_id, ARRAY_AGG(DISTINCT fase) AS fases
  FROM fases_por_lead GROUP BY cliente_id
)
SELECT etapa, COUNTIF(etapa IN UNNEST(fases)) AS alcancaram FROM alc,
  UNNEST(['prospeccao','contato','negociacao','visita','fechado']) AS etapa
GROUP BY etapa
ORDER BY ARRAY_LENGTH(['prospeccao','contato','negociacao','visita','fechado'])
       - (SELECT off FROM UNNEST(['prospeccao','contato','negociacao','visita','fechado'])
            AS f WITH OFFSET off WHERE f = etapa);
-- A maior queda entre etapas consecutivas é o gargalo do funil da operação.
```

## 8. Velocidade — tempo médio entre transições de fase
```sql
WITH mud AS (
  SELECT
    REGEXP_EXTRACT(document_name, r'/clientes/([^/]+)/historico/') AS cliente_id,
    JSON_VALUE(data, '$.dados.fase') AS fase,
    TIMESTAMP(JSON_VALUE(data, '$.timestamp')) AS ts
  FROM `crm-pessoal-d993d.crm_analytics.historico_raw_latest`
  WHERE JSON_VALUE(data, '$.tipo') = 'mudanca_fase'
),
seq AS (
  SELECT cliente_id, fase, ts,
    LAG(ts) OVER (PARTITION BY cliente_id ORDER BY ts) AS ts_anterior,
    LAG(fase) OVER (PARTITION BY cliente_id ORDER BY ts) AS fase_anterior
  FROM mud
)
SELECT
  CONCAT(fase_anterior, ' → ', fase) AS transicao,
  COUNT(*) AS n,
  ROUND(AVG(TIMESTAMP_DIFF(ts, ts_anterior, DAY)),1) AS dias_medios
FROM seq WHERE ts_anterior IS NOT NULL
GROUP BY transicao
ORDER BY dias_medios DESC;
-- Onde os leads "empacam" mais tempo no pipeline.
```

---

## 9. Realimentar os pesos no código
Com os `lift_pts` da §6 medidos:
- Ajustar os bônus/penalidades em `lib/services/lead_score.dart` proporcionalmente
  ao lift real de cada sinal (ex.: se "Visitou" tiver lift baixo, reduzir o +10).
- Revisar os limites de dias em `lib/services/risco_silencio.dart` com a §8
  (se o pipeline real leva 20 dias na negociação, "esfriando >7d" pode ser cedo).
- Cada ajuste mantém a lógica pura testável — atualizar os testes em
  `test/services/` com os novos números esperados.

## 10. Observação importante
Toda query aqui normaliza `fechamento`→`fechado`. Quando o **ticket #47** for
corrigido no app (alias em `fromFirestore` + backfill), os dados crus já virão
certos e os `CASE ... WHEN 'fechamento'` viram redundância inofensiva (podem ser
removidos das views).

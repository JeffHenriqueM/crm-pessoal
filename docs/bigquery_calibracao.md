# Fundação de Dados — Calibração e BigQuery

> Objetivo: sair do "achismo" e **medir** se os pesos do Lead Score e do Risco
> de Silêncio realmente preveem fechamento. Há duas camadas: a **local** (já
> pronta, dentro do app) e a **de escala** (BigQuery, descrita aqui para você
> executar no console quando quiser).

---

## 1. Camada local (já no app) — aba **Calibração**

A aba **Calibração** (dashboard admin) faz o backtest direto sobre o snapshot
do Firestore, sem custo e sem infra:

- Pega os leads **decididos** (`fechado` + `perdido`).
- Para cada sinal (visitou, esteve na sala, respondeu, ficou sem responder),
  compara a taxa de fechamento de quem **tem** o sinal vs quem **não tem**.
- O **lift** (diferença em pontos %) é o poder preditivo real do sinal:
  - lift alto e positivo → o peso no Lead Score está justificado;
  - lift ≈ 0 → sinal é ruído, peso deveria cair;
  - lift negativo → sinal está invertido.

Lógica pura e testada em `lib/services/calibracao.dart`
(testes em `test/services/calibracao_test.dart`).

**Limite:** o snapshot guarda só a fase **atual**. Não dá para reconstruir o
funil por etapa ao longo do tempo (quando o lead passou de contato→negociação,
quanto tempo ficou em cada uma, em que etapa foi perdido). Para isso é preciso o
**histórico**, que vive na subcoleção `clientes/{id}/historico/` — e é aí que o
BigQuery entra.

---

## 2. Camada de escala — Firestore → BigQuery

### 2.1 Por que
- Calibrar com **volume** (a amostra local fica pequena e ruidosa no começo).
- Reconstruir o **funil por etapa** e o **vazamento exato** a partir do
  `historico/` (impossível fazer bem no cliente).
- Cruzar com origem, captador, brinde, sala — segmentações que hoje não temos
  em análise.

### 2.2 Como ligar (console, ~15 min)
1. Firebase Console → projeto `crm-pessoal-d993d` → **Extensions**.
2. Instalar **"Stream Firestore to BigQuery"** (`firestore-bigquery-export`).
3. Configurar uma instância por coleção a exportar:
   - `clientes` (collection path: `clientes`)
   - `clientes/{clienteId}/historico` (collection group, marcar a opção
     **collection group** / usar wildcard `clientes/{clienteId}/historico`)
4. Dataset: `crm_analytics` · Região: `southamerica-east1` (mesma do projeto).
5. Habilitar **"Import existing documents"** no setup (backfill do que já existe).

> ⚠️ A extensão exige plano **Blaze** (pay-as-you-go). O volume deste CRM cabe
> folgado no tier gratuito do BigQuery (1 TB de query/mês). Custo esperado ≈ R$0.

### 2.3 O que ela cria
- Tabela bruta `clientes_raw_changelog` (append-only, cada mudança).
- View `clientes_raw_latest` (estado atual de cada doc).
- Idem para `historico`.

---

## 3. Queries de calibração (rodar no BigQuery)

### 3.1 Taxa de fechamento por temperatura prevista
Valida se as faixas do Lead Score discriminam de verdade (quente deve fechar
muito mais que frio):

```sql
-- Pseudocódigo: a temperatura precisa ser recalculada a partir dos sinais
-- crus do changelog NO MOMENTO em que o lead ainda estava ativo.
-- Estrutura geral (ajustar nomes de coluna ao schema gerado pela extensão):
SELECT
  faixa_temperatura,           -- derivada dos sinais (quente/morno/frio)
  COUNT(*)                              AS decididos,
  COUNTIF(fase = 'fechado')             AS fechados,
  ROUND(100 * COUNTIF(fase = 'fechado') / COUNT(*), 1) AS taxa_fechamento
FROM `crm-pessoal-d993d.crm_analytics.leads_decididos_com_score`
GROUP BY faixa_temperatura
ORDER BY taxa_fechamento DESC;
```
Se quente ≈ frio, os pesos estão errados.

### 3.2 Funil por etapa (a partir do histórico)
```sql
-- Quantos leads ALCANÇARAM cada fase, e quantos avançaram para a próxima.
-- Reconstrói o caminho real de cada lead a partir dos snapshots de historico.
WITH fases_alcancadas AS (
  SELECT
    document_id AS cliente_id,
    ARRAY_AGG(DISTINCT fase) AS fases
  FROM `crm-pessoal-d993d.crm_analytics.historico_raw_latest`
  GROUP BY document_id
)
SELECT
  'prospeccao' AS etapa, COUNTIF('prospeccao' IN UNNEST(fases)) AS alcancaram FROM fases_alcancadas
UNION ALL SELECT 'contato',    COUNTIF('contato'    IN UNNEST(fases)) FROM fases_alcancadas
UNION ALL SELECT 'negociacao', COUNTIF('negociacao' IN UNNEST(fases)) FROM fases_alcancadas
UNION ALL SELECT 'visita',     COUNTIF('visita'     IN UNNEST(fases)) FROM fases_alcancadas
UNION ALL SELECT 'fechado',    COUNTIF('fechado'    IN UNNEST(fases)) FROM fases_alcancadas;
```
A maior queda entre etapas consecutivas é o gargalo do funil.

### 3.3 Tempo médio em cada etapa
```sql
-- Diferença entre timestamps de entrada em fases consecutivas (do historico).
-- Mede a VELOCIDADE real do pipeline e onde os leads "empacam".
```

---

## 4. Auditoria pendente: risco do `orElse: prospeccao`

`lib/models/cliente_model.dart` (fromFirestore) faz:

```dart
faseRecuperada = FaseCliente.values.firstWhere(
  (e) => e.toString().split('.').last == stringFase,
  orElse: () => FaseCliente.prospeccao,   // ← silencioso
);
```

Qualquer doc com um rótulo de fase **fora do enum** (legado, importação
NeuroCRM, typo) vira `prospeccao` **sem aviso**, contaminando funil, risco e
calibração. Antes de confiar nos números em escala, **quantificar** quantos docs
têm fase desconhecida.

### 4.1 Auditar via REST API (sem abrir o app)
Usa o token do `firebase login` (mesmo padrão do script de tickets no
`CLAUDE.md`). Lista as fases distintas e conta as fora do enum:

```bash
node -e "
const path=require('path'),os=require('os'),fs=require('fs'),https=require('https');
const token=JSON.parse(fs.readFileSync(path.join(os.homedir(),'.config/configstore/firebase-tools.json'),'utf8')).tokens.access_token;
const base='/v1/projects/crm-pessoal-d993d/databases/(default)/documents';
const validas=new Set(['atendimento','prospeccao','contato','negociacao','visita','fechado','perdido']);
function get(url){return new Promise((res,rej)=>{https.request({hostname:'firestore.googleapis.com',path:url,method:'GET',headers:{Authorization:'Bearer '+token}},r=>{let d='';r.on('data',c=>d+=c);r.on('end',()=>res(JSON.parse(d)));}).on('error',rej).end();});}
(async()=>{
  let token2=null,cont={};
  do{
    const url=base+'/clientes?pageSize=300'+(token2?'&pageToken='+token2:'');
    const page=await get(url);
    (page.documents||[]).forEach(d=>{const f=d.fields?.fase?.stringValue||'(sem fase)';cont[f]=(cont[f]||0)+1;});
    token2=page.nextPageToken;
  }while(token2);
  console.log('Distribuição de fases:');
  Object.entries(cont).sort((a,b)=>b[1]-a[1]).forEach(([f,n])=>{
    const flag=validas.has(f)?'  ':'⚠️';
    console.log(flag+' '+f.padEnd(16)+n);
  });
  const fora=Object.entries(cont).filter(([f])=>!validas.has(f));
  console.log('\\nFases fora do enum (viram prospecção silenciosamente): '+(fora.length?fora.map(x=>x[0]).join(', '):'NENHUMA ✅'));
})();
"
```

### 4.2 Se houver fases fora do enum
- Decidir o mapeamento correto (ex.: `'novo'`→`prospeccao`, `'ganho'`→`fechado`).
- Abrir ticket e migrar os docs (respeitando soft-delete e gravando em
  `/audit_log` se a migração tocar `clientes/`).
- Trocar o `orElse` silencioso por um `debugPrint` de alerta, para não mascarar
  futuros valores inesperados.

---

## 5. Ordem sugerida
1. **Já feito:** aba Calibração local (valida sinais com o que temos hoje).
2. Rodar a **auditoria de fases** (§4) — barato e destrava confiança nos números.
3. Ligar a **extensão BigQuery** (§2) quando quiser volume + funil por etapa.
4. Calibrar pesos com as queries (§3) e ajustar `lead_score.dart` /
   `risco_silencio.dart` com base nos lifts medidos.

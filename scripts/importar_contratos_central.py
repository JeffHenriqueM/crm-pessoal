#!/usr/bin/env python3
"""
Importador de contratos da Central de Contratos (xlsx) para o Firestore.

Espelha o fluxo in-app (PosVendaScreen -> parsearCsvContratos -> salvarContratosLote),
mas lendo o **xlsx** direto (números nativos + datas em serial do Excel), o que é mais
preciso que o parser de CSV. Documentação das regras: docs/importacao_contratos.md.

GARANTIAS (iguais ao salvarContrato com set(merge:true)):
  - Grava por updateMask APENAS os campos vindos da planilha. Campos fora da máscara
    ficam intactos no Firestore.
  - NUNCA grava os campos "nossos": statusAssinatura, linkContratoDrive, codigoContrato,
    interacoesPorMes, upgradeOferecidoEm, upgradeRealizadoEm, precisaReajuste,
    motivoReajuste. (codigoContrato não vem nesta planilha -> preservado.)
  - criadoEm só é gravado em documentos novos; reimportações preservam o original.

USO:
  python3 scripts/importar_contratos_central.py "<arquivo.xlsx>"            # dry-run (não grava)
  python3 scripts/importar_contratos_central.py "<arquivo.xlsx>" --only 4373 # grava só 1 (teste)
  python3 scripts/importar_contratos_central.py "<arquivo.xlsx>" --apply     # grava o lote todo
"""
import sys, os, json, zipfile, datetime, urllib.request, urllib.error
import xml.etree.ElementTree as ET

PROJ = 'crm-pessoal-d993d'
BASE = f'https://firestore.googleapis.com/v1/projects/{PROJ}/databases/(default)/documents'
NS = {'a': 'http://schemas.openxmlformats.org/spreadsheetml/2006/main'}
# Brasil é UTC-3 fixo (sem horário de verão desde 2019). Datas são gravadas como
# meia-noite local, igual ao que o app (browser em -03:00) grava via CSV.
TZ_OFFSET = '-03:00'

# ── Campos "nossos" — JAMAIS entram na máscara de escrita ──────────────────────
CAMPOS_PRESERVADOS = {
    'statusAssinatura', 'linkContratoDrive', 'codigoContrato', 'interacoesPorMes',
    'upgradeOferecidoEm', 'upgradeRealizadoEm', 'precisaReajuste', 'motivoReajuste',
    'criadoEm',  # tratado à parte (só em doc novo)
}


def token():
    p = os.path.expanduser('~/.config/configstore/firebase-tools.json')
    return json.load(open(p))['tokens']['access_token']


def http(method, url, body=None):
    data = json.dumps(body).encode() if body is not None else None
    headers = {'Authorization': 'Bearer ' + token()}
    if data:
        headers['Content-Type'] = 'application/json'
    req = urllib.request.Request(url, data=data, headers=headers, method=method)
    try:
        with urllib.request.urlopen(req) as r:
            return json.loads(r.read().decode()), None
    except urllib.error.HTTPError as e:
        return None, f'{e.code} {e.read().decode()[:400]}'


# ── Leitura do xlsx ────────────────────────────────────────────────────────────
def ler_xlsx(path):
    z = zipfile.ZipFile(path)
    ss = []
    r = ET.fromstring(z.read('xl/sharedStrings.xml'))
    for si in r.findall('a:si', NS):
        ss.append(''.join(t.text or '' for t in si.iter(
            '{http://schemas.openxmlformats.org/spreadsheetml/2006/main}t')))
    sheet = ET.fromstring(z.read('xl/worksheets/sheet1.xml'))
    rows = sheet.findall('.//a:row', NS)

    def colnum(ref):
        s = ''.join(c for c in ref if c.isalpha()); n = 0
        for ch in s:
            n = n * 26 + (ord(ch) - 64)
        return n - 1

    def cv(c):
        t = c.get('t'); v = c.find('a:v', NS)
        if v is None:
            return None
        return ss[int(v.text)] if t == 's' else v.text

    parsed = [{colnum(c.get('r')): cv(c) for c in row.findall('a:c', NS)} for row in rows]
    header = parsed[0]
    linhas = parsed[1:]
    return header, linhas


# ── Resolução de colunas (espelha idx/idxExato do parser Dart) ─────────────────
class Cols:
    def __init__(self, header):
        # header é dict {indice: nome}
        self.itens = [(i, (header.get(i) or '').strip().replace('﻿', ''))
                      for i in sorted(header)]

    def idx(self, nome):
        nome = nome.lower()
        for i, h in self.itens:
            if nome in h.lower():
                return i
        return -1

    def exato(self, nome):
        nome = nome.lower()
        for i, h in self.itens:
            if h.lower() == nome:
                return i
        return -1


def excel_date(serial):
    return datetime.datetime(1899, 12, 30) + datetime.timedelta(days=float(serial))


# ── Conversão de uma linha -> dict de campos (espelha Contrato + toFirestore) ──
def linha_para_contrato(row, C):
    def cel(i):
        if i < 0:
            return ''
        v = row.get(i)
        return '' if v is None else str(v).strip()

    def num(i):
        s = cel(i)
        if s == '':
            return 0.0
        try:
            return float(s)  # xlsx já vem com ponto decimal
        except ValueError:
            # fallback formato BR "1.234,56"
            return float(s.replace('.', '').replace(',', '.')) if s else 0.0

    def data(i):
        s = cel(i)
        if s == '':
            return None
        try:
            return excel_date(s).date()
        except (ValueError, OverflowError):
            # fallback string MM/DD/YYYY (serial negativo/ inválido -> None)
            p = s.split('/')
            if len(p) == 3:
                try:
                    return datetime.date(int(p[2]), int(p[0]), int(p[1]))
                except ValueError:
                    return None
        return None

    def data_nasc(i):
        s = cel(i)
        if s == '':
            return None
        try:
            return excel_date(s).date()
        except (ValueError, OverflowError):
            p = s.split('/')  # nascimento vem como string DD/MM/YYYY
            if len(p) == 3:
                try:
                    return datetime.date(int(p[2]), int(p[1]), int(p[0]))
                except ValueError:
                    return None
        return None

    loc = cel(C.idx_loc)
    rev = cel(C.idx('REVERTIDO')).lower() in ('sim', 'true', '1', 'verdadeiro')
    origem = cel(C.idx('ORIGEM REVERSÃO'))
    origem = origem if (rev and origem and origem != '0') else None
    dn1 = data_nasc(C.idx('DATA NASCIMENTO CESSIONÁRIO 1'))
    dn2 = data_nasc(C.idx('DATA NASCIMENTO CESSIONÁRIO 2'))

    def opt(i):
        v = cel(i)
        return v if v != '' else None

    return {
        'localizador': loc,
        'localizadorAtendimento': cel(C.idx('LOCALIZADOR ATENDIMENTO')),
        'dataContrato': data(C.exato('DATA')),
        'nomeComprador': cel(C.idx('CESSIONÁRIO 1')),
        'cpfComprador': cel(C.idx('CPF/CNPJ cessionário 1')),
        'emailComprador': cel(C.idx('E-mail cessionário 1')),
        'telefoneComprador': cel(C.idx('Telefone cessionário 1')),
        'dataNascimentoComprador': dn1,
        'diaNascimentoComprador': dn1.day if dn1 else None,
        'mesNascimentoComprador': dn1.month if dn1 else None,
        'nomeComprador2': opt(C.idx('CESSIONÁRIO 2')),
        'cpfComprador2': opt(C.idx('CPF/CNPJ cessionário 2')),
        'emailComprador2': opt(C.idx('E-mail cessionário 2')),
        'telefoneComprador2': opt(C.idx('Telefone cessionário 2')),
        'dataNascimentoComprador2': dn2,
        'diaNascimentoComprador2': dn2.day if dn2 else None,
        'mesNascimentoComprador2': dn2.month if dn2 else None,
        'logradouro': cel(C.idx('LOGRADOURO')),
        'numero': cel(C.idx('NÚMERO')),
        'complemento': cel(C.idx('COMPLEMENTO')),
        'bairro': cel(C.idx('BAIRRO')),
        'cidade': cel(C.idx('CIDADE')),
        'estado': cel(C.idx('ESTADO')),
        'pais': cel(C.idx('PAÍS')) or 'Brasil',
        'sala': cel(C.idx('SALA')),
        'bloco': cel(C.idx('BLOCO')),
        'imovel': cel(C.idx('IMÓVEL')),
        'produto': cel(C.idx('PRODUTO')),
        'cota': cel(C.idx('COTA')),
        'status': cel(C.exato('STATUS')) or 'Ativo',
        'revertido': rev,
        'origemReversao': origem,
        'statusFinanceiro': cel(C.exato('STATUS FINANCEIRO')) or 'Em andamento',
        'dataQuitacao': data(C.idx('DATA QUITAÇÃO')),
        'entrada': num(C.idx('ENTRADA')),
        'saldoRestante': num(C.idx('SALDO RESTANTE')),
        'valorFinanciado': num(C.idx('VALOR FINANCIADO')),
        'valorIntegralizado': num(C.idx('VALOR INTEGRALIZADO')),
        'valorAtrasado': num(C.idx('VALOR ATRASADO')),
        'percentualIntegralizado': num(C.idx('PERCENTUAL INTEGRALIZADO')),
        'valorTotalReajustado': num(C.idx('VALOR TOTAL REAJUSTADO')),
        'dataProximoVencimento': data(C.idx('DATA PRÓXIMO VENCIMENTO')),
        'vendedorCloser': cel(C.idx('VENDEDOR CLOSER')),
        'captador': cel(C.idx('CAPTADOR')),
        'vendedorLiner': cel(C.idx('VENDEDOR LINER')),
        'pontoCapatcao': cel(C.idx('PONTO DE CAPTAÇÃO')),
    }


# ── Encoding p/ Firestore REST ─────────────────────────────────────────────────
def fs_val(v):
    if v is None:
        return {'nullValue': None}
    if isinstance(v, bool):
        return {'booleanValue': v}
    if isinstance(v, int):
        return {'integerValue': str(v)}
    if isinstance(v, float):
        return {'doubleValue': v}
    if isinstance(v, datetime.date):
        return {'timestampValue': f'{v.isoformat()}T00:00:00{TZ_OFFSET}'}
    return {'stringValue': str(v)}


def montar_write(contrato, existe):
    """Monta o objeto de write (update + updateMask) espelhando toFirestore + merge."""
    loc = contrato['localizador']
    fields = {}
    mask = []
    for k, v in contrato.items():
        if k in CAMPOS_PRESERVADOS:
            continue
        # Campos condicionais nulos são OMITIDOS (igual ao `if (x != null)` do
        # toFirestore com merge): não entram na máscara -> ficam intactos.
        condicional_nulo = v is None and k in {
            'dataContrato', 'dataNascimentoComprador', 'diaNascimentoComprador',
            'mesNascimentoComprador', 'nomeComprador2', 'cpfComprador2',
            'emailComprador2', 'telefoneComprador2', 'dataNascimentoComprador2',
            'diaNascimentoComprador2', 'mesNascimentoComprador2', 'origemReversao',
            'dataQuitacao', 'dataProximoVencimento',
        }
        if condicional_nulo:
            continue
        fields[k] = fs_val(v)
        mask.append(k)
    # atualizadoEm sempre (serverTimestamp no app -> usamos agora em UTC)
    agora = datetime.datetime.now(datetime.timezone.utc).strftime('%Y-%m-%dT%H:%M:%SZ')
    fields['atualizadoEm'] = {'timestampValue': agora}
    mask.append('atualizadoEm')
    if not existe:
        fields['criadoEm'] = {'timestampValue': agora}
        mask.append('criadoEm')
    return {
        'update': {'name': f'projects/{PROJ}/databases/(default)/documents/contratos/{loc}',
                   'fields': fields},
        'updateMask': {'fieldPaths': mask},
    }


def batch_get(locs):
    """Retorna dict loc -> fields (ou None se não existe)."""
    out = {}
    for i in range(0, len(locs), 200):
        chunk = locs[i:i + 200]
        docs = [f'projects/{PROJ}/databases/(default)/documents/contratos/{l}' for l in chunk]
        res, err = http('POST', BASE + ':batchGet', {'documents': docs})
        if err:
            print('  ⚠ batchGet erro:', err); continue
        for item in res:
            if 'found' in item:
                name = item['found']['name'].split('/')[-1]
                out[name] = item['found'].get('fields', {})
            elif 'missing' in item:
                name = item['missing'].split('/')[-1]
                out[name] = None
    return out


def commit(writes):
    total = 0
    for i in range(0, len(writes), 150):
        chunk = writes[i:i + 150]
        res, err = http('POST', BASE + ':commit', {'writes': chunk})
        if err:
            print('  ❌ commit erro:', err); sys.exit(1)
        total += len(chunk)
        print(f'  gravados {total}/{len(writes)}')
    return total


def fmt(v):
    if v is None:
        return '∅'
    if isinstance(v, float):
        return f'{v:.2f}'
    return str(v)


def main():
    args = sys.argv[1:]
    if not args:
        print(__doc__); sys.exit(1)
    path = args[0]
    only = None
    apply = '--apply' in args
    if '--only' in args:
        only = args[args.index('--only') + 1]

    header, linhas = ler_xlsx(path)
    C = Cols(header)
    C.idx_loc = C.exato('LOCALIZADOR')
    if C.idx_loc < 0:
        print('Coluna LOCALIZADOR não encontrada'); sys.exit(1)

    contratos = []
    for row in linhas:
        loc = (str(row.get(C.idx_loc)) if row.get(C.idx_loc) is not None else '').strip()
        if loc == '' or loc.startswith('Qtd:'):
            continue
        contratos.append(linha_para_contrato(row, C))

    if only:
        contratos = [c for c in contratos if c['localizador'] == only]
        if not contratos:
            print(f'Localizador {only} não está na planilha'); sys.exit(1)

    print(f'Contratos na planilha: {len(contratos)}')
    locs = [c['localizador'] for c in contratos]
    print('Lendo estado atual no Firestore...')
    atual = batch_get(locs)
    novos = [l for l in locs if atual.get(l) is None]
    print(f'  já existem: {len(locs) - len(novos)} | novos: {len(novos)}')

    # ── Diff dos campos financeiros (amostra) ──────────────────────────────────
    fin = ['statusFinanceiro', 'entrada', 'saldoRestante', 'valorFinanciado',
           'valorIntegralizado', 'valorAtrasado', 'percentualIntegralizado',
           'valorTotalReajustado']

    def atual_val(fields, k):
        if not fields or k not in fields:
            return None
        v = list(fields[k].values())[0]
        try:
            return float(v)
        except (ValueError, TypeError):
            return v

    mudancas = 0
    amostra = []
    for c in contratos:
        f = atual.get(c['localizador'])
        difs = []
        for k in fin:
            old = atual_val(f, k)
            new = c[k]
            o = f'{old:.2f}' if isinstance(old, float) else old
            n = f'{new:.2f}' if isinstance(new, float) else new
            if str(o) != str(n):
                difs.append((k, o, n))
        if difs:
            mudancas += 1
            if len(amostra) < 12:
                amostra.append((c['localizador'], c['nomeComprador'], difs))

    print(f'\nContratos com mudança em campos financeiros: {mudancas}')
    print('Amostra (antigo → novo):')
    for loc, nome, difs in amostra:
        print(f'  [{loc}] {nome[:30]}')
        for k, o, n in difs:
            print(f'       {k}: {fmt(o)} → {fmt(n)}')

    # quitado com 0% integralizado (regra documentada: efetivamente 100%)
    quit0 = [c for c in contratos
             if c['statusFinanceiro'].lower() == 'quitado'
             and c['percentualIntegralizado'] == 0]
    print(f'\nQuitados com 0% integralizado (tratados como 100% via getter '
          f'percentualEfetivo — ver docs): {len(quit0)}')
    print('  locs:', ', '.join(c['localizador'] for c in quit0))

    writes = [montar_write(c, atual.get(c['localizador']) is not None) for c in contratos]

    if not apply and not only:
        print('\n[DRY-RUN] Nada gravado. Use --only <LOC> p/ testar 1, depois --apply.')
        return
    if only:
        print(f'\n[TESTE] Gravando só o localizador {only}...')
        commit(writes)
        depois = batch_get([only]).get(only) or {}
        print('Estado depois (campos financeiros + preservados):')
        for k in fin + ['statusAssinatura', 'linkContratoDrive', 'criadoEm']:
            if k in depois:
                print(f'  {k} =', list(depois[k].values())[0])
        return
    print(f'\n[APPLY] Gravando {len(writes)} contratos...')
    commit(writes)
    print('✅ Concluído.')


if __name__ == '__main__':
    main()

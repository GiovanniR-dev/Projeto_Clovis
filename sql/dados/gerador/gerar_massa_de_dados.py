# Massa de dados do CRMoveis (Etapa 16 do manual): cerca de oito meses de operacao de uma imobiliaria
# pequena de Sao Paulo, Guarulhos e Aruja. Todos os nomes, documentos, telefones e enderecos sao ficticios.
# O gerador e reproduzivel (semente fixa) e grava sql/dados/10_massa_de_dados.sql.
# Uso, na pasta do repositorio: python sql/dados/gerador/gerar_massa_de_dados.py
# A carga passa pelas restricoes e gatilhos do banco: o que violar uma regra e recusado.
import random, hashlib, json, sys
from datetime import date, datetime, timedelta
R = random.Random(2026)
OUT = sys.argv[1] if len(sys.argv) > 1 else "sql/dados/10_massa_de_dados.sql"
HOJE = date(2026, 10, 20)

def q(v):
    if v is None: return "NULL"
    if isinstance(v, bool): return "TRUE" if v else "FALSE"
    if isinstance(v, (int, float)): return repr(round(v, 2)) if isinstance(v, float) else str(v)
    if isinstance(v, datetime): return f"'{v:%Y-%m-%d %H:%M:%S}'"
    if isinstance(v, date): return f"'{v:%Y-%m-%d}'"
    if isinstance(v, Raw): return v.s
    return "'" + str(v).replace("'", "''") + "'"
class Raw:
    def __init__(self, s): self.s = s
SQL = []
def sec(t): SQL.append(f"\n-- {'-' * 66}\n-- {t}\n-- {'-' * 66}")
def ins(table, rows, comment=None):
    if not rows: return
    if comment: SQL.append(f"-- {comment}")
    cols = list(rows[0].keys())
    vals = ",\n    ".join("(" + ", ".join(q(r[c]) for c in cols) + ")" for r in rows)
    SQL.append(f"INSERT INTO {table} ({', '.join(cols)}) VALUES\n    {vals};")
def stmt(s): SQL.append(s)
def money(x): return round(x + 1e-9, 2)
def dia_util_apos(d, n):
    while n:
        d += timedelta(days=1)
        if d.weekday() < 5: n -= 1
    return d
def util_ou_seguinte(d):
    while d.weekday() >= 5: d += timedelta(days=1)
    return d
def dt(d, h=10, m=0): return datetime(d.year, d.month, d.day, h, m)
def cpf(n):
    base = [int(x) for x in f"{n:09d}"]
    for k in (10, 11):
        s = sum(b * w for b, w in zip(base, range(k, 1, -1))); dv = (s * 10) % 11 % 10; base.append(dv)
    return "".join(map(str, base))
def cnpj(n):
    base = [int(x) for x in f"{n:08d}0001"]
    for ws in ([5, 4, 3, 2, 9, 8, 7, 6, 5, 4, 3, 2], [6, 5, 4, 3, 2, 9, 8, 7, 6, 5, 4, 3, 2]):
        s = sum(b * w for b, w in zip(base, ws)); r = s % 11; base.append(0 if r < 2 else 11 - r)
    return "".join(map(str, base))
def fone_cel(n): return f"1190000{n:04d}"    # celular: 9 digitos depois do DDD
def fone_fixo(n): return f"113000{n:04d}"    # fixo: 8 digitos depois do DDD
# listas de dominio (sql/dados/07_dados_de_referencia.sql): os codigos tem numero fixo
ORIGEM_ID = {"site": 1, "indicacao": 2, "portal": 3, "instagram": 4, "whatsapp": 5, "interno": 6}
TIPO_ID = {"Apartamento": 1, "Casa": 2, "Casa em condominio": 3, "Cobertura": 4, "Kitnet": 5, "Terreno": 6, "Sala comercial": 7, "Loja": 8, "Galpao": 9, "Chacara": 10}
FORMA_ID = {"pix": 1, "ted": 2, "boleto": 3, "dinheiro": 4, "cartao": 5}
CAT = {"corretagem_venda": 1, "intermediacao_locacao": 2, "aluguel": 3, "taxa_administracao": 4, "multa_rescisoria": 5, "servico": 6,
       "comissao": 7, "repasse": 8, "despesa_operacional": 9, "imposto": 10}

# =====================================================================
# 1. PESSOAS E PAPEIS
# =====================================================================
U = {}   # id -> dict
ROLES = {}  # id -> {papel: (dt_inicio, dt_fim)}
def pessoa(i, nome, origem, papeis, email=None, doc=None, cad=None, senha=False):
    U[i] = dict(id_usuario=i, nm_usuario=nome, nr_cpf_cnpj=doc, ds_email=email, ds_senha_hash=("$2b$12$" + hashlib.sha256(nome.encode()).hexdigest()[:53]) if senha else None,
                id_origem=ORIGEM_ID[origem], fl_ativo=True, dt_cadastro=cad or dt(date(2026, 3, 2)), dt_anonimizacao=None)
    ROLES[i] = dict(papeis)
STAFF = [(1, "Carla Mendes", {"administrador": date(2024, 2, 1)}),
         (2, "Fabio Torres", {"financeiro": date(2024, 3, 1)}),
         (3, "Renata Lopes", {"financeiro": date(2025, 6, 2)}),
         (4, "Rui Almeida", {"corretor": date(2024, 2, 1)}),
         (5, "Lia Martins", {"corretor": date(2024, 8, 1)}),
         (6, "Paulo Nunes", {"corretor": date(2025, 3, 10)}),
         (7, "Bianca Freitas", {"corretor": date(2026, 2, 2)}),
         (8, "Sergio Dias", {"corretor": date(2024, 5, 2)})]
for i, n, p in STAFF:
    pessoa(i, n, "interno", p, email=n.split()[0].lower().replace("e", "e").replace("a", "a") + "@crmoveis.example", doc=cpf(100000000 + i * 7919),
           cad=dt(min(p.values())), senha=True)
CRECI = {4: "CRECI-SP 101010-F", 5: "CRECI-SP 202020-F", 6: "CRECI-SP 303030-F", 7: "CRECI-SP 404040-F", 8: "CRECI-SP 505050-F"}
EMPRESAS = [(9, "Foto Pro Imagens Ltda", "fornecedor", 11223344), (10, "Reparos Casa & Cia Ltda", "fornecedor", 22334455),
            (11, "Vistoria Certa Ltda", "fornecedor", 33445566), (12, "Banco Horizonte S.A.", "instituicao_financeira", 44556677),
            (13, "Banco Litoral S.A.", "instituicao_financeira", 55667788)]
for i, n, papel, c in EMPRESAS:
    pessoa(i, n, "interno", {papel: date(2025, 1, 15)}, email="contato@" + n.split()[0].lower() + n.split()[1].lower() + ".example", doc=cnpj(c), cad=dt(date(2025, 1, 15)))
PROPS = [(14, "Marta Rocha", "indicacao"), (15, "Ana Souza", "site"), (16, "Otavio Prado", "portal"), (17, "Helena Castro", "indicacao"),
         (18, "Jorge Matos", "portal"), (19, "Beatriz Antunes", "instagram"), (20, "Construtora Vale Verde Ltda", "interno"),
         (21, "Ricardo Pires", "site"), (22, "Lucia Fernandes", "indicacao"), (23, "Eduardo Lima", "portal")]
for k, (i, n, o) in enumerate(PROPS):
    ini = date(2025, 8, 4) + timedelta(days=17 * k)
    doc = cnpj(66778899) if i == 20 else cpf(200000000 + i * 104729)
    pessoa(i, n, o, {"proprietario": ini}, email=None if i == 20 else n.split()[0].lower().replace("u", "u").replace("a", "a") + "." + n.split()[-1].lower() + "@email.example", doc=doc, cad=dt(ini))
U[20]["ds_email"] = "comercial@valeverde.example"
ROLES[15]["cliente"] = date(2026, 5, 4)    # Ana: proprietaria que tambem procura imovel para alugar (dois papeis)
ROLES[19]["cliente"] = date(2026, 6, 15)   # Beatriz: proprietaria que quer comprar outro imovel
CLIENTES = ["Bruno Lima", "Camila Rocha", "Diego Alves", "Elisa Moura", "Felipe Santos", "Gabriela Nunes", "Henrique Costa", "Isabela Ribeiro",
            "Joao Pedro Silva", "Karina Duarte", "Leonardo Teixeira", "Mariana Oliveira", "Nicolas Barbosa", "Olivia Cardoso", "Pedro Araujo",
            "Quiteria Martins", "Rafael Gomes", "Sabrina Lopes", "Thiago Ferreira", "Ursula Campos", "Vinicius Ramos", "Wesley Pinto",
            "Yasmin Correia", "Zeca Batista", "Amanda Freire", "Caio Monteiro", "Daniela Prates", "Everton Silveira", "Fernanda Viana",
            "Gustavo Lacerda", "Heloisa Brandao", "Igor Sampaio"]
ORIGENS = ["whatsapp", "whatsapp", "whatsapp", "site", "portal", "instagram", "indicacao"]
CLI_INI = {}
for k, n in enumerate(CLIENTES):
    i = 24 + k
    if i == 24: ini = date(2025, 8, 18)            # Bruno: inquilino desde 2025
    elif i in (25, 26, 27): ini = date(2026, 1, 12) + timedelta(days=9 * (i - 25))
    else: ini = date(2026, 2, 2) + timedelta(days=int(k * 7.2))
    CLI_INI[i] = ini
    import unicodedata
    slug = unicodedata.normalize("NFKD", n.lower()).encode("ascii", "ignore").decode().replace(" ", ".")
    needs_doc = i in (24, 25, 26, 27, 28, 29, 30, 31, 32)
    pessoa(i, n, ORIGENS[k % len(ORIGENS)], {"cliente": ini}, email=slug + "@email.example", doc=cpf(300000000 + i * 15485863 % 99999999) if needs_doc else None,
           cad=dt(ini, 9 + k % 8, (k * 7) % 60))
# telefones: entidade fraca de USUARIO (pessoa + sequencia). O numero nao e chave: o mesmo numero pode estar
# no cadastro de mais de uma pessoa, e exatamente uma delas e a titular (RN03)
TEL = []
def tel(i, numero, principal, titular):
    seq = sum(1 for t in TEL if t["id_usuario"] == i) + 1
    TEL.append(dict(id_usuario=i, nr_sequencia=seq, nr_telefone=numero, fl_principal=principal, fl_titular=titular))
nt = 0
for i in sorted(U):
    nt += 1
    tel(i, fone_fixo(nt) if i in (9, 10, 11, 12, 13, 20) else fone_cel(nt), True, True)
# segundo numero para alguns
for i in (4, 5, 15, 20, 30):
    nt += 1
    tel(i, fone_cel(nt), False, True)
# numeros compartilhados: o fixo do casal Camila (titular) e Diego; o celular comercial da construtora usado pelo socio Eduardo
nt += 1
tel(25, fone_fixo(nt), False, True); tel(26, fone_fixo(nt), False, False)
tel(23, next(t["nr_telefone"] for t in TEL if t["id_usuario"] == 20 and not t["fl_principal"]), False, False)

sec("1. PESSOAS E PAPEIS (especializacao de USUARIO) e TELEFONES")
stmt("SET crmoveis.id_usuario = '1';   -- quem esta gravando: a administradora (auditoria, RN40)")
stmt("BEGIN;")
ins("usuario", [U[i] for i in sorted(U)], "55 pessoas: equipe, fornecedores, bancos, proprietarios e clientes")
for papel in ["administrador", "financeiro", "corretor", "fornecedor", "instituicao_financeira", "proprietario", "cliente"]:
    rows = []
    for i in sorted(U):
        if papel in ROLES[i]:
            r = dict(id_usuario=i)
            if papel == "corretor": r["nr_creci"] = CRECI[i]
            r["dt_inicio"] = ROLES[i][papel]; r["dt_fim"] = None
            rows.append(r)
    ins(papel, rows)
ins("telefone", TEL, "o telefone e da pessoa (usuario + sequencia); dois numeros aparecem em duas pessoas, cada um com exatamente um titular (RN03)")
stmt("COMMIT;")

# =====================================================================
# 2. LOCALIZACAO, IMOVEIS, CARACTERISTICAS E FOTOS
# =====================================================================
CID = [(1, "Sao Paulo", "SP"), (2, "Guarulhos", "SP"), (3, "Aruja", "SP")]
CEPS = [("03310000", 1, "logradouro", "Tatuape", "Rua Tuiuti"), ("03320010", 1, "logradouro", "Tatuape", "Rua Serra de Japi"),
        ("03104000", 1, "logradouro", "Mooca", "Rua da Mooca"), ("04101000", 1, "logradouro", "Vila Mariana", "Rua Domingos de Morais"),
        ("05422000", 1, "logradouro", "Pinheiros", "Rua dos Pinheiros"), ("02012000", 1, "logradouro", "Santana", "Rua Voluntarios da Patria"),
        ("03602000", 1, "logradouro", "Penha", "Rua Padre Joao"), ("07010000", 2, "logradouro", "Centro", "Rua Dom Pedro II"),
        ("07061000", 2, "logradouro", "Vila Galvao", "Avenida Emilio Ribas"), ("07110000", 2, "logradouro", "Macedo", "Avenida Paulo Faccini"),
        ("07115000", 2, "logradouro", "Bosque Maia", "Rua Francisco Foot"), ("07082000", 2, "logradouro", "Picanco", "Avenida Brigadeiro Faria Lima"),
        ("07020000", 2, "logradouro", "Gopouva", "Avenida Doutor Timoteo Penteado"), ("07400000", 3, "geral", None, None),
        ("07432000", 3, "logradouro", "Jardim Real", "Rua das Hortensias")]
CEPINFO = {c[0]: c for c in CEPS}
# bairros de cada cidade (RN51): os dos CEPs de logradouro, o do imovel no CEP geral de Aruja e o Centro de Aruja,
# que tem o mesmo nome do Centro de Guarulhos (o nome so nao se repete dentro da mesma cidade)
BAIRROS = []
for _c in CEPS:
    if _c[3] and (_c[1], _c[3]) not in BAIRROS: BAIRROS.append((_c[1], _c[3]))
BAIRROS += [(3, "Parque Rodrigo Barreto"), (3, "Centro")]
BAIRRO_ID = {b: k for k, b in enumerate(BAIRROS, 1)}
# (id, cep, tipo, finalidade, numero, complemento, bairro (se CEP geral), area_util, area_total, quartos, banheiros, vagas, venda, aluguel, proprietario, corretor)
IM = [
 (101, "03310000", "Apartamento", "locacao", "450", "Apto 82", None, 68, 68, 2, 2, 1, None, 2800, 14, 4),      # C1 Bruno
 (102, "07115000", "Casa", "locacao", "120", None, None, 110, 180, 3, 2, 2, None, 2200, 16, 5),               # C2 Camila
 (103, "07061000", "Apartamento", "locacao", "1500", "Apto 34 Bloco B", None, 54, 54, 2, 1, 1, None, 1800, 17, 6),  # C3 Diego
 (104, "03104000", "Apartamento", "ambas", "2100", "Apto 121", None, 72, 72, 2, 2, 1, 520000, 2500, 18, 8),   # C4 Elisa (rescindido)
 (105, "07010000", "Sala comercial", "locacao", "300", "Sala 2 e 3", None, 140, 140, 0, 2, 3, None, 4500, 21, 7),  # C5 Felipe
 (106, "07115000", "Casa", "venda", "455", None, None, 160, 250, 3, 3, 2, 650000, None, 15, 4),               # C6 Gabriela (vendido)
 (107, "03320010", "Apartamento", "venda", "88", "Apto 154", None, 98, 98, 3, 2, 2, 780000, None, 20, 6),     # C7 Henrique (financiado)
 (108, "07432000", "Casa", "venda", "37", None, None, 130, 300, 3, 2, 3, 520000, None, 23, 7),                # C8 Isabela (cancelado)
 (109, "05422000", "Apartamento", "locacao", "1020", "Apto 51", None, 75, 75, 2, 2, 1, None, 3900, 22, 5),    # C9 rascunho
 (110, "02012000", "Apartamento", "venda", "900", "Apto 63", None, 65, 65, 2, 1, 1, 430000, None, 14, 5),     # proposta da Beatriz (cliente) no imovel da Marta
 (111, "07110000", "Apartamento", "venda", "2500", "Apto 12 Torre 1", None, 62, 62, 2, 1, 1, 390000, None, 20, 6),
 (112, "07110000", "Apartamento", "venda", "2500", "Apto 44 Torre 2", None, 62, 62, 2, 1, 1, 395000, None, 20, 6),
 (113, "07082000", "Casa", "ambas", "260", None, None, 140, 200, 3, 2, 2, 610000, 3200, 21, 7),
 (114, "03602000", "Casa", "venda", "75", None, None, 90, 125, 2, 1, 1, 450000, None, 14, 4),
 (115, "04101000", "Kitnet", "locacao", "3100", "Apto 92", None, 45, 45, 1, 1, 0, None, 2900, 22, 5),
 (116, "07020000", "Apartamento", "locacao", "640", "Apto 21", None, 50, 50, 2, 1, 1, None, 1600, 17, 6),
 (117, "07400000", "Terreno", "venda", "s/n", "Lote 14 Quadra C", "Parque Rodrigo Barreto", 0, 360, 0, 0, 0, 230000, None, 23, 7),
 (118, "07010000", "Loja", "ambas", "410", "Loja terrea", None, 85, 85, 0, 1, 0, 720000, 5200, 21, 7),
 (119, "03310000", "Apartamento", "venda", "620", "Apto 33", None, 82, 82, 3, 2, 2, 690000, None, 14, 4),
 (120, "07061000", "Casa", "locacao", "58", None, None, 120, 160, 3, 2, 2, None, 2600, 16, 5),
 (121, "05422000", "Cobertura", "venda", "1200", "Apto 102", None, 110, 110, 3, 3, 2, 1250000, None, 22, 5),
 (122, "07115000", "Apartamento", "locacao", "95", "Apto 11", None, 58, 58, 2, 1, 1, None, 1900, 18, 6),
 (123, "02012000", "Apartamento", "locacao", "1400", "Apto 74", None, 60, 60, 2, 1, 1, None, 2300, 19, 5),
 (124, "07432000", "Casa em condominio", "venda", "12", None, None, 150, 300, 4, 3, 2, 690000, None, 23, 7),
 (125, "03320010", "Apartamento", "ambas", "200", "Apto 41", None, 70, 70, 2, 2, 1, 560000, 2700, 18, 4),
 (126, "07082000", "Apartamento", "venda", "1800", "Apto 23", None, 55, 55, 2, 1, 1, 340000, None, 16, 6),
 (127, "03104000", "Galpao", "locacao", "1750", "Galpao", None, 400, 450, 0, 2, 4, None, 9500, 21, 4),
 (128, "07020000", "Casa", "venda", "310", None, None, 100, 140, 3, 2, 2, 480000, None, 17, 6),
 (129, "04101000", "Apartamento", "venda", "2200", "Apto 152", None, 88, 88, 2, 2, 1, 830000, None, 15, 5),
 (130, "07110000", "Casa", "locacao", "77", None, None, 95, 140, 2, 1, 2, None, 2100, 23, 7)]
STATUS_IM = {101: "alugado", 102: "alugado", 103: "alugado", 104: "alugado", 105: "alugado", 106: "reservado", 107: "reservado", 108: "reservado", 127: "inativo"}
GRUPO = {"Apartamento": "apto", "Cobertura": "apto", "Kitnet": "apto", "Casa": "casa", "Casa em condominio": "casa", "Chacara": "casa",
         "Terreno": "terreno", "Sala comercial": "comercial", "Loja": "comercial", "Galpao": "comercial"}
TIPO_NM = {}   # id do imovel -> nome do tipo
rows = []
for (i, cep, tp, fin, num, comp, bairro_g, au, at, qq, bb, vv, venda, alug, prop, cor) in IM:
    c = CEPINFO[cep]
    TIPO_NM[i] = tp
    rows.append(dict(id_imovel=i, cd_imobizi=f"IMB-{3400 + i}", id_proprietario=prop, id_corretor_responsavel=cor, nr_cep=cep, id_tipo_imovel=TIPO_ID[tp], tp_finalidade=fin,
                     nm_logradouro=c[4] or "Estrada do Rio Abaixo", nr_endereco=num, ds_complemento=comp, id_bairro=BAIRRO_ID[(c[1], bairro_g or c[3])], nm_bairro=bairro_g or c[3],
                     vl_area_util=au or None, vl_area_total=at, qt_quartos=qq, qt_banheiros=bb, qt_vagas_garagem=vv, vl_venda=venda, vl_aluguel=alug,
                     st_imovel="disponivel", ds_anuncio=None, dt_cadastro=dt(ROLES[prop]["proprietario"] + timedelta(days=(i * 3) % 40), 14)))
TXT = {"apto": "{n} de {q} dormitorio(s) no bairro {b}, {a} m2 de area util", "casa": "{n} de {q} dormitorios em {b}, terreno de {t} m2",
       "comercial": "{n} em {b}, {a} m2", "terreno": "Terreno de {t} m2 em {b}, pronto para construir"}
for r, im in zip(rows, IM):
    nm = TIPO_NM[r["id_imovel"]]
    r["ds_anuncio"] = TXT[GRUPO[nm]].format(n=nm, q=r["qt_quartos"], b=r["nm_bairro"], a=int(r["vl_area_util"] or 0), t=int(r["vl_area_total"]))
CARS = ["Piscina", "Churrasqueira", "Academia", "Varanda gourmet", "Elevador", "Portaria 24h", "Quintal", "Aceita pet", "Mobiliado",
        "Proximo ao metro", "Vaga coberta", "Salao de festas", "Ar-condicionado", "Energia solar", "Area de servico"]
IMCAR, FOTOS = [], []
for (i, cep, tp, *_rest) in IM:
    g = GRUPO[tp]
    pool = list(range(1, 16))
    if g == "casa": pool = [2, 7, 8, 11, 13, 14, 15, 1]
    elif g == "terreno": pool = []
    elif g == "comercial": pool = [5, 6, 10, 11, 13]
    for c in R.sample(pool, min(len(pool), R.randint(2, 5))): IMCAR.append(dict(id_caracteristica=c, id_imovel=i))
    for n in range(1, (2 if g == "terreno" else R.randint(4, 7)) + 1):
        FOTOS.append(dict(id_imovel=i, nr_foto=n, nr_ordem=n, ds_url=f"https://img.crmoveis.example/imoveis/{i}/{n}.jpg"))
sec("2. LOCALIZACAO, IMOVEIS, CARACTERISTICAS E FOTOS")
ins("cidade", [dict(id_cidade=a, nm_cidade=b, sg_uf=c) for a, b, c in CID])
ins("cep", [dict(nr_cep=c[0], id_cidade=c[1], tp_cep=c[2]) for c in CEPS], "o CEP geral de Aruja nao determina rua nem bairro (17.25)")
ins("bairro", [dict(id_bairro=k, id_cidade=ci, nm_bairro=nm) for (ci, nm), k in BAIRRO_ID.items()],
    "bairros de cada cidade, cadastrados uma vez; o Centro existe em Guarulhos e em Aruja (RN51)")
ins("caracteristica", [dict(id_caracteristica=k, nm_caracteristica=n) for k, n in enumerate(CARS, 1)])
ins("imovel", [{k: v for k, v in r.items() if k != "nm_bairro"} for r in rows], "30 imoveis de 10 proprietarios; cidade e UF vem do CEP (RN41); o bairro e da cidade do CEP (RN51)")
ins("imovel_caracteristica", IMCAR)
ins("foto", FOTOS)
ins("conta_bancaria", [dict(id_conta=1, nm_apelido="Conta movimento", nm_instituicao="Banco Horizonte S.A.", tp_conta_bancaria="corrente", fl_ativa=True),
                       dict(id_conta=2, nm_apelido="Conta alugueis", nm_instituicao="Banco Horizonte S.A.", tp_conta_bancaria="corrente", fl_ativa=True),
                       dict(id_conta=3, nm_apelido="Caixa do escritorio", nm_instituicao=None, tp_conta_bancaria="caixa", fl_ativa=True)])
TAGS = ["quente", "morno", "frio", "investidor", "primeira compra", "locacao", "financiamento", "permuta"]
ins("tag", [dict(id_tag=k, nm_tag=n) for k, n in enumerate(TAGS, 1)])

# =====================================================================
# 3. PERFIS DE INTERESSE, CONVERSAS, MENSAGENS, FUNIL, TAREFAS E AUTOMACAO
# =====================================================================
IMD = {r["id_imovel"]: r for r in rows}
BAIRRO_CID = {c[3]: c[1] for c in CEPS if c[3]}
# roteiro de cada conversa: (id_conversa, cliente, corretor, data de inicio, estagio final, imoveis de interesse, contrato)
ROT = []
def conv(cid, cli, cor, ini, final, ims, tags):
    ROT.append(dict(id=cid, cli=cli, cor=cor, ini=ini, final=final, ims=ims, tags=tags))
# conversas que viraram contrato
conv(1, 24, 4, date(2025, 8, 18), "Ganho", [101, 125], [6, 1])
conv(2, 25, 5, date(2026, 1, 12), "Ganho", [102, 120], [6, 1])
conv(3, 26, 6, date(2026, 1, 21), "Ganho", [103, 116, 122], [6])
conv(4, 27, 8, date(2026, 1, 30), "Ganho", [104, 125], [6])
conv(5, 28, 7, date(2026, 5, 18), "Ganho", [105, 118], [6, 4])
conv(6, 29, 4, date(2026, 3, 9), "Ganho", [106, 113, 124], [1, 5])
conv(7, 30, 6, date(2026, 5, 4), "Ganho", [107, 119], [1, 7])
conv(8, 31, 7, date(2026, 6, 22), "Perdido", [108, 124], [7])          # venda cancelada: financiamento reprovado
conv(9, 32, 5, date(2026, 9, 14), "Contrato", [109, 115], [6, 1])      # contrato em rascunho
# propostas em andamento
conv(10, 19, 5, date(2026, 6, 15), "Proposta", [110, 114], [4])        # Beatriz: proprietaria e cliente
conv(11, 33, 6, date(2026, 8, 3), "Proposta", [111, 112, 126], [5, 7])
conv(12, 34, 7, date(2026, 7, 6), "Perdido", [113, 128], [3])          # proposta recusada
conv(13, 15, 5, date(2026, 5, 4), "Visita", [115, 123], [6])            # Ana: proprietaria que procura aluguel
# visitas
for k, (cli, cor, ims) in enumerate([(35, 4, [119, 114]), (36, 5, [121, 129]), (37, 6, [116, 122]), (38, 7, [124, 117]), (39, 4, [125, 101]),
                                     (40, 5, [123, 115]), (41, 6, [126, 111])]):
    conv(14 + k, cli, cor, date(2026, 6, 1) + timedelta(days=12 * k), "Visita", ims, [R.choice([1, 2])])
# qualificacao e novos contatos
for k, cli in enumerate(range(42, 50)):
    conv(21 + k, cli, [4, 5, 6, 7][k % 4], date(2026, 7, 20) + timedelta(days=8 * k), "Qualificacao", R.sample([111, 112, 114, 116, 120, 122, 126, 128, 130], 2), [2])
for k, cli in enumerate(range(50, 56)):
    conv(29 + k, cli, None if k % 2 == 0 else [5, 6, 7][k % 3], date(2026, 10, 2) + timedelta(days=3 * k), "Novo contato", R.sample([111, 116, 120, 130, 115], 1), [])
# perdidos
for k, (cli, cor) in enumerate([(35, 8), (36, 8), (42, 4), (43, 5), (44, 6), (45, 7), (46, 4), (47, 8), (48, 5)]):
    conv(35 + k, cli, cor, date(2026, 2, 16) + timedelta(days=11 * k), "Perdido", R.sample([110, 114, 119, 121, 126, 128, 129], 2), [3])
# segundas conversas de clientes que voltaram
conv(44, 24, 4, date(2026, 9, 21), "Qualificacao", [114, 119], [1, 5])   # Bruno, depois de sair da locacao, quer comprar
conv(45, 49, 6, date(2026, 10, 8), "Novo contato", [128], [])
MARCOS = {1: ["2025-08-18", "2025-08-25", "2025-09-06", "2025-09-08", "2025-09-15", "2025-09-22"],
          2: ["2026-01-12", "2026-01-19", "2026-01-31", "2026-02-03", "2026-02-10", "2026-02-20"],
          3: ["2026-01-21", "2026-02-02", "2026-03-14", "2026-03-16", "2026-03-20", "2026-03-30"],
          4: ["2026-01-30", "2026-02-06", "2026-02-21", "2026-02-25", "2026-03-02", "2026-03-09"],
          5: ["2026-05-18", "2026-05-25", "2026-06-06", "2026-06-10", "2026-06-15", "2026-06-24"],
          6: ["2026-03-09", "2026-03-16", "2026-03-28", "2026-04-01", "2026-04-15", "2026-05-20"],
          7: ["2026-05-04", "2026-05-11", "2026-05-23", "2026-05-26", "2026-06-10", "2026-06-30"],
          8: ["2026-06-22", "2026-06-29", "2026-07-11", "2026-07-15", "2026-07-30", "2026-09-12"],
          9: ["2026-09-14", "2026-09-18", "2026-09-26", "2026-09-29", "2026-10-16"],
          10: ["2026-06-15", "2026-06-22", "2026-07-04", "2026-10-09"],
          11: ["2026-08-03", "2026-08-10", "2026-08-22", "2026-10-14"],
          12: ["2026-07-06", "2026-07-13", "2026-07-25", "2026-08-01", "2026-08-05"],
          13: ["2026-05-04", "2026-05-11", "2026-06-13"]}
for k in range(7):
    ini = date(2026, 6, 1) + timedelta(days=12 * k)
    MARCOS[14 + k] = [str(ini), str(ini + timedelta(days=4)), str(ini + timedelta(days=10 + k))]
ESTAGIO = {"Novo contato": 1, "Qualificacao": 2, "Visita": 3, "Proposta": 4, "Contrato": 5, "Ganho": 6, "Perdido": 7}
CAMINHO = {"Novo contato": [1], "Qualificacao": [1, 2], "Visita": [1, 2, 3], "Proposta": [1, 2, 3, 4], "Contrato": [1, 2, 3, 4, 5],
           "Ganho": [1, 2, 3, 4, 5, 6], "Perdido": None}
CONV, HIST, MSG, CTAG, CIM, TAR, EXE, LOG = [], [], [], [], [], [], [], []
R2 = random.Random(7)          # sorteios do acompanhamento, separados para nao mudar o restante da massa
PARADAS = {16, 23}            # conversas abertas deixadas sem contato recente, de proposito
ANONIMIZADOS = {47: date(2026, 9, 30)}   # cliente que pediu a exclusao dos dados (PO07): a conversa aberta e encerrada nesse dia
ntar = 0
for c in ROT:
    cam = CAMINHO[c["final"]] or ([1, 2, 7] if c["id"] in range(35, 44) and c["id"] % 2 else ([1, 2, 3, 4, 7] if c["id"] == 12 else ([1, 2, 3, 4, 5, 7] if c["id"] == 8 else [1, 7])))
    t = dt(c["ini"], 9 + c["id"] % 9, (c["id"] * 13) % 60)
    passos = []
    if c["id"] in MARCOS:
        assert len(MARCOS[c["id"]]) == len(cam), (c["id"], cam)
        passos = [(dt(date.fromisoformat(d_), 9 + k, (c["id"] * 7) % 60), e) for k, (d_, e) in enumerate(zip(MARCOS[c["id"]], cam))]
    else:
        for k, e in enumerate(cam):
            passos.append((t, e))
            t = t + timedelta(days=R.randint(2, 9) if e < 4 else R.randint(5, 14), hours=R.randint(0, 5))
        if passos[-1][0] > dt(HOJE, 8):   # comprime a linha do tempo ate hoje, sem repetir horarios
            t0 = passos[0][0]; span = (passos[-1][0] - t0).total_seconds(); lim = (dt(HOJE, 8) - t0).total_seconds()
            passos = [(t0 + timedelta(seconds=int((p - t0).total_seconds() * lim / span)), e) for p, e in passos]
    encerrada = c["final"] in ("Ganho", "Perdido")
    CONV.append(dict(id_conversa=c["id"], id_cliente=c["cli"], id_corretor=c["cor"], id_estagio=cam[-1], st_conversa="encerrada" if encerrada else "aberta",
                     ds_notas={"Ganho": "Negocio fechado.", "Perdido": "Cliente desistiu ou foi atendido por outra imobiliaria."}.get(c["final"]), dt_inicio=passos[0][0]))
    for k, (ti, e) in enumerate(passos):
        HIST.append(dict(id_conversa=c["id"], dt_alteracao=ti, id_estagio=e, id_usuario=c["cor"] if k > 0 and c["cor"] else None))
    c["passos"] = passos
    for tg in c["tags"]: CTAG.append(dict(id_conversa=c["id"], id_tag=tg))
    for k, im in enumerate(c["ims"]): CIM.append(dict(id_imovel=im, id_conversa=c["id"], dt_interesse=passos[0][0] + timedelta(hours=1 + k)))
    # mensagens
    nome = U[c["cli"]]["nm_usuario"].split()[0]
    im0 = IMD[c["ims"][0]]
    alvo = "comprar" if im0["tp_finalidade"] == "venda" else ("alugar" if im0["tp_finalidade"] == "locacao" else R.choice(["comprar", "alugar"]))
    roteiro = [("entrada", f"Ola! Vi o anuncio do imovel {im0['cd_imobizi']} ({im0['nm_bairro']}). Ainda esta disponivel?"),
               ("saida", f"Oi, {nome}! Esta sim. Voce procura para {alvo}? Quantos dormitorios e qual faixa de valor?"),
               ("entrada", f"Quero {alvo}, {max(1, im0['qt_quartos'] or 1)} quartos, regiao de {im0['nm_bairro']}.")]
    if 2 in cam: roteiro += [("saida", "Separei algumas opcoes no seu perfil. Vou te mandar os links."), ("nota", "Cliente qualificado: perfil cadastrado.")]
    if 3 in cam: roteiro += [("entrada", "Gostei de dois. Da para visitar no sabado?"), ("saida", "Agendado! Te mando o endereco e o horario.")]
    if 4 in cam: roteiro += [("entrada", "Quero fazer uma proposta."), ("nota", "Proposta registrada no sistema.")]
    if 5 in cam: roteiro += [("saida", "Contrato em preparacao. Preciso dos seus documentos."), ("entrada", "Enviei os documentos por e-mail.")]
    if 6 in cam: roteiro += [("saida", "Contrato assinado. Parabens!"), ("entrada", "Obrigado pelo atendimento!")]
    if 7 in cam: roteiro += [("entrada", "Obrigado, mas por enquanto vou aguardar."), ("nota", "Marcado como perdido.")]
    tm = passos[0][0]
    for k, (d_, txt) in enumerate(roteiro, 1):
        tm = tm + timedelta(minutes=R.randint(3, 240))
        if k > 3 and len(passos) > 1:
            tm = max(tm, passos[min(len(passos) - 1, (k - 2) // 2)][0])
        if tm.date() > HOJE: tm = dt(HOJE, 8) + timedelta(minutes=k)
        nota = d_ == "nota"
        MSG.append(dict(id_conversa=c["id"], nr_mensagem=k, cd_externo=None if nota else "wamid." + hashlib.md5(f"{c['id']}-{k}".encode()).hexdigest()[:20].upper(),
                        tp_direcao=None if nota else d_, tp_canal="nota_interna" if nota else "whatsapp", ds_corpo=txt, dt_mensagem=tm))
    # acompanhamento das conversas abertas: o corretor retoma o contato nos ultimos dias.
    # As conversas em PARADAS ficam de proposito sem contato recente (a consulta de auditoria A06 deve encontra-las).
    if not encerrada and c["cor"] and c["id"] not in PARADAS and c["cli"] not in ANONIMIZADOS and (HOJE - tm.date()).days > 7:
        seg = R2.choice({
            "Qualificacao": [[("saida", f"Oi, {nome}! Separei mais duas opcoes no seu perfil. Posso te mandar?"), ("entrada", "Pode mandar, vou olhar hoje a noite.")],
                             [("saida", f"{nome}, entrou um imovel novo na regiao que voce procura. Quer o link?"), ("entrada", "Quero sim! Tem vaga de garagem?")],
                             [("saida", f"Oi, {nome}! Conseguiu ver as opcoes que mandei?"), ("entrada", "Vi algumas. Vou separar as que gostei e te falo.")]],
            "Visita": [[("saida", f"{nome}, o que achou da visita? Quer ver outros imoveis parecidos?"), ("entrada", "Gostei, mas quero ver mais um antes de decidir.")],
                       [("saida", f"Oi, {nome}! Posso marcar a segunda visita para sabado?"), ("entrada", "Pode ser sabado de manha.")],
                       [("saida", f"{nome}, o proprietario aceita conversar sobre o valor. Quer fazer uma proposta?"), ("entrada", "Vou conversar em casa e te respondo.")]],
            "Proposta": [[("saida", "O proprietario esta analisando a sua proposta; devo ter retorno ate sexta."), ("entrada", "Combinado, aguardo.")],
                         [("saida", "Recebi uma contraproposta do proprietario. Posso te ligar?"), ("entrada", "Pode ligar depois das 18h.")]],
        }.get(c["final"], [[]]))
        t1 = dt(HOJE - timedelta(days=R2.randint(1, 6)), R2.randint(9, 15), R2.randint(0, 59))
        for d_, txt in seg:
            k += 1
            MSG.append(dict(id_conversa=c["id"], nr_mensagem=k, cd_externo="wamid." + hashlib.md5(f"{c['id']}-{k}".encode()).hexdigest()[:20].upper(),
                            tp_direcao=d_, tp_canal="whatsapp", ds_corpo=txt, dt_mensagem=t1))
            t1 += timedelta(minutes=R2.randint(5, 90))
    # tarefas do corretor
    if c["cor"]:
        for k, (titulo, prazo, st) in enumerate([("Retornar o primeiro contato", 1, "concluida"), ("Enviar opcoes do perfil", 3, "concluida" if len(cam) > 2 else "pendente"),
                                                  ("Confirmar visita", 6, "concluida" if 3 in cam else None)]):
            if st is None: continue
            ntar += 1
            venc = passos[0][0] + timedelta(days=prazo)
            if st == "pendente" and c["final"] == "Perdido": st = "cancelada"
            TAR.append(dict(id_tarefa=ntar, id_conversa=c["id"], id_corretor=c["cor"], ds_titulo=titulo, ds_tarefa=None, dt_vencimento=venc, st_tarefa=st))
    # automacao N8N: demanda extraida das mensagens (mesma ideia do app original)
    if c["id"] % 3 != 2 or c["final"] in ("Visita", "Proposta"):
        dem = dict(finalidade=alvo, regiao=im0["nm_bairro"], quartos_min=im0["qt_quartos"], valor_max=int((im0["vl_venda"] or im0["vl_aluguel"]) * 1.1))
        cd = hashlib.sha1(json.dumps(dem, sort_keys=True).encode()).hexdigest()[:16]
        te = passos[0][0] + timedelta(minutes=12)
        st = "enviada"
        if c["id"] in (31, 33): st = "recebida"
        if c["id"] in (22, 38): st = "erro"
        if c["id"] in (27,): st = "processada"
        EXE.append(dict(id_conversa=c["id"], nr_execucao=1, cd_demanda=cd, st_execucao=st, ds_demanda=json.dumps(dem, ensure_ascii=False),
                        ds_criterios=None if st == "recebida" else json.dumps(dict(tipo=TIPO_NM[im0["id_imovel"]], bairro=im0["nm_bairro"], quartos_min=im0["qt_quartos"]), ensure_ascii=False),
                        ds_conteudo_enviado=f"{nome}, separei {len(c['ims'])} opcoes para voce: " + ", ".join(IMD[i]["cd_imobizi"] for i in c["ims"]) if st == "enviada" else None,
                        ds_resumo=None if st == "recebida" else f"Cliente quer {alvo} em {im0['nm_bairro']}",
                        ds_erro="Tempo esgotado ao consultar o seletor de imoveis" if st == "erro" else None,
                        dt_execucao=te, dt_envio=te + timedelta(minutes=2) if st == "enviada" else None))
        evs = [("demanda_recebida", "Webhook do WhatsApp recebido")]
        if st != "recebida": evs.append(("criterios_extraidos", "Criterios extraidos das mensagens"))
        if st in ("processada", "enviada"): evs.append(("seletor_consultado", f"{len(c['ims'])} imoveis compativeis"))
        if st == "enviada": evs.append(("disparo_enviado", "Mensagem enviada pelo WhatsApp"))
        if st == "erro": evs.append(("erro", "Seletor nao respondeu em 30 s"))
        for k, (ev, ds) in enumerate(evs, 1):
            LOG.append(dict(id_conversa=c["id"], nr_execucao=1, nr_log=k, nm_evento=ev, ds_evento=ds, ds_dados=None, dt_log=te + timedelta(seconds=20 * k)))
# perfis de interesse e os tipos de imovel que cada perfil aceita (DESEJA)
PERF, PIT, PIB = [], [], []
VIZINHO = {"Tatuape": "Mooca", "Mooca": "Tatuape", "Vila Mariana": "Pinheiros", "Pinheiros": "Vila Mariana", "Santana": "Tatuape", "Penha": "Tatuape",
           "Centro": "Macedo", "Vila Galvao": "Picanco", "Macedo": "Centro", "Bosque Maia": "Macedo", "Picanco": "Vila Galvao", "Gopouva": "Centro",
           "Jardim Real": "Centro", "Parque Rodrigo Barreto": "Jardim Real"}
for c in ROT:
    if c["final"] == "Novo contato" or any(p["id_usuario"] == c["cli"] for p in PERF): continue
    im0 = IMD[c["ims"][0]]
    fin = "venda" if im0["tp_finalidade"] == "venda" else "locacao"
    val = im0["vl_venda"] if fin == "venda" else im0["vl_aluguel"]
    cid_ = CEPINFO[im0["nr_cep"]][1]
    PERF.append(dict(id_usuario=c["cli"], nr_perfil=1, id_cidade=cid_, tp_finalidade=fin,
                     vl_minimo=round(val * 0.7, -2), vl_maximo=round(val * 1.15, -2), qt_quartos_min=im0["qt_quartos"] or None))
    # bairros aceitos (ABRANGE, RN52): o do imovel e, para um terco dos clientes, tambem um bairro vizinho da mesma cidade
    bai_ = [im0["nm_bairro"]] + ([VIZINHO[im0["nm_bairro"]]] if c["cli"] % 3 == 0 else [])
    PIB += [dict(id_usuario=c["cli"], nr_perfil=1, id_bairro=BAIRRO_ID[(cid_, b_)]) for b_ in bai_]
    tipos = [TIPO_NM[im0["id_imovel"]]]
    # metade dos clientes aceita tambem um tipo parecido (RN47: o perfil pode ter varios tipos)
    if c["cli"] % 2 == 0:
        tipos += {"Apartamento": ["Cobertura" if fin == "venda" else "Kitnet"], "Casa": ["Casa em condominio"], "Casa em condominio": ["Casa"],
                  "Sala comercial": ["Loja"], "Loja": ["Sala comercial"]}.get(tipos[0], [])
    PIT += [dict(id_usuario=c["cli"], nr_perfil=1, id_tipo_imovel=TIPO_ID[t]) for t in tipos]
PERF.append(dict(id_usuario=24, nr_perfil=2, id_cidade=1, tp_finalidade="venda", vl_minimo=400000, vl_maximo=700000, qt_quartos_min=2))
PIB += [dict(id_usuario=24, nr_perfil=2, id_bairro=BAIRRO_ID[(1, b_)]) for b_ in ("Tatuape", "Mooca")]
PIT += [dict(id_usuario=24, nr_perfil=2, id_tipo_imovel=TIPO_ID[t]) for t in ("Apartamento", "Cobertura")]
PERF.append(dict(id_usuario=33, nr_perfil=2, id_cidade=2, tp_finalidade="locacao", vl_minimo=1500, vl_maximo=2200, qt_quartos_min=2))
# o perfil 2 do cliente 33 nao tem tipo nem bairro: aceita qualquer tipo de imovel em qualquer bairro de Guarulhos (RN47, RN52)

# o cliente que pediu a exclusao dos dados tinha uma conversa aberta: ela e encerrada como perdida no mesmo dia
for cli, dia in ANONIMIZADOS.items():
    for cv_ in [r for r in CONV if r["id_cliente"] == cli and r["st_conversa"] == "aberta"]:
        k_ = cv_["id_conversa"]
        fim = dt(dia, 9, 5)
        assert max(h["dt_alteracao"] for h in HIST if h["id_conversa"] == k_) < fim and max(m["dt_mensagem"] for m in MSG if m["id_conversa"] == k_) < fim
        cv_.update(id_estagio=ESTAGIO["Perdido"], st_conversa="encerrada", ds_notas="Cliente pediu a exclusao dos dados pessoais (LGPD, PO07); conversa encerrada.")
        HIST.append(dict(id_conversa=k_, dt_alteracao=fim, id_estagio=ESTAGIO["Perdido"], id_usuario=cv_["id_corretor"]))
        n_ = max(m["nr_mensagem"] for m in MSG if m["id_conversa"] == k_)
        MSG.append(dict(id_conversa=k_, nr_mensagem=n_ + 1, cd_externo="wamid." + hashlib.md5(f"{k_}-{n_ + 1}".encode()).hexdigest()[:20].upper(), tp_direcao="entrada",
                        tp_canal="whatsapp", ds_corpo="Bom dia. Nao tenho mais interesse e peco que apaguem os meus dados, por favor.", dt_mensagem=dt(dia, 8, 40)))
        MSG.append(dict(id_conversa=k_, nr_mensagem=n_ + 2, cd_externo=None, tp_direcao=None, tp_canal="nota_interna",
                        ds_corpo="Pedido de exclusao dos dados (LGPD). Cadastro anonimizado e conversa encerrada.", dt_mensagem=fim))
        for t_ in TAR:
            if t_["id_conversa"] == k_ and t_["st_tarefa"] == "pendente": t_["st_tarefa"] = "cancelada"

sec("3. PERFIS DE INTERESSE, CONVERSAS, FUNIL, MENSAGENS, TAREFAS E AUTOMACAO N8N")
ins("perfil_interesse", PERF, "o perfil indica no maximo uma cidade do cadastro (RN42)")
ins("perfil_interesse_tipo", PIT, "tipos aceitos por perfil: um, varios ou nenhum (nenhum = qualquer tipo) (RN47)")
ins("perfil_interesse_bairro", PIB, "bairros aceitos por perfil, todos da cidade do perfil: um, varios ou nenhum (nenhum = qualquer bairro) (RN52)")
ins("conversa", sorted(CONV, key=lambda r: r["id_conversa"]), "45 conversas do WhatsApp; o estagio atual e o do ultimo registro do historico (RN14)")
ins("historico_estagio", HIST, "toda mudanca de estagio, inclusive a inicial, gera um registro (MOVE)")
ins("conversa_tag", CTAG)
ins("conversa_imovel", CIM, "interesse da conversa em imoveis (antes um texto livre 'property_codes' no app original)")
ins("mensagem", MSG, "mensagens com o codigo do WhatsApp (wamid): a mesma mensagem nao e gravada duas vezes (RN31)")
ins("tarefa", TAR)
ins("automacao_execucao", EXE, "a mesma demanda da conversa nao e processada duas vezes (RN31, RNF08)")
ins("automacao_log", LOG)

# =====================================================================
# 4. VISITAS, PROPOSTAS, CONTRATOS, FINANCIAMENTOS E COMISSOES
# =====================================================================
VIS, PROP = [], []
nv = 0
def visita(conv_id, im, d, st, fb=None):
    global nv
    c = next(x for x in ROT if x["id"] == conv_id); nv += 1
    VIS.append(dict(id_visita=nv, id_imovel=im, id_cliente=c["cli"], id_corretor=c["cor"], dt_visita=d, st_visita=st, ds_feedback=fb))
    return nv
VID = {}
VID[1] = visita(1, 101, dt(date(2025, 9, 6), 10), "realizada", "Gostou do apartamento e da localizacao perto do metro.")
visita(1, 125, dt(date(2025, 9, 6), 11, 30), "realizada", "Achou o aluguel acima do orcamento.")
VID[2] = visita(2, 102, dt(date(2026, 1, 31), 9), "realizada", "Casa com quintal, ideal para o cachorro.")
visita(2, 120, dt(date(2026, 1, 31), 11), "cancelada")
VID[3] = visita(3, 103, dt(date(2026, 3, 14), 15), "realizada", "Aprovou; quer mudar em abril.")
visita(3, 116, dt(date(2026, 3, 14), 16, 30), "realizada", "Pequeno demais.")
VID[4] = visita(4, 104, dt(date(2026, 2, 21), 10), "realizada", "Gostou da varanda.")
VID[5] = visita(5, 105, dt(date(2026, 6, 6), 14), "realizada", "Salas adequadas para o escritorio de contabilidade.")
VID[6] = visita(6, 106, dt(date(2026, 3, 28), 10), "realizada", "Quer fazer proposta.")
visita(6, 113, dt(date(2026, 3, 28), 11, 30), "realizada", "Gostou, mas prefere o Bosque Maia.")
VID[7] = visita(7, 107, dt(date(2026, 5, 23), 9, 30), "realizada", "Precisa de financiamento.")
VID[8] = visita(8, 108, dt(date(2026, 7, 11), 10), "realizada", "Casa grande, vai financiar.")
VID[9] = visita(9, 109, dt(date(2026, 9, 26), 11), "realizada", "Fechou: quer comecar em novembro.")
VID[10] = visita(10, 110, dt(date(2026, 7, 4), 15), "realizada", "Quer comprar para investir.")
VID[11] = visita(11, 111, dt(date(2026, 8, 22), 10), "realizada", "Gostou da torre 1.")
visita(11, 112, dt(date(2026, 8, 22), 10, 40), "realizada", "Torre 2 tem menos sol.")
VID[12] = visita(12, 113, dt(date(2026, 7, 25), 16), "realizada", "Achou caro.")
visita(13, 115, dt(date(2026, 6, 13), 10), "realizada", "Quer algo maior.")
visita(13, 123, dt(date(2026, 10, 24), 10), "agendada")
for k in range(7):
    c = ROT[13 + k]
    visita(c["id"], c["ims"][0], dt(c["ini"] + timedelta(days=10 + k), 10 + k % 5), "realizada", "Visita feita; aguardando decisao.")
    if k % 3 == 0: visita(c["id"], c["ims"][1], dt(HOJE + timedelta(days=3 + k), 15), "agendada")
visita(36, 110, dt(date(2026, 3, 7), 10), "cancelada")
visita(37, 114, dt(date(2026, 3, 19), 9), "realizada", "Nao gostou da rua.")
np_ = 0
def proposta(conv_id, im, vl, anunc, st, d, visita_id=None, resp=None, autoriza=False, cond=None):
    global np_
    c = next(x for x in ROT if x["id"] == conv_id); np_ += 1
    PROP.append(dict(id_proposta=np_, id_imovel=im, id_cliente=c["cli"], id_corretor=c["cor"], id_autorizador=1 if autoriza else None,
                     id_proposta_respondida=resp, id_visita=visita_id, vl_proposto=vl, vl_anunciado=anunc, ds_condicoes=cond, st_proposta=st,
                     dt_proposta=d, dt_autorizacao=d + timedelta(hours=3) if autoriza else None))
    return np_
PID = {}
PID[1] = proposta(1, 101, 2800, 2800, "aceita", dt(date(2025, 9, 8), 14), VID[1], cond="Locacao de 12 meses, garantia por seguro-fianca")
PID[2] = proposta(2, 102, 2200, 2200, "aceita", dt(date(2026, 2, 3), 11), VID[2], cond="Entrada em marco")
p = proposta(3, 103, 1650, 1800, "substituida", dt(date(2026, 3, 16), 10), VID[3])
PID[3] = proposta(3, 103, 1800, 1800, "aceita", dt(date(2026, 3, 18), 17), VID[3], resp=p, cond="Contraproposta do proprietario aceita")
PID[4] = proposta(4, 104, 2500, 2500, "aceita", dt(date(2026, 2, 25), 9), VID[4])
PID[5] = proposta(5, 105, 4500, 4500, "aceita", dt(date(2026, 6, 10), 15), VID[5], cond="Locacao comercial de 24 meses")
p1 = proposta(6, 106, 590000, 650000, "substituida", dt(date(2026, 4, 1), 10), VID[6], cond="A vista")
p2 = proposta(6, 106, 630000, 650000, "substituida", dt(date(2026, 4, 3), 16), VID[6], resp=p1, cond="Contraproposta da proprietaria")
PID[6] = proposta(6, 106, 620000, 650000, "aceita", dt(date(2026, 4, 6), 11), VID[6], resp=p2, cond="A vista, escritura em maio")
p = proposta(7, 107, 690000, 780000, "recusada", dt(date(2026, 5, 26), 10), VID[7], autoriza=True, cond="Financiamento de 80%")
PID[7] = proposta(7, 107, 750000, 780000, "aceita", dt(date(2026, 6, 2), 15), VID[7], cond="Financiamento pelo Banco Horizonte")
PID[8] = proposta(8, 108, 520000, 520000, "aceita", dt(date(2026, 7, 15), 10), VID[8], cond="Financiamento pelo Banco Litoral")
PID[9] = proposta(9, 109, 3900, 3900, "aceita", dt(date(2026, 9, 29), 11), VID[9], cond="Inicio em 01/11")
proposta(10, 110, 400000, 430000, "pendente", dt(date(2026, 10, 9), 10), VID[10], cond="A vista")
proposta(11, 111, 345000, 390000, "pendente", dt(date(2026, 10, 14), 16), VID[11], autoriza=True, cond="Desconto acima de 10% autorizado para analise do proprietario")
proposta(12, 113, 520000, 610000, "recusada", dt(date(2026, 8, 1), 9), VID[12], autoriza=True)
sec("4. VISITAS E PROPOSTAS")
ins("visita", VIS, "visita e proposta sao N:N entre cliente e imovel, com atributos proprios (RN16)")
ins("proposta", PROP, "contrapropostas encadeadas (RESPONDE, RN35); desconto acima de 10% com autorizacao do administrador (PO03)")

# contratos: nascem em rascunho e passam a valer na assinatura (RN36)
CT = [  # id, proposta, tipo, forma, valor, pc_corretagem, pc_adm, dia, assinatura, inicio, fim
 (1, PID[1], "locacao", "parcelado_direto", 2800, 100, 10, 5, date(2025, 9, 22), date(2025, 10, 1), date(2026, 9, 30)),
 (2, PID[2], "locacao", "parcelado_direto", 2200, 100, 8, 5, date(2026, 2, 20), date(2026, 3, 1), date(2027, 2, 28)),
 (3, PID[3], "locacao", "parcelado_direto", 1800, 100, 10, 10, date(2026, 3, 30), date(2026, 4, 10), date(2027, 4, 9)),
 (4, PID[4], "locacao", "parcelado_direto", 2500, 100, 10, 15, date(2026, 3, 9), date(2026, 3, 15), date(2027, 3, 14)),
 (5, PID[5], "locacao", "parcelado_direto", 4500, 100, 8, 5, date(2026, 6, 24), date(2026, 7, 1), date(2028, 6, 30)),
 (6, PID[6], "venda", "a_vista", 620000, 6, None, None, date(2026, 5, 20), None, None),
 (7, PID[7], "venda", "financiado", 750000, 5, None, None, date(2026, 6, 30), None, None),
 (8, PID[8], "venda", "financiado", 520000, 5, None, None, date(2026, 8, 25), None, None),
 (9, PID[9], "locacao", "parcelado_direto", 3900, 100, 10, 5, None, date(2026, 11, 1), date(2027, 10, 31))]
CTD = {c[0]: c for c in CT}
CT_IM = {1: 101, 2: 102, 3: 103, 4: 104, 5: 105, 6: 106, 7: 107, 8: 108, 9: 109}
CT_CLI = {1: 24, 2: 25, 3: 26, 4: 27, 5: 28, 6: 29, 7: 30, 8: 31, 9: 32}
sec("5. CONTRATOS, DOCUMENTOS, FINANCIAMENTOS E COMISSOES")
ins("contrato", [dict(id_contrato=c[0], id_proposta=c[1], tp_contrato=c[2], tp_condicao_pagamento=c[3], vl_final=c[4], pc_corretagem=c[5], pc_administracao=c[6],
                      nr_dia_vencimento=c[7], dt_assinatura=None, dt_inicio=c[9], dt_fim=c[10], st_contrato="rascunho", dt_termino=None,
                      ds_motivo_termino=None, tp_iniciativa_rescisao=None) for c in CT], "todos nascem em rascunho (RN36)")
for c in CT:
    if c[8]:
        stmt(f"UPDATE contrato SET st_contrato = 'vigente', dt_assinatura = {q(c[8])} WHERE id_contrato = {c[0]};"
             + ("   -- locacao assinada: o cliente passa a ser tambem INQUILINO (RN33)" if c[2] == "locacao" else ""))
stmt("UPDATE imovel SET st_imovel = 'alugado' WHERE id_imovel IN (101, 102, 103, 104, 105);")
stmt("UPDATE imovel SET st_imovel = 'reservado' WHERE id_imovel IN (106, 107, 108);")
stmt("UPDATE imovel SET st_imovel = 'inativo' WHERE id_imovel = 127;   -- galpao retirado da carteira pelo proprietario")
DOCS = []
for c in CT:
    if not c[8]: continue
    tipos_doc = [1, 2] + ([4] if c[2] == "locacao" else [3])   # contrato assinado, documento do cliente, laudo de vistoria ou matricula (RN53)
    for k, n in enumerate(tipos_doc, 1):
        DOCS.append(dict(id_contrato=c[0], nr_documento=k, id_tipo_documento=n, ds_url=f"https://docs.crmoveis.example/contratos/{c[0]}/{k}.pdf"))
ins("documento", DOCS)
ins("financiamento", [dict(id_contrato=7, id_instituicao=12, vl_financiado=600000, vl_entrada=150000, nr_parcelas=360, pc_juros_aa=10.49,
                           st_financiamento="liberado", dt_aprovacao=date(2026, 8, 20), dt_liberacao=date(2026, 9, 15)),
                      dict(id_contrato=8, id_instituicao=13, vl_financiado=416000, vl_entrada=104000, nr_parcelas=300, pc_juros_aa=11.2,
                           st_financiamento="reprovado", dt_aprovacao=None, dt_liberacao=None)],
    "um financiamento por contrato financiado, identificado pelo proprio contrato (RN22)")
COM = [(1, 4, 40, "assinatura"), (2, 5, 40, "assinatura"), (3, 6, 40, "assinatura"), (4, 8, 40, "assinatura"), (5, 7, 30, "assinatura"), (5, 4, 10, "recebimento"),
       (6, 4, 30, "recebimento"), (6, 5, 20, "recebimento"), (7, 6, 50, "liberacao_credito"), (8, 7, 50, "liberacao_credito")]
ins("comissao", [dict(id_contrato=a, id_corretor=b, pc_comissao=c, tp_regra_pagamento=d) for a, b, c, d in COM],
    "percentual sobre a corretagem do contrato; a soma por contrato nao passa de 100% (RN20)")

# =====================================================================
# 6. FINANCEIRO: CONTAS, BAIXAS, REPASSES, COMISSOES, DESPESAS
# =====================================================================
CR, REC, CP, PAG, MOV, CONC = [], [], [], [], [], []
ncr, ncp = 0, 0
# a categoria define a natureza do lancamento (RN26): o codigo de cada uma esta em CAT
def conta_receber(contrato, cat, pagador, papel, ds, comp, vl, venc):
    global ncr; ncr += 1
    CR.append(dict(id_conta_receber=ncr, id_contrato=contrato, id_categoria=CAT[cat], id_pagador=pagador, tp_papel_pagador=papel,
                   ds_conta=ds, dt_competencia=comp, vl_receber=vl, dt_vencimento=venc, fl_cancelada=False))
    return ncr
def receber(cr, d, vl, conta, forma="pix"):
    n = sum(1 for r in REC if r["id_conta_receber"] == cr) + 1
    REC.append(dict(id_conta_receber=cr, nr_recebimento=n, id_conta=conta, dt_recebimento=d, vl_recebido=vl, id_forma_pagamento=FORMA_ID[forma], nr_movimento=None, dt_conciliacao=None))
    return (cr, n)
def conta_pagar(contrato, cat, fav, custeio, custeador, ds, comp, vl, venc):
    global ncp; ncp += 1
    CP.append(dict(id_conta_pagar=ncp, id_contrato=contrato, id_categoria=CAT[cat], id_favorecido=fav, id_custeador=custeador, id_conta_receber_origem=None,
                   nr_recebimento_origem=None, tp_papel_custeio=custeio, ds_conta=ds, dt_competencia=comp, vl_pagar=vl, dt_vencimento=venc, fl_cancelada=False))
    return ncp
def pagar(cp_ref, d, vl, conta, quem, forma="pix"):
    PAG.append(dict(ref=cp_ref, dt_pagamento=d, vl_pago=vl, id_conta=conta, id_usuario=quem, id_forma_pagamento=FORMA_ID[forma]))
REPASSES = []   # (recebimento, data de pagamento ou None)
def mes(d, k):
    y, m = d.year + (d.month - 1 + k) // 12, (d.month - 1 + k) % 12 + 1
    return date(y, m, 1)
PROP_OF = {c: IMD[CT_IM[c]]["id_proprietario"] for c in CT_IM}
# intermediacao da locacao e corretagem da venda (pagas pelo proprietario)
for c in (1, 2, 3, 4, 5):
    v = CTD[c][4] * CTD[c][5] / 100
    cr = conta_receber(c, "intermediacao_locacao", PROP_OF[c], "proprietario", f"Intermediacao da locacao — contrato {c}", CTD[c][8], v, CTD[c][8] + timedelta(days=10))
    receber(cr, util_ou_seguinte(CTD[c][8] + timedelta(days=8)), v, 1, "ted")
cr6 = conta_receber(6, "corretagem_venda", 15, "proprietario", "Corretagem da venda — contrato 6", date(2026, 5, 1), 37200, date(2026, 6, 5))
receber(cr6, date(2026, 6, 5), 37200, 1, "ted")
cr7 = conta_receber(7, "corretagem_venda", 20, "proprietario", "Corretagem da venda financiada — contrato 7", date(2026, 9, 1), 37500, date(2026, 9, 25))
receber(cr7, date(2026, 9, 25), 37500, 1, "ted")     # depois da liberacao do credito em 15/09 (RN23)
cr8 = conta_receber(8, "corretagem_venda", 23, "proprietario", "Corretagem da venda — contrato 8", date(2026, 9, 1), 26000, date(2026, 10, 15))
# alugueis: gerados mes a mes; pagamentos em dia, atrasados, parciais e em aberto
ALUG = {}
def aluguel(c, comp):
    ct = CTD[c]; venc = date(comp.year, comp.month, ct[7])
    return conta_receber(c, "aluguel", CT_CLI[c], "inquilino", f"Aluguel {comp:%m/%Y} — contrato {c}", comp, ct[4], venc)
PLANO = {  # contrato: lista de (competencia, [(dia de pagamento, valor), ...])  — valor None = aluguel inteiro
 1: [(mes(date(2025, 10, 1), k), [(None, None)]) for k in range(12)],
 2: [(mes(date(2026, 3, 1), k), [(None, None)]) for k in range(7)] + [(date(2026, 10, 1), [(date(2026, 10, 5), 1200)])],
 3: [(date(2026, 4, 1), [(None, None)]), (date(2026, 5, 1), [(date(2026, 5, 18), None)]), (date(2026, 6, 1), [(None, None)]), (date(2026, 7, 1), [(None, None)]),
     (date(2026, 8, 1), [(date(2026, 8, 10), 1000), (date(2026, 8, 24), 800)]), (date(2026, 9, 1), []), (date(2026, 10, 1), [])],
 4: [(mes(date(2026, 3, 1), k), [(None, None)]) for k in range(1, 5)] + [(date(2026, 8, 1), [])],
 5: [(mes(date(2026, 7, 1), k), [(None, None)]) for k in range(3)] + [(date(2026, 10, 1), [(date(2026, 10, 16), None)])]}
for c, meses in PLANO.items():
    for comp, pags in meses:
        cr = aluguel(c, comp); ALUG[(c, comp)] = cr
        venc = date(comp.year, comp.month, CTD[c][7])
        for (d, v) in pags:
            dpag = d or (venc - timedelta(days=R.choice([0, 1, 2])) if R.random() < 0.8 else venc + timedelta(days=R.choice([1, 2, 3])))
            if dpag > HOJE: continue
            rid = receber(cr, dpag, v or CTD[c][4], 2, "pix" if R.random() < 0.85 else "boleto")
            REPASSES.append(rid)
# comissoes liberadas: geram a conta a pagar ao corretor (RN25) e sao pagas pelo administrador (PO01)
LIB = {(1, 4): date(2025, 9, 23), (2, 5): date(2026, 2, 23), (3, 6): date(2026, 3, 31), (4, 8): date(2026, 3, 10), (5, 7): date(2026, 6, 25),
       (6, 4): date(2026, 6, 6), (6, 5): date(2026, 6, 6), (7, 6): date(2026, 9, 16)}
PAGA_COM = {(1, 4): date(2025, 10, 15), (2, 5): date(2026, 3, 10), (3, 6): date(2026, 4, 15), (4, 8): date(2026, 3, 25), (5, 7): date(2026, 7, 10),
            (6, 4): date(2026, 6, 15), (6, 5): date(2026, 6, 15), (7, 6): date(2026, 10, 5)}
COMCP = {}
for (c, cor), d in LIB.items():
    pc = next(x[2] for x in COM if x[0] == c and x[1] == cor)
    v = money(CTD[c][4] * CTD[c][5] / 100 * pc / 100)
    cp = conta_pagar(c, "comissao", cor, "imobiliaria", None, f"Comissao de {U[cor]['nm_usuario']} — contrato {c}", d, v, d + timedelta(days=15))
    COMCP[(c, cor)] = cp
    pagar(cp, PAGA_COM[(c, cor)], v, 1, 1, "ted")
# despesas: fotografia (imobiliaria), manutencao (custeada pelo proprietario), vistoria (custeada pelo inquilino), imposto
DES = [(None, "despesa_operacional", 9, "imobiliaria", None, "Fotos profissionais de 12 imoveis", date(2026, 3, 1), 1800, date(2026, 3, 20), date(2026, 3, 19)),
       (2, "despesa_operacional", 10, "proprietario", 16, "Troca do aquecedor — casa do contrato 2", date(2026, 5, 1), 950, date(2026, 5, 12), date(2026, 5, 12)),
       (3, "despesa_operacional", 11, "inquilino", 26, "Vistoria de entrada — contrato 3", date(2026, 4, 1), 380, date(2026, 4, 10), date(2026, 4, 9)),
       (5, "despesa_operacional", 11, "inquilino", 28, "Vistoria de entrada — contrato 5", date(2026, 7, 1), 520, date(2026, 7, 3), date(2026, 7, 3)),
       (None, "despesa_operacional", 9, "imobiliaria", None, "Fotos profissionais de 6 imoveis", date(2026, 9, 1), 900, date(2026, 9, 25), None),
       (None, "imposto", None, "imobiliaria", None, "ISS sobre intermediacoes — junho", date(2026, 6, 1), 1650.40, date(2026, 7, 10), date(2026, 7, 10)),
       (None, "imposto", None, "imobiliaria", None, "ISS sobre intermediacoes — setembro", date(2026, 9, 1), 1980.25, date(2026, 10, 10), None)]
for (c, cat, fav, cus, cust_id, ds, comp, v, venc, dpag) in DES:
    cp = conta_pagar(c, cat, fav, cus, cust_id, ds, comp, v, venc)
    if dpag: pagar(cp, dpag, v, 1, 2, "boleto")

sec("6. CONTAS A PAGAR LANCADAS PELA EQUIPE: COMISSOES E DESPESAS")
ins("conta_pagar", CP, "comissoes (custo da imobiliaria), despesas custeadas pela imobiliaria, pelo proprietario ou pelo inquilino (RN28)")
stmt("SELECT setval(pg_get_serial_sequence('conta_pagar', 'id_conta_pagar'), (SELECT max(id_conta_pagar) FROM conta_pagar));   -- os repasses continuam a numeracao")
sec("7. CONTAS A RECEBER E RECEBIMENTOS (cada recebimento de aluguel gera o seu repasse — RN30)")
ins("conta_receber", CR, "intermediacao, corretagem e alugueis; o pagador exerce o papel indicado (RN27, RN32)")
stmt("SELECT setval(pg_get_serial_sequence('conta_receber', 'id_conta_receber'), (SELECT max(id_conta_receber) FROM conta_receber));   -- a multa rescisoria continua a numeracao")
ins("recebimento", REC, "baixas totais e parciais; o gatilho cria a conta a pagar do repasse de cada recebimento de aluguel")
sec("8. COMISSOES LIBERADAS E PAGAMENTOS")
for (c, cor), d in LIB.items():
    stmt(f"UPDATE comissao SET st_comissao = 'liberada', id_aprovador = 1, dt_aprovacao = {q(dt(d, 9))}, id_conta_pagar = {COMCP[(c, cor)]} "
         f"WHERE id_contrato = {c} AND id_corretor = {cor};")
# pagamentos das contas lancadas aqui
rows = []
for p in PAG:
    n = sum(1 for x in rows if x["id_conta_pagar"] == p["ref"]) + 1
    rows.append(dict(id_conta_pagar=p["ref"], nr_pagamento=n, id_conta=p["id_conta"], id_usuario=p["id_usuario"], dt_pagamento=p["dt_pagamento"], vl_pago=p["vl_pago"],
                     id_forma_pagamento=p["id_forma_pagamento"], nr_movimento=None, dt_conciliacao=None))
ins("pagamento", rows, "comissoes pagas pelo administrador (PO01); despesas pagas pelo financeiro (RN39)")
PAGROWS = rows
# repasses: pagos pelo financeiro ate o vencimento; o de outubro do contrato 2 ainda esta dentro do prazo e um de setembro ficou atrasado
REC_BY = {(r["id_conta_receber"], r["nr_recebimento"]): r for r in REC}
REP_PAG = []
for rid in REPASSES:
    r = REC_BY[rid]
    venc = dia_util_apos(r["dt_recebimento"], 5)
    c = next(k[0] for k, v in ALUG.items() if v == rid[0])
    if r["dt_recebimento"] >= date(2026, 10, 13): continue                     # ainda no prazo
    if c == 5 and r["dt_recebimento"].month == 9: continue                      # repasse atrasado (auditoria)
    dpag = venc - timedelta(days=R.choice([0, 1, 2]))
    while dpag.weekday() >= 5: dpag -= timedelta(days=1)
    vl = money(r["vl_recebido"] * (1 - CTD[c][6] / 100))
    REP_PAG.append((rid, dpag, vl))
stmt("-- pagamento de cada repasse (a conta a pagar foi criada pelo gatilho; ela e encontrada pelo recebimento de origem)")
for (cr, nr), dpag, vl in REP_PAG:
    who = 2 if dpag < date(2026, 6, 1) else 3
    stmt(f"INSERT INTO pagamento (id_conta_pagar, nr_pagamento, id_conta, id_usuario, dt_pagamento, vl_pago, id_forma_pagamento) "
         f"SELECT id_conta_pagar, 1, 2, {who}, {q(dpag)}, vl_pagar, {FORMA_ID['pix']} FROM conta_pagar WHERE id_conta_receber_origem = {cr} AND nr_recebimento_origem = {nr};")

# =====================================================================
# 8. TERMINO DOS CONTRATOS (RN37, RN43, RN44)
# =====================================================================
sec("9. TERMINO DOS CONTRATOS")
stmt("-- rescisao da locacao 4 a pedido da inquilina, com multa de dois alugueis; o aluguel de agosto (periodo futuro e sem baixa) e cancelado")
stmt("CALL rescindir_contrato(4, '2026-07-31', 'Inquilina transferida para outra cidade', 'cliente', 5000, '2026-08-14');")
stmt("UPDATE imovel SET st_imovel = 'disponivel' WHERE id_imovel = 104;")
stmt("-- a multa rescisoria foi paga em 12/08")
stmt("INSERT INTO recebimento (id_conta_receber, nr_recebimento, id_conta, dt_recebimento, vl_recebido, id_forma_pagamento) "
     f"SELECT id_conta_receber, 1, 1, '2026-08-12', vl_receber, {FORMA_ID['pix']} FROM conta_receber WHERE id_contrato = 4 AND id_categoria = {CAT['multa_rescisoria']};")
stmt("-- venda 8 cancelada: o banco reprovou o financiamento; corretagem sem baixa e comissao pendente sao canceladas e o imovel volta a disponivel")
stmt("CALL cancelar_contrato(8, '2026-09-12', 'Financiamento reprovado pelo Banco Litoral');")
stmt("-- venda 6 encerrada: todas as contas quitadas; o imovel fica vendido")
stmt("CALL encerrar_contrato(6, '2026-06-30');")
stmt("-- locacao 1 encerrada no fim do prazo; o papel de inquilino do Bruno recebe a data de fim")
stmt("CALL encerrar_contrato(1, '2026-10-01');")

# =====================================================================
# 9. EXTRATO BANCARIO E CONCILIACAO (RN45, RN46)
# =====================================================================
nm = {1: 0, 2: 0}
EXTR = []
def mov(conta, d, vl, tp, hist):
    nm[conta] += 1
    cd = f"{'MV' if conta == 1 else 'AL'}{d:%Y%m%d}{nm[conta]:04d}"
    EXTR.append(dict(id_conta=conta, nr_movimento=nm[conta], cd_transacao_banco=cd, dt_movimento=d, vl_movimento=vl, tp_movimento=tp, ds_historico=hist,
                     dt_importacao=dt(min(HOJE, d + timedelta(days=1)), 7, 30)))
    return nm[conta]
LIMITE = date(2026, 10, 15)   # extrato importado ate 15/10
LIGA_REC, LIGA_PAG = [], []
for r in REC:
    if r["dt_recebimento"] > LIMITE or r["id_conta"] == 3: continue
    if r["dt_recebimento"] < date(2026, 3, 1): continue   # extratos importados a partir de marco de 2026
    n = mov(r["id_conta"], r["dt_recebimento"], r["vl_recebido"], "credito", f"PIX/TED RECEBIDO {U[next(c['id_pagador'] for c in CR if c['id_conta_receber'] == r['id_conta_receber'])]['nm_usuario'].upper()}")
    if (r["id_conta_receber"], r["nr_recebimento"]) == (ALUG.get((3, date(2026, 8, 1))), 2): continue   # baixa ainda nao conferida
    LIGA_REC.append((r["id_conta_receber"], r["nr_recebimento"], r["id_conta"], n, r["dt_recebimento"] + timedelta(days=1)))
for p in PAGROWS:
    if p["dt_pagamento"] > LIMITE or p["dt_pagamento"] < date(2026, 3, 1): continue
    n = mov(p["id_conta"], p["dt_pagamento"], p["vl_pago"], "debito", "TED/PIX ENVIADO")
    LIGA_PAG.append(("id", p["id_conta_pagar"], p["nr_pagamento"], p["id_conta"], n, p["dt_pagamento"] + timedelta(days=1)))
for (cr, nr), dpag, vl in REP_PAG:
    if dpag > LIMITE or dpag < date(2026, 3, 1): continue
    n = mov(2, dpag, vl, "debito", "PIX ENVIADO REPASSE")
    LIGA_PAG.append(("origem", cr, nr, 2, n, dpag + timedelta(days=1)))
# movimentos sem baixa correspondente: tarifas e um credito nao identificado (ficam pendentes para o financeiro)
for m in range(3, 11):
    d = date(2026, m, 1) if m < 10 else date(2026, 10, 1)
    mov(1, util_ou_seguinte(d), 39.90, "debito", "TARIFA PACOTE DE SERVICOS")
MULTA_MOV = mov(1, date(2026, 8, 12), 5000.00, "credito", "PIX RECEBIDO ELISA MOURA")
mov(1, date(2026, 9, 18), 350.00, "credito", "TED RECEBIDA — REMETENTE NAO IDENTIFICADO")
mov(2, date(2026, 10, 6), 1800.00, "credito", "PIX RECEBIDO DIEGO ALVES")   # valor de aluguel ainda nao lancado (divergencia)
sec("10. EXTRATO BANCARIO E CONCILIACAO")
ins("movimento_bancario", EXTR, "extratos importados de marco a 15/10; o codigo da transacao nao se repete na conta (RN46)")
stmt("-- conciliacao: cada baixa e ligada ao movimento do extrato que a comprova, da mesma conta e na mesma direcao (RN45)")
for cr, nr, conta, n, dc in LIGA_REC:
    stmt(f"UPDATE recebimento SET nr_movimento = {n}, dt_conciliacao = {q(dc)} WHERE id_conta_receber = {cr} AND nr_recebimento = {nr};")
stmt(f"UPDATE recebimento SET nr_movimento = {MULTA_MOV}, dt_conciliacao = '2026-08-13' WHERE nr_recebimento = 1 AND id_conta_receber = "
     f"(SELECT id_conta_receber FROM conta_receber WHERE id_contrato = 4 AND id_categoria = {CAT['multa_rescisoria']});")
for kind, a, b, conta, n, dc in LIGA_PAG:
    if kind == "id":
        stmt(f"UPDATE pagamento SET nr_movimento = {n}, dt_conciliacao = {q(dc)} WHERE id_conta_pagar = {a} AND nr_pagamento = {b};")
    else:
        stmt(f"UPDATE pagamento SET nr_movimento = {n}, dt_conciliacao = {q(dc)} WHERE nr_pagamento = 1 AND id_conta_pagar = "
             f"(SELECT id_conta_pagar FROM conta_pagar WHERE id_conta_receber_origem = {a} AND nr_recebimento_origem = {b});")

# =====================================================================
# 10. MUDANCAS DE CADASTRO
# =====================================================================
sec("11. MUDANCAS DE CADASTRO")
stmt("-- o corretor Sergio saiu em 30/06: as conversas abertas dele passam para a Bianca, e o papel recebe a data de fim (RN02)")
stmt("UPDATE conversa SET id_corretor = 7 WHERE id_corretor = 8 AND st_conversa = 'aberta';")
stmt("UPDATE imovel SET id_corretor_responsavel = 7 WHERE id_corretor_responsavel = 8;")
stmt("UPDATE corretor SET dt_fim = '2026-06-30' WHERE id_usuario = 8;")
stmt("UPDATE usuario SET fl_ativo = FALSE WHERE id_usuario = 8;")
stmt("-- um cliente pediu a anonimizacao dos dados (LGPD, PO07): o registro fica, os dados pessoais saem")
stmt("UPDATE usuario SET nm_usuario = 'Titular anonimizado', ds_email = NULL, nr_cpf_cnpj = NULL, fl_ativo = FALSE, dt_anonimizacao = '2026-09-30 10:00:00' WHERE id_usuario = 47;")
stmt("DELETE FROM telefone WHERE id_usuario = 47;   -- o telefone tambem e dado pessoal e sai do cadastro")
stmt("-- precos atualizados pelo proprietario")
stmt("UPDATE imovel SET vl_venda = 410000 WHERE id_imovel = 110;")
stmt("UPDATE imovel SET vl_aluguel = 2750 WHERE id_imovel = 125;")
sec("12. SEQUENCIAS (os proximos cadastros continuam a numeracao)")
for t, c in [("usuario", "id_usuario"), ("cidade", "id_cidade"), ("bairro", "id_bairro"), ("imovel", "id_imovel"), ("caracteristica", "id_caracteristica"),
             ("conversa", "id_conversa"), ("tarefa", "id_tarefa"), ("tag", "id_tag"), ("visita", "id_visita"), ("proposta", "id_proposta"),
             ("contrato", "id_contrato"), ("conta_bancaria", "id_conta"), ("conta_receber", "id_conta_receber"), ("conta_pagar", "id_conta_pagar")]:
    stmt(f"SELECT setval(pg_get_serial_sequence('{t}', '{c}'), (SELECT max({c}) FROM {t}));")

head = """-- =====================================================================
-- CRMoveis · Massa de dados
-- Projeto Integrador · Modelagem de Dados · Prof. Clovis · Grupo 4
-- Cerca de oito meses de operacao de uma imobiliaria pequena (Sao Paulo, Guarulhos e Aruja).
-- Todos os nomes, documentos, telefones, e-mails e enderecos sao FICTICIOS.
-- Gerado pelo script massa.py (semente fixa: o resultado e sempre o mesmo) e validado pelas
-- restricoes e gatilhos do banco: um dado que viole uma regra e recusado na carga.
-- Execucao: psql -d crmoveis -v ON_ERROR_STOP=1 -f sql/dados/10_massa_de_dados.sql
-- =====================================================================
\\set ON_ERROR_STOP on
"""
# envolve tudo (menos o primeiro bloco, que ja tem BEGIN/COMMIT) numa transacao
body = "\n".join(SQL)
i = body.index("COMMIT;") + len("COMMIT;")
body = body[:i] + "\nBEGIN;" + body[i:] + "\nCOMMIT;\n"
open(OUT, "w", encoding="utf-8").write(head + body)
print("linhas:", len((head + body).splitlines()), "| usuarios", len(U), "| imoveis", len(IM), "| conversas", len(CONV), "| mensagens", len(MSG),
      "| visitas", len(VIS), "| propostas", len(PROP), "| contas a receber", len(CR), "| recebimentos", len(REC), "| movimentos", len(EXTR))

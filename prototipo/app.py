"""CRMoveis — prototipo do sistema sobre o banco da entrega final (PostgreSQL).

Baseado no app SP Imoveis CRM (Flask + SQLite), que deu origem ao projeto: o layout (barra lateral,
area de trabalho e painel de detalhes a direita), o funil em colunas e a API de integracao com o N8N
vem dele. Aqui tudo grava no banco do modelo logico, e as regras de negocio sao as do proprio banco:
quando uma gravacao viola uma regra (chave, CHECK ou gatilho), o prototipo mostra a mensagem do banco.

Execucao:  python app.py   (veja README.md)
"""
import os, re, sys, json, decimal, datetime, hashlib
from pathlib import Path
from contextlib import contextmanager

import psycopg
from psycopg.rows import dict_row
from flask import Flask, jsonify, request, render_template, send_from_directory, abort
from flask.json.provider import DefaultJSONProvider

BASE = Path(__file__).resolve().parent
REPO = BASE.parent

# Iniciado pelo Windows sem janela (pythonw, ver INSTALAR_INICIAR_COM_WINDOWS): nao ha console,
# entao as mensagens do servidor vao para prototipo.log.
if sys.stdout is None or sys.stderr is None:
    sys.stdout = sys.stderr = open(BASE / "prototipo.log", "a", encoding="utf-8", buffering=1)

# --------------------------------------------------------------------------------------------
# configuracao (.env opcional, no mesmo formato do app original)
# --------------------------------------------------------------------------------------------
def carregar_env():
    arq = BASE / ".env"
    if arq.exists():
        for linha in arq.read_text(encoding="utf-8").splitlines():
            linha = linha.strip()
            if linha and not linha.startswith("#") and "=" in linha:
                k, v = linha.split("=", 1)
                os.environ.setdefault(k.strip(), v.strip())
carregar_env()
DATABASE_URL = os.environ.get("DATABASE_URL", "postgresql://postgres:postgres@localhost:5432/crmoveis")
PORTA = int(os.environ.get("CRM_PORTA", "5003"))
TOKEN_INTEGRACAO = os.environ.get("CRM_INTEGRATION_TOKEN", "")
META = json.loads((BASE / "dados_modelo.json").read_text(encoding="utf-8"))
CONSULTAS = json.loads((BASE / "consultas.json").read_text(encoding="utf-8"))   # as mesmas de sql/consultas e sql/auditoria


class JSONBR(DefaultJSONProvider):
    ensure_ascii = False
    sort_keys = False

    @staticmethod
    def default(o):
        if isinstance(o, decimal.Decimal):
            return float(o)
        if isinstance(o, datetime.datetime):
            return o.isoformat(sep=" ", timespec="minutes")
        if isinstance(o, datetime.date):
            return o.isoformat()
        return DefaultJSONProvider.default(o)


app = Flask(__name__)
app.json = JSONBR(app)


# --------------------------------------------------------------------------------------------
# banco: cada requisicao e uma transacao; o usuario que esta agindo vai para crmoveis.id_usuario
# (e o que a auditoria grava e o que os gatilhos de pagamento conferem, RN39/RN40/PO01)
# --------------------------------------------------------------------------------------------
class ErroApp(Exception):
    pass


def usuario_atual():
    v = request.headers.get("X-Usuario") or request.args.get("como") or "1"
    try:
        return int(v)
    except ValueError:
        raise ErroApp("Usuario invalido")


@contextmanager
def transacao(somente_leitura=False, usuario=None):
    conn = psycopg.connect(DATABASE_URL, row_factory=dict_row)
    try:
        if somente_leitura:
            conn.execute("SET TRANSACTION READ ONLY")
        conn.execute("SELECT set_config('crmoveis.id_usuario', %s, true)", (str(usuario or usuario_atual()),))
        yield conn
        conn.commit()
    except Exception:
        conn.rollback()
        raise
    finally:
        conn.close()


def q(conn, sql, params=None):
    return conn.execute(sql, params).fetchall()


def q1(conn, sql, params=None):
    return conn.execute(sql, params).fetchone()


def ler(sql, params=None):
    with transacao(somente_leitura=True) as c:
        return q(c, sql, params)


def corpo():
    return request.get_json(silent=True) or {}


def obrig(d, *campos):
    faltando = [c for c in campos if d.get(c) in (None, "")]
    if faltando:
        raise ErroApp("Preencha: " + ", ".join(faltando))
    return [d.get(c) for c in campos]


def nulo(v):
    return None if v in ("", None) else v


@app.errorhandler(psycopg.Error)
def erro_banco(e):
    diag = getattr(e, "diag", None)
    msg = (diag.message_primary if diag and diag.message_primary else str(e)).strip()
    restricao = diag.constraint_name if diag else None
    m = re.match(r"((?:RNF?|PO)\d+(?:/RN\d+)?)", msg)
    return jsonify(erro=msg, regra=m.group(1) if m else None, restricao=restricao,
                   explicacao=META["restricoes"].get(restricao), detalhe=diag.message_detail if diag else None,
                   origem="banco"), 409


@app.errorhandler(ErroApp)
def erro_app(e):
    return jsonify(erro=str(e), origem="prototipo"), 400


# --------------------------------------------------------------------------------------------
# paginas, saude e dados de apoio
# --------------------------------------------------------------------------------------------
@app.get("/")
def index():
    return render_template("index.html")


@app.get("/docs/<path:caminho>")
def docs(caminho):
    pasta = (REPO / "docs").resolve()
    alvo = (pasta / caminho).resolve()
    if pasta not in alvo.parents or not alvo.exists():
        abort(404)
    return send_from_directory(pasta, caminho)


@app.get("/api/health")
def health():
    try:
        with transacao(somente_leitura=True, usuario=1) as c:
            r = q1(c, "SELECT current_database() AS banco, version() AS versao, (SELECT count(*) FROM pg_tables WHERE schemaname = 'public') AS tabelas")
        return jsonify(ok=True, **r)
    except psycopg.Error as e:
        return jsonify(ok=False, erro=str(e).strip(), dica="Confira DATABASE_URL no arquivo .env e se os scripts de sql/ foram executados."), 503


PAPEIS = ["cliente", "proprietario", "inquilino", "corretor", "financeiro", "fornecedor", "administrador", "instituicao_financeira"]
SQL_PAPEIS = " UNION ALL ".join(f"SELECT id_usuario, '{p}' AS papel, dt_inicio, dt_fim FROM {p}" for p in PAPEIS)


@app.get("/api/meta")
def meta():
    with transacao(somente_leitura=True) as c:
        internos = q(c, f"""SELECT u.id_usuario, u.nm_usuario, string_agg(p.papel, ', ' ORDER BY p.papel) AS papeis,
                                   bool_and(p.dt_fim IS NOT NULL) AS encerrado
                              FROM usuario u JOIN ({SQL_PAPEIS}) p ON p.id_usuario = u.id_usuario
                             WHERE p.papel IN ('administrador', 'financeiro', 'corretor')
                             GROUP BY u.id_usuario ORDER BY min(CASE p.papel WHEN 'administrador' THEN 1 WHEN 'financeiro' THEN 2 ELSE 3 END), u.nm_usuario""")
        return jsonify(
            internos=internos,
            estagios=q(c, "SELECT id_estagio, nm_estagio, nr_ordem, ds_cor FROM funil_estagio ORDER BY nr_ordem"),
            tags=q(c, "SELECT id_tag, nm_tag FROM tag ORDER BY nm_tag"),
            corretores=q(c, "SELECT u.id_usuario, u.nm_usuario, co.nr_creci, co.dt_fim FROM corretor co JOIN usuario u USING (id_usuario) ORDER BY co.dt_fim NULLS FIRST, u.nm_usuario"),
            clientes=q(c, "SELECT u.id_usuario, u.nm_usuario FROM cliente cl JOIN usuario u USING (id_usuario) WHERE cl.dt_fim IS NULL ORDER BY u.nm_usuario"),
            proprietarios=q(c, "SELECT u.id_usuario, u.nm_usuario FROM proprietario p JOIN usuario u USING (id_usuario) WHERE p.dt_fim IS NULL ORDER BY u.nm_usuario"),
            instituicoes=q(c, "SELECT u.id_usuario, u.nm_usuario FROM instituicao_financeira i JOIN usuario u USING (id_usuario) ORDER BY u.nm_usuario"),
            inquilinos=q(c, "SELECT u.id_usuario, u.nm_usuario FROM inquilino i JOIN usuario u USING (id_usuario) WHERE i.dt_fim IS NULL ORDER BY u.nm_usuario"),
            fornecedores=q(c, "SELECT u.id_usuario, u.nm_usuario FROM fornecedor f JOIN usuario u USING (id_usuario) WHERE f.dt_fim IS NULL ORDER BY u.nm_usuario"),
            contas=q(c, "SELECT id_conta, nm_apelido, nm_instituicao FROM conta_bancaria WHERE fl_ativa ORDER BY id_conta"),
            categorias=q(c, "SELECT id_categoria, cd_categoria, nm_categoria, tp_categoria FROM categoria_financeira ORDER BY tp_categoria, nm_categoria"),
            tipos_imovel=q(c, "SELECT id_tipo_imovel, nm_tipo_imovel FROM tipo_imovel ORDER BY nm_tipo_imovel"),
            origens=q(c, "SELECT id_origem, nm_origem FROM origem_contato ORDER BY nm_origem"),
            formas=q(c, "SELECT id_forma_pagamento, nm_forma_pagamento FROM forma_pagamento ORDER BY id_forma_pagamento"),
            ceps=q(c, "SELECT cep.nr_cep, cep.tp_cep, ci.id_cidade, ci.nm_cidade, ci.sg_uf FROM cep JOIN cidade ci USING (id_cidade) ORDER BY cep.nr_cep"),
            cidades=q(c, "SELECT ci.id_cidade, ci.nm_cidade, ci.sg_uf, uf.nm_uf FROM cidade ci JOIN uf USING (sg_uf) ORDER BY ci.nm_cidade"),
            bairros=q(c, "SELECT b.id_bairro, b.id_cidade, b.nm_bairro, ci.nm_cidade FROM bairro b JOIN cidade ci USING (id_cidade) ORDER BY ci.nm_cidade, b.nm_bairro"),
            ufs=q(c, "SELECT sg_uf, nm_uf FROM uf ORDER BY nm_uf"),
            tipos_documento=q(c, "SELECT id_tipo_documento, nm_tipo_documento FROM tipo_documento ORDER BY nm_tipo_documento"),
            caracteristicas=q(c, "SELECT id_caracteristica, nm_caracteristica FROM caracteristica ORDER BY nm_caracteristica"),
            imoveis=q(c, """SELECT i.id_imovel, i.cd_imobizi, i.id_tipo_imovel, t.nm_tipo_imovel, b.nm_bairro, i.tp_finalidade, i.st_imovel, i.vl_venda, i.vl_aluguel
                              FROM imovel i JOIN tipo_imovel t USING (id_tipo_imovel) JOIN bairro b ON b.id_bairro = i.id_bairro ORDER BY i.cd_imobizi"""),
            papeis=PAPEIS,
        )


# --------------------------------------------------------------------------------------------
# painel
# --------------------------------------------------------------------------------------------
@app.get("/api/painel")
def painel():
    with transacao(somente_leitura=True) as c:
        k = q1(c, """SELECT
            (SELECT count(*) FROM conversa WHERE st_conversa = 'aberta') AS conversas_abertas,
            (SELECT count(*) FROM conversa WHERE dt_inicio >= CURRENT_DATE - 30) AS conversas_30d,
            (SELECT count(*) FROM contrato WHERE st_contrato = 'vigente') AS contratos_vigentes,
            (SELECT count(*) FROM contrato WHERE st_contrato = 'rascunho') AS contratos_rascunho,
            (SELECT coalesce(sum(vl_recebido), 0) FROM recebimento WHERE date_trunc('month', dt_recebimento) = date_trunc('month', CURRENT_DATE)) AS recebido_mes,
            (SELECT coalesce(sum(vl_receber - vl_baixado), 0) FROM vw_conta_receber WHERE st_conta = 'atrasada') AS em_atraso,
            (SELECT count(*) FROM vw_conta_receber WHERE st_conta = 'atrasada') AS contas_atrasadas,
            (SELECT count(*) FROM vw_conta_pagar JOIN categoria_financeira USING (id_categoria) WHERE cd_categoria = 'repasse' AND st_conta IN ('prevista', 'parcial', 'atrasada')) AS repasses_abertos,
            (SELECT count(*) FROM vw_conta_pagar JOIN categoria_financeira USING (id_categoria) WHERE cd_categoria = 'repasse' AND st_conta = 'atrasada') AS repasses_atrasados,
            (SELECT count(*) FROM vw_movimento_bancario WHERE st_conciliacao <> 'conciliado') AS movimentos_pendentes,
            (SELECT count(*) FROM imovel WHERE st_imovel = 'disponivel') AS imoveis_disponiveis""")
        funil = q(c, """SELECT fe.id_estagio, fe.nm_estagio, fe.ds_cor, count(cv.id_conversa) AS qt
                          FROM funil_estagio fe LEFT JOIN conversa cv ON cv.id_estagio = fe.id_estagio
                         GROUP BY fe.id_estagio ORDER BY fe.nr_ordem""")
        receita = q(c, """SELECT to_char(m, 'MM/YYYY') AS mes, coalesce(sum(r.vl_recebido), 0) AS valor
                            FROM generate_series(date_trunc('month', CURRENT_DATE) - interval '5 months', date_trunc('month', CURRENT_DATE), interval '1 month') m
                            LEFT JOIN recebimento r ON date_trunc('month', r.dt_recebimento) = m
                           GROUP BY m ORDER BY m""")
        agenda = q(c, """SELECT 'visita' AS tipo, v.dt_visita AS quando, u.nm_usuario AS pessoa, i.cd_imobizi AS detalhe, co.nm_usuario AS responsavel
                           FROM visita v JOIN usuario u ON u.id_usuario = v.id_cliente JOIN imovel i USING (id_imovel) JOIN usuario co ON co.id_usuario = v.id_corretor
                          WHERE v.st_visita = 'agendada'
                         UNION ALL
                         SELECT 'tarefa', t.dt_vencimento::timestamp, coalesce(cl.nm_usuario, '—'), t.ds_titulo, co.nm_usuario
                           FROM tarefa t JOIN usuario co ON co.id_usuario = t.id_corretor
                           LEFT JOIN conversa cv ON cv.id_conversa = t.id_conversa LEFT JOIN usuario cl ON cl.id_usuario = cv.id_cliente
                          WHERE t.st_tarefa = 'pendente'
                          ORDER BY 2 LIMIT 12""")
        alertas = []
        for a in CONSULTAS["auditoria"]:
            n = q1(c, f"SELECT count(*) AS n FROM ({a['sql'].rstrip().rstrip(';')}) x")["n"]
            alertas.append(dict(id=a["id"], titulo=a["titulo"], qt=n))
    return jsonify(kpis=k, funil=funil, receita=receita, agenda=agenda, alertas=alertas)


# --------------------------------------------------------------------------------------------
# CRM: funil (kanban) e conversa
# --------------------------------------------------------------------------------------------
@app.get("/api/crm/board")
def crm_board():
    busca = f"%{request.args.get('busca', '').strip()}%"
    situacao = request.args.get("situacao", "aberta")
    corretor = nulo(request.args.get("corretor"))
    tag = nulo(request.args.get("tag"))
    with transacao(somente_leitura=True) as c:
        cards = q(c, """
            SELECT cv.id_conversa, cv.id_estagio, cv.st_conversa, cv.dt_inicio, vc.dt_atualizacao,
                   CURRENT_DATE - vc.dt_atualizacao::date AS dias_sem_contato,
                   cl.id_usuario AS id_cliente, cl.nm_usuario AS cliente, oc.nm_origem,
                   co.id_usuario AS id_corretor, co.nm_usuario AS corretor,
                   (SELECT t.nr_telefone FROM telefone t WHERE t.id_usuario = cl.id_usuario ORDER BY t.fl_principal DESC, t.nr_sequencia LIMIT 1) AS telefone,
                   (SELECT m.ds_corpo FROM mensagem m WHERE m.id_conversa = cv.id_conversa ORDER BY m.dt_mensagem DESC, m.nr_mensagem DESC LIMIT 1) AS ultima_mensagem,
                   (SELECT string_agg(i.cd_imobizi, ', ' ORDER BY i.cd_imobizi) FROM conversa_imovel ci JOIN imovel i USING (id_imovel) WHERE ci.id_conversa = cv.id_conversa) AS imoveis,
                   (SELECT coalesce(json_agg(t.nm_tag ORDER BY t.nm_tag), '[]') FROM conversa_tag ct JOIN tag t USING (id_tag) WHERE ct.id_conversa = cv.id_conversa) AS tags
              FROM vw_conversa vc
              JOIN conversa cv ON cv.id_conversa = vc.id_conversa
              JOIN usuario cl ON cl.id_usuario = cv.id_cliente
              LEFT JOIN origem_contato oc ON oc.id_origem = cl.id_origem
              LEFT JOIN usuario co ON co.id_usuario = cv.id_corretor
             WHERE (%(sit)s = 'todas' OR cv.st_conversa = %(sit)s)
               AND (%(cor)s::int IS NULL OR cv.id_corretor = %(cor)s::int)
               AND (%(tag)s::int IS NULL OR EXISTS (SELECT 1 FROM conversa_tag ct WHERE ct.id_conversa = cv.id_conversa AND ct.id_tag = %(tag)s::int))
               AND (cl.nm_usuario ILIKE %(b)s OR coalesce(cv.ds_notas, '') ILIKE %(b)s
                    OR EXISTS (SELECT 1 FROM telefone t WHERE t.id_usuario = cl.id_usuario AND t.nr_telefone ILIKE %(b)s))
             ORDER BY vc.dt_atualizacao DESC""", dict(sit=situacao, cor=corretor, tag=tag, b=busca))
        estagios = q(c, "SELECT id_estagio, nm_estagio, nr_ordem, ds_cor FROM funil_estagio ORDER BY nr_ordem")
    return jsonify(estagios=estagios, cards=cards)


def criar_pessoa(c, d, papel="cliente"):
    """Cria usuario + papel + telefone na mesma transacao (RN01: todo usuario tem pelo menos um papel)."""
    nome = (d.get("nome") or "").strip()
    if not nome:
        raise ErroApp("Informe o nome da pessoa")
    origem = nulo(d.get("id_origem")) or q1(c, "SELECT id_origem FROM origem_contato WHERE nm_origem = 'WhatsApp'")["id_origem"]
    u = q1(c, "INSERT INTO usuario (nm_usuario, nr_cpf_cnpj, ds_email, id_origem) VALUES (%s, %s, %s, %s) RETURNING id_usuario",
           (nome, nulo(d.get("cpf")), nulo(d.get("email")), origem))["id_usuario"]
    if papel == "corretor":
        c.execute("INSERT INTO corretor (id_usuario, nr_creci) VALUES (%s, %s)", (u, obrig(d, "creci")[0]))
    else:
        c.execute(f"INSERT INTO {papel} (id_usuario) VALUES (%s)", (u,))
    incluir_telefone(c, u, d.get("telefone"))
    return u


def incluir_telefone(c, uid, numero):
    """TELEFONE e entidade fraca de USUARIO: chave (id_usuario, nr_sequencia). O numero nao e chave e pode
    estar em mais de uma pessoa; quem cadastra primeiro e a titular, e as outras so usam o numero (RN03)."""
    tel = re.sub(r"\D", "", numero or "")
    if not tel:
        return None
    seq = q1(c, "SELECT coalesce(max(nr_sequencia), 0) + 1 AS n, bool_or(fl_principal) AS tem_principal FROM telefone WHERE id_usuario = %s", (uid,))
    compartilhado = bool(q1(c, "SELECT 1 AS x FROM telefone WHERE nr_telefone = %s LIMIT 1", (tel,)))
    c.execute("INSERT INTO telefone (id_usuario, nr_sequencia, nr_telefone, fl_principal, fl_titular) VALUES (%s, %s, %s, %s, %s)",
              (uid, seq["n"], tel, not seq["tem_principal"], not compartilhado))
    return compartilhado


@app.post("/api/crm/conversas")
def crm_nova_conversa():
    d = corpo()
    with transacao() as c:
        cliente = nulo(d.get("id_cliente")) or criar_pessoa(c, d.get("novo") or {}, "cliente")
        estagio = nulo(d.get("id_estagio")) or q1(c, "SELECT id_estagio FROM funil_estagio ORDER BY nr_ordem LIMIT 1")["id_estagio"]
        cv = q1(c, "INSERT INTO conversa (id_cliente, id_corretor, id_estagio, ds_notas) VALUES (%s, %s, %s, %s) RETURNING id_conversa",
                (cliente, nulo(d.get("id_corretor")), estagio, nulo(d.get("ds_notas"))))["id_conversa"]
        c.execute("INSERT INTO historico_estagio (id_conversa, id_estagio, id_usuario) VALUES (%s, %s, %s)", (cv, estagio, usuario_atual()))
        if nulo(d.get("mensagem")):
            c.execute("""INSERT INTO mensagem (id_conversa, nr_mensagem, tp_direcao, tp_canal, ds_corpo) VALUES (%s, 1, 'entrada', 'whatsapp', %s)""", (cv, d["mensagem"]))
    return jsonify(id_conversa=cv), 201


@app.get("/api/crm/conversas/<int:cid>")
def crm_conversa(cid):
    with transacao(somente_leitura=True) as c:
        cv = q1(c, """SELECT cv.*, vc.dt_atualizacao, fe.nm_estagio, fe.ds_cor, cl.nm_usuario AS cliente, oc.nm_origem, cl.ds_email, cl.dt_anonimizacao,
                             co.nm_usuario AS corretor
                        FROM conversa cv JOIN vw_conversa vc USING (id_conversa) JOIN funil_estagio fe ON fe.id_estagio = cv.id_estagio
                        JOIN usuario cl ON cl.id_usuario = cv.id_cliente LEFT JOIN origem_contato oc ON oc.id_origem = cl.id_origem
                        LEFT JOIN usuario co ON co.id_usuario = cv.id_corretor
                       WHERE cv.id_conversa = %s""", (cid,))
        if not cv:
            abort(404)
        u = cv["id_cliente"]
        return jsonify(
            conversa=cv,
            papeis=q(c, f"SELECT papel, dt_inicio, dt_fim FROM ({SQL_PAPEIS}) p WHERE id_usuario = %s ORDER BY papel", (u,)),
            telefones=telefones_de(c, u),
            tags=q(c, "SELECT t.id_tag, t.nm_tag FROM conversa_tag ct JOIN tag t USING (id_tag) WHERE ct.id_conversa = %s ORDER BY t.nm_tag", (cid,)),
            imoveis=q(c, """SELECT i.id_imovel, i.cd_imobizi, t.nm_tipo_imovel, b.nm_bairro, i.tp_finalidade, i.vl_venda, i.vl_aluguel, i.st_imovel, ci.dt_interesse
                              FROM conversa_imovel ci JOIN imovel i USING (id_imovel) JOIN tipo_imovel t ON t.id_tipo_imovel = i.id_tipo_imovel
                              JOIN bairro b ON b.id_bairro = i.id_bairro
                             WHERE ci.id_conversa = %s ORDER BY ci.dt_interesse""", (cid,)),
            mensagens=q(c, "SELECT * FROM mensagem WHERE id_conversa = %s ORDER BY dt_mensagem, nr_mensagem", (cid,)),
            historico=q(c, """SELECT h.dt_alteracao, fe.nm_estagio, fe.ds_cor, u.nm_usuario AS quem FROM historico_estagio h JOIN funil_estagio fe USING (id_estagio)
                               LEFT JOIN usuario u ON u.id_usuario = h.id_usuario WHERE h.id_conversa = %s ORDER BY h.dt_alteracao""", (cid,)),
            tarefas=q(c, """SELECT t.*, u.nm_usuario AS corretor, t.st_tarefa = 'pendente' AND t.dt_vencimento < CURRENT_DATE AS vencida
                              FROM tarefa t JOIN usuario u ON u.id_usuario = t.id_corretor WHERE t.id_conversa = %s ORDER BY t.dt_vencimento""", (cid,)),
            execucoes=execucoes(c, cid),
            visitas=q(c, """SELECT v.id_visita, v.dt_visita, v.st_visita, v.ds_feedback, i.cd_imobizi, b.nm_bairro FROM visita v JOIN imovel i USING (id_imovel)
                              JOIN bairro b ON b.id_bairro = i.id_bairro WHERE v.id_cliente = %s ORDER BY v.dt_visita""", (u,)),
            propostas=q(c, """SELECT p.id_proposta, p.dt_proposta, p.vl_proposto, p.vl_anunciado, p.st_proposta, i.cd_imobizi, ct.id_contrato, ct.st_contrato
                                FROM proposta p JOIN imovel i USING (id_imovel) LEFT JOIN contrato ct ON ct.id_proposta = p.id_proposta
                               WHERE p.id_cliente = %s ORDER BY p.dt_proposta""", (u,)),
            perfis=q(c, SQL_PERFIL + " WHERE p.id_usuario = %s ORDER BY p.nr_perfil", (u,)),
            outras_conversas=q(c, """SELECT cv.id_conversa, cv.dt_inicio, cv.st_conversa, fe.nm_estagio FROM conversa cv JOIN funil_estagio fe USING (id_estagio)
                                      WHERE cv.id_cliente = %s AND cv.id_conversa <> %s ORDER BY cv.dt_inicio""", (u, cid)),
        )


# perfil de interesse com os tipos aceitos (N:N DESEJA); perfil sem tipo aceita qualquer tipo (RN47)
SQL_PERFIL = """
    SELECT p.*, u.nm_usuario, ci.nm_cidade,
           coalesce((SELECT array_agg(pt.id_tipo_imovel ORDER BY pt.id_tipo_imovel) FROM perfil_interesse_tipo pt
                      WHERE pt.id_usuario = p.id_usuario AND pt.nr_perfil = p.nr_perfil), '{}') AS tipos,
           (SELECT string_agg(t.nm_tipo_imovel, ', ' ORDER BY t.nm_tipo_imovel) FROM perfil_interesse_tipo pt JOIN tipo_imovel t USING (id_tipo_imovel)
             WHERE pt.id_usuario = p.id_usuario AND pt.nr_perfil = p.nr_perfil) AS nm_tipos,
           coalesce((SELECT array_agg(pb.id_bairro ORDER BY pb.id_bairro) FROM perfil_interesse_bairro pb
                      WHERE pb.id_usuario = p.id_usuario AND pb.nr_perfil = p.nr_perfil), '{}') AS bairros,
           (SELECT string_agg(b.nm_bairro, ', ' ORDER BY b.nm_bairro) FROM perfil_interesse_bairro pb JOIN bairro b USING (id_bairro)
             WHERE pb.id_usuario = p.id_usuario AND pb.nr_perfil = p.nr_perfil) AS nm_bairros
      FROM perfil_interesse p JOIN usuario u USING (id_usuario) LEFT JOIN cidade ci USING (id_cidade)"""


def telefones_de(c, u):
    """Celular ou fixo nao e guardado: se deduz do numero (celular tem 9 digitos depois do DDD)."""
    return q(c, """SELECT t.nr_sequencia, t.nr_telefone, t.fl_principal, t.fl_titular,
                          CASE WHEN length(t.nr_telefone) = 11 AND substr(t.nr_telefone, 3, 1) = '9' THEN 'celular' ELSE 'fixo' END AS tipo,
                          (SELECT string_agg(o.nm_usuario || CASE WHEN x.fl_titular THEN ' (titular)' ELSE '' END, ', ')
                             FROM telefone x JOIN usuario o ON o.id_usuario = x.id_usuario
                            WHERE x.nr_telefone = t.nr_telefone AND x.id_usuario <> t.id_usuario) AS compartilhado_com
                     FROM telefone t WHERE t.id_usuario = %s ORDER BY t.fl_principal DESC, t.nr_sequencia""", (u,))


def execucoes(c, cid=None):
    ex = q(c, """SELECT e.*, cl.nm_usuario AS cliente FROM automacao_execucao e JOIN conversa cv USING (id_conversa)
                 JOIN usuario cl ON cl.id_usuario = cv.id_cliente WHERE (%s::int IS NULL OR e.id_conversa = %s::int)
                 ORDER BY e.dt_execucao DESC""", (cid, cid))
    logs = q(c, "SELECT * FROM automacao_log WHERE (%s::int IS NULL OR id_conversa = %s::int) ORDER BY dt_log", (cid, cid))
    for e in ex:
        e["logs"] = [l for l in logs if l["id_conversa"] == e["id_conversa"] and l["nr_execucao"] == e["nr_execucao"]]
    return ex


@app.patch("/api/crm/conversas/<int:cid>")
def crm_atualizar_conversa(cid):
    d = corpo()
    campos = {k: nulo(d[k]) for k in ("id_corretor", "ds_notas", "st_conversa") if k in d}
    if not campos:
        raise ErroApp("Nada para alterar")
    with transacao() as c:
        sets = ", ".join(f"{k} = %({k})s" for k in campos)
        c.execute(f"UPDATE conversa SET {sets} WHERE id_conversa = %(id)s", dict(campos, id=cid))
    return jsonify(ok=True)


@app.post("/api/crm/conversas/<int:cid>/estagio")
def crm_mover(cid):
    """RN14: o estagio atual e o historico sao gravados juntos, na mesma transacao."""
    est = obrig(corpo(), "id_estagio")[0]
    with transacao() as c:
        atual = q1(c, "SELECT id_estagio FROM conversa WHERE id_conversa = %s FOR UPDATE", (cid,))
        if not atual:
            abort(404)
        if int(atual["id_estagio"]) == int(est):
            return jsonify(ok=True, mudou=False)
        final = q1(c, "SELECT nm_estagio FROM funil_estagio WHERE id_estagio = %s", (est,))["nm_estagio"]
        st = "encerrada" if final in ("Ganho", "Perdido") else "aberta"
        c.execute("UPDATE conversa SET id_estagio = %s, st_conversa = %s WHERE id_conversa = %s", (est, st, cid))
        c.execute("INSERT INTO historico_estagio (id_conversa, id_estagio, id_usuario) VALUES (%s, %s, %s)", (cid, est, usuario_atual()))
    return jsonify(ok=True, mudou=True)


@app.post("/api/crm/conversas/<int:cid>/mensagens")
def crm_mensagem(cid):
    d = corpo()
    tipo, texto = obrig(d, "tipo", "texto")
    with transacao() as c:
        n = q1(c, "SELECT coalesce(max(nr_mensagem), 0) + 1 AS n FROM mensagem WHERE id_conversa = %s", (cid,))["n"]
        if tipo == "nota":
            c.execute("INSERT INTO mensagem (id_conversa, nr_mensagem, tp_canal, ds_corpo) VALUES (%s, %s, 'nota_interna', %s)", (cid, n, texto))
        else:
            cd = "wamid.PROTO" + hashlib.md5(f"{cid}-{n}-{datetime.datetime.now()}".encode()).hexdigest()[:14].upper()
            c.execute("INSERT INTO mensagem (id_conversa, nr_mensagem, cd_externo, tp_direcao, tp_canal, ds_corpo) VALUES (%s, %s, %s, %s, 'whatsapp', %s)",
                      (cid, n, cd, tipo, texto))
    return jsonify(ok=True, nr_mensagem=n), 201


@app.post("/api/crm/conversas/<int:cid>/tags")
def crm_tag(cid):
    d = corpo()
    with transacao() as c:
        tag = nulo(d.get("id_tag"))
        if not tag and nulo(d.get("nm_tag")):
            r = q1(c, "SELECT id_tag FROM tag WHERE lower(nm_tag) = lower(%s)", (d["nm_tag"].strip(),))
            tag = r["id_tag"] if r else q1(c, "INSERT INTO tag (nm_tag) VALUES (%s) RETURNING id_tag", (d["nm_tag"].strip(),))["id_tag"]
        if not tag:
            raise ErroApp("Escolha ou digite uma etiqueta")
        c.execute("INSERT INTO conversa_tag (id_conversa, id_tag) VALUES (%s, %s)", (cid, tag))
    return jsonify(ok=True), 201


@app.delete("/api/crm/conversas/<int:cid>/tags/<int:tid>")
def crm_tag_remover(cid, tid):
    with transacao() as c:
        c.execute("DELETE FROM conversa_tag WHERE id_conversa = %s AND id_tag = %s", (cid, tid))
    return jsonify(ok=True)


@app.post("/api/crm/conversas/<int:cid>/imoveis")
def crm_imovel(cid):
    im = obrig(corpo(), "id_imovel")[0]
    with transacao() as c:
        c.execute("INSERT INTO conversa_imovel (id_imovel, id_conversa) VALUES (%s, %s)", (im, cid))
    return jsonify(ok=True), 201


@app.delete("/api/crm/conversas/<int:cid>/imoveis/<int:iid>")
def crm_imovel_remover(cid, iid):
    with transacao() as c:
        c.execute("DELETE FROM conversa_imovel WHERE id_conversa = %s AND id_imovel = %s", (cid, iid))
    return jsonify(ok=True)


@app.post("/api/crm/conversas/<int:cid>/tarefas")
def crm_tarefa(cid):
    d = corpo()
    titulo, venc = obrig(d, "ds_titulo", "dt_vencimento")
    with transacao() as c:
        cor = nulo(d.get("id_corretor")) or q1(c, "SELECT id_corretor FROM conversa WHERE id_conversa = %s", (cid,))["id_corretor"]
        if not cor:
            raise ErroApp("A conversa nao tem corretor: escolha um corretor antes de criar a tarefa")
        c.execute("INSERT INTO tarefa (id_conversa, id_corretor, ds_titulo, ds_tarefa, dt_vencimento) VALUES (%s, %s, %s, %s, %s)",
                  (cid, cor, titulo, nulo(d.get("ds_tarefa")), venc))
    return jsonify(ok=True), 201


@app.patch("/api/tarefas/<int:tid>")
def tarefa_atualizar(tid):
    st = obrig(corpo(), "st_tarefa")[0]
    with transacao() as c:
        c.execute("UPDATE tarefa SET st_tarefa = %s WHERE id_tarefa = %s", (st, tid))
    return jsonify(ok=True)


# --------------------------------------------------------------------------------------------
# pessoas e papeis (especializacao de USUARIO)
# --------------------------------------------------------------------------------------------
@app.get("/api/pessoas")
def pessoas():
    papel = nulo(request.args.get("papel"))
    busca = f"%{request.args.get('busca', '').strip()}%"
    rows = ler(f"""
        SELECT u.id_usuario, u.nm_usuario, u.nr_cpf_cnpj, u.ds_email, oc.nm_origem, u.fl_ativo, u.dt_anonimizacao,
               json_agg(json_build_object('papel', p.papel, 'ativo', p.dt_fim IS NULL) ORDER BY p.papel) AS papeis,
               (SELECT t.nr_telefone FROM telefone t WHERE t.id_usuario = u.id_usuario ORDER BY t.fl_principal DESC, t.nr_sequencia LIMIT 1) AS telefone
          FROM usuario u JOIN ({SQL_PAPEIS}) p ON p.id_usuario = u.id_usuario
          LEFT JOIN origem_contato oc ON oc.id_origem = u.id_origem
         WHERE (u.nm_usuario ILIKE %(b)s OR coalesce(u.nr_cpf_cnpj, '') ILIKE %(b)s OR coalesce(u.ds_email, '') ILIKE %(b)s)
         GROUP BY u.id_usuario, oc.nm_origem
        HAVING %(p)s::text IS NULL OR bool_or(p.papel = %(p)s::text)
         ORDER BY u.nm_usuario""", dict(b=busca, p=papel))
    return jsonify(pessoas=rows)


@app.get("/api/pessoas/<int:uid>")
def pessoa(uid):
    with transacao(somente_leitura=True) as c:
        u = q1(c, "SELECT u.*, oc.nm_origem FROM usuario u LEFT JOIN origem_contato oc USING (id_origem) WHERE u.id_usuario = %s", (uid,))
        if not u:
            abort(404)
        u.pop("ds_senha_hash", None)
        papeis = q(c, f"SELECT papel, dt_inicio, dt_fim FROM ({SQL_PAPEIS}) p WHERE id_usuario = %s ORDER BY papel", (uid,))
        creci = q1(c, "SELECT nr_creci FROM corretor WHERE id_usuario = %s", (uid,))
        return jsonify(
            usuario=u, papeis=papeis, creci=creci and creci["nr_creci"], telefones=telefones_de(c, uid),
            perfis=q(c, SQL_PERFIL + " WHERE p.id_usuario = %s ORDER BY p.nr_perfil", (uid,)),
            conversas=q(c, """SELECT cv.id_conversa, cv.dt_inicio, cv.st_conversa, fe.nm_estagio, fe.ds_cor, co.nm_usuario AS corretor, cl.nm_usuario AS cliente
                               FROM conversa cv JOIN funil_estagio fe USING (id_estagio) JOIN usuario cl ON cl.id_usuario = cv.id_cliente
                               LEFT JOIN usuario co ON co.id_usuario = cv.id_corretor
                              WHERE cv.id_cliente = %s OR cv.id_corretor = %s ORDER BY cv.dt_inicio DESC""", (uid, uid)),
            imoveis=q(c, """SELECT i.id_imovel, i.cd_imobizi, t.nm_tipo_imovel, b.nm_bairro, i.st_imovel, i.vl_venda, i.vl_aluguel,
                                   CASE WHEN i.id_proprietario = %s THEN 'proprietario' ELSE 'corretor responsavel' END AS vinculo
                              FROM imovel i JOIN tipo_imovel t USING (id_tipo_imovel) JOIN bairro b ON b.id_bairro = i.id_bairro
                             WHERE i.id_proprietario = %s OR i.id_corretor_responsavel = %s ORDER BY i.cd_imobizi""", (uid, uid, uid)),
            contratos=q(c, """SELECT ct.id_contrato, ct.tp_contrato, ct.st_contrato, ct.vl_final, i.cd_imobizi,
                                     CASE WHEN p.id_cliente = %(u)s THEN 'cliente' WHEN i.id_proprietario = %(u)s THEN 'proprietario' ELSE 'corretor' END AS vinculo
                                FROM contrato ct JOIN proposta p USING (id_proposta) JOIN imovel i USING (id_imovel)
                               WHERE p.id_cliente = %(u)s OR i.id_proprietario = %(u)s OR p.id_corretor = %(u)s ORDER BY ct.id_contrato""", dict(u=uid)),
            receber=q(c, "SELECT id_conta_receber, ds_conta, tp_papel_pagador, vl_receber, vl_baixado, dt_vencimento, st_conta FROM vw_conta_receber WHERE id_pagador = %s ORDER BY dt_vencimento DESC LIMIT 30", (uid,)),
            pagar=q(c, """SELECT cp.id_conta_pagar, cp.ds_conta, cf.nm_categoria, cp.vl_pagar, cp.vl_baixado, cp.dt_vencimento, cp.st_conta,
                                 CASE WHEN cp.id_favorecido = %(u)s THEN 'recebe' ELSE 'arca com o custo' END AS vinculo
                            FROM vw_conta_pagar cp JOIN categoria_financeira cf USING (id_categoria)
                           WHERE cp.id_favorecido = %(u)s OR cp.id_custeador = %(u)s ORDER BY cp.dt_vencimento DESC LIMIT 30""", dict(u=uid)),
        )


@app.post("/api/pessoas")
def pessoa_nova():
    d = corpo()
    papel = d.get("papel") or "cliente"
    if papel not in PAPEIS:
        raise ErroApp("Papel invalido")
    with transacao() as c:
        uid = criar_pessoa(c, d, papel)
    return jsonify(id_usuario=uid), 201


@app.post("/api/pessoas/<int:uid>/papeis")
def pessoa_papel(uid):
    d = corpo()
    papel = d.get("papel")
    if papel not in PAPEIS:
        raise ErroApp("Papel invalido")
    with transacao() as c:
        existe = q1(c, f"SELECT dt_fim FROM {papel} WHERE id_usuario = %s", (uid,))
        if existe:   # papel encerrado volta a valer
            c.execute(f"UPDATE {papel} SET dt_fim = NULL WHERE id_usuario = %s", (uid,))
        elif papel == "corretor":
            c.execute("INSERT INTO corretor (id_usuario, nr_creci, dt_inicio) VALUES (%s, %s, coalesce(%s::date, CURRENT_DATE))", (uid, obrig(d, "creci")[0], nulo(d.get("dt_inicio"))))
        else:
            c.execute(f"INSERT INTO {papel} (id_usuario, dt_inicio) VALUES (%s, coalesce(%s::date, CURRENT_DATE))", (uid, nulo(d.get("dt_inicio"))))
    return jsonify(ok=True), 201


@app.post("/api/pessoas/<int:uid>/papeis/<papel>/encerrar")
def pessoa_encerrar_papel(uid, papel):
    if papel not in PAPEIS:
        raise ErroApp("Papel invalido")
    d = corpo()
    with transacao() as c:
        c.execute(f"UPDATE {papel} SET dt_fim = coalesce(%s::date, CURRENT_DATE) WHERE id_usuario = %s", (nulo(d.get("dt_fim")), uid))
    return jsonify(ok=True)


@app.delete("/api/pessoas/<int:uid>/papeis/<papel>")
def pessoa_remover_papel(uid, papel):
    """Exclui o papel (so se nada o referencia: as FKs com RESTRICT protegem o historico; RN01 exige outro papel)."""
    if papel not in PAPEIS:
        raise ErroApp("Papel invalido")
    with transacao() as c:
        c.execute(f"DELETE FROM {papel} WHERE id_usuario = %s", (uid,))
    return jsonify(ok=True)


@app.post("/api/pessoas/<int:uid>/anonimizar")
def pessoa_anonimizar(uid):
    """PO07 (LGPD): os dados pessoais saem (inclusive os telefones), o registro e o historico dos negocios ficam.
    Se a pessoa era a titular de um numero compartilhado, a titularidade passa para outra pessoa que usa o numero (RN03)."""
    with transacao() as c:
        c.execute("""UPDATE usuario SET nm_usuario = 'Titular anonimizado', nr_cpf_cnpj = NULL, ds_email = NULL, fl_ativo = FALSE,
                            dt_anonimizacao = CURRENT_TIMESTAMP WHERE id_usuario = %s""", (uid,))
        titulares = [r["nr_telefone"] for r in q(c, "SELECT nr_telefone FROM telefone WHERE id_usuario = %s AND fl_titular", (uid,))]
        c.execute("DELETE FROM telefone WHERE id_usuario = %s", (uid,))
        for n in titulares:
            c.execute("""UPDATE telefone SET fl_titular = TRUE WHERE (id_usuario, nr_sequencia) =
                           (SELECT id_usuario, nr_sequencia FROM telefone WHERE nr_telefone = %s ORDER BY id_usuario LIMIT 1)""", (n,))
    return jsonify(ok=True)


@app.post("/api/pessoas/<int:uid>/telefones")
def pessoa_telefone(uid):
    d = corpo()
    numero = obrig(d, "telefone")[0]
    with transacao() as c:
        compartilhado = incluir_telefone(c, uid, numero)   # numero de outra pessoa: passa a ser compartilhado e o titular continua o mesmo (RN03)
    return jsonify(ok=True, compartilhado=compartilhado), 201


@app.post("/api/pessoas/<int:uid>/perfis")
def pessoa_perfil(uid):
    d = corpo()
    fin = obrig(d, "tp_finalidade")[0]
    with transacao() as c:
        n = q1(c, "SELECT coalesce(max(nr_perfil), 0) + 1 AS n FROM perfil_interesse WHERE id_usuario = %s", (uid,))["n"]
        c.execute("""INSERT INTO perfil_interesse (id_usuario, nr_perfil, id_cidade, tp_finalidade, vl_minimo, vl_maximo, qt_quartos_min)
                     VALUES (%s, %s, %s, %s, %s, %s, %s)""",
                  (uid, n, nulo(d.get("id_cidade")), fin, nulo(d.get("vl_minimo")), nulo(d.get("vl_maximo")), nulo(d.get("qt_quartos_min"))))
        for tp in d.get("tipos") or []:   # N:N DESEJA: um perfil aceita varios tipos (RN47)
            c.execute("INSERT INTO perfil_interesse_tipo (id_usuario, nr_perfil, id_tipo_imovel) VALUES (%s, %s, %s)", (uid, n, tp))
        for b in d.get("bairros") or []:  # N:N ABRANGE: um perfil aceita varios bairros da sua cidade (o gatilho confere a cidade, RN52)
            c.execute("INSERT INTO perfil_interesse_bairro (id_usuario, nr_perfil, id_bairro) VALUES (%s, %s, %s)", (uid, n, b))
    return jsonify(ok=True, nr_perfil=n), 201


# --------------------------------------------------------------------------------------------
# imoveis e seletor por perfil (a "Selecao Interna" do app original, agora sobre o banco)
# --------------------------------------------------------------------------------------------
SQL_IMOVEL = """
    SELECT i.*, t.nm_tipo_imovel, b.nm_bairro, ci.id_cidade, ci.nm_cidade, ci.sg_uf, uf.nm_uf, cep.tp_cep, pr.nm_usuario AS proprietario, co.nm_usuario AS corretor,
           (SELECT count(*) FROM conversa_imovel x WHERE x.id_imovel = i.id_imovel) AS interesses,
           (SELECT count(*) FROM visita x WHERE x.id_imovel = i.id_imovel) AS visitas,
           (SELECT count(*) FROM proposta x WHERE x.id_imovel = i.id_imovel) AS propostas,
           (SELECT count(*) FROM foto x WHERE x.id_imovel = i.id_imovel) AS fotos
      FROM imovel i JOIN tipo_imovel t USING (id_tipo_imovel) JOIN bairro b ON b.id_bairro = i.id_bairro
      JOIN cep ON cep.nr_cep = i.nr_cep JOIN cidade ci ON ci.id_cidade = cep.id_cidade JOIN uf ON uf.sg_uf = ci.sg_uf
      JOIN usuario pr ON pr.id_usuario = i.id_proprietario LEFT JOIN usuario co ON co.id_usuario = i.id_corretor_responsavel"""


@app.get("/api/imoveis")
def imoveis():
    """Busca dos imoveis cadastrados (RF37): tipo (da tabela tipo_imovel), cidade, bairro (da tabela bairro), finalidade, situacao, quartos e texto."""
    a = request.args
    rows = ler(SQL_IMOVEL + """
     WHERE (%(cid)s::int IS NULL OR ci.id_cidade = %(cid)s::int)
       AND (%(fin)s::text IS NULL OR i.tp_finalidade = %(fin)s::text OR i.tp_finalidade = 'ambas')
       AND (%(st)s::text IS NULL OR i.st_imovel = %(st)s::text)
       AND (%(tp)s::int IS NULL OR i.id_tipo_imovel = %(tp)s::int)
       AND (%(bai)s::int IS NULL OR i.id_bairro = %(bai)s::int)
       AND (%(q)s::int IS NULL OR i.qt_quartos >= %(q)s::int)
       AND (coalesce(i.cd_imobizi, '') ILIKE %(b)s OR b.nm_bairro ILIKE %(b)s OR i.nm_logradouro ILIKE %(b)s OR pr.nm_usuario ILIKE %(b)s OR t.nm_tipo_imovel ILIKE %(b)s)
     ORDER BY i.dt_cadastro DESC, i.cd_imobizi""", dict(cid=nulo(a.get("cidade")), fin=nulo(a.get("finalidade")), st=nulo(a.get("situacao")), tp=nulo(a.get("tipo")), bai=nulo(a.get("bairro")),
                                     q=nulo(a.get("quartos")), b=f"%{a.get('busca', '').strip()}%"))
    return jsonify(imoveis=rows)


@app.get("/api/imoveis/<int:iid>")
def imovel(iid):
    with transacao(somente_leitura=True) as c:
        i = q1(c, SQL_IMOVEL + " WHERE i.id_imovel = %s", (iid,))
        if not i:
            abort(404)
        return jsonify(
            imovel=i,
            fotos=q(c, "SELECT * FROM foto WHERE id_imovel = %s ORDER BY nr_ordem", (iid,)),
            caracteristicas=q(c, "SELECT c.* FROM imovel_caracteristica ic JOIN caracteristica c USING (id_caracteristica) WHERE ic.id_imovel = %s ORDER BY nm_caracteristica", (iid,)),
            interesses=q(c, """SELECT ci.id_conversa, ci.dt_interesse, u.nm_usuario AS cliente, fe.nm_estagio, cv.st_conversa FROM conversa_imovel ci
                                JOIN conversa cv USING (id_conversa) JOIN usuario u ON u.id_usuario = cv.id_cliente JOIN funil_estagio fe USING (id_estagio)
                               WHERE ci.id_imovel = %s ORDER BY ci.dt_interesse DESC""", (iid,)),
            visitas=q(c, """SELECT v.*, u.nm_usuario AS cliente, co.nm_usuario AS corretor FROM visita v JOIN usuario u ON u.id_usuario = v.id_cliente
                             JOIN usuario co ON co.id_usuario = v.id_corretor WHERE v.id_imovel = %s ORDER BY v.dt_visita DESC""", (iid,)),
            propostas=q(c, """SELECT p.*, u.nm_usuario AS cliente, ct.id_contrato, ct.st_contrato FROM proposta p JOIN usuario u ON u.id_usuario = p.id_cliente
                               LEFT JOIN contrato ct ON ct.id_proposta = p.id_proposta WHERE p.id_imovel = %s ORDER BY p.dt_proposta DESC""", (iid,)),
        )


@app.post("/api/imoveis")
def imovel_novo():
    """Cadastro de imovel novo (RF13). O tipo vem da lista tipo_imovel (FK, RN48) e o bairro, da tabela bairro (FK, RN51); o banco confere
    o papel do proprietario e do corretor (RN32), o valor exigido pela finalidade (CHECK) e se o bairro e da cidade do CEP (gatilho, RN51).
    CEP novo entra na tabela cep com a cidade escolhida."""
    d = corpo()
    prop, tipo, fin, cep, logradouro, numero, bairro = obrig(d, "id_proprietario", "id_tipo_imovel", "tp_finalidade", "nr_cep", "nm_logradouro", "nr_endereco", "id_bairro")
    cep = re.sub(r"\D", "", cep)
    if len(cep) != 8:
        raise ErroApp("O CEP tem 8 digitos")
    with transacao() as c:
        if not q1(c, "SELECT 1 AS x FROM cep WHERE nr_cep = %s", (cep,)):
            cidade = nulo(d.get("id_cidade")) or (q1(c, "SELECT id_cidade FROM bairro WHERE id_bairro = %s", (bairro,)) or {}).get("id_cidade")
            if not cidade:
                raise ErroApp(f"O CEP {cep} ainda nao esta cadastrado: escolha a cidade dele")
            c.execute("INSERT INTO cep (nr_cep, id_cidade, tp_cep) VALUES (%s, %s, 'logradouro')", (cep, cidade))
        r = q1(c, """INSERT INTO imovel (cd_imobizi, id_proprietario, id_corretor_responsavel, nr_cep, id_tipo_imovel, tp_finalidade, nm_logradouro, nr_endereco,
                                         ds_complemento, id_bairro, vl_area_util, vl_area_total, qt_quartos, qt_banheiros, qt_vagas_garagem, vl_venda, vl_aluguel, ds_anuncio)
                     VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s) RETURNING id_imovel""",
               (nulo(d.get("cd_imobizi")), prop, nulo(d.get("id_corretor_responsavel")), cep, tipo, fin, logradouro, numero, nulo(d.get("ds_complemento")), bairro,
                nulo(d.get("vl_area_util")), nulo(d.get("vl_area_total")), nulo(d.get("qt_quartos")), nulo(d.get("qt_banheiros")), nulo(d.get("qt_vagas_garagem")),
                nulo(d.get("vl_venda")), nulo(d.get("vl_aluguel")), nulo(d.get("ds_anuncio"))))
        for car in d.get("caracteristicas") or []:
            c.execute("INSERT INTO imovel_caracteristica (id_caracteristica, id_imovel) VALUES (%s, %s)", (car, r["id_imovel"]))
    return jsonify(r), 201


@app.patch("/api/imoveis/<int:iid>")
def imovel_atualizar(iid):
    d = corpo()
    campos = {k: nulo(d[k]) for k in ("id_tipo_imovel", "vl_venda", "vl_aluguel", "st_imovel", "tp_finalidade", "id_corretor_responsavel", "ds_anuncio") if k in d}
    if not campos:
        raise ErroApp("Nada para alterar")
    with transacao() as c:
        c.execute(f"UPDATE imovel SET {', '.join(f'{k} = %({k})s' for k in campos)} WHERE id_imovel = %(id)s", dict(campos, id=iid))
    return jsonify(ok=True)


@app.post("/api/imoveis/<int:iid>/caracteristicas")
def imovel_caracteristica(iid):
    car = obrig(corpo(), "id_caracteristica")[0]
    with transacao() as c:
        c.execute("INSERT INTO imovel_caracteristica (id_caracteristica, id_imovel) VALUES (%s, %s)", (car, iid))
    return jsonify(ok=True), 201


@app.delete("/api/imoveis/<int:iid>/caracteristicas/<int:car>")
def imovel_caracteristica_remover(iid, car):
    with transacao() as c:
        c.execute("DELETE FROM imovel_caracteristica WHERE id_imovel = %s AND id_caracteristica = %s", (iid, car))
    return jsonify(ok=True)


def selecionar(c, perfil, limite=10):
    """Pontua os imoveis disponiveis pelo perfil de interesse (finalidade obrigatoria; cidade, bairro, tipo, faixa e quartos somam pontos).
    O perfil pode aceitar varios tipos (N:N DESEJA, RN47) e varios bairros (N:N ABRANGE, RN52): soma pontos o imovel de qualquer um deles.
    A comparacao do bairro e pela chave (id_bairro), e nao pelo texto: "Tatuape" e "tatuape " sao o mesmo bairro."""
    return q(c, """
        SELECT i.id_imovel, i.cd_imobizi, t.nm_tipo_imovel, i.tp_finalidade, b.nm_bairro, ci.nm_cidade, i.qt_quartos, i.vl_area_util,
               CASE WHEN %(fin)s = 'venda' THEN i.vl_venda ELSE i.vl_aluguel END AS valor,
               (CASE WHEN %(cid)s::int IS NOT NULL AND ci.id_cidade = %(cid)s::int THEN 3 ELSE 0 END
              + CASE WHEN i.id_bairro = ANY(%(bairros)s::int[]) OR (%(bai)s::text IS NOT NULL AND b.nm_bairro ILIKE %(bai)s::text) THEN 3 ELSE 0 END
              + CASE WHEN i.id_tipo_imovel = ANY(%(tipos)s::int[]) THEN 2 ELSE 0 END
              + CASE WHEN (CASE WHEN %(fin)s = 'venda' THEN i.vl_venda ELSE i.vl_aluguel END)
                          BETWEEN coalesce(%(vmin)s::numeric, 0) AND coalesce(%(vmax)s::numeric, 1e12) THEN 3 ELSE 0 END
              + CASE WHEN coalesce(i.qt_quartos, 0) >= coalesce(%(qmin)s::int, 0) THEN 1 ELSE 0 END) AS pontos
          FROM imovel i JOIN tipo_imovel t USING (id_tipo_imovel) JOIN bairro b ON b.id_bairro = i.id_bairro
          JOIN cep ON cep.nr_cep = i.nr_cep JOIN cidade ci ON ci.id_cidade = cep.id_cidade
         WHERE i.st_imovel = 'disponivel' AND (i.tp_finalidade = %(fin)s OR i.tp_finalidade = 'ambas')
         ORDER BY pontos DESC, valor LIMIT %(lim)s""",
        dict(fin=perfil["tp_finalidade"], cid=perfil.get("id_cidade"), bai=perfil.get("nm_bairro"), bairros=[int(x) for x in perfil.get("bairros") or []],
             tipos=[int(x) for x in perfil.get("tipos") or []],
             vmin=perfil.get("vl_minimo"), vmax=perfil.get("vl_maximo"), qmin=perfil.get("qt_quartos_min"), lim=limite))


@app.get("/api/seletor")
def seletor():
    with transacao(somente_leitura=True) as c:
        perfis = q(c, SQL_PERFIL + " ORDER BY u.nm_usuario, p.nr_perfil")
        uid, nr = nulo(request.args.get("usuario")), nulo(request.args.get("perfil"))
        escolhido = next((p for p in perfis if str(p["id_usuario"]) == str(uid) and str(p["nr_perfil"]) == str(nr)), None)
        return jsonify(perfis=perfis, perfil=escolhido, imoveis=selecionar(c, escolhido) if escolhido else [])


# --------------------------------------------------------------------------------------------
# negociacao: visitas, propostas, contratos, comissoes
# --------------------------------------------------------------------------------------------
@app.get("/api/visitas")
def visitas():
    return jsonify(visitas=ler("""
        SELECT v.*, i.cd_imobizi, b.nm_bairro, cl.nm_usuario AS cliente, co.nm_usuario AS corretor,
               (SELECT count(*) FROM proposta p WHERE p.id_visita = v.id_visita) AS propostas
          FROM visita v JOIN imovel i USING (id_imovel) JOIN bairro b ON b.id_bairro = i.id_bairro JOIN usuario cl ON cl.id_usuario = v.id_cliente JOIN usuario co ON co.id_usuario = v.id_corretor
         WHERE (%(st)s::text IS NULL OR v.st_visita = %(st)s::text) ORDER BY v.dt_visita DESC""", dict(st=nulo(request.args.get("situacao")))))


@app.post("/api/visitas")
def visita_nova():
    d = corpo()
    im, cl, co, dtv = obrig(d, "id_imovel", "id_cliente", "id_corretor", "dt_visita")
    with transacao() as c:
        r = q1(c, "INSERT INTO visita (id_imovel, id_cliente, id_corretor, dt_visita) VALUES (%s, %s, %s, %s) RETURNING id_visita", (im, cl, co, dtv))
    return jsonify(r), 201


@app.patch("/api/visitas/<int:vid>")
def visita_atualizar(vid):
    d = corpo()
    with transacao() as c:
        c.execute("UPDATE visita SET st_visita = coalesce(%s, st_visita), ds_feedback = coalesce(%s, ds_feedback) WHERE id_visita = %s",
                  (nulo(d.get("st_visita")), nulo(d.get("ds_feedback")), vid))
    return jsonify(ok=True)


@app.get("/api/propostas")
def propostas():
    return jsonify(propostas=ler("""
        SELECT p.*, i.cd_imobizi, i.tp_finalidade, cl.nm_usuario AS cliente, co.nm_usuario AS corretor, au.nm_usuario AS autorizador,
               round(100 * (1 - p.vl_proposto / p.vl_anunciado), 1) AS pc_desconto, ct.id_contrato, ct.st_contrato
          FROM proposta p JOIN imovel i USING (id_imovel) JOIN usuario cl ON cl.id_usuario = p.id_cliente JOIN usuario co ON co.id_usuario = p.id_corretor
          LEFT JOIN usuario au ON au.id_usuario = p.id_autorizador LEFT JOIN contrato ct ON ct.id_proposta = p.id_proposta
         WHERE (%(st)s::text IS NULL OR p.st_proposta = %(st)s::text) ORDER BY p.dt_proposta DESC""", dict(st=nulo(request.args.get("situacao")))))


@app.post("/api/propostas")
def proposta_nova():
    """PO03: desconto acima de 10% so com o administrador registrado como autorizador (CHECK no banco)."""
    d = corpo()
    im, cl, co, vl = obrig(d, "id_imovel", "id_cliente", "id_corretor", "vl_proposto")
    with transacao() as c:
        i = q1(c, "SELECT tp_finalidade, vl_venda, vl_aluguel FROM imovel WHERE id_imovel = %s", (im,))
        tipo = d.get("tipo") or ("locacao" if i["tp_finalidade"] == "locacao" else "venda")
        anunciado = i["vl_aluguel"] if tipo == "locacao" else i["vl_venda"]
        if anunciado is None:
            raise ErroApp("O imovel nao tem valor anunciado para essa finalidade")
        resp = nulo(d.get("id_proposta_respondida"))
        if resp:
            c.execute("UPDATE proposta SET st_proposta = 'substituida' WHERE id_proposta = %s AND st_proposta = 'pendente'", (resp,))
        aut = usuario_atual() if d.get("autorizar") else None
        r = q1(c, """INSERT INTO proposta (id_imovel, id_cliente, id_corretor, id_autorizador, id_proposta_respondida, id_visita, vl_proposto, vl_anunciado, ds_condicoes, dt_autorizacao)
                     VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, CASE WHEN %s::int IS NULL THEN NULL ELSE CURRENT_TIMESTAMP END) RETURNING id_proposta""",
               (im, cl, co, aut, resp, nulo(d.get("id_visita")), vl, anunciado, nulo(d.get("ds_condicoes")), aut))
    return jsonify(r), 201


@app.patch("/api/propostas/<int:pid>")
def proposta_atualizar(pid):
    st = obrig(corpo(), "st_proposta")[0]
    with transacao() as c:
        c.execute("UPDATE proposta SET st_proposta = %s WHERE id_proposta = %s", (st, pid))
    return jsonify(ok=True)


@app.post("/api/propostas/<int:pid>/contrato")
def contrato_novo(pid):
    """Gera o contrato da proposta aceita, em rascunho (RN36). FECHA e 1:1: id_proposta e UNIQUE."""
    d = corpo()
    with transacao() as c:
        p = q1(c, "SELECT p.*, i.tp_finalidade FROM proposta p JOIN imovel i USING (id_imovel) WHERE id_proposta = %s", (pid,))
        if p["st_proposta"] != "aceita":
            c.execute("UPDATE proposta SET st_proposta = 'aceita' WHERE id_proposta = %s", (pid,))
        tipo = d.get("tp_contrato") or ("locacao" if p["tp_finalidade"] == "locacao" else "venda")
        r = q1(c, """INSERT INTO contrato (id_proposta, tp_contrato, tp_condicao_pagamento, vl_final, pc_corretagem, pc_administracao, nr_dia_vencimento, dt_inicio, dt_fim)
                     VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s) RETURNING id_contrato""",
               (pid, tipo, d.get("tp_condicao_pagamento") or "a_vista", nulo(d.get("vl_final")) or p["vl_proposto"],
                nulo(d.get("pc_corretagem")) or (100 if tipo == "locacao" else 6), nulo(d.get("pc_administracao")) if tipo == "locacao" else None,
                nulo(d.get("nr_dia_vencimento")) if tipo == "locacao" else None, nulo(d.get("dt_inicio")), nulo(d.get("dt_fim"))))
    return jsonify(r), 201


SQL_CONTRATO = """
    SELECT vc.*, p.id_imovel, p.id_cliente, p.id_corretor, p.vl_anunciado, i.cd_imobizi, b.nm_bairro, i.id_proprietario,
           cl.nm_usuario AS cliente, pr.nm_usuario AS proprietario, co.nm_usuario AS corretor
      FROM vw_contrato vc JOIN proposta p USING (id_proposta) JOIN imovel i USING (id_imovel) JOIN bairro b ON b.id_bairro = i.id_bairro
      JOIN usuario cl ON cl.id_usuario = p.id_cliente JOIN usuario pr ON pr.id_usuario = i.id_proprietario JOIN usuario co ON co.id_usuario = p.id_corretor"""


@app.get("/api/contratos")
def contratos():
    return jsonify(contratos=ler(SQL_CONTRATO + " ORDER BY vc.id_contrato"))


@app.get("/api/contratos/<int:ctid>")
def contrato(ctid):
    with transacao(somente_leitura=True) as c:
        ct = q1(c, SQL_CONTRATO + " WHERE vc.id_contrato = %s", (ctid,))
        if not ct:
            abort(404)
        receber = q(c, "SELECT * FROM vw_conta_receber WHERE id_contrato = %s ORDER BY dt_vencimento", (ctid,))
        recs = q(c, "SELECT r.* FROM recebimento r JOIN conta_receber cr USING (id_conta_receber) WHERE cr.id_contrato = %s ORDER BY dt_recebimento", (ctid,))
        for cr in receber:
            cr["baixas"] = [r for r in recs if r["id_conta_receber"] == cr["id_conta_receber"]]
        pagar = q(c, """SELECT cp.*, f.nm_usuario AS favorecido FROM vw_conta_pagar cp LEFT JOIN usuario f ON f.id_usuario = cp.id_favorecido
                        WHERE cp.id_contrato = %s ORDER BY cp.dt_vencimento""", (ctid,))
        return jsonify(
            contrato=ct,
            comissoes=q(c, """SELECT cm.*, u.nm_usuario AS corretor, a.nm_usuario AS aprovador FROM vw_comissao cm JOIN usuario u ON u.id_usuario = cm.id_corretor
                               LEFT JOIN usuario a ON a.id_usuario = cm.id_aprovador WHERE cm.id_contrato = %s ORDER BY u.nm_usuario""", (ctid,)),
            financiamento=q1(c, "SELECT f.*, u.nm_usuario AS instituicao FROM financiamento f JOIN usuario u ON u.id_usuario = f.id_instituicao WHERE f.id_contrato = %s", (ctid,)),
            documentos=q(c, "SELECT d.*, td.nm_tipo_documento FROM documento d JOIN tipo_documento td USING (id_tipo_documento) WHERE d.id_contrato = %s ORDER BY d.nr_documento", (ctid,)),
            receber=receber, pagar=pagar,
            auditoria=auditoria_de(c, "a.id_contrato = %(id)s OR a.id_proposta = %(prop)s OR a.id_comissao_contrato = %(id)s "
                                      "OR a.id_conta_receber IN (SELECT id_conta_receber FROM conta_receber WHERE id_contrato = %(id)s) "
                                      "OR a.id_recebimento_conta IN (SELECT id_conta_receber FROM conta_receber WHERE id_contrato = %(id)s) "
                                      "OR a.id_conta_pagar IN (SELECT id_conta_pagar FROM conta_pagar WHERE id_contrato = %(id)s) "
                                      "OR a.id_pagamento_conta IN (SELECT id_conta_pagar FROM conta_pagar WHERE id_contrato = %(id)s)",
                                   dict(id=ctid, prop=ct["id_proposta"]), 200),
        )


@app.post("/api/contratos/<int:ctid>/assinar")
def contrato_assinar(ctid):
    """RN36: o contrato passa a valer na assinatura. Na locacao, o gatilho torna o cliente inquilino (RN33).
    O prototipo tambem lanca a conta da corretagem/intermediacao, paga pelo proprietario."""
    d = corpo()
    with transacao() as c:
        dta = nulo(d.get("dt_assinatura")) or datetime.date.today().isoformat()
        c.execute("UPDATE contrato SET st_contrato = 'vigente', dt_assinatura = %s WHERE id_contrato = %s AND st_contrato = 'rascunho'", (dta, ctid))
        ct = q1(c, SQL_CONTRATO + " WHERE vc.id_contrato = %s", (ctid,))
        if ct["st_contrato"] != "vigente":
            raise ErroApp("So contrato em rascunho pode ser assinado")
        locacao = ct["tp_contrato"] == "locacao"
        c.execute("""INSERT INTO conta_receber (id_contrato, id_categoria, id_pagador, tp_papel_pagador, ds_conta, dt_competencia, vl_receber, dt_vencimento)
                     VALUES (%s, (SELECT id_categoria FROM categoria_financeira WHERE cd_categoria = %s), %s, 'proprietario', %s, %s::date, %s, %s::date + 10)""",
                  (ctid, "intermediacao_locacao" if locacao else "corretagem_venda", ct["id_proprietario"],
                   f"{'Intermediacao da locacao' if locacao else 'Corretagem da venda'} - contrato {ctid}", dta, ct["vl_corretagem"], dta))
    return jsonify(ok=True)


@app.post("/api/contratos/<int:ctid>/aluguel")
def contrato_aluguel(ctid):
    """Lanca o aluguel de uma competencia (pago pelo inquilino). A taxa de administracao sai no repasse (RN30)."""
    d = corpo()
    comp = obrig(d, "competencia")[0]  # AAAA-MM
    with transacao() as c:
        ct = q1(c, SQL_CONTRATO + " WHERE vc.id_contrato = %s", (ctid,))
        if ct["tp_contrato"] != "locacao" or ct["st_contrato"] != "vigente":
            raise ErroApp("Aluguel so para locacao vigente")
        dcomp = datetime.date.fromisoformat(comp + "-01")
        venc = dcomp.replace(day=min(int(ct["nr_dia_vencimento"] or 10), 28))
        r = q1(c, """INSERT INTO conta_receber (id_contrato, id_categoria, id_pagador, tp_papel_pagador, ds_conta, dt_competencia, vl_receber, dt_vencimento)
                     VALUES (%s, (SELECT id_categoria FROM categoria_financeira WHERE cd_categoria = 'aluguel'), %s, 'inquilino', %s, %s, %s, %s)
                     RETURNING id_conta_receber""", (ctid, ct["id_cliente"], f"Aluguel {dcomp:%m/%Y} - contrato {ctid}", dcomp, ct["vl_final"], venc))
    return jsonify(r), 201


@app.post("/api/contratos/<int:ctid>/cancelar")
def contrato_cancelar(ctid):
    d = corpo()
    data, motivo = obrig(d, "data", "motivo")
    with transacao() as c:
        c.execute("CALL cancelar_contrato(%s, %s, %s)", (ctid, data, motivo))
    return jsonify(ok=True)


@app.post("/api/contratos/<int:ctid>/rescindir")
def contrato_rescindir(ctid):
    d = corpo()
    data, motivo, ini = obrig(d, "data", "motivo", "iniciativa")
    with transacao() as c:
        c.execute("CALL rescindir_contrato(%s, %s, %s, %s, %s, %s)", (ctid, data, motivo, ini, nulo(d.get("vl_multa")), nulo(d.get("vencimento_multa"))))
    return jsonify(ok=True)


@app.post("/api/contratos/<int:ctid>/encerrar")
def contrato_encerrar(ctid):
    data = obrig(corpo(), "data")[0]
    with transacao() as c:
        c.execute("CALL encerrar_contrato(%s, %s)", (ctid, data))
    return jsonify(ok=True)


@app.post("/api/contratos/<int:ctid>/comissoes")
def comissao_nova(ctid):
    d = corpo()
    cor, pc = obrig(d, "id_corretor", "pc_comissao")
    with transacao() as c:
        c.execute("INSERT INTO comissao (id_contrato, id_corretor, pc_comissao, tp_regra_pagamento) VALUES (%s, %s, %s, %s)",
                  (ctid, cor, pc, d.get("tp_regra_pagamento") or "assinatura"))
    return jsonify(ok=True), 201


@app.patch("/api/contratos/<int:ctid>/comissoes/<int:cor>")
def comissao_atualizar(ctid, cor):
    d = corpo()
    with transacao() as c:
        if "pc_comissao" in d:
            c.execute("UPDATE comissao SET pc_comissao = %s WHERE id_contrato = %s AND id_corretor = %s", (d["pc_comissao"], ctid, cor))
        if d.get("st_comissao") == "cancelada":
            c.execute("UPDATE comissao SET st_comissao = 'cancelada' WHERE id_contrato = %s AND id_corretor = %s", (ctid, cor))
    return jsonify(ok=True)


@app.post("/api/contratos/<int:ctid>/comissoes/<int:cor>/liberar")
def comissao_liberar(ctid, cor):
    """RN25/PO01: o administrador aprova; a liberacao gera a conta a pagar ao corretor (LANCA, 1:1)."""
    with transacao() as c:
        cm = q1(c, "SELECT cm.*, u.nm_usuario FROM vw_comissao cm JOIN usuario u ON u.id_usuario = cm.id_corretor WHERE id_contrato = %s AND id_corretor = %s", (ctid, cor))
        if not cm:
            abort(404)
        if cm["st_comissao"] != "pendente":
            raise ErroApp("So comissao pendente pode ser liberada")
        cp = q1(c, """INSERT INTO conta_pagar (id_contrato, id_categoria, id_favorecido, tp_papel_custeio, ds_conta, dt_competencia, vl_pagar, dt_vencimento)
                      VALUES (%s, (SELECT id_categoria FROM categoria_financeira WHERE cd_categoria = 'comissao'), %s, 'imobiliaria', %s,
                              CURRENT_DATE, %s, CURRENT_DATE + 15) RETURNING id_conta_pagar""",
                (ctid, cor, f"Comissao de {cm['nm_usuario']} - contrato {ctid}", cm["vl_comissao"]))["id_conta_pagar"]
        c.execute("""UPDATE comissao SET st_comissao = 'liberada', id_aprovador = %s, dt_aprovacao = CURRENT_TIMESTAMP, id_conta_pagar = %s
                     WHERE id_contrato = %s AND id_corretor = %s""", (usuario_atual(), cp, ctid, cor))
    return jsonify(ok=True, id_conta_pagar=cp)


@app.post("/api/contratos/<int:ctid>/financiamento")
def financiamento(ctid):
    d = corpo()
    with transacao() as c:
        if q1(c, "SELECT 1 AS x FROM financiamento WHERE id_contrato = %s", (ctid,)):
            c.execute("""UPDATE financiamento SET st_financiamento = %s, dt_aprovacao = coalesce(%s::date, dt_aprovacao), dt_liberacao = coalesce(%s::date, dt_liberacao)
                         WHERE id_contrato = %s""", (obrig(d, "st_financiamento")[0], nulo(d.get("dt_aprovacao")), nulo(d.get("dt_liberacao")), ctid))
        else:
            inst, vl = obrig(d, "id_instituicao", "vl_financiado")
            c.execute("""INSERT INTO financiamento (id_contrato, id_instituicao, vl_financiado, vl_entrada, nr_parcelas, pc_juros_aa)
                         VALUES (%s, %s, %s, %s, %s, %s)""", (ctid, inst, vl, nulo(d.get("vl_entrada")), nulo(d.get("nr_parcelas")), nulo(d.get("pc_juros_aa"))))
    return jsonify(ok=True)


# --------------------------------------------------------------------------------------------
# financeiro: contas, baixas (o repasse nasce do gatilho), conciliacao
# --------------------------------------------------------------------------------------------
@app.get("/api/financeiro/receber")
def receber():
    return jsonify(contas=ler("""
        SELECT cr.*, u.nm_usuario AS pagador, cf.nm_categoria, i.cd_imobizi,
               (SELECT count(*) FROM recebimento r WHERE r.id_conta_receber = cr.id_conta_receber) AS baixas
          FROM vw_conta_receber cr JOIN usuario u ON u.id_usuario = cr.id_pagador JOIN categoria_financeira cf USING (id_categoria)
          LEFT JOIN contrato ct USING (id_contrato) LEFT JOIN proposta p USING (id_proposta) LEFT JOIN imovel i USING (id_imovel)
         WHERE (%(st)s::text IS NULL OR cr.st_conta = %(st)s::text) AND (u.nm_usuario ILIKE %(b)s OR coalesce(cr.ds_conta, '') ILIKE %(b)s)
         ORDER BY cr.dt_vencimento DESC""", dict(st=nulo(request.args.get("situacao")), b=f"%{request.args.get('busca', '').strip()}%")))


@app.get("/api/financeiro/pagar")
def pagar():
    return jsonify(contas=ler("""
        SELECT cp.*, f.nm_usuario AS favorecido, cu.nm_usuario AS custeador, cf.nm_categoria,
               (SELECT count(*) FROM pagamento x WHERE x.id_conta_pagar = cp.id_conta_pagar) AS baixas
          FROM vw_conta_pagar cp LEFT JOIN usuario f ON f.id_usuario = cp.id_favorecido LEFT JOIN usuario cu ON cu.id_usuario = cp.id_custeador
          JOIN categoria_financeira cf USING (id_categoria)
         WHERE (%(st)s::text IS NULL OR cp.st_conta = %(st)s::text) AND (%(tp)s::text IS NULL OR cf.cd_categoria = %(tp)s::text)
           AND (coalesce(f.nm_usuario, '') ILIKE %(b)s OR coalesce(cp.ds_conta, '') ILIKE %(b)s)
         ORDER BY cp.dt_vencimento DESC""", dict(st=nulo(request.args.get("situacao")), tp=nulo(request.args.get("tipo")), b=f"%{request.args.get('busca', '').strip()}%")))


@app.get("/api/financeiro/receber/<int:crid>")
def receber_detalhe(crid):
    with transacao(somente_leitura=True) as c:
        conta = q1(c, """SELECT cr.*, u.nm_usuario AS pagador, cf.nm_categoria FROM vw_conta_receber cr JOIN usuario u ON u.id_usuario = cr.id_pagador
                           JOIN categoria_financeira cf USING (id_categoria) WHERE id_conta_receber = %s""", (crid,))
        baixas = q(c, """SELECT r.*, cb.nm_apelido, fp.nm_forma_pagamento, rp.id_conta_pagar AS repasse, rp.vl_pagar AS vl_repasse, rp.st_conta AS st_repasse
                         FROM recebimento r JOIN conta_bancaria cb USING (id_conta) JOIN forma_pagamento fp USING (id_forma_pagamento)
                         LEFT JOIN vw_conta_pagar rp ON rp.id_conta_receber_origem = r.id_conta_receber AND rp.nr_recebimento_origem = r.nr_recebimento
                         WHERE r.id_conta_receber = %s ORDER BY nr_recebimento""", (crid,))
        return jsonify(conta=conta, baixas=baixas)


@app.get("/api/financeiro/pagar/<int:cpid>")
def pagar_detalhe(cpid):
    with transacao(somente_leitura=True) as c:
        conta = q1(c, """SELECT cp.*, f.nm_usuario AS favorecido, cu.nm_usuario AS custeador, cf.nm_categoria,
                                cr.ds_conta AS origem_ds, r.dt_recebimento AS origem_data, r.vl_recebido AS origem_valor
                           FROM vw_conta_pagar cp LEFT JOIN usuario f ON f.id_usuario = cp.id_favorecido LEFT JOIN usuario cu ON cu.id_usuario = cp.id_custeador
                           JOIN categoria_financeira cf USING (id_categoria)
                           LEFT JOIN recebimento r ON r.id_conta_receber = cp.id_conta_receber_origem AND r.nr_recebimento = cp.nr_recebimento_origem
                           LEFT JOIN conta_receber cr ON cr.id_conta_receber = cp.id_conta_receber_origem
                          WHERE cp.id_conta_pagar = %s""", (cpid,))
        if not conta:
            abort(404)
        baixas = q(c, """SELECT p.*, cb.nm_apelido, fp.nm_forma_pagamento, u.nm_usuario AS efetivado_por FROM pagamento p JOIN conta_bancaria cb USING (id_conta)
                         JOIN forma_pagamento fp USING (id_forma_pagamento)
                         JOIN usuario u ON u.id_usuario = p.id_usuario WHERE p.id_conta_pagar = %s ORDER BY nr_pagamento""", (cpid,))
        comissao = q1(c, "SELECT id_contrato, id_corretor, pc_comissao, vl_comissao FROM vw_comissao WHERE id_conta_pagar = %s", (cpid,))
        return jsonify(conta=conta, baixas=baixas, comissao=comissao)


def forma(c, d):
    """Forma de pagamento da baixa: id da tabela forma_pagamento (RN50); se nao vier, Pix."""
    return nulo(d.get("id_forma_pagamento")) or q1(c, "SELECT id_forma_pagamento FROM forma_pagamento WHERE nm_forma_pagamento = 'Pix'")["id_forma_pagamento"]


@app.post("/api/financeiro/receber/<int:crid>/baixa")
def receber_baixa(crid):
    """Recebimento (baixa). RN29: a soma nao passa do valor da conta. RN30: se for aluguel, o gatilho gera o repasse ao proprietario."""
    d = corpo()
    conta, valor = obrig(d, "id_conta", "vl_recebido")
    with transacao() as c:
        n = q1(c, "SELECT coalesce(max(nr_recebimento), 0) + 1 AS n FROM recebimento WHERE id_conta_receber = %s", (crid,))["n"]
        c.execute("""INSERT INTO recebimento (id_conta_receber, nr_recebimento, id_conta, dt_recebimento, vl_recebido, id_forma_pagamento)
                     VALUES (%s, %s, %s, coalesce(%s::date, CURRENT_DATE), %s, %s)""", (crid, n, conta, nulo(d.get("dt_recebimento")), valor, forma(c, d)))
        rep = q1(c, "SELECT id_conta_pagar, vl_pagar, dt_vencimento FROM conta_pagar WHERE id_conta_receber_origem = %s AND nr_recebimento_origem = %s", (crid, n))
    return jsonify(ok=True, nr_recebimento=n, repasse=rep), 201


@app.post("/api/financeiro/pagar/<int:cpid>/baixa")
def pagar_baixa(cpid):
    """Pagamento (baixa). RN39: quem efetiva e o usuario que esta agindo; PO01: comissao so pelo administrador."""
    d = corpo()
    conta, valor = obrig(d, "id_conta", "vl_pago")
    with transacao() as c:
        n = q1(c, "SELECT coalesce(max(nr_pagamento), 0) + 1 AS n FROM pagamento WHERE id_conta_pagar = %s", (cpid,))["n"]
        c.execute("""INSERT INTO pagamento (id_conta_pagar, nr_pagamento, id_conta, id_usuario, dt_pagamento, vl_pago, id_forma_pagamento)
                     VALUES (%s, %s, %s, %s, coalesce(%s::date, CURRENT_DATE), %s, %s)""",
                  (cpid, n, conta, usuario_atual(), nulo(d.get("dt_pagamento")), valor, forma(c, d)))
    return jsonify(ok=True, nr_pagamento=n), 201


@app.post("/api/financeiro/despesas")
def despesa_nova():
    """Despesa: RN28 - quem arca com o custo (imobiliaria, proprietario ou inquilino). A categoria precisa ser de despesa (RN26, gatilho)."""
    d = corpo()
    ds, vl, venc, custeio = obrig(d, "ds_conta", "vl_pagar", "dt_vencimento", "tp_papel_custeio")
    with transacao() as c:
        r = q1(c, """INSERT INTO conta_pagar (id_contrato, id_categoria, id_favorecido, id_custeador, tp_papel_custeio, ds_conta, dt_competencia, vl_pagar, dt_vencimento)
                     VALUES (%s, coalesce(%s, (SELECT id_categoria FROM categoria_financeira WHERE cd_categoria = 'despesa_operacional')), %s, %s, %s, %s, CURRENT_DATE, %s, %s)
                     RETURNING id_conta_pagar""",
               (nulo(d.get("id_contrato")), nulo(d.get("id_categoria")), nulo(d.get("id_favorecido")), nulo(d.get("id_custeador")), custeio, ds, vl, venc))
    return jsonify(r), 201


@app.get("/api/conciliacao")
def conciliacao():
    with transacao(somente_leitura=True) as c:
        contas = q(c, """SELECT cb.*, (SELECT count(*) FROM vw_movimento_bancario m WHERE m.id_conta = cb.id_conta AND m.st_conciliacao <> 'conciliado') AS pendentes
                         FROM conta_bancaria cb ORDER BY id_conta""")
        conta = int(request.args.get("conta") or contas[0]["id_conta"])
        movs = q(c, "SELECT * FROM vw_movimento_bancario WHERE id_conta = %s ORDER BY dt_movimento DESC, nr_movimento DESC", (conta,))
        baixas = q(c, """
            SELECT 'recebimento' AS tipo, r.id_conta_receber AS id_conta_lancamento, r.nr_recebimento AS nr_baixa, r.dt_recebimento AS data, r.vl_recebido AS valor,
                   cr.ds_conta, u.nm_usuario AS pessoa, r.nr_movimento, r.dt_conciliacao
              FROM recebimento r JOIN conta_receber cr USING (id_conta_receber) JOIN usuario u ON u.id_usuario = cr.id_pagador WHERE r.id_conta = %(c)s
            UNION ALL
            SELECT 'pagamento', p.id_conta_pagar, p.nr_pagamento, p.dt_pagamento, p.vl_pago, cp.ds_conta, coalesce(f.nm_usuario, '—'), p.nr_movimento, p.dt_conciliacao
              FROM pagamento p JOIN conta_pagar cp USING (id_conta_pagar) LEFT JOIN usuario f ON f.id_usuario = cp.id_favorecido WHERE p.id_conta = %(c)s
             ORDER BY 4 DESC""", dict(c=conta))
        return jsonify(contas=contas, conta=conta, movimentos=movs, baixas=baixas)


@app.post("/api/conciliacao")
def conciliar():
    """CONCILIA/CONFERE. RN45: mesma conta (FK composta), direcao certa e soma ate o valor do extrato (gatilhos)."""
    d = corpo()
    tipo, idc, nr = obrig(d, "tipo", "id_conta_lancamento", "nr_baixa")
    mov = nulo(d.get("nr_movimento"))
    with transacao() as c:
        if tipo == "recebimento":
            c.execute("UPDATE recebimento SET nr_movimento = %s, dt_conciliacao = CASE WHEN %s::int IS NULL THEN NULL ELSE CURRENT_DATE END WHERE id_conta_receber = %s AND nr_recebimento = %s",
                      (mov, mov, idc, nr))
        else:
            c.execute("UPDATE pagamento SET nr_movimento = %s, dt_conciliacao = CASE WHEN %s::int IS NULL THEN NULL ELSE CURRENT_DATE END WHERE id_conta_pagar = %s AND nr_pagamento = %s",
                      (mov, mov, idc, nr))
    return jsonify(ok=True)


# --------------------------------------------------------------------------------------------
# automacao N8N — painel e API de integracao (endpoints do app original, adaptados ao banco)
# --------------------------------------------------------------------------------------------
@app.get("/api/automacao")
def automacao():
    with transacao(somente_leitura=True) as c:
        return jsonify(execucoes=execucoes(c), resumo=q(c, "SELECT st_execucao, count(*) AS qt FROM automacao_execucao GROUP BY 1 ORDER BY 2 DESC"))


def autorizado():
    return not TOKEN_INTEGRACAO or request.headers.get("X-Integration-Token") == TOKEN_INTEGRACAO


def demanda_da_conversa(c, cid):
    """A demanda que o app original extraia do texto agora vem do perfil de interesse e dos imoveis da conversa."""
    cv = q1(c, """SELECT cv.id_conversa, cv.id_cliente, u.nm_usuario AS nome,
                         (SELECT t.nr_telefone FROM telefone t WHERE t.id_usuario = u.id_usuario ORDER BY t.fl_principal DESC, t.nr_sequencia LIMIT 1) AS telefone
                    FROM conversa cv JOIN usuario u ON u.id_usuario = cv.id_cliente WHERE cv.id_conversa = %s""", (cid,))
    if not cv:
        abort(404)
    perfil = q1(c, SQL_PERFIL + " WHERE p.id_usuario = %s ORDER BY p.nr_perfil LIMIT 1", (cv["id_cliente"],))
    dem = None
    if perfil:
        dem = {k: perfil[k] for k in ("tp_finalidade", "id_cidade", "tipos", "nm_tipos", "bairros", "nm_bairros", "vl_minimo", "vl_maximo", "qt_quartos_min")}
    return cv, dem


@app.get("/api/integration/leads/pending")
def int_pendentes():
    """Conversas abertas com mensagem recebida depois da ultima execucao da automacao (ou sem execucao)."""
    if not autorizado():
        return jsonify(erro="token invalido"), 401
    rows = ler("""SELECT cv.id_conversa AS lead_id, u.nm_usuario AS nome, max(m.dt_mensagem) AS ultima_mensagem_recebida
                    FROM conversa cv JOIN usuario u ON u.id_usuario = cv.id_cliente JOIN mensagem m ON m.id_conversa = cv.id_conversa AND m.tp_direcao = 'entrada'
                   WHERE cv.st_conversa = 'aberta'
                   GROUP BY cv.id_conversa, u.nm_usuario
                  HAVING max(m.dt_mensagem) > coalesce((SELECT max(e.dt_execucao) FROM automacao_execucao e WHERE e.id_conversa = cv.id_conversa), '-infinity')
                   ORDER BY 3 DESC LIMIT 50""")
    return jsonify(leads=rows, count=len(rows))


@app.get("/api/integration/leads/<int:cid>")
def int_lead(cid):
    if not autorizado():
        return jsonify(erro="token invalido"), 401
    with transacao(somente_leitura=True) as c:
        cv, dem = demanda_da_conversa(c, cid)
        msgs = q(c, "SELECT nr_mensagem, tp_direcao, tp_canal, ds_corpo, dt_mensagem FROM mensagem WHERE id_conversa = %s ORDER BY dt_mensagem", (cid,))
    return jsonify(lead=cv, demanda=dem, mensagens=msgs)


@app.post("/api/integration/selector/search")
def int_seletor():
    if not autorizado():
        return jsonify(erro="token invalido"), 401
    d = corpo()
    with transacao(somente_leitura=True) as c:
        dem = d.get("demanda")
        if not dem and d.get("lead_id"):
            _, dem = demanda_da_conversa(c, int(d["lead_id"]))
        if not dem or not dem.get("tp_finalidade"):
            raise ErroApp("Informe a demanda (tp_finalidade obrigatorio) ou um lead_id com perfil de interesse")
        ops = selecionar(c, dem, int(d.get("max_results") or 5))
    return jsonify(filtros_usados=dem, count=len(ops), opcoes=ops)


@app.post("/api/integration/leads/<int:cid>/automation-result")
def int_resultado(cid):
    """Grava a execucao. RN31: a mesma demanda (cd_demanda) nao e processada duas vezes na conversa (UNIQUE)."""
    if not autorizado():
        return jsonify(erro="token invalido"), 401
    d = corpo()
    st = d.get("status") or "enviada"
    dem = d.get("demanda") or {}
    cd = d.get("demand_hash") or hashlib.sha1(json.dumps(dem, sort_keys=True, default=str).encode()).hexdigest()[:16]
    with transacao() as c:
        n = q1(c, "SELECT coalesce(max(nr_execucao), 0) + 1 AS n FROM automacao_execucao WHERE id_conversa = %s", (cid,))["n"]
        c.execute("""INSERT INTO automacao_execucao (id_conversa, nr_execucao, cd_demanda, st_execucao, ds_demanda, ds_criterios, ds_conteudo_enviado, ds_resumo, ds_erro, dt_envio)
                     VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, CASE WHEN %s = 'enviada' THEN CURRENT_TIMESTAMP END)""",
                  (cid, n, cd, st, json.dumps(dem, ensure_ascii=False, default=str), json.dumps(d.get("criterios"), ensure_ascii=False, default=str) if d.get("criterios") else None,
                   nulo(d.get("mensagem")), nulo(d.get("resumo")), nulo(d.get("erro")), st))
        for k, ev in enumerate(d.get("logs") or [dict(evento="resultado_registrado", descricao=f"Execucao registrada com situacao {st}")], 1):
            c.execute("INSERT INTO automacao_log (id_conversa, nr_execucao, nr_log, nm_evento, ds_evento, ds_dados) VALUES (%s, %s, %s, %s, %s, %s)",
                      (cid, n, k, ev.get("evento") or "evento", ev.get("descricao"), json.dumps(ev.get("dados"), ensure_ascii=False) if ev.get("dados") else None))
        if st == "enviada" and nulo(d.get("mensagem")):
            m = q1(c, "SELECT coalesce(max(nr_mensagem), 0) + 1 AS n FROM mensagem WHERE id_conversa = %s", (cid,))["n"]
            c.execute("INSERT INTO mensagem (id_conversa, nr_mensagem, cd_externo, tp_direcao, tp_canal, ds_corpo) VALUES (%s, %s, %s, 'saida', 'whatsapp', %s)",
                      (cid, m, "wamid.N8N" + cd.upper()[:12] + str(n), d["mensagem"]))
    return jsonify(ok=True, nr_execucao=n, cd_demanda=cd), 201


@app.post("/api/integration/leads/<int:cid>/automation-log")
def int_log(cid):
    if not autorizado():
        return jsonify(erro="token invalido"), 401
    d = corpo()
    with transacao() as c:
        ex = nulo(d.get("nr_execucao")) or q1(c, "SELECT max(nr_execucao) AS n FROM automacao_execucao WHERE id_conversa = %s", (cid,))["n"]
        if not ex:
            raise ErroApp("A conversa ainda nao tem execucao: registre o resultado primeiro (o log pertence a uma execucao)")
        n = q1(c, "SELECT coalesce(max(nr_log), 0) + 1 AS n FROM automacao_log WHERE id_conversa = %s AND nr_execucao = %s", (cid, ex))["n"]
        c.execute("INSERT INTO automacao_log (id_conversa, nr_execucao, nr_log, nm_evento, ds_evento, ds_dados) VALUES (%s, %s, %s, %s, %s, %s)",
                  (cid, ex, n, d.get("evento") or "evento", d.get("descricao"), json.dumps(d.get("dados"), ensure_ascii=False) if d.get("dados") else None))
    return jsonify(ok=True, nr_log=n), 201


@app.post("/api/integration/whatsapp/mensagem")
def int_whatsapp():
    """Webhook de mensagem recebida. RN31: o codigo da mensagem do WhatsApp (wamid) e unico — a repeticao e recusada pelo banco."""
    if not autorizado():
        return jsonify(erro="token invalido"), 401
    d = corpo()
    cid, wamid, texto = obrig(d, "lead_id", "wamid", "texto")
    with transacao() as c:
        n = q1(c, "SELECT coalesce(max(nr_mensagem), 0) + 1 AS n FROM mensagem WHERE id_conversa = %s", (cid,))["n"]
        c.execute("INSERT INTO mensagem (id_conversa, nr_mensagem, cd_externo, tp_direcao, tp_canal, ds_corpo) VALUES (%s, %s, %s, 'entrada', 'whatsapp', %s)", (cid, n, wamid, texto))
    return jsonify(ok=True, nr_mensagem=n), 201


# --------------------------------------------------------------------------------------------
# auditoria, consultas, modelo logico e console SQL
# --------------------------------------------------------------------------------------------
AUD_REGISTRO = """CASE WHEN a.id_contrato IS NOT NULL THEN 'contrato ' || a.id_contrato
                       WHEN a.id_proposta IS NOT NULL THEN 'proposta ' || a.id_proposta
                       WHEN a.id_comissao_contrato IS NOT NULL THEN 'comissao ' || a.id_comissao_contrato || '/' || a.id_comissao_corretor
                       WHEN a.id_conta_receber IS NOT NULL THEN 'conta a receber ' || a.id_conta_receber
                       WHEN a.id_recebimento_conta IS NOT NULL THEN 'recebimento ' || a.id_recebimento_conta || '/' || a.nr_recebimento
                       WHEN a.id_conta_pagar IS NOT NULL THEN 'conta a pagar ' || a.id_conta_pagar
                       ELSE 'pagamento ' || a.id_pagamento_conta || '/' || a.nr_pagamento END"""
AUD_TABELA = """CASE WHEN a.id_contrato IS NOT NULL THEN 'contrato' WHEN a.id_proposta IS NOT NULL THEN 'proposta'
                     WHEN a.id_comissao_contrato IS NOT NULL THEN 'comissao' WHEN a.id_conta_receber IS NOT NULL THEN 'conta_receber'
                     WHEN a.id_recebimento_conta IS NOT NULL THEN 'recebimento' WHEN a.id_conta_pagar IS NOT NULL THEN 'conta_pagar' ELSE 'pagamento' END"""


def auditoria_de(c, where, params, limite):
    rows = q(c, f"""SELECT a.id_auditoria, a.dt_acao, a.tp_acao, u.nm_usuario AS usuario, {AUD_TABELA} AS tabela, {AUD_REGISTRO} AS registro,
                           coalesce((SELECT json_agg(json_build_object('campo', f.nm_campo, 'antes', f.ds_valor_anterior, 'depois', f.ds_valor_novo) ORDER BY f.nm_campo)
                                       FROM auditoria_campo f WHERE f.id_auditoria = a.id_auditoria), '[]') AS campos
                      FROM auditoria a JOIN usuario u ON u.id_usuario = a.id_usuario
                     WHERE {where} ORDER BY a.id_auditoria DESC LIMIT {int(limite)}""", params)
    return rows


@app.get("/api/auditoria")
def auditoria():
    a = request.args
    with transacao(somente_leitura=True) as c:
        rows = auditoria_de(c, f"(%(t)s::text IS NULL OR {AUD_TABELA} = %(t)s::text) AND (%(u)s::int IS NULL OR a.id_usuario = %(u)s::int) "
                               "AND (%(ac)s::text IS NULL OR a.tp_acao = %(ac)s::text)",
                            dict(t=nulo(a.get("tabela")), u=nulo(a.get("usuario")), ac=nulo(a.get("acao"))), int(a.get("limite") or 150))
        usuarios = q(c, "SELECT DISTINCT u.id_usuario, u.nm_usuario FROM auditoria a JOIN usuario u USING (id_usuario) ORDER BY 2")
    return jsonify(registros=rows, usuarios=usuarios)


@app.get("/api/consultas")
def consultas_lista():
    return jsonify(gerenciais=CONSULTAS["gerenciais"], auditoria=CONSULTAS["auditoria"])


@app.get("/api/consultas/<cid>")
def consulta_rodar(cid):
    item = next((x for x in CONSULTAS["gerenciais"] + CONSULTAS["auditoria"] if x["id"] == cid.upper()), None)
    if not item:
        abort(404)
    return jsonify(dict(item, **executar_sql(item["sql"])))


def executar_sql(sql, limite=500):
    with transacao(somente_leitura=True) as c:
        c.execute("SET LOCAL statement_timeout = '5s'")
        cur = c.execute(sql)
        if cur.description is None:
            return dict(colunas=[], linhas=[], total=0)
        cols = [d.name for d in cur.description]
        linhas = cur.fetchmany(limite + 1)
        return dict(colunas=cols, linhas=[list(r.values()) for r in linhas[:limite]], total=len(linhas), cortado=len(linhas) > limite)


@app.post("/api/sql")
def sql_console():
    """Console somente leitura: a transacao e READ ONLY, entao INSERT/UPDATE/DELETE sao recusados pelo proprio PostgreSQL."""
    sql = (corpo().get("sql") or "").strip().rstrip(";")
    if not sql:
        raise ErroApp("Digite uma consulta")
    return jsonify(executar_sql(sql))


@app.get("/api/modelo")
def modelo():
    with transacao(somente_leitura=True) as c:
        cont = {r["t"]: r["n"] for r in q(c, """SELECT t.table_name AS t,
              (xpath('/row/c/text()', query_to_xml(format('SELECT count(*) AS c FROM %I', t.table_name), FALSE, TRUE, '')))[1]::text::int AS n
              FROM information_schema.tables t WHERE t.table_schema = 'public' AND t.table_type = 'BASE TABLE'""")}
        com = {r["t"]: r["d"] for r in q(c, """SELECT c.relname AS t, d.description AS d FROM pg_description d JOIN pg_class c ON c.oid = d.objoid
                                             WHERE c.relnamespace = 'public'::regnamespace AND d.objsubid = 0 AND c.relkind = 'r'""")}
        visoes = q(c, "SELECT viewname, definition FROM pg_views WHERE schemaname = 'public' ORDER BY 1")
    tabelas = [dict(nome=t, linhas=cont.get(t, 0), descricao=com.get(t, ""), **{k: META["tabelas"][t][k] for k in ("area", "cor", "entidade", "tipo", "folha", "pk")})
               for g in META["grupos"] for t in g["tabelas"]]
    return jsonify(grupos=META["grupos"], tabelas=tabelas, folhas=META["folhas"], visoes=visoes, alteracoes=META["alteracoes"])


@app.get("/api/modelo/<tabela>")
def modelo_tabela(tabela):
    if tabela not in META["tabelas"]:
        abort(404)
    m = META["tabelas"][tabela]
    with transacao(somente_leitura=True) as c:
        cols = q(c, """SELECT c.column_name AS nome, c.data_type AS tipo, c.character_maximum_length AS tamanho, c.numeric_precision AS precisao, c.numeric_scale AS escala,
                              c.is_nullable = 'YES' AS aceita_nulo, c.column_default AS padrao, c.is_identity = 'YES' AS identidade, col_description(%s::regclass, c.ordinal_position) AS descricao
                         FROM information_schema.columns c WHERE c.table_schema = 'public' AND c.table_name = %s ORDER BY c.ordinal_position""", (tabela, tabela))
        cons = q(c, """SELECT c.conname AS nome, c.contype AS tipo, pg_get_constraintdef(c.oid) AS definicao,
                              (SELECT array_agg(a.attname ORDER BY k.ord) FROM unnest(c.conkey) WITH ORDINALITY k(n, ord) JOIN pg_attribute a ON a.attrelid = c.conrelid AND a.attnum = k.n) AS colunas
                         FROM pg_constraint c WHERE c.conrelid = %s::regclass ORDER BY c.contype, c.conname""", (tabela,))
        idx = q(c, "SELECT indexname AS nome, indexdef AS definicao FROM pg_indexes WHERE schemaname = 'public' AND tablename = %s ORDER BY 1", (tabela,))
        trig = q(c, """SELECT t.tgname AS nome, p.proname AS funcao, pg_get_triggerdef(t.oid) AS definicao FROM pg_trigger t JOIN pg_proc p ON p.oid = t.tgfoid
                        WHERE t.tgrelid = %s::regclass AND NOT t.tgisinternal ORDER BY 1""", (tabela,))
        refs = q(c, """SELECT c.conname AS nome, cl.relname AS tabela, pg_get_constraintdef(c.oid) AS definicao FROM pg_constraint c JOIN pg_class cl ON cl.oid = c.conrelid
                        WHERE c.contype = 'f' AND c.confrelid = %s::regclass ORDER BY cl.relname""", (tabela,))
    fkcols = {x for f in m["fks"] for x in f["colunas"]}
    ukcols = {x for k in cons if k["tipo"] == "u" for x in (k["colunas"] or []) if len(k["colunas"]) == 1}
    for col in cols:
        col["pk"] = col["nome"] in m["pk"]
        col["fk"] = col["nome"] in fkcols
        col["uk"] = col["nome"] in ukcols
    for k in cons:
        k["por_que"] = META["restricoes"].get(k["nome"])
    for t in trig:
        t["por_que"] = META["gatilhos"].get(t["funcao"])
    for r in refs:
        r["por_que"] = META["restricoes"].get(r["nome"])
    return jsonify(tabela=tabela, meta=m, colunas=cols, restricoes=cons, indices=idx, gatilhos=trig, referenciada_por=refs)


def busca_imovel(a, busca):
    """Monta a procura de imoveis da aba Dados (RF37). Cada filtro vira uma linha do WHERE so quando e usado,
    e os nomes (tipo, bairro, cidade, proprietario) vem das tabelas ligadas pelas chaves estrangeiras (JOIN)."""
    frm = """SELECT t.nm_tipo_imovel AS "tipo_imovel.nm_tipo_imovel", b.nm_bairro AS "bairro.nm_bairro",
       ci.nm_cidade AS "cidade.nm_cidade", ci.sg_uf AS "cidade.sg_uf", pr.nm_usuario AS "proprietario.nm_usuario", i.*
  FROM imovel i
  JOIN tipo_imovel t ON t.id_tipo_imovel = i.id_tipo_imovel
  JOIN bairro b      ON b.id_bairro = i.id_bairro
  JOIN cep           ON cep.nr_cep = i.nr_cep
  JOIN cidade ci     ON ci.id_cidade = cep.id_cidade
  JOIN usuario pr    ON pr.id_usuario = i.id_proprietario"""
    w, p = [], {}
    def filtro(nome, cond, conv=int):
        v = nulo(a.get(nome))
        if v is not None:
            p[nome] = conv(v)
            w.append(cond)
    filtro("tipo", "i.id_tipo_imovel = %(tipo)s")
    fin = nulo(a.get("finalidade"))
    if fin in ("venda", "locacao"):
        p["finalidade"] = fin
        w.append("i.tp_finalidade IN (%(finalidade)s, 'ambas')")
    filtro("situacao", "i.st_imovel = %(situacao)s", str)
    filtro("cidade", "ci.id_cidade = %(cidade)s")
    filtro("bairro", "i.id_bairro = %(bairro)s")
    filtro("quartos", "i.qt_quartos >= %(quartos)s")
    coluna_valor = {"venda": "i.vl_venda", "locacao": "i.vl_aluguel"}.get(fin)
    filtro("valor_max", f"{coluna_valor} <= %(valor_max)s" if coluna_valor else "(i.vl_venda <= %(valor_max)s OR i.vl_aluguel <= %(valor_max)s)", decimal.Decimal)
    if busca:
        p["busca"] = f"%{busca}%"
        w.append("(i.cd_imobizi ILIKE %(busca)s OR i.nm_logradouro ILIKE %(busca)s OR b.nm_bairro ILIKE %(busca)s\n        OR pr.nm_usuario ILIKE %(busca)s OR t.nm_tipo_imovel ILIKE %(busca)s)")
    return frm, w, p, "i.id_imovel"


@app.get("/api/modelo/<tabela>/dados")
def modelo_dados(tabela):
    """Linhas da tabela na ordem da chave primaria. ?busca= procura o texto em todas as colunas (concat_ws junta as colunas
    num texto so); na tabela imovel da para procurar tambem por tipo, finalidade, situacao, cidade, bairro, quartos e valor.
    O SQL executado volta junto, com os valores ja colocados, para estudo."""
    if tabela not in META["tabelas"]:
        abort(404)
    a = request.args
    lim = min(int(a.get("limite") or 100), 500)
    busca = (a.get("busca") or "").strip()
    with transacao(somente_leitura=True) as c:
        c.execute("SET LOCAL statement_timeout = '5s'")
        cols = [r["n"] for r in q(c, """SELECT column_name AS n FROM information_schema.columns
                                         WHERE table_schema = 'public' AND table_name = %s ORDER BY ordinal_position""", (tabela,))]
        if tabela == "imovel":
            frm, w, p, ordem = busca_imovel(a, busca)
        else:
            vis = [x for x in cols if x != "ds_senha_hash"]   # o hash de senha nao e exibido nem pesquisado
            frm = f"SELECT {'*' if vis == cols else ', '.join(vis)}\n  FROM {tabela}"
            w, p = [], {}
            if busca:
                p["busca"] = f"%{busca}%"
                w.append(f"concat_ws(' ', {', '.join(vis)}) ILIKE %(busca)s")
            ordem = ", ".join(META["tabelas"][tabela]["pk"])
        where = ("\n WHERE " + "\n   AND ".join(w)) if w else ""
        sql = f"{frm}{where}\n ORDER BY {ordem}\n LIMIT {lim}"
        cur = c.execute(sql, p)
        colunas = [d.name for d in cur.description]
        linhas = [list(r.values()) for r in cur.fetchall()]
        total = q1(c, f"SELECT count(*) AS n FROM ({frm}{where}) x", p)["n"] if (w or len(linhas) == lim) else len(linhas)
        texto = psycopg.ClientCursor(c).mogrify(sql, p) if p else sql
    return jsonify(colunas=colunas, linhas=linhas, total=total, filtrado=bool(w), sql=texto)


if __name__ == "__main__":
    banco = re.sub(r"://([^:/@]+):[^@]+@", r"://\1:***@", DATABASE_URL)   # nao mostra a senha
    print(f"CRMoveis — prototipo em http://127.0.0.1:{PORTA}  (banco: {banco})")
    app.run(host="127.0.0.1", port=PORTA, debug=os.environ.get("CRM_DEBUG") == "1")

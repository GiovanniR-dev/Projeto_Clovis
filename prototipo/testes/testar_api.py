"""Testes automaticos do prototipo: todas as telas (leitura) e as gravacoes, inclusive as que o banco deve recusar.

As gravacoes mudam os dados, entao rode numa COPIA do banco:
    psql -U postgres -c "CREATE DATABASE crmoveis_teste_api TEMPLATE crmoveis"
    set DATABASE_URL=postgresql://postgres:SENHA@localhost:5432/crmoveis_teste_api      (Linux/macOS: export ...)
    python testes/testar_api.py
"""
import os, sys, json
from urllib.parse import urlparse
AQUI = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.dirname(AQUI))
url = os.environ.get("DATABASE_URL", "")
nome_banco = urlparse(url).path.lstrip("/") if url else ""
if not url or nome_banco == "crmoveis":
    sys.exit("Defina DATABASE_URL apontando para uma COPIA do banco (ex.: crmoveis_teste_api), nao para o banco crmoveis.")
import app as A
c = A.app.test_client()
res = []

# ---------------------------------------------------------------- leitura: toda tela responde
def get(u):
    r = c.get(u, headers={"X-Usuario": "1"})
    ok = r.status_code == 200
    res.append(ok)
    if not ok: print("FALHOU", r.status_code, u, r.get_data(as_text=True)[:300])
LEITURAS = ["/api/health", "/api/meta", "/api/painel", "/api/crm/board", "/api/crm/board?situacao=todas&busca=ana", "/api/crm/conversas/2", "/api/pessoas",
            "/api/pessoas?papel=corretor", "/api/pessoas/25", "/api/imoveis", "/api/imoveis?cidade=2&finalidade=locacao", "/api/imoveis?tipo=1&quartos=2",
            "/api/imoveis?busca=cobertura", "/api/imoveis?cidade=1&bairro=1", "/api/imoveis/101", "/api/seletor",
            "/api/seletor?usuario=24&perfil=2", "/api/visitas", "/api/propostas", "/api/contratos", "/api/contratos/3", "/api/financeiro/receber",
            "/api/financeiro/receber?situacao=atrasada", "/api/financeiro/pagar", "/api/financeiro/receber/10", "/api/financeiro/pagar/1", "/api/conciliacao",
            "/api/conciliacao?conta=2", "/api/automacao", "/api/integration/leads/pending", "/api/integration/leads/21", "/api/auditoria",
            "/api/auditoria?tabela=contrato", "/api/consultas", "/api/modelo"]
CAT = json.load(open(os.path.join(os.path.dirname(AQUI), "consultas.json"), encoding="utf-8"))
LEITURAS += [f"/api/consultas/{q['id']}" for q in CAT["gerenciais"] + CAT["auditoria"]]
for t in json.load(open(os.path.join(os.path.dirname(AQUI), "dados_modelo.json"), encoding="utf-8"))["tabelas"]:
    LEITURAS += [f"/api/modelo/{t}", f"/api/modelo/{t}/dados"]
LEITURAS += ["/api/modelo/imovel/dados?busca=tatuape", "/api/modelo/imovel/dados?tipo=1&finalidade=venda&situacao=disponivel&cidade=1&bairro=1&quartos=2&valor_max=900000",
             "/api/modelo/cidade/dados?busca=guarulhos", "/api/modelo/usuario/dados?busca=lima"]
for u in LEITURAS: get(u)
print(f"Leitura: {sum(res)} de {len(res)} enderecos responderam.")
n_leitura = len(res)

# ---------------------------------------------------------------- gravacoes e recusas do banco
def chamar(nome, metodo, url, body=None, como=1, esperado=(200, 201), contem=None):
    r = getattr(c, metodo)(url, json=body, headers={"X-Usuario": str(como)})
    j = r.get_json(silent=True) or {}
    ok = r.status_code in (esperado if isinstance(esperado, tuple) else (esperado,))
    if contem: ok = ok and contem in (j.get("erro", "") + " " + str(j.get("restricao")))
    res.append(ok)
    print(("OK " if ok else "FALHOU ") + f"[{r.status_code}] {nome}: " + (j.get("erro") or str({k: v for k, v in j.items() if k != 'ok'}))[:160])
    return j
j = chamar("nova conversa com contato novo", "post", "/api/crm/conversas", {"novo": {"nome": "Teste Prototipo", "telefone": "11955550000", "id_origem": 1}, "id_corretor": 5, "mensagem": "Ola"})
cv = j.get("id_conversa")
chamar("mover etapa", "post", f"/api/crm/conversas/{cv}/estagio", {"id_estagio": 2})
chamar("mensagem enviada", "post", f"/api/crm/conversas/{cv}/mensagens", {"tipo": "saida", "texto": "Oi!"})
chamar("nota", "post", f"/api/crm/conversas/{cv}/mensagens", {"tipo": "nota", "texto": "anotacao"})
chamar("etiqueta nova", "post", f"/api/crm/conversas/{cv}/tags", {"nm_tag": "teste prototipo"})
chamar("etiqueta repetida (PK)", "post", f"/api/crm/conversas/{cv}/tags", {"nm_tag": "teste prototipo"}, esperado=409, contem="pk_conversa_tag")
chamar("imovel de interesse", "post", f"/api/crm/conversas/{cv}/imoveis", {"id_imovel": 111})
chamar("tarefa", "post", f"/api/crm/conversas/{cv}/tarefas", {"ds_titulo": "Ligar", "dt_vencimento": "2026-10-25"})
chamar("corretor que saiu (RN32)", "patch", f"/api/crm/conversas/{cv}", {"id_corretor": 8}, esperado=409, contem="RN32")
chamar("detalhe da conversa", "get", f"/api/crm/conversas/{cv}")
chamar("pessoa corretor sem CRECI", "post", "/api/pessoas", {"nome": "Sem Creci", "papel": "corretor"}, esperado=400)
j = chamar("pessoa cliente", "post", "/api/pessoas", {"nome": "Cliente Novo", "papel": "cliente", "telefone": "11900000061"})
pid = j.get("id_usuario")
chamar("vira proprietario tambem", "post", f"/api/pessoas/{pid}/papeis", {"papel": "proprietario"})
chamar("perfil com faixa invertida (CHECK)", "post", f"/api/pessoas/{pid}/perfis", {"tp_finalidade": "venda", "vl_minimo": 500000, "vl_maximo": 100000}, esperado=409, contem="ck_perfil_interesse")
chamar("perfil com dois tipos (N:N DESEJA)", "post", f"/api/pessoas/{pid}/perfis", {"tp_finalidade": "venda", "vl_minimo": 300000, "vl_maximo": 700000, "id_cidade": 1, "tipos": [1, 4]})
chamar("perfil com tipo inexistente (FK)", "post", f"/api/pessoas/{pid}/perfis", {"tp_finalidade": "venda", "tipos": [99]}, esperado=409, contem="fk_perfil_interesse_tipo")
chamar("perfil com dois bairros de Sao Paulo (N:N ABRANGE)", "post", f"/api/pessoas/{pid}/perfis", {"tp_finalidade": "locacao", "id_cidade": 1, "bairros": [1, 2], "vl_maximo": 3500})
chamar("perfil de Sao Paulo com bairro de Guarulhos (gatilho, RN52)", "post", f"/api/pessoas/{pid}/perfis", {"tp_finalidade": "locacao", "id_cidade": 1, "bairros": [1, 7]}, esperado=409, contem="RN52")
chamar("perfil sem cidade com bairro (RN52)", "post", f"/api/pessoas/{pid}/perfis", {"tp_finalidade": "venda", "bairros": [1]}, esperado=409, contem="RN52")
chamar("perfil com bairro que nao existe (FK)", "post", f"/api/pessoas/{pid}/perfis", {"tp_finalidade": "venda", "id_cidade": 1, "bairros": [999]}, esperado=409, contem="fk_perfil_interesse_bairro")
pf = c.get(f"/api/pessoas/{pid}").get_json()["perfis"]
res.append(len(pf) == 2 and pf[0]["nm_tipos"] == "Apartamento, Cobertura" and pf[1]["nm_bairros"] == "Mooca, Tatuape" and pf[1]["bairros"] == [1, 2])
print(("OK " if res[-1] else "FALHOU ") + "perfis gravados: tipos " + str(pf and pf[0]["nm_tipos"]) + " | bairros " + str(len(pf) > 1 and pf[1]["nm_bairros"]))
sel = c.get(f"/api/seletor?usuario={pid}&perfil=2").get_json()["imoveis"]
res.append(bool(sel) and sel[0]["nm_bairro"] in ("Tatuape", "Mooca"))
print(("OK " if res[-1] else "FALHOU ") + "seletor pontua os bairros aceitos pela chave: " + str([(x["cd_imobizi"], x["nm_bairro"], x["pontos"]) for x in sel[:3]]))
j = chamar("telefone de outra pessoa vira compartilhado (RN03)", "post", f"/api/pessoas/{pid}/telefones", {"telefone": "(11) 3000-0061"})
res.append(j.get("compartilhado") is True)
chamar("mesmo numero de novo na mesma pessoa (UNIQUE)", "post", f"/api/pessoas/{pid}/telefones", {"telefone": "1130000061"}, esperado=409, contem="uk_telefone_id_usuario_nr_telefone")
chamar("telefone curto demais (CHECK)", "post", f"/api/pessoas/{pid}/telefones", {"telefone": "12345"}, esperado=409, contem="ck_telefone_nr_telefone")
# imoveis: buscar e cadastrar
NOVO = {"id_proprietario": 15, "id_corretor_responsavel": 5, "id_tipo_imovel": 4, "tp_finalidade": "venda", "nr_cep": "07061-000", "nm_logradouro": "Avenida Emilio Ribas",
        "nr_endereco": "880", "ds_complemento": "Cobertura 2", "id_bairro": 8, "vl_area_util": 140, "vl_area_total": 160, "qt_quartos": 3, "qt_banheiros": 3,
        "qt_vagas_garagem": 2, "vl_venda": 980000, "cd_imobizi": "IMB-9001", "caracteristicas": [1, 4, 5]}
chamar("imovel com tipo que nao existe (FK, RN48)", "post", "/api/imoveis", {**NOVO, "id_tipo_imovel": 99, "cd_imobizi": None}, esperado=409, contem="fk_imovel_tipifica")
chamar("imovel de quem nao e proprietario (RN32)", "post", "/api/imoveis", {**NOVO, "id_proprietario": 24, "cd_imobizi": None}, esperado=409, contem="RN32")
chamar("imovel a venda sem valor de venda (CHECK)", "post", "/api/imoveis", {**NOVO, "vl_venda": None, "cd_imobizi": None}, esperado=409, contem="ck_imovel_tp_finalidade_vl_venda")
chamar("imovel com bairro de outra cidade: Tatuape (SP) com CEP de Guarulhos (gatilho, RN51)", "post", "/api/imoveis", {**NOVO, "id_bairro": 1, "cd_imobizi": None}, esperado=409, contem="RN51")
chamar("imovel com bairro que nao existe (FK SITUA)", "post", "/api/imoveis", {**NOVO, "id_bairro": 999, "cd_imobizi": None}, esperado=409, contem="fk_imovel_situa")
chamar("imovel sem bairro", "post", "/api/imoveis", {**NOVO, "id_bairro": "", "cd_imobizi": None}, esperado=400)
chamar("imovel em CEP novo de Sao Paulo com bairro de Guarulhos (RN51)", "post", "/api/imoveis", {**NOVO, "nr_cep": "07091000", "id_cidade": 1, "cd_imobizi": None}, esperado=409, contem="RN51")
j = chamar("cadastrar imovel novo (cobertura)", "post", "/api/imoveis", NOVO)
novo_im = j.get("id_imovel")
chamar("cadastrar outro com o mesmo codigo Imobzi (UNIQUE)", "post", "/api/imoveis", NOVO, esperado=409, contem="uk_imovel_cd_imobizi")
chamar("cadastrar imovel em CEP novo, com a cidade", "post", "/api/imoveis", {**NOVO, "nr_cep": "07090-000", "id_cidade": 2, "id_bairro": 9, "cd_imobizi": None, "id_tipo_imovel": 1, "tp_finalidade": "locacao", "vl_venda": None, "vl_aluguel": 2100})
j = chamar("imovel em CEP novo sem cidade: a cidade do CEP vem do bairro", "post", "/api/imoveis", {**NOVO, "nr_cep": "07092-000", "id_bairro": 10, "cd_imobizi": None})
res.append(c.get(f"/api/imoveis/{j.get('id_imovel')}").get_json()["imovel"]["nm_cidade"] == "Guarulhos")
print(("OK " if res[-1] else "FALHOU ") + "CEP novo gravado na cidade do bairro (Bosque Maia, Guarulhos)")
achou = c.get("/api/imoveis?busca=IMB-9001&tipo=4").get_json()["imoveis"]
res.append(len(achou) == 1 and achou[0]["id_imovel"] == novo_im and achou[0]["nm_tipo_imovel"] == "Cobertura")
print(("OK " if res[-1] else "FALHOU ") + f"busca encontra o imovel novo pelo codigo e pelo tipo: {[(x['cd_imobizi'], x['nm_tipo_imovel']) for x in achou]}")
det = c.get(f"/api/imoveis/{novo_im}").get_json()
res.append(len(det["caracteristicas"]) == 3 and det["imovel"]["nm_cidade"] == "Guarulhos" and det["imovel"]["nm_bairro"] == "Vila Galvao" and det["imovel"]["nm_uf"] == "Sao Paulo")
print(("OK " if res[-1] else "FALHOU ") + f"imovel novo com 3 caracteristicas, bairro pela FK e cidade e UF pelo CEP: {det['imovel']['nm_bairro']}, {det['imovel']['nm_cidade']}, {det['imovel']['nm_uf']}")
# modelo logico, aba Dados: procurar na tabela
def dados(u):
    r = c.get(u); return r.status_code, r.get_json()
s, d = dados("/api/modelo/imovel/dados?busca=IMB-9001")
res.append(s == 200 and d["total"] == 1 and d["linhas"][0][d["colunas"].index("cd_imobizi")] == "IMB-9001" and "ILIKE '%IMB-9001%'" in d["sql"])
print(("OK " if res[-1] else "FALHOU ") + f"aba Dados: procurar o imovel pelo codigo -> {d['total']} linha(s)")
s, d = dados("/api/modelo/imovel/dados?bairro=1")
nb = d["colunas"].index("bairro.nm_bairro")
res.append(s == 200 and d["total"] >= 1 and all(l[nb] == "Tatuape" for l in d["linhas"]) and "i.id_bairro = 1" in d["sql"])
print(("OK " if res[-1] else "FALHOU ") + f"aba Dados: imoveis do bairro Tatuape pela chave id_bairro -> {d['total']} linha(s)")
s, d = dados("/api/modelo/imovel/dados?finalidade=locacao&cidade=2&valor_max=2000")
ci, fi, va = d["colunas"].index("cidade.nm_cidade"), d["colunas"].index("tp_finalidade"), d["colunas"].index("vl_aluguel")
res.append(s == 200 and d["total"] >= 1 and all(l[ci] == "Guarulhos" and l[fi] in ("locacao", "ambas") and float(l[va]) <= 2000 for l in d["linhas"]))
print(("OK " if res[-1] else "FALHOU ") + f"aba Dados: locacao em Guarulhos ate R$ 2.000 -> {d['total']} linha(s)")
s, d = dados("/api/modelo/imovel/dados?busca=%27%20OR%201%3D1%20--")
res.append(s == 200 and d["total"] == 0)
print(("OK " if res[-1] else "FALHOU ") + "aba Dados: texto com aspas e procurado como texto, nao vira SQL (parametro)")
s, d = dados("/api/modelo/usuario/dados?busca=lima")
res.append(s == 200 and "ds_senha_hash" not in d["colunas"] and d["total"] >= 1)
print(("OK " if res[-1] else "FALHOU ") + f"aba Dados: procurar em usuario sem mostrar o hash da senha -> {d['total']} linha(s)")
s, d = dados("/api/modelo/bairro/dados?busca=centro")
res.append(s == 200 and d["total"] == 2)
print(("OK " if res[-1] else "FALHOU ") + f"aba Dados: Centro existe em duas cidades (Guarulhos e Aruja) -> {d['total']} linha(s)")
chamar("trocar o tipo do imovel", "patch", f"/api/imoveis/{novo_im}", {"id_tipo_imovel": 1})
chamar("excluir papel proprietario (sobra cliente)", "delete", f"/api/pessoas/{pid}/papeis/proprietario")
chamar("excluir o unico papel (RN01)", "delete", f"/api/pessoas/{pid}/papeis/cliente", esperado=409, contem="RN01")
chamar("visita com corretor que saiu (RN32)", "post", "/api/visitas", {"id_imovel": 111, "id_cliente": pid, "id_corretor": 8, "dt_visita": "2026-10-22T10:00"}, esperado=409, contem="RN32")
chamar("visita ok", "post", "/api/visitas", {"id_imovel": 111, "id_cliente": pid, "id_corretor": 5, "dt_visita": "2026-10-22T10:00"})
im = [i for i in c.get("/api/meta").get_json()["imoveis"] if i["st_imovel"] == "disponivel" and i["tp_finalidade"] == "venda"][0]
chamar("proposta com 20% de desconto sem autorizacao (PO03)", "post", "/api/propostas", {"id_imovel": im["id_imovel"], "id_cliente": pid, "id_corretor": 5, "vl_proposto": float(im["vl_venda"]) * 0.8}, esperado=409, contem="ck_proposta_id_autorizador")
chamar("autorizacao por corretor (RN32)", "post", "/api/propostas", {"id_imovel": im["id_imovel"], "id_cliente": pid, "id_corretor": 5, "vl_proposto": float(im["vl_venda"]) * 0.8, "autorizar": True}, como=5, esperado=409, contem="RN32")
j = chamar("autorizacao pelo administrador", "post", "/api/propostas", {"id_imovel": im["id_imovel"], "id_cliente": pid, "id_corretor": 5, "vl_proposto": float(im["vl_venda"]) * 0.8, "autorizar": True})
prop = j.get("id_proposta")
j = chamar("contraproposta", "post", "/api/propostas", {"id_imovel": im["id_imovel"], "id_cliente": pid, "id_corretor": 5, "vl_proposto": float(im["vl_venda"]) * 0.95, "id_proposta_respondida": prop})
prop2 = j.get("id_proposta")
j = chamar("gerar contrato", "post", f"/api/propostas/{prop2}/contrato", {"tp_condicao_pagamento": "a_vista", "pc_corretagem": 6})
ct = j.get("id_contrato")
chamar("segundo contrato da mesma proposta (UNIQUE)", "post", f"/api/propostas/{prop2}/contrato", {}, esperado=409, contem="uk_contrato_id_proposta")
chamar("assinar", "post", f"/api/contratos/{ct}/assinar", {"dt_assinatura": "2026-10-20"})
chamar("comissao 60%", "post", f"/api/contratos/{ct}/comissoes", {"id_corretor": 5, "pc_comissao": 60})
chamar("comissao +50% (RN20)", "post", f"/api/contratos/{ct}/comissoes", {"id_corretor": 6, "pc_comissao": 50}, esperado=409, contem="RN20")
chamar("liberar comissao como corretor (RN32: aprovador admin)", "post", f"/api/contratos/{ct}/comissoes/5/liberar", como=5, esperado=409, contem="RN32")
j = chamar("liberar comissao como administrador", "post", f"/api/contratos/{ct}/comissoes/5/liberar")
cp = j.get("id_conta_pagar")
chamar("pagar comissao como financeiro (PO01)", "post", f"/api/financeiro/pagar/{cp}/baixa", {"id_conta": 1, "vl_pago": 100}, como=3, esperado=409, contem="PO01")
chamar("pagar comissao como corretor (RN39/PO01)", "post", f"/api/financeiro/pagar/{cp}/baixa", {"id_conta": 1, "vl_pago": 100}, como=5, esperado=409)
chamar("pagar comissao como administrador", "post", f"/api/financeiro/pagar/{cp}/baixa", {"id_conta": 1, "vl_pago": 100})
chamar("detalhe conta pagar", "get", f"/api/financeiro/pagar/{cp}")
cr = c.get(f"/api/contratos/{ct}").get_json()["receber"][0]
chamar("recebimento acima do valor (RN29)", "post", f"/api/financeiro/receber/{cr['id_conta_receber']}/baixa", {"id_conta": 1, "vl_recebido": float(cr["vl_receber"]) + 1}, esperado=409, contem="RN29")
chamar("recebimento com forma que nao existe (FK, RN50)", "post", f"/api/financeiro/receber/{cr['id_conta_receber']}/baixa", {"id_conta": 1, "vl_recebido": 100, "id_forma_pagamento": 99}, esperado=409, contem="fk_recebimento_recebido_via")
chamar("recebimento parcial por TED", "post", f"/api/financeiro/receber/{cr['id_conta_receber']}/baixa", {"id_conta": 1, "vl_recebido": 1000, "id_forma_pagamento": 2})
chamar("encerrar venda com conta aberta (RN44)", "post", f"/api/contratos/{ct}/encerrar", {"data": "2026-10-21"}, esperado=409, contem="RN44")
# aluguel → repasse
alug = [x for x in c.get("/api/financeiro/receber?situacao=atrasada").get_json()["contas"] if x["nm_categoria"] == "Aluguel"][0]
j = chamar("recebimento de aluguel gera repasse (RN30)", "post", f"/api/financeiro/receber/{alug['id_conta_receber']}/baixa", {"id_conta": 2, "vl_recebido": 500})
print("   repasse:", j.get("repasse"))
# conciliacao errada: recebimento com movimento de debito
conc = c.get("/api/conciliacao?conta=1").get_json()
deb = [m for m in conc["movimentos"] if m["tp_movimento"] == "debito"][0]
rec = [b for b in conc["baixas"] if b["tipo"] == "recebimento" and not b["nr_movimento"]][0]
chamar("conciliar recebimento com debito (RN45)", "post", "/api/conciliacao", {**rec, "nr_movimento": deb["nr_movimento"]}, esperado=409, contem="RN45")
cred = [m for m in conc["movimentos"] if m["tp_movimento"] == "credito" and m["st_conciliacao"] == "pendente"]
if cred:
    chamar("conciliar com credito maior que o valor? (RN45 soma)", "post", "/api/conciliacao", {**rec, "nr_movimento": cred[0]["nr_movimento"]}, esperado=(200, 409))
# locacao: rescindir / encerrar antes do fim
chamar("encerrar locacao antes do termino (RN44)", "post", "/api/contratos/2/encerrar", {"data": "2026-10-21"}, esperado=409, contem="RN44")
chamar("cancelar contrato rascunho 9", "post", "/api/contratos/9/cancelar", {"data": "2026-10-20", "motivo": "Cliente desistiu"})
chamar("cancelar de novo (RN37)", "post", "/api/contratos/9/cancelar", {"data": "2026-10-20", "motivo": "x"}, esperado=409, contem="RN37")
chamar("rescindir locacao 3 com multa", "post", "/api/contratos/3/rescindir", {"data": "2026-10-20", "motivo": "Mudanca", "iniciativa": "cliente", "vl_multa": 3000, "vencimento_multa": "2026-11-05"})
chamar("aluguel em contrato rescindido", "post", "/api/contratos/3/aluguel", {"competencia": "2026-11"}, esperado=400)
chamar("lancar aluguel locacao 2", "post", "/api/contratos/2/aluguel", {"competencia": "2026-11"})
chamar("despesa custeada pelo inquilino sem pessoa (RN28)", "post", "/api/financeiro/despesas", {"ds_conta": "Vistoria", "vl_pagar": 200, "dt_vencimento": "2026-11-01", "tp_papel_custeio": "inquilino"}, esperado=409)
chamar("despesa custeada pelo proprietario errado (RN32)", "post", "/api/financeiro/despesas", {"ds_conta": "Reparo", "vl_pagar": 200, "dt_vencimento": "2026-11-01", "tp_papel_custeio": "inquilino", "id_custeador": 16}, esperado=409, contem="RN32")
chamar("despesa ok", "post", "/api/financeiro/despesas", {"ds_conta": "Material", "vl_pagar": 200, "dt_vencimento": "2026-11-01", "tp_papel_custeio": "imobiliaria", "id_favorecido": 9})
chamar("despesa numa categoria de receita (RN26)", "post", "/api/financeiro/despesas", {"ds_conta": "Errada", "vl_pagar": 50, "dt_vencimento": "2026-11-01", "tp_papel_custeio": "imobiliaria", "id_categoria": 3}, esperado=409, contem="RN26")
# N8N
j = chamar("n8n resultado", "post", f"/api/integration/leads/{cv}/automation-result", {"status": "enviada", "demanda": {"x": 1}, "mensagem": "Separei opcoes"})
chamar("n8n mesma demanda (RN31)", "post", f"/api/integration/leads/{cv}/automation-result", {"status": "enviada", "demanda": {"x": 1}}, esperado=409, contem="uk_automacao")
chamar("n8n log", "post", f"/api/integration/leads/{cv}/automation-log", {"evento": "teste", "descricao": "ok"})
chamar("whatsapp msg", "post", "/api/integration/whatsapp/mensagem", {"lead_id": cv, "wamid": "wamid.XYZ1", "texto": "oi"})
chamar("whatsapp mesmo wamid (RN31)", "post", "/api/integration/whatsapp/mensagem", {"lead_id": cv, "wamid": "wamid.XYZ1", "texto": "oi"}, esperado=409, contem="uk_mensagem")
chamar("seletor por lead", "post", "/api/integration/selector/search", {"lead_id": 21})
chamar("anonimizar", "post", f"/api/pessoas/{pid}/anonimizar")
res.append(c.get(f"/api/pessoas/{pid}").get_json()["telefones"] == [])
print(("OK " if res[-1] else "FALHOU ") + "anonimizado sem telefones (dado pessoal, PO07)")
chamar("anonimizar a titular de um numero compartilhado (Camila)", "post", "/api/pessoas/25/anonimizar")
tel26 = [t for t in c.get("/api/pessoas/26").get_json()["telefones"] if t["nr_telefone"] == "1130000061"]
res.append(len(tel26) == 1 and tel26[0]["fl_titular"])
print(("OK " if res[-1] else "FALHOU ") + "a titularidade do fixo do casal passou para o Diego (RN03)")
chamar("imovel a venda sem valor (CHECK)", "patch", f"/api/imoveis/{im['id_imovel']}", {"vl_venda": ""}, esperado=409, contem="ck_imovel")
chamar("auditoria do contrato", "get", f"/api/contratos/{ct}")
docs = c.get("/api/contratos/1").get_json()["documentos"]
res.append(bool(docs) and all(x.get("nm_tipo_documento") for x in docs))
print(("OK " if res[-1] else "FALHOU ") + "documentos do contrato com o nome do tipo (tipo_documento): " + ", ".join(x["nm_tipo_documento"] for x in docs))
m = c.get("/api/meta").get_json()
res.append(len(m["bairros"]) >= 15 and len(m["ufs"]) == 27 and len(m["tipos_documento"]) == 6)
print(("OK " if res[-1] else "FALHOU ") + f"listas do cadastro: {len(m['bairros'])} bairros, {len(m['ufs'])} UFs, {len(m['tipos_documento'])} tipos de documento")
print(f"Gravacao: {sum(res[n_leitura:])} de {len(res) - n_leitura} cenarios como esperado.")
print(f"TOTAL: {sum(res)} de {len(res)}")
sys.exit(0 if all(res) else 1)

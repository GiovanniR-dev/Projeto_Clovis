/* CRMoveis — prototipo. Mesma organizacao do app.js do SP Imoveis CRM (estado, $/$$, toast, setView,
   funil em colunas e painel de detalhes), agora lendo e gravando no banco do modelo logico. */
"use strict";

const S = {
  meta: null,
  usuario: Number(localStorage.getItem("crmoveis.usuario") || 1),
  view: "painel",
  drawer: null,
  modelo: { tabela: null, aba: "colunas", lista: [], filtro: {} },
  conciliacao: { conta: null, movimento: null },
  consultasCache: null,
};

const $ = (s, el = document) => el.querySelector(s);
const $$ = (s, el = document) => Array.from(el.querySelectorAll(s));

function esc(v) {
  return String(v ?? "").replaceAll("&", "&amp;").replaceAll("<", "&lt;").replaceAll(">", "&gt;").replaceAll('"', "&quot;").replaceAll("'", "&#039;");
}
const ROTULOS = {
  disponivel: "disponivel", locacao: "locacao", comissao: "comissao", imobiliaria: "imobiliaria", proprietario: "proprietario",
  instituicao_financeira: "instituicao financeira", a_vista: "a vista", parcelado_direto: "parcelado direto", em_analise: "em analise",
  substituida: "substituida", concluida: "concluida", criacao: "criacao", alteracao: "alteracao", liberacao_credito: "liberacao do credito",
  comum_acordo: "comum acordo", multa_rescisoria: "multa rescisoria", intermediacao: "intermediacao", administracao: "administracao",
  servico: "servico", nota_interna: "nota interna", indicacao: "indicacao", credito: "credito", debito: "debito", poupanca: "poupanca",
  saida: "enviada", entrada: "recebida", ambas: "venda e locacao", conciliado: "conciliado",
};
const rotulo = (v) => (v == null ? "—" : ROTULOS[v] || String(v).replaceAll("_", " "));
const ST_CLASSE = {
  aberta: "info", encerrada: "off", vigente: "ok", rascunho: "warn", encerrado: "off", rescindido: "bad", cancelado: "bad",
  quitada: "ok", paga: "ok", atrasada: "bad", prevista: "info", parcial: "warn", cancelada: "off", pendente: "warn",
  conciliado: "ok", liberada: "ok", aceita: "ok", recusada: "bad", substituida: "off", agendada: "info", realizada: "ok",
  disponivel: "ok", reservado: "warn", alugado: "violet", vendido: "violet", inativo: "off", enviada: "ok", recebida: "info",
  processada: "warn", erro: "bad", concluida: "ok", em_analise: "warn", aprovado: "info", reprovado: "bad", liberado: "ok",
  criacao: "info", alteracao: "warn", cancelamento: "bad",
};
const st = (v) => `<span class="st ${ST_CLASSE[v] || ""}">${esc(rotulo(v))}</span>`;
const brl = (v) => (v == null ? "—" : Number(v).toLocaleString("pt-BR", { style: "currency", currency: "BRL" }));
const num = (v) => (v == null ? "—" : Number(v).toLocaleString("pt-BR"));
function paraData(v) {
  if (!v) return null;
  const s = String(v);
  return new Date(s.length === 10 ? s + "T00:00:00" : s.replace(" ", "T"));
}
const dataBR = (v) => (v ? paraData(v).toLocaleDateString("pt-BR") : "—");
const dataHoraBR = (v) => (v ? paraData(v).toLocaleString("pt-BR", { dateStyle: "short", timeStyle: "short" }) : "—");
const hoje = () => { const d = new Date(); d.setMinutes(d.getMinutes() - d.getTimezoneOffset()); return d.toISOString().slice(0, 10); };   // data local, nao UTC
const nomeUsuario = (id) => (S.meta?.internos.find((u) => u.id_usuario === id) || {}).nm_usuario || `usuario ${id}`;
const debounce = (fn, ms = 300) => { let t; return (...a) => { clearTimeout(t); t = setTimeout(() => fn(...a), ms); }; };

// ---------------------------------------------------------------------------------------------
// comunicacao com o servidor e mensagens
// ---------------------------------------------------------------------------------------------
async function api(url, opcoes = {}) {
  const r = await fetch(url, {
    method: opcoes.method || "GET",
    headers: { "Content-Type": "application/json", "X-Usuario": String(S.usuario) },
    body: opcoes.body ? JSON.stringify(opcoes.body) : undefined,
  });
  const dados = await r.json().catch(() => ({ erro: `${r.status} ${r.statusText}` }));
  if (!r.ok) {
    const e = new Error(dados.erro || "Erro");
    e.dados = dados;
    throw e;
  }
  return dados;
}
const post = (url, body) => api(url, { method: "POST", body });
const patch = (url, body) => api(url, { method: "PATCH", body });
const del = (url) => api(url, { method: "DELETE" });

function erroHTML(e) {
  const d = e.dados || {};
  if (d.origem === "banco") {
    return `<b>O banco recusou a gravacao${d.regra ? " · " + esc(d.regra) : ""}</b>${esc(d.erro)}` +
      (d.restricao ? `<br><span class="mono">${esc(d.restricao)}</span>` : "") + (d.explicacao ? `<br>${esc(d.explicacao)}` : "");
  }
  return `<b>Nao foi possivel concluir</b>${esc(e.message)}`;
}
function erroTexto(e) {
  const d = e.dados || {};
  if (d.origem === "banco") return `O banco recusou${d.regra ? " (" + d.regra + ")" : ""}:\n${d.erro}${d.explicacao ? "\n" + d.explicacao : ""}`;
  return e.message;
}
let toastTimer;
function toast(msg, tipo = "") {
  const n = $("#toast");
  n.textContent = msg;
  n.className = "show " + tipo;
  clearTimeout(toastTimer);
  toastTimer = setTimeout(() => (n.className = ""), tipo === "erro" ? 7000 : 3200);
}
async function acao(fn, ok) {
  try {
    const r = await fn();
    if (ok) toast(typeof ok === "function" ? ok(r) : ok, "ok");
    return r;
  } catch (e) {
    toast(erroTexto(e), "erro");
    console.warn(e.dados || e);
  }
}

// ---------------------------------------------------------------------------------------------
// componentes: tabela, formulario (modal), painel de detalhes
// ---------------------------------------------------------------------------------------------
function montarTabela(el, colunas, linhas, aoClicar, vazio = "Nenhum registro.") {
  if (!linhas.length) { el.innerHTML = `<div class="vazio">${esc(vazio)}</div>`; return; }
  el.innerHTML = `<table class="data"><thead><tr>${colunas.map((c) => `<th class="${c.cls || ""}">${esc(c.t)}</th>`).join("")}</tr></thead>
    <tbody>${linhas.map((l, i) => `<tr data-i="${i}" class="${aoClicar ? "clicavel" : ""}">${colunas.map((c) => `<td class="${c.cls || ""}">${c.v(l)}</td>`).join("")}</tr>`).join("")}</tbody></table>`;
  if (aoClicar) $$("tbody tr", el).forEach((tr) => tr.addEventListener("click", (ev) => { if (!ev.target.closest("button,a,select,textarea,input[type=text]")) aoClicar(linhas[tr.dataset.i]); }));
}
function tabelaSimples(colunas, linhas) {   // colunas e linhas cruas (consultas e console)
  if (!linhas.length) return `<div class="vazio">Nenhuma linha.</div>`;
  const fmt = (v) => (v === null ? '<span class="muted">null</span>' : typeof v === "object" ? esc(JSON.stringify(v)) : esc(v));
  const tit = (v) => (typeof v === "string" && v.length > 40 ? ` title="${esc(v)}"` : "");
  return `<table class="data"><thead><tr>${colunas.map((c) => `<th>${esc(c)}</th>`).join("")}</tr></thead><tbody>${linhas.map((l) => `<tr>${l.map((v) => `<td${tit(v)}>${fmt(v)}</td>`).join("")}</tr>`).join("")}</tbody></table>`;
}

function formulario({ titulo, ajuda = "", campos, enviarTexto = "Salvar", enviar, aoAbrir }) {
  $("#modal-titulo").textContent = titulo;
  $("#modal-ajuda").innerHTML = ajuda;
  $("#modal-erro").hidden = true;
  $("#modal-enviar").textContent = enviarTexto;
  $("#modal-campos").innerHTML = campos.map((c) => {
    const id = `f-${c.n}`;
    const v = c.v ?? "";
    let input;
    if (c.t === "select") input = `<select id="${id}" name="${c.n}">${(c.op || []).map(([val, lab]) => `<option value="${esc(val)}" ${String(val) === String(v) ? "selected" : ""}>${esc(lab)}</option>`).join("")}</select>`;
    else if (c.t === "textarea") input = `<textarea id="${id}" name="${c.n}" rows="3">${esc(v)}</textarea>`;
    else if (c.t === "checkbox") return `<label class="check-field ${c.full ? "full" : ""}"><input type="checkbox" id="${id}" name="${c.n}" ${v ? "checked" : ""}><span>${esc(c.r)}</span></label>`;
    else if (c.t === "checks") return `<div class="field full"><span>${esc(c.r)}</span><div class="checks" id="${id}">${(c.op || []).map(([val, lab]) => `<label class="check-chip"><input type="checkbox" value="${esc(val)}" ${(c.v || []).map(String).includes(String(val)) ? "checked" : ""}> ${esc(lab)}</label>`).join("")}</div>${c.dica ? `<small class="muted">${esc(c.dica)}</small>` : ""}</div>`;
    else input = `<input id="${id}" name="${c.n}" type="${c.t || "text"}" value="${esc(v)}" ${c.step ? `step="${c.step}"` : ""} ${c.ph ? `placeholder="${esc(c.ph)}"` : ""}>`;
    return `<label class="field ${c.full ? "full" : ""}"><span>${esc(c.r)}${c.obrig ? " *" : ""}</span>${input}${c.dica ? `<small class="muted">${esc(c.dica)}</small>` : ""}</label>`;
  }).join("");
  $("#modal").hidden = false;
  if (aoAbrir) aoAbrir();
  const form = $("#modal-form");
  form.onsubmit = async (ev) => {
    ev.preventDefault();
    const dados = {};
    campos.forEach((c) => {
      const el = $(`#f-${c.n}`);
      dados[c.n] = c.t === "checkbox" ? el.checked : c.t === "checks" ? $$("input:checked", el).map((x) => x.value) : el.value.trim();
    });
    $("#modal-enviar").disabled = true;
    try {
      const r = await enviar(dados);
      fecharModal();
      return r;
    } catch (e) {
      $("#modal-erro").innerHTML = erroHTML(e);
      $("#modal-erro").hidden = false;
    } finally {
      $("#modal-enviar").disabled = false;
    }
  };
  setTimeout(() => $("#modal-campos input, #modal-campos select, #modal-campos textarea")?.focus(), 30);
}
function fecharModal() { $("#modal").hidden = true; }

function abrirDrawer(titulo, subtitulo, html) {
  $("#drawer-titulo").textContent = titulo;
  $("#drawer-subtitulo").innerHTML = subtitulo || "";
  $("#drawer-corpo").innerHTML = html;
  $("#shell").classList.remove("drawer-collapsed");
}
function fecharDrawer() { $("#shell").classList.add("drawer-collapsed"); S.drawer = null; }
async function recarregarDrawer() {
  if (!S.drawer) return;
  const { tipo, id } = S.drawer;
  const f = { conversa: abrirConversa, pessoa: abrirPessoa, imovel: abrirImovel, contrato: abrirContrato, receber: abrirContaReceber, pagar: abrirContaPagar }[tipo];
  if (f) await f(id);
}
async function depois() { await recarregarDrawer(); await recarregarView(); }

const secao = (titulo, corpo, extra = "", nota = "") =>
  `<div class="secao"><div class="secao-head"><h3>${esc(titulo)} ${nota ? `<small>${esc(nota)}</small>` : ""}</h3>${extra}</div>${corpo}</div>`;
const kv = (pares) => `<dl class="kv">${pares.filter(Boolean).map(([k, v]) => `<dt>${esc(k)}</dt><dd>${v ?? "—"}</dd>`).join("")}</dl>`;
const lista = (itens, vazio = "Nada registrado.") => (itens.length ? `<div class="lista">${itens.join("")}</div>` : `<div class="vazio">${esc(vazio)}</div>`);
const item = (esq, dir = "", attrs = "") => `<div class="lista-item ${attrs.includes("data-abrir") ? "clicavel" : ""}" ${attrs}><span>${esq}</span><span>${dir}</span></div>`;
const btn = (txt, attrs = "", cls = "secondary-button small") => `<button type="button" class="${cls}" ${attrs}>${esc(txt)}</button>`;
const regra = (txt) => `<div class="regra">${txt}</div>`;
// bairros (tabela bairro, RN51/RN52): cada bairro e de uma cidade; o formulario so mostra os da cidade escolhida
const bairrosDa = (cid) => S.meta.bairros.filter((b) => !cid || String(b.id_cidade) === String(cid));
const cidadeDoCep = (cep) => (S.meta.ceps.find((c) => c.nr_cep === String(cep || "").replace(/\D/g, "")) || {}).id_cidade;
const opcoesBairro = (cid, todos = "") => (todos ? `<option value="">${esc(todos)}</option>` : "") +
  bairrosDa(cid).map((b) => `<option value="${b.id_bairro}">${esc(b.nm_bairro)}${cid ? "" : ` (${esc(b.nm_cidade)})`}</option>`).join("");
const regiaoPerfil = (p) => [p.nm_cidade, p.nm_bairros].filter(Boolean).join(": ") || "qualquer regiao";
const linkModelo = (t) => `<button type="button" class="fk-link" data-modelo="${t}">${t}</button>`;
function ligarDrawer() {
  const corpo = $("#drawer-corpo");
  $$("[data-abrir]", corpo).forEach((el) => el.addEventListener("click", (ev) => {
    ev.stopPropagation();
    const [tipo, id] = el.dataset.abrir.split(":");
    ({ conversa: abrirConversa, pessoa: abrirPessoa, imovel: abrirImovel, contrato: abrirContrato, receber: abrirContaReceber, pagar: abrirContaPagar })[tipo](Number(id));
  }));
  $$("[data-modelo]", corpo).forEach((el) => el.addEventListener("click", () => irModelo(el.dataset.modelo)));
}
function irModelo(tabela) { fecharDrawer(); S.modelo.tabela = tabela; setView("modelo"); }

// ---------------------------------------------------------------------------------------------
// navegacao
// ---------------------------------------------------------------------------------------------
const VIEWS = {
  painel: ["Painel", "Indicadores do dia, funil e alertas das consultas de auditoria.", carregarPainel],
  crm: ["CRM — funil de atendimento", "As colunas sao as etapas de funil_estagio; cada card e uma conversa (WhatsApp).", carregarCRM],
  pessoas: ["Pessoas e papeis", "Uma pessoa (usuario) e os seus papeis: os 8 subtipos da especializacao.", carregarPessoas],
  imoveis: ["Imoveis — buscar e cadastrar", "Busque os imoveis cadastrados por tipo, cidade, finalidade, situacao e texto, ou cadastre um imovel novo (o tipo vem da tabela tipo_imovel).", carregarImoveis],
  seletor: ["Imoveis — seletor por perfil", "Imoveis disponiveis pontuados pelo perfil de interesse do cliente.", carregarSeletor],
  visitas: ["Negociacao — visitas", "Visitas agendadas e realizadas (associativa entre cliente e imovel).", carregarVisitas],
  propostas: ["Negociacao — propostas", "Propostas, contrapropostas e autorizacoes de desconto.", carregarPropostas],
  contratos: ["Negociacao — contratos e comissoes", "Contratos de venda e locacao, do rascunho ao termino.", carregarContratos],
  receber: ["Financeiro — contas a receber", "Alugueis, corretagens e multas; cada baixa e um recebimento.", carregarReceber],
  pagar: ["Financeiro — contas a pagar", "Comissoes, repasses, despesas e impostos; cada baixa e um pagamento.", carregarPagar],
  conciliacao: ["Financeiro — conciliacao bancaria", "Confere as baixas com o extrato do banco (CONCILIA e CONFERE, RN45).", carregarConciliacao],
  automacao: ["Automacao N8N", "As execucoes do fluxo do N8N e a API de integracao herdada do app original.", carregarAutomacao],
  auditoria: ["Auditoria", "Quem fez o que e quando, campo por campo (auditoria e auditoria_campo).", carregarAuditoria],
  gerenciais: ["Consultas gerenciais", "Pergunta do negocio → SQL → informacao para decisao (Etapas 18 e 20).", () => carregarConsultas("gerenciais")],
  verificacoes: ["Consultas de auditoria", "Situacoes que merecem verificacao (Etapa 19).", () => carregarConsultas("auditoria")],
  modelo: ["Modelo logico — tabelas", "Lido ao vivo do catalogo do PostgreSQL, com as justificativas da documentacao.", carregarModelo],
  diagramas: ["Modelo logico — diagramas e evolucao", "As cinco folhas do modelo logico e o que mudou desde o app original.", carregarDiagramas],
  sql: ["Modelo logico — console SQL", "Consultas livres, somente leitura, no banco do prototipo.", carregarSQL],
};
const ACOES = {
  crm: [["Nova conversa", novaConversa]],
  pessoas: [["Nova pessoa", novaPessoa]],
  imoveis: [["Novo imovel", novoImovel]],
  visitas: [["Agendar visita", () => novaVisita({})]],
  propostas: [["Nova proposta", () => novaProposta({})]],
  pagar: [["Nova despesa", novaDespesa]],
};
function setView(v) {
  S.view = v;
  const grupoAtivo = $(`.subnav-button[data-view="${v}"]`)?.closest(".subnav")?.dataset.subnav;
  $$(".nav-button").forEach((b) => b.classList.toggle("active", b.dataset.grupo ? b.dataset.grupo === grupoAtivo : b.dataset.view === v));
  $$(".subnav").forEach((s) => s.classList.toggle("open", s.dataset.subnav === grupoAtivo));
  $$(".subnav-button").forEach((b) => b.classList.toggle("active", b.dataset.view === v));
  $$(".view").forEach((s) => s.classList.toggle("active", s.id === `view-${v}`));
  const [t, sub] = VIEWS[v];
  $("#view-title").textContent = t;
  $("#view-subtitle").textContent = sub;
  $("#view-actions").innerHTML = "";
  (ACOES[v] || []).forEach(([txt, fn]) => {
    const b = document.createElement("button");
    b.className = "primary-button";
    b.textContent = txt;
    b.onclick = fn;
    $("#view-actions").appendChild(b);
  });
  history.replaceState(null, "", "#" + v);
  recarregarView();
}
async function recarregarView() {
  try { await VIEWS[S.view][2](); } catch (e) { toast(erroTexto(e), "erro"); console.error(e); }
}

// ---------------------------------------------------------------------------------------------
// painel
// ---------------------------------------------------------------------------------------------
async function carregarPainel() {
  const d = await api("/api/painel");
  const k = d.kpis;
  const maxF = Math.max(1, ...d.funil.map((f) => f.qt));
  const maxR = Math.max(1, ...d.receita.map((r) => r.valor));
  $("#view-painel").innerHTML = `
    <div class="kpis">
      <div class="kpi"><span>Conversas abertas</span><strong>${num(k.conversas_abertas)}</strong><em>${num(k.conversas_30d)} novas em 30 dias</em></div>
      <div class="kpi"><span>Contratos vigentes</span><strong>${num(k.contratos_vigentes)}</strong><em>${num(k.contratos_rascunho)} em rascunho</em></div>
      <div class="kpi"><span>Recebido no mes</span><strong>${brl(k.recebido_mes)}</strong><em>soma dos recebimentos</em></div>
      <div class="kpi ${k.contas_atrasadas ? "alerta" : ""}"><span>Em atraso</span><strong>${brl(k.em_atraso)}</strong><em>${num(k.contas_atrasadas)} contas a receber</em></div>
      <div class="kpi ${k.repasses_atrasados ? "alerta" : ""}"><span>Repasses em aberto</span><strong>${num(k.repasses_abertos)}</strong><em>${num(k.repasses_atrasados)} atrasado(s) · PO05</em></div>
      <div class="kpi"><span>Extrato a conciliar</span><strong>${num(k.movimentos_pendentes)}</strong><em>movimentos pendentes ou parciais</em></div>
      <div class="kpi"><span>Imoveis disponiveis</span><strong>${num(k.imoveis_disponiveis)}</strong><em>no catalogo</em></div>
    </div>
    <div class="three-cols">
      <section class="panel"><div class="panel-head"><h2>Conversas por etapa</h2><button class="link-button small" data-ir="crm">Abrir CRM</button></div>
        <div class="bars">${d.funil.map((f) => `<div class="bar-row"><span>${esc(f.nm_estagio)}</span><div class="bar"><div style="width:${(100 * f.qt) / maxF}%;background:${esc(f.ds_cor || "")}"></div></div><b>${f.qt}</b></div>`).join("")}</div></section>
      <section class="panel"><div class="panel-head"><h2>Recebimentos — ultimos 6 meses</h2><button class="link-button small" data-ir="gerenciais">G04</button></div>
        <div class="colunas-v">${d.receita.map((r) => `<div title="${brl(r.valor)}"><span>${r.valor ? (r.valor / 1000).toLocaleString("pt-BR", { maximumFractionDigits: 1 }) + " mil" : "0"}</span><i style="height:${Math.max(2, (100 * r.valor) / maxR)}%"></i><span>${esc(r.mes.slice(0, 2))}/${esc(r.mes.slice(5))}</span></div>`).join("")}</div></section>
      <section class="panel"><div class="panel-head"><h2>Agenda</h2><span class="muted">visitas agendadas e tarefas pendentes</span></div>
        ${d.agenda.length ? d.agenda.map((a) => `<div class="agenda-item"><small>${a.tipo === "visita" ? dataHoraBR(a.quando) : dataBR(a.quando)}</small><span>${a.tipo === "visita" ? "🏠 Visita" : "☑ Tarefa"} · ${esc(a.detalhe)} · ${esc(a.pessoa)}<br><small>${esc(a.responsavel)}</small></span></div>`).join("") : '<div class="vazio">Nada agendado.</div>'}</section>
    </div>
    <section class="panel" style="margin-top:14px"><div class="panel-head"><h2>Consultas de auditoria</h2><span class="muted">quantas situacoes cada uma encontrou agora (clique para ver)</span></div>
      <div class="alertas">${d.alertas.map((a) => `<div class="alerta-item ${a.qt ? "tem" : ""}" data-consulta="${a.id}"><span><b class="mono" style="background:none;color:inherit;padding:0">${a.id}</b> ${esc(a.titulo)}</span><b>${a.qt}</b></div>`).join("")}</div></section>`;
  $$("[data-ir]", $("#view-painel")).forEach((b) => (b.onclick = () => setView(b.dataset.ir)));
  $$("[data-consulta]", $("#view-painel")).forEach((b) => (b.onclick = async () => { setView("verificacoes"); setTimeout(() => abrirConsulta(b.dataset.consulta), 150); }));
}

// ---------------------------------------------------------------------------------------------
// CRM
// ---------------------------------------------------------------------------------------------
async function carregarCRM() {
  const p = new URLSearchParams({ busca: $("#crm-busca").value, corretor: $("#crm-corretor").value, tag: $("#crm-tag").value, situacao: $("#crm-situacao").value });
  const d = await api("/api/crm/board?" + p);
  const board = $("#crm-board");
  board.innerHTML = d.estagios.map((e) => {
    const cards = d.cards.filter((c) => c.id_estagio === e.id_estagio);
    return `<section class="kanban-column" data-estagio="${e.id_estagio}">
      <div class="column-head" style="border-top-color:${esc(e.ds_cor || "#0f766e")}"><div><strong>${esc(e.nm_estagio)}</strong><span class="column-count">${cards.length} conversa(s)</span></div></div>
      <div class="card-list">${cards.map(cardConversa).join("") || '<div class="empty-list">Arraste conversas para ca</div>'}</div></section>`;
  }).join("");
  $$(".contact-card", board).forEach((c) => {
    c.addEventListener("click", () => abrirConversa(Number(c.dataset.id)));
    c.addEventListener("dragstart", (ev) => { ev.dataTransfer.setData("text/plain", c.dataset.id); c.classList.add("dragging"); });
    c.addEventListener("dragend", () => c.classList.remove("dragging"));
  });
  $$(".kanban-column", board).forEach((col) => {
    col.addEventListener("dragover", (ev) => { ev.preventDefault(); col.classList.add("drag-target"); });
    col.addEventListener("dragleave", () => col.classList.remove("drag-target"));
    col.addEventListener("drop", async (ev) => {
      ev.preventDefault();
      col.classList.remove("drag-target");
      const id = ev.dataTransfer.getData("text/plain");
      await acao(() => post(`/api/crm/conversas/${id}/estagio`, { id_estagio: Number(col.dataset.estagio) }), "Etapa alterada: conversa e historico gravados juntos (RN14).");
      await depois();
    });
  });
}
function cardConversa(c) {
  const parada = c.st_conversa === "aberta" && c.dias_sem_contato > 7;
  return `<article class="contact-card ${!c.id_corretor ? "sem-corretor" : parada ? "parada" : ""}" draggable="true" data-id="${c.id_conversa}">
    <h3>${esc(c.cliente)}</h3>
    <p>${esc((c.ultima_mensagem || "").slice(0, 90))}${(c.ultima_mensagem || "").length > 90 ? "…" : ""}</p>
    <div class="linha"><span>${c.corretor ? esc(c.corretor) : "<b>sem corretor</b>"}</span><span title="dias desde a ultima mensagem">${c.dias_sem_contato} d</span></div>
    ${c.imoveis ? `<div class="linha"><span>🏠 ${esc(c.imoveis)}</span></div>` : ""}
    ${c.tags.length ? `<div class="tags">${c.tags.map((t) => `<span class="tag">${esc(t)}</span>`).join("")}</div>` : ""}
  </article>`;
}
async function abrirConversa(id) {
  S.drawer = { tipo: "conversa", id };
  const d = await api(`/api/crm/conversas/${id}`);
  const c = d.conversa;
  const m = S.meta;
  const opEst = m.estagios.map((e) => `<option value="${e.id_estagio}" ${e.id_estagio === c.id_estagio ? "selected" : ""}>${esc(e.nm_estagio)}</option>`).join("");
  const opCor = `<option value="">— sem corretor —</option>` + m.corretores.map((u) => `<option value="${u.id_usuario}" ${u.id_usuario === c.id_corretor ? "selected" : ""}>${esc(u.nm_usuario)}${u.dt_fim ? " (saiu)" : ""}</option>`).join("");
  const msgs = d.mensagens.map((x) => {
    const cls = x.tp_canal === "nota_interna" ? "note" : x.tp_direcao === "saida" ? "out" : "in";
    const quem = x.tp_canal === "nota_interna" ? "Nota interna" : x.tp_direcao === "saida" ? "Enviada" : "Recebida";
    return `<div class="message-item ${cls}"><div class="message-head"><strong>${quem}</strong><small>${dataHoraBR(x.dt_mensagem)} · no ${x.nr_mensagem}</small></div>${esc(x.ds_corpo)}${x.cd_externo ? `<small class="mono">${esc(x.cd_externo)}</small>` : ""}</div>`;
  }).join("");
  const html =
    secao("Atendimento", kv([
      ["Cliente", `<button class="fk-link" data-abrir="pessoa:${c.id_cliente}">${esc(c.cliente)}</button>${c.dt_anonimizacao ? " " + st("anonimizado") : ""}`],
      ["Papeis", d.papeis.map((p) => `<span class="papel ${p.dt_fim ? "encerrado" : ""}">${esc(rotulo(p.papel))}</span>`).join("")],
      ["Telefones", d.telefones.map((t) => `${esc(t.nr_telefone)} <small class="muted">${esc(t.tipo)}${t.fl_titular ? " · titular" : ""}${t.compartilhado_com ? " · tambem de " + esc(t.compartilhado_com) : ""}</small>`).join("<br>") || "—"],
      ["Origem", esc(c.nm_origem || "—")],
      ["Corretor", `<select id="cv-corretor">${opCor}</select>`],
      ["Etapa", `<select id="cv-etapa">${opEst}</select>`],
      ["Situacao", st(c.st_conversa)],
      ["Inicio", dataHoraBR(c.dt_inicio)],
      ["Ultima mensagem", `${dataHoraBR(c.dt_atualizacao)} <small class="muted">(derivado: vw_conversa)</small>`],
    ]) + `<div class="inline-form"><textarea id="cv-notas" placeholder="Observacoes da conversa">${esc(c.ds_notas || "")}</textarea></div>
      <div class="button-row" style="margin-top:6px">${btn("Salvar observacoes", 'id="cv-salvar-notas"')}${btn("Ver tabela conversa no modelo", 'data-modelo="conversa"', "ghost-button small")}</div>`) +
    secao("Etiquetas", `<div class="chips">${d.tags.map((t) => `<span class="chip">${esc(t.nm_tag)} <button title="remover" data-rmtag="${t.id_tag}">×</button></span>`).join("") || '<span class="muted">nenhuma</span>'}</div>
      <div class="inline-form"><input id="cv-tag" list="lista-tags" placeholder="Etiqueta (escolha ou digite uma nova)"><datalist id="lista-tags">${m.tags.map((t) => `<option value="${esc(t.nm_tag)}">`).join("")}</datalist>${btn("Adicionar", 'id="cv-add-tag"')}</div>`, "", "conversa_tag (N:N MARCA)") +
    secao("Imoveis de interesse", lista(d.imoveis.map((i) => item(`<b>${esc(i.cd_imobizi)}</b> ${esc(i.nm_tipo_imovel)} · ${esc(i.nm_bairro)} <small>desde ${dataBR(i.dt_interesse)}</small>`, `${st(i.st_imovel)} <button class="ghost-button small" data-rmimovel="${i.id_imovel}">remover</button>`, `data-abrir="imovel:${i.id_imovel}"`)), "Nenhum imovel.") +
      `<div class="inline-form"><select id="cv-imovel">${m.imoveis.map((i) => `<option value="${i.id_imovel}">${esc(i.cd_imobizi || "imovel " + i.id_imovel)} · ${esc(i.nm_tipo_imovel)} · ${esc(i.nm_bairro)}</option>`).join("")}</select>${btn("Adicionar", 'id="cv-add-imovel"')}</div>`, "", "conversa_imovel — era o texto property_codes no app original") +
    secao("Mensagens", `<div class="message-list">${msgs || '<div class="vazio">Sem mensagens.</div>'}</div>
      <div class="inline-form"><textarea id="cv-msg" placeholder="Mensagem ou nota"></textarea></div>
      <div class="button-row" style="margin-top:6px">${btn("Nota", 'data-msg="nota"')}${btn("Recebida", 'data-msg="entrada"')}${btn("Enviada", 'data-msg="saida"')}</div>`, "", "mensagem (fraca de conversa)") +
    secao("Historico de etapas", `<ul class="timeline">${d.historico.map((h) => `<li style="--dot:${esc(h.ds_cor || "#0f766e")}"><b>${esc(h.nm_estagio)}</b> <small>${dataHoraBR(h.dt_alteracao)}${h.quem ? " · " + esc(h.quem) : ""}</small></li>`).join("")}</ul>`, "", "historico_estagio (MOVE)") +
    secao("Tarefas", lista(d.tarefas.map((t) => item(`${esc(t.ds_titulo)} <small>vence ${dataBR(t.dt_vencimento)} · ${esc(t.corretor)}</small>`, `${t.vencida ? st("atrasada") : st(t.st_tarefa)} ${t.st_tarefa === "pendente" ? `<button class="ghost-button small" data-tarefa="${t.id_tarefa}">concluir</button>` : ""}`)), "Nenhuma tarefa.") +
      `<div class="inline-form"><input id="cv-tarefa" placeholder="Nova tarefa"><input id="cv-tarefa-data" type="date" value="${hoje()}" style="flex:0 0 150px">${btn("Criar", 'id="cv-add-tarefa"')}</div>`) +
    secao("Visitas e propostas do cliente", lista([
      ...d.visitas.map((v) => item(`Visita ${esc(v.cd_imobizi)} <small>${dataHoraBR(v.dt_visita)}</small>`, st(v.st_visita))),
      ...d.propostas.map((p) => item(`Proposta ${esc(p.cd_imobizi)} · ${brl(p.vl_proposto)} <small>anunciado ${brl(p.vl_anunciado)}</small>`, `${st(p.st_proposta)}${p.id_contrato ? ` <button class="fk-link" data-abrir="contrato:${p.id_contrato}">contrato ${p.id_contrato}</button>` : ""}`)),
    ], "Nenhuma visita ou proposta."), `<span>${btn("Agendar visita", 'id="cv-visita"')} ${btn("Proposta", 'id="cv-proposta"')}</span>`) +
    secao("Perfis de interesse", lista(d.perfis.map((p) => item(`Perfil ${p.nr_perfil}: ${esc(rotulo(p.tp_finalidade))} · ${esc(p.nm_tipos || "qualquer tipo")} · ${esc(regiaoPerfil(p))} <small>${brl(p.vl_minimo)} a ${brl(p.vl_maximo)}</small>`, `<button class="ghost-button small" data-seletor="${c.id_cliente}:${p.nr_perfil}">imoveis compativeis</button>`)), "Sem perfil cadastrado.")) +
    secao("Automacao N8N", d.execucoes.length ? d.execucoes.map(execucaoHTML).join("") : '<div class="vazio">Nenhuma execucao.</div>', "", "automacao_execucao e automacao_log") +
    (d.outras_conversas.length ? secao("Outras conversas do cliente", lista(d.outras_conversas.map((o) => item(`Conversa ${o.id_conversa} <small>${dataBR(o.dt_inicio)}</small>`, `${esc(o.nm_estagio)} ${st(o.st_conversa)}`, `data-abrir="conversa:${o.id_conversa}"`)))) : "");
  abrirDrawer(c.cliente, `Conversa ${c.id_conversa} · ${esc(c.nm_estagio)}`, html);
  ligarDrawer();
  const corpo = $("#drawer-corpo");
  $("#cv-corretor").onchange = async (ev) => { await acao(() => patch(`/api/crm/conversas/${id}`, { id_corretor: ev.target.value }), "Corretor alterado."); await depois(); };
  $("#cv-etapa").onchange = async (ev) => { await acao(() => post(`/api/crm/conversas/${id}/estagio`, { id_estagio: Number(ev.target.value) }), "Etapa alterada e historico gravado."); await depois(); };
  $("#cv-salvar-notas").onclick = async () => { await acao(() => patch(`/api/crm/conversas/${id}`, { ds_notas: $("#cv-notas").value }), "Observacoes salvas."); await depois(); };
  $("#cv-add-tag").onclick = async () => { await acao(() => post(`/api/crm/conversas/${id}/tags`, { nm_tag: $("#cv-tag").value }), "Etiqueta adicionada."); await carregarMeta(); await depois(); };
  $$("[data-rmtag]", corpo).forEach((b) => (b.onclick = async () => { await acao(() => del(`/api/crm/conversas/${id}/tags/${b.dataset.rmtag}`), "Etiqueta removida."); await depois(); }));
  $("#cv-add-imovel").onclick = async () => { await acao(() => post(`/api/crm/conversas/${id}/imoveis`, { id_imovel: $("#cv-imovel").value }), "Imovel adicionado ao interesse."); await depois(); };
  $$("[data-rmimovel]", corpo).forEach((b) => (b.onclick = async (ev) => { ev.stopPropagation(); await acao(() => del(`/api/crm/conversas/${id}/imoveis/${b.dataset.rmimovel}`), "Imovel removido."); await depois(); }));
  $$("[data-msg]", corpo).forEach((b) => (b.onclick = async () => { await acao(() => post(`/api/crm/conversas/${id}/mensagens`, { tipo: b.dataset.msg, texto: $("#cv-msg").value }), "Mensagem gravada."); await depois(); }));
  $$("[data-tarefa]", corpo).forEach((b) => (b.onclick = async () => { await acao(() => patch(`/api/tarefas/${b.dataset.tarefa}`, { st_tarefa: "concluida" }), "Tarefa concluida."); await depois(); }));
  $("#cv-add-tarefa").onclick = async () => { await acao(() => post(`/api/crm/conversas/${id}/tarefas`, { ds_titulo: $("#cv-tarefa").value, dt_vencimento: $("#cv-tarefa-data").value }), "Tarefa criada."); await depois(); };
  $("#cv-visita").onclick = () => novaVisita({ id_cliente: c.id_cliente, id_corretor: c.id_corretor, id_imovel: d.imoveis[0]?.id_imovel });
  $("#cv-proposta").onclick = () => novaProposta({ id_cliente: c.id_cliente, id_corretor: c.id_corretor, id_imovel: d.imoveis[0]?.id_imovel });
  $$("[data-seletor]", corpo).forEach((b) => (b.onclick = () => { fecharDrawer(); S.seletorEscolha = b.dataset.seletor; setView("seletor"); }));
}
function execucaoHTML(e) {
  return `<div class="lista-item" style="display:block"><div style="display:flex;justify-content:space-between"><span><b>Execucao ${e.nr_execucao}</b> · ${esc(e.cliente || "")} <small>${dataHoraBR(e.dt_execucao)} · demanda <span class="mono">${esc(e.cd_demanda)}</span></small></span>${st(e.st_execucao)}</div>
    ${e.ds_resumo ? `<div class="muted">${esc(e.ds_resumo)}</div>` : ""}${e.ds_erro ? `<div class="erro-banco" style="margin:4px 0">${esc(e.ds_erro)}</div>` : ""}
    ${e.ds_conteudo_enviado ? `<div style="margin-top:4px">${esc(e.ds_conteudo_enviado)}</div>` : ""}
    <ul class="timeline" style="margin-top:6px">${e.logs.map((l) => `<li><span class="mono">${esc(l.nm_evento)}</span> <small>${dataHoraBR(l.dt_log)} · ${esc(l.ds_evento || "")}</small></li>`).join("")}</ul></div>`;
}
function novaConversa() {
  const m = S.meta;
  formulario({
    titulo: "Nova conversa",
    ajuda: "Escolha um cliente ja cadastrado ou preencha os dados de um contato novo. O contato novo vira <b>usuario + cliente + telefone</b> na mesma transacao (RN01: todo usuario tem pelo menos um papel).",
    campos: [
      { n: "id_cliente", r: "Cliente cadastrado", t: "select", op: [["", "— contato novo —"], ...m.clientes.map((u) => [u.id_usuario, u.nm_usuario])], full: true },
      { n: "nome", r: "Nome do contato novo" }, { n: "telefone", r: "Telefone / WhatsApp", ph: "11999990000" },
      { n: "origem", r: "Origem", t: "select", op: ["whatsapp", "site", "portal", "instagram", "indicacao"].map((o) => [o, rotulo(o)]) },
      { n: "id_corretor", r: "Corretor", t: "select", op: [["", "— sem corretor —"], ...m.corretores.filter((u) => !u.dt_fim).map((u) => [u.id_usuario, u.nm_usuario])] },
      { n: "id_estagio", r: "Etapa", t: "select", op: m.estagios.map((e) => [e.id_estagio, e.nm_estagio]) },
      { n: "mensagem", r: "Primeira mensagem recebida", t: "textarea", full: true },
    ],
    enviarTexto: "Criar conversa",
    enviar: async (f) => {
      const r = await post("/api/crm/conversas", { id_cliente: f.id_cliente, novo: { nome: f.nome, telefone: f.telefone, id_origem: f.id_origem }, id_corretor: f.id_corretor, id_estagio: f.id_estagio, mensagem: f.mensagem });
      toast("Conversa criada.", "ok");
      await carregarMeta();
      await recarregarView();
      abrirConversa(r.id_conversa);
    },
  });
}

// ---------------------------------------------------------------------------------------------
// pessoas
// ---------------------------------------------------------------------------------------------
const papelBadge = (p) => `<span class="papel ${p.ativo === false || p.dt_fim ? "encerrado" : ""}">${esc(rotulo(p.papel))}</span>`;
async function carregarPessoas() {
  const d = await api("/api/pessoas?" + new URLSearchParams({ busca: $("#pessoas-busca").value, papel: $("#pessoas-papel").value }));
  montarTabela($("#pessoas-tabela"), [
    { t: "Pessoa", v: (p) => `<b>${esc(p.nm_usuario)}</b>${p.dt_anonimizacao ? " " + st("anonimizado") : ""}` },
    { t: "Papeis (subtipos)", v: (p) => p.papeis.map(papelBadge).join("") },
    { t: "Telefone", v: (p) => esc(p.telefone || "—") }, { t: "E-mail", v: (p) => esc(p.ds_email || "—") },
    { t: "CPF/CNPJ", v: (p) => esc(p.nr_cpf_cnpj || "—") }, { t: "Origem", v: (p) => esc(p.nm_origem || "—") },
  ], d.pessoas, (p) => abrirPessoa(p.id_usuario));
}
async function abrirPessoa(id) {
  S.drawer = { tipo: "pessoa", id };
  const d = await api(`/api/pessoas/${id}`);
  const u = d.usuario;
  const ativos = d.papeis.filter((p) => !p.dt_fim).map((p) => p.papel);
  const html =
    secao("Cadastro", kv([["Nome", esc(u.nm_usuario)], ["CPF/CNPJ", esc(u.nr_cpf_cnpj || "—")], ["E-mail", esc(u.ds_email || "—")], ["Origem", esc(u.nm_origem || "—")],
      ["Cadastro", dataHoraBR(u.dt_cadastro)], ["Situacao", u.fl_ativo ? st("ativo") : st("inativo")], u.dt_anonimizacao && ["Anonimizado em", dataHoraBR(u.dt_anonimizacao)], d.creci && ["CRECI", esc(d.creci)]]) +
      `<div class="button-row" style="margin-top:8px">${u.dt_anonimizacao ? "" : btn("Anonimizar (LGPD, PO07)", 'id="ps-anonimizar"', "danger-button small")}${btn("Ver tabela usuario", 'data-modelo="usuario"', "ghost-button small")}</div>`) +
    secao("Papeis", lista(d.papeis.map((p) => item(`${papelBadge(p)} <small>desde ${dataBR(p.dt_inicio)}${p.dt_fim ? " ate " + dataBR(p.dt_fim) : ""}</small>`,
      `${p.dt_fim ? btn("reativar", `data-reativar="${p.papel}"`, "ghost-button small") : btn("encerrar", `data-encerrar="${p.papel}"`, "ghost-button small")} ${btn("excluir", `data-excluir="${p.papel}"`, "ghost-button small")}`))) +
      `<div class="inline-form"><select id="ps-papel">${S.meta.papeis.filter((p) => !d.papeis.some((x) => x.papel === p)).map((p) => `<option value="${p}">${esc(rotulo(p))}</option>`).join("")}</select><input id="ps-creci" placeholder="CRECI (so corretor)">${btn("Adicionar papel", 'id="ps-add-papel"')}</div>` +
      regra("Cada papel e uma tabela-subtipo cuja chave e o id_usuario (PK e FK). Encerrar grava dt_fim: o papel deixa de valer para novos registros (RN32), mas o historico fica. Excluir so e possivel se nada referencia o papel (FK RESTRICT) e se sobrar outro papel (RN01)."), "", "especializacao total e compartilhada") +
    secao("Telefones", lista(d.telefones.map((t) => item(`${esc(t.nr_telefone)} <small>telefone ${t.nr_sequencia} · ${esc(t.tipo)}${t.fl_principal ? " · principal" : ""}</small>`, `${t.fl_titular ? st("titular") : '<span class="st off">usa o numero</span>'}${t.compartilhado_com ? ` <small>tambem: ${esc(t.compartilhado_com)}</small>` : ""}`))) +
      `<div class="inline-form"><input id="ps-tel" placeholder="Numero com DDD (se outra pessoa ja usa, vira compartilhado)">${btn("Adicionar", 'id="ps-add-tel"')}</div>`, "", "telefone: entidade fraca da pessoa (id_usuario + nr_sequencia); um titular por numero (RN03)") +
    (ativos.includes("cliente") || d.perfis.length ? secao("Perfis de interesse", lista(d.perfis.map((p) => item(`Perfil ${p.nr_perfil}: ${esc(rotulo(p.tp_finalidade))} · ${esc(p.nm_tipos || "qualquer tipo")} · ${esc(regiaoPerfil(p))}`, `${brl(p.vl_minimo)} a ${brl(p.vl_maximo)}`))), btn("Novo perfil", 'id="ps-perfil"'), "fraca de cliente; tipos aceitos em perfil_interesse_tipo (N:N DESEJA) e bairros em perfil_interesse_bairro (N:N ABRANGE)") : "") +
    secao("Conversas", lista(d.conversas.map((c) => item(`Conversa ${c.id_conversa} · ${esc(c.cliente)} <small>${dataBR(c.dt_inicio)} · ${esc(c.corretor || "sem corretor")}</small>`, `${esc(c.nm_estagio)} ${st(c.st_conversa)}`, `data-abrir="conversa:${c.id_conversa}"`)))) +
    (d.imoveis.length ? secao("Imoveis", lista(d.imoveis.map((i) => item(`<b>${esc(i.cd_imobizi)}</b> ${esc(i.nm_tipo_imovel)} · ${esc(i.nm_bairro)} <small>${esc(i.vinculo)}</small>`, st(i.st_imovel), `data-abrir="imovel:${i.id_imovel}"`)))) : "") +
    (d.contratos.length ? secao("Contratos", lista(d.contratos.map((c) => item(`Contrato ${c.id_contrato} · ${esc(rotulo(c.tp_contrato))} · ${esc(c.cd_imobizi)} <small>${esc(c.vinculo)}</small>`, `${brl(c.vl_final)} ${st(c.st_contrato)}`, `data-abrir="contrato:${c.id_contrato}"`)))) : "") +
    (d.receber.length ? secao("Contas a receber (como pagador)", lista(d.receber.map((c) => item(`${esc(c.ds_conta)} <small>vence ${dataBR(c.dt_vencimento)} · papel: ${esc(rotulo(c.tp_papel_pagador))}</small>`, `${brl(c.vl_receber)} ${st(c.st_conta)}`, `data-abrir="receber:${c.id_conta_receber}"`)))) : "") +
    (d.pagar.length ? secao("Contas a pagar", lista(d.pagar.map((c) => item(`${esc(c.ds_conta)} <small>${esc(c.vinculo)} · vence ${dataBR(c.dt_vencimento)}</small>`, `${brl(c.vl_pagar)} ${st(c.st_conta)}`, `data-abrir="pagar:${c.id_conta_pagar}"`)))) : "");
  abrirDrawer(u.nm_usuario, `Usuario ${u.id_usuario} · ${d.papeis.map((p) => rotulo(p.papel)).join(", ")}`, html);
  ligarDrawer();
  const corpo = $("#drawer-corpo");
  $("#ps-anonimizar") && ($("#ps-anonimizar").onclick = async () => {
    if (!confirm("Anonimizar? Nome, CPF e e-mail saem; o historico dos negocios fica (PO07).")) return;
    await acao(() => post(`/api/pessoas/${id}/anonimizar`), "Dados pessoais removidos; o registro e o historico ficaram."); await depois();
  });
  $$("[data-encerrar]", corpo).forEach((b) => (b.onclick = async () => { await acao(() => post(`/api/pessoas/${id}/papeis/${b.dataset.encerrar}/encerrar`, {}), "Papel encerrado (dt_fim)."); await carregarMeta(); await depois(); }));
  $$("[data-reativar]", corpo).forEach((b) => (b.onclick = async () => { await acao(() => post(`/api/pessoas/${id}/papeis`, { papel: b.dataset.reativar }), "Papel reativado."); await carregarMeta(); await depois(); }));
  $$("[data-excluir]", corpo).forEach((b) => (b.onclick = async () => { await acao(() => del(`/api/pessoas/${id}/papeis/${b.dataset.excluir}`), "Papel excluido."); await carregarMeta(); await depois(); }));
  $("#ps-add-papel").onclick = async () => { await acao(() => post(`/api/pessoas/${id}/papeis`, { papel: $("#ps-papel").value, creci: $("#ps-creci").value }), "Papel adicionado."); await carregarMeta(); await depois(); };
  $("#ps-add-tel").onclick = async () => { await acao(() => post(`/api/pessoas/${id}/telefones`, { telefone: $("#ps-tel").value }), (r) => (r.compartilhado ? "Numero ja existia: agora e compartilhado, e o titular continua o mesmo." : "Telefone cadastrado (titular).")); await depois(); };
  $("#ps-perfil") && ($("#ps-perfil").onclick = () => novoPerfil(id));
}
function novaPessoa() {
  formulario({
    titulo: "Nova pessoa",
    ajuda: "A pessoa nasce com um papel. Sem papel o banco recusa a gravacao no fim da transacao (RN01, especializacao total).",
    campos: [
      { n: "nome", r: "Nome", obrig: true, full: true }, { n: "cpf", r: "CPF/CNPJ (so numeros)" }, { n: "email", r: "E-mail", t: "email" },
      { n: "papel", r: "Papel", t: "select", op: S.meta.papeis.map((p) => [p, rotulo(p)]) }, { n: "creci", r: "CRECI (se corretor)" },
      { n: "telefone", r: "Telefone" }, { n: "id_origem", r: "Origem", t: "select", op: [["", "—"], ...S.meta.origens.map((o) => [o.id_origem, o.nm_origem])] },
    ],
    enviar: async (f) => { const r = await post("/api/pessoas", f); toast("Pessoa cadastrada.", "ok"); await carregarMeta(); await recarregarView(); abrirPessoa(r.id_usuario); },
  });
}
function novoPerfil(uid) {
  formulario({
    titulo: "Novo perfil de interesse",
    ajuda: "Entidade fraca de CLIENTE: a chave e (id_usuario, nr_perfil). O banco confere se a pessoa e cliente (RN32) e se a faixa e coerente (CHECK). Os tipos marcados vao para perfil_interesse_tipo (N:N DESEJA, RN47) e os bairros, para perfil_interesse_bairro (N:N ABRANGE, RN52): o perfil pode aceitar varios de cada, e sem nenhum aceita qualquer um. So aparecem os bairros da cidade escolhida, e o banco recusa bairro de outra cidade (gatilho, RN52).",
    campos: [
      { n: "tp_finalidade", r: "Finalidade", t: "select", op: [["locacao", "locacao"], ["venda", "compra"]] },
      { n: "tipos", r: "Tipos de imovel aceitos (nenhum = qualquer tipo)", t: "checks", op: S.meta.tipos_imovel.map((t) => [t.id_tipo_imovel, t.nm_tipo_imovel]) },
      { n: "id_cidade", r: "Cidade", t: "select", op: [["", "qualquer"], ...S.meta.cidades.map((c) => [c.id_cidade, `${c.nm_cidade}/${c.sg_uf}`])] },
      { n: "bairros", r: "Bairros aceitos (nenhum = qualquer bairro da cidade)", t: "checks", op: [] },
      { n: "vl_minimo", r: "Valor minimo", t: "number", step: "0.01" }, { n: "vl_maximo", r: "Valor maximo", t: "number", step: "0.01" },
      { n: "qt_quartos_min", r: "Quartos (min.)", t: "number" },
    ],
    enviar: async (f) => { await post(`/api/pessoas/${uid}/perfis`, f); toast("Perfil criado.", "ok"); await depois(); },
    aoAbrir: () => {
      const caixa = $("#f-bairros");
      const montar = () => {
        const cid = $("#f-id_cidade").value;
        caixa.innerHTML = cid ? bairrosDa(cid).map((b) => `<label class="check-chip"><input type="checkbox" value="${b.id_bairro}"> ${esc(b.nm_bairro)}</label>`).join("") || '<small class="muted">Nenhum bairro cadastrado nesta cidade.</small>'
          : '<small class="muted">Escolha a cidade para ver os bairros dela. Perfil sem cidade aceita qualquer lugar.</small>';
      };
      $("#f-id_cidade").onchange = montar;
      montar();
    },
  });
}

// ---------------------------------------------------------------------------------------------
// imoveis e seletor
// ---------------------------------------------------------------------------------------------
const CORES_FOTO = [["#0f766e", "#14b8a6"], ["#1d4ed8", "#60a5fa"], ["#7c3aed", "#a78bfa"], ["#b45309", "#f59e0b"], ["#be123c", "#fb7185"], ["#334155", "#94a3b8"]];
const foto = (i, txt, extra = "") => { const [a, b] = CORES_FOTO[i % CORES_FOTO.length]; return `<div class="foto" style="background:linear-gradient(135deg,${a},${b})">${esc(txt)}${extra}</div>`; };
const precoImovel = (i) => [i.vl_venda != null ? `Venda ${brl(i.vl_venda)}` : "", i.vl_aluguel != null ? `Aluguel ${brl(i.vl_aluguel)}` : ""].filter(Boolean).join(" · ");
async function carregarImoveis() {
  const sb = $("#imoveis-bairro"), bAtual = sb.value;
  sb.innerHTML = opcoesBairro($("#imoveis-cidade").value, "Todos");
  sb.value = [...sb.options].some((o) => o.value === bAtual) ? bAtual : "";
  const p = new URLSearchParams({ busca: $("#imoveis-busca").value, cidade: $("#imoveis-cidade").value, bairro: sb.value, finalidade: $("#imoveis-finalidade").value, tipo: $("#imoveis-tipo").value, situacao: $("#imoveis-situacao").value, quartos: $("#imoveis-quartos").value });
  const d = await api("/api/imoveis?" + p);
  $("#imoveis-grid").innerHTML = d.imoveis.map((i) => `<article class="imovel-card" data-id="${i.id_imovel}">
      ${foto(i.id_imovel, i.nm_tipo_imovel.toUpperCase(), `<small>${i.fotos} foto(s)</small>`)}
      <div class="corpo"><h3>${esc(i.cd_imobizi || "imovel " + i.id_imovel)} · ${esc(i.nm_bairro)}</h3><p>${esc(i.nm_cidade)}/${esc(i.sg_uf)} · ${i.qt_quartos ?? 0} quarto(s) · ${num(i.vl_area_util)} m2</p>
      <div class="preco">${precoImovel(i)}</div>
      <div class="linha" style="display:flex;justify-content:space-between;margin-top:6px;font-size:11px;color:var(--muted)"><span>${i.interesses} interesse(s) · ${i.visitas} visita(s) · ${i.propostas} proposta(s)</span>${st(i.st_imovel)}</div></div></article>`).join("") || '<div class="vazio">Nenhum imovel com esses filtros.</div>';
  $$(".imovel-card").forEach((c) => (c.onclick = () => abrirImovel(Number(c.dataset.id))));
}
async function abrirImovel(id) {
  S.drawer = { tipo: "imovel", id };
  const d = await api(`/api/imoveis/${id}`);
  const i = d.imovel;
  const html =
    `<div class="galeria">${d.fotos.slice(0, 6).map((f) => foto(i.id_imovel + f.nr_ordem, `foto ${f.nr_ordem}`)).join("")}</div><p class="muted" style="font-size:11px">Fotos ilustrativas: os enderecos de arquivo da massa de dados sao ficticios (${d.fotos.length} registro(s) em foto).</p>` +
    secao("Imovel", kv([["Codigo Imobzi", esc(i.cd_imobizi || "—")], ["Tipo", `${esc(i.nm_tipo_imovel)} <small class="muted">(tipo_imovel, FK TIPIFICA)</small>`], ["Finalidade", esc(rotulo(i.tp_finalidade))], ["Situacao", st(i.st_imovel)],
      ["Endereco", `${esc(i.nm_logradouro)}, ${esc(i.nr_endereco)}${i.ds_complemento ? " — " + esc(i.ds_complemento) : ""}<br>${esc(i.nm_bairro)} <small class="muted">(bairro, FK SITUA)</small>`],
      ["CEP → cidade → UF", `${esc(i.nr_cep)} → ${esc(i.nm_cidade)} → ${esc(i.sg_uf)} (${esc(i.nm_uf)}) <small class="muted">(CEP ${esc(i.tp_cep)}; a cidade vem do CEP e a UF, da cidade: 3FN)</small>`],
      ["Area util / total", `${num(i.vl_area_util)} m2 / ${num(i.vl_area_total)} m2`], ["Quartos · banheiros · vagas", `${i.qt_quartos ?? "—"} · ${i.qt_banheiros ?? "—"} · ${i.qt_vagas_garagem ?? "—"}`],
      ["Venda", brl(i.vl_venda)], ["Aluguel", brl(i.vl_aluguel)],
      ["Proprietario", `<button class="fk-link" data-abrir="pessoa:${i.id_proprietario}">${esc(i.proprietario)}</button>`],
      ["Corretor responsavel", i.id_corretor_responsavel ? `<button class="fk-link" data-abrir="pessoa:${i.id_corretor_responsavel}">${esc(i.corretor)}</button>` : "—"],
    ]) + (i.ds_anuncio ? `<p style="font-size:13px">${esc(i.ds_anuncio)}</p>` : "") +
      `<div class="button-row wrap" style="margin-top:8px">${btn("Editar valores e situacao", 'id="im-editar"')}${btn("Agendar visita", 'id="im-visita"')}${btn("Nova proposta", 'id="im-proposta"')}${btn("Ver tabela imovel", 'data-modelo="imovel"', "ghost-button small")}</div>`) +
    secao("Caracteristicas", `<div class="chips">${d.caracteristicas.map((c) => `<span class="chip">${esc(c.nm_caracteristica)} <button data-rmcar="${c.id_caracteristica}">×</button></span>`).join("") || '<span class="muted">nenhuma</span>'}</div>
      <div class="inline-form"><select id="im-car">${S.meta.caracteristicas.filter((c) => !d.caracteristicas.some((x) => x.id_caracteristica === c.id_caracteristica)).map((c) => `<option value="${c.id_caracteristica}">${esc(c.nm_caracteristica)}</option>`).join("")}</select>${btn("Adicionar", 'id="im-add-car"')}</div>`, "", "imovel_caracteristica (N:N APRESENTA)") +
    secao("Interesses", lista(d.interesses.map((x) => item(`${esc(x.cliente)} <small>${dataBR(x.dt_interesse)}</small>`, `${esc(x.nm_estagio)} ${st(x.st_conversa)}`, `data-abrir="conversa:${x.id_conversa}"`)), "Nenhuma conversa.")) +
    secao("Visitas", lista(d.visitas.map((v) => item(`${esc(v.cliente)} <small>${dataHoraBR(v.dt_visita)} · ${esc(v.corretor)}</small>`, st(v.st_visita))), "Nenhuma visita.")) +
    secao("Propostas", lista(d.propostas.map((p) => item(`${esc(p.cliente)} · ${brl(p.vl_proposto)} <small>${dataBR(p.dt_proposta)} · anunciado ${brl(p.vl_anunciado)}</small>`, `${st(p.st_proposta)}${p.id_contrato ? ` <button class="fk-link" data-abrir="contrato:${p.id_contrato}">contrato ${p.id_contrato}</button>` : ""}`)), "Nenhuma proposta."));
  abrirDrawer(`${i.cd_imobizi || "Imovel " + i.id_imovel} · ${i.nm_bairro}`, `Imovel ${i.id_imovel} · ${esc(i.nm_tipo_imovel)} · ${esc(i.nm_cidade)}`, html);
  ligarDrawer();
  const corpo = $("#drawer-corpo");
  $("#im-editar").onclick = () => formulario({
    titulo: `Editar ${i.cd_imobizi || "imovel " + i.id_imovel}`,
    ajuda: "O banco confere: imovel a venda precisa de valor de venda e para locacao precisa de aluguel (CHECKs ck_imovel_tp_finalidade_vl_venda e …_vl_aluguel).",
    campos: [{ n: "id_tipo_imovel", r: "Tipo", t: "select", v: i.id_tipo_imovel, op: S.meta.tipos_imovel.map((t) => [t.id_tipo_imovel, t.nm_tipo_imovel]) },
      { n: "tp_finalidade", r: "Finalidade", t: "select", v: i.tp_finalidade, op: [["venda", "venda"], ["locacao", "locacao"], ["ambas", "venda e locacao"]] },
      { n: "st_imovel", r: "Situacao", t: "select", v: i.st_imovel, op: ["disponivel", "reservado", "alugado", "vendido", "inativo"].map((x) => [x, rotulo(x)]) },
      { n: "vl_venda", r: "Valor de venda", t: "number", step: "0.01", v: i.vl_venda ?? "" }, { n: "vl_aluguel", r: "Valor do aluguel", t: "number", step: "0.01", v: i.vl_aluguel ?? "" }],
    enviar: async (f) => { await patch(`/api/imoveis/${id}`, f); toast("Imovel atualizado.", "ok"); await carregarMeta(); await depois(); },
  });
  $("#im-visita").onclick = () => novaVisita({ id_imovel: id, id_corretor: i.id_corretor_responsavel });
  $("#im-proposta").onclick = () => novaProposta({ id_imovel: id, id_corretor: i.id_corretor_responsavel });
  $("#im-add-car").onclick = async () => { await acao(() => post(`/api/imoveis/${id}/caracteristicas`, { id_caracteristica: $("#im-car").value }), "Caracteristica adicionada."); await depois(); };
  $$("[data-rmcar]", corpo).forEach((b) => (b.onclick = async () => { await acao(() => del(`/api/imoveis/${id}/caracteristicas/${b.dataset.rmcar}`), "Caracteristica removida."); await depois(); }));
}
function novoImovel() {
  const m = S.meta;
  formulario({
    titulo: "Cadastrar imovel novo",
    ajuda: "O tipo e escolhido da tabela <b>tipo_imovel</b> (FK, RN48). O banco confere se a pessoa e proprietaria e se o corretor esta ativo (RN32), e se a finalidade tem o valor certo: venda exige valor de venda e locacao exige aluguel (CHECK). A cidade e a UF vem do CEP (3FN); se o CEP ainda nao estiver cadastrado, escolha a cidade dele. O bairro e escolhido da tabela <b>bairro</b> (FK SITUA): a lista mostra so os bairros da cidade do CEP, e o banco recusa bairro de outra cidade (gatilho, RN51).",
    campos: [
      { n: "id_tipo_imovel", r: "Tipo", t: "select", obrig: true, op: m.tipos_imovel.map((t) => [t.id_tipo_imovel, t.nm_tipo_imovel]) },
      { n: "tp_finalidade", r: "Finalidade", t: "select", obrig: true, op: [["venda", "venda"], ["locacao", "locacao"], ["ambas", "venda e locacao"]] },
      { n: "id_proprietario", r: "Proprietario", t: "select", obrig: true, op: m.proprietarios.map((u) => [u.id_usuario, u.nm_usuario]) },
      { n: "id_corretor_responsavel", r: "Corretor responsavel", t: "select", op: [["", "— nenhum —"], ...m.corretores.filter((u) => !u.dt_fim).map((u) => [u.id_usuario, u.nm_usuario])] },
      { n: "cd_imobizi", r: "Codigo no Imobzi (opcional)", ph: "IMB-0000" },
      { n: "nr_cep", r: "CEP", obrig: true, ph: "07061000", dica: "Cadastrados: " + m.ceps.map((c) => `${c.nr_cep} (${c.nm_cidade})`).join(", ") },
      { n: "id_cidade", r: "Cidade (so se o CEP for novo)", t: "select", op: [["", "—"], ...m.cidades.map((c) => [c.id_cidade, `${c.nm_cidade}/${c.sg_uf}`])] },
      { n: "id_bairro", r: "Bairro (tabela bairro)", t: "select", obrig: true, op: [] },
      { n: "nm_logradouro", r: "Logradouro", obrig: true, full: true }, { n: "nr_endereco", r: "Numero", obrig: true }, { n: "ds_complemento", r: "Complemento" },
      { n: "vl_area_util", r: "Area util (m2)", t: "number", step: "0.01" }, { n: "vl_area_total", r: "Area total (m2)", t: "number", step: "0.01" },
      { n: "qt_quartos", r: "Quartos", t: "number" }, { n: "qt_banheiros", r: "Banheiros", t: "number" }, { n: "qt_vagas_garagem", r: "Vagas", t: "number" },
      { n: "vl_venda", r: "Valor de venda", t: "number", step: "0.01" }, { n: "vl_aluguel", r: "Valor do aluguel", t: "number", step: "0.01" },
      { n: "caracteristicas", r: "Caracteristicas (imovel_caracteristica, N:N APRESENTA)", t: "checks", op: m.caracteristicas.map((c) => [c.id_caracteristica, c.nm_caracteristica]) },
      { n: "ds_anuncio", r: "Texto do anuncio", t: "textarea", full: true },
    ],
    enviarTexto: "Cadastrar imovel",
    enviar: async (f) => { const r = await post("/api/imoveis", f); toast(`Imovel ${r.id_imovel} cadastrado.`, "ok"); await carregarMeta(); await recarregarView(); abrirImovel(r.id_imovel); },
    aoAbrir: () => {
      const sel = $("#f-id_bairro");
      const montar = () => {
        const cid = cidadeDoCep($("#f-nr_cep").value) || $("#f-id_cidade").value;
        const atual = sel.value;
        sel.innerHTML = opcoesBairro(cid);
        if ([...sel.options].some((o) => o.value === atual)) sel.value = atual;
      };
      $("#f-nr_cep").addEventListener("input", montar);
      $("#f-id_cidade").onchange = montar;
      montar();
    },
  });
}
async function carregarSeletor() {
  const sel = $("#seletor-perfil");
  const [u, p] = (sel.value || S.seletorEscolha || "").split(":");
  const d = await api("/api/seletor?" + new URLSearchParams({ usuario: u || "", perfil: p || "" }));
  sel.innerHTML = `<option value="">— escolha um perfil —</option>` + d.perfis.map((x) => `<option value="${x.id_usuario}:${x.nr_perfil}">${esc(x.nm_usuario)} · perfil ${x.nr_perfil}: ${esc(rotulo(x.tp_finalidade))} ${esc(x.nm_tipos || "qualquer tipo")} · ${esc(regiaoPerfil(x))} (${brl(x.vl_minimo)} a ${brl(x.vl_maximo)})</option>`).join("");
  if (u) sel.value = `${u}:${p}`;
  S.seletorEscolha = null;
  const out = $("#seletor-resultado");
  if (!d.perfil) { out.innerHTML = '<div class="vazio">Escolha um perfil para ver os imoveis compativeis.</div>'; return; }
  const pf = d.perfil;
  out.innerHTML = `<section class="panel"><div class="panel-head"><h2>${esc(pf.nm_usuario)} — perfil ${pf.nr_perfil}</h2><button class="link-button small" id="sel-cliente">ver cliente</button></div>
    ${kv([["Finalidade", esc(rotulo(pf.tp_finalidade))], ["Tipos aceitos", esc(pf.nm_tipos || "qualquer tipo")], ["Cidade", esc(pf.nm_cidade || "qualquer")], ["Bairros aceitos", esc(pf.nm_bairros || "qualquer bairro da cidade")], ["Faixa", `${brl(pf.vl_minimo)} a ${brl(pf.vl_maximo)}`], ["Quartos (min.)", pf.qt_quartos_min ?? "—"]])}
    ${regra("Pontos: cidade 3 · bairro 3 · tipo aceito pelo perfil 2 · valor na faixa 3 · quartos 1 (maximo 12). So entram imoveis disponiveis da finalidade do perfil. O perfil pode aceitar varios tipos (perfil_interesse_tipo, N:N DESEJA) e varios bairros (perfil_interesse_bairro, N:N ABRANGE); o bairro e comparado pela chave id_bairro, e nao pelo texto.")}
    <div class="table-wrap tall" id="sel-tabela" style="margin-top:10px"></div></section>`;
  montarTabela($("#sel-tabela"), [
    { t: "Pontos", v: (i) => `<span class="pontos">${i.pontos}</span>` }, { t: "Imovel", v: (i) => `<b>${esc(i.cd_imobizi || "imovel " + i.id_imovel)}</b> ${esc(i.nm_tipo_imovel)}` },
    { t: "Local", v: (i) => `${esc(i.nm_bairro)} · ${esc(i.nm_cidade)}` }, { t: "Quartos", v: (i) => i.qt_quartos ?? "—", cls: "num" },
    { t: "Area", v: (i) => `${num(i.vl_area_util)} m2`, cls: "num" }, { t: "Valor", v: (i) => brl(i.valor), cls: "num" },
  ], d.imoveis, (i) => abrirImovel(i.id_imovel), "Nenhum imovel disponivel nessa finalidade.");
  $("#sel-cliente").onclick = () => abrirPessoa(pf.id_usuario);
}

// ---------------------------------------------------------------------------------------------
// negociacao
// ---------------------------------------------------------------------------------------------
const opImoveis = () => S.meta.imoveis.map((i) => [i.id_imovel, `${i.cd_imobizi || "imovel " + i.id_imovel} · ${i.nm_tipo_imovel} · ${i.nm_bairro} (${rotulo(i.st_imovel)})`]);
const opClientes = () => S.meta.clientes.map((u) => [u.id_usuario, u.nm_usuario]);
const opCorretores = (todos = false) => S.meta.corretores.filter((u) => todos || !u.dt_fim).map((u) => [u.id_usuario, u.nm_usuario + (u.dt_fim ? " (saiu)" : "")]);
function novaVisita(v) {
  formulario({
    titulo: "Agendar visita",
    ajuda: "VISITA e associativa entre CLIENTE e IMOVEL, com chave substituta: o mesmo cliente pode visitar o mesmo imovel mais de uma vez (RN16). O banco confere os papeis (RN32).",
    campos: [{ n: "id_imovel", r: "Imovel", t: "select", op: opImoveis(), v: v.id_imovel, full: true }, { n: "id_cliente", r: "Cliente", t: "select", op: opClientes(), v: v.id_cliente },
      { n: "id_corretor", r: "Corretor", t: "select", op: opCorretores(true), v: v.id_corretor, dica: "Escolha o corretor que saiu para ver a regra RN32 recusar." }, { n: "dt_visita", r: "Data e hora", t: "datetime-local", v: hoje() + "T10:00" }],
    enviar: async (f) => { await post("/api/visitas", f); toast("Visita agendada.", "ok"); await depois(); },
  });
}
async function carregarVisitas() {
  const d = await api("/api/visitas?" + new URLSearchParams({ situacao: $("#visitas-situacao").value }));
  montarTabela($("#visitas-tabela"), [
    { t: "Data", v: (v) => dataHoraBR(v.dt_visita) }, { t: "Imovel", v: (v) => `<button class="fk-link" data-imovel="${v.id_imovel}">${esc(v.cd_imobizi)}</button> ${esc(v.nm_bairro)}` },
    { t: "Cliente", v: (v) => esc(v.cliente) }, { t: "Corretor", v: (v) => esc(v.corretor) }, { t: "Situacao", v: (v) => st(v.st_visita) },
    { t: "Retorno do cliente", v: (v) => esc(v.ds_feedback || "—") }, { t: "Propostas", v: (v) => v.propostas, cls: "num" },
  ], d.visitas, (v) => formulario({
    titulo: `Visita ${v.id_visita} — ${v.cd_imobizi}`,
    campos: [{ n: "st_visita", r: "Situacao", t: "select", v: v.st_visita, op: [["agendada", "agendada"], ["realizada", "realizada"], ["cancelada", "cancelada"]] }, { n: "ds_feedback", r: "Retorno do cliente", t: "textarea", v: v.ds_feedback || "", full: true }],
    enviar: async (f) => { await patch(`/api/visitas/${v.id_visita}`, f); toast("Visita atualizada.", "ok"); await depois(); },
  }));
  $$("[data-imovel]", $("#visitas-tabela")).forEach((b) => (b.onclick = () => abrirImovel(Number(b.dataset.imovel))));
}
function novaProposta(v) {
  formulario({
    titulo: v.id_proposta_respondida ? `Contraproposta a proposta ${v.id_proposta_respondida}` : "Nova proposta",
    ajuda: `O valor anunciado e copiado do imovel e congelado na proposta. <b>Desconto acima de 10%</b> so com autorizacao do administrador: marque a caixa agindo como <b>${esc(nomeUsuario(1))}</b> (PO03). Agindo como outra pessoa, o banco recusa (RN32: o autorizador precisa ser administrador).`,
    campos: [{ n: "id_imovel", r: "Imovel", t: "select", op: opImoveis(), v: v.id_imovel, full: true }, { n: "id_cliente", r: "Cliente", t: "select", op: opClientes(), v: v.id_cliente },
      { n: "id_corretor", r: "Corretor", t: "select", op: opCorretores(), v: v.id_corretor }, { n: "tipo", r: "Proposta de", t: "select", op: [["", "conforme o imovel"], ["venda", "compra"], ["locacao", "locacao"]], v: v.tipo || "" },
      { n: "vl_proposto", r: "Valor proposto", t: "number", step: "0.01", obrig: true, v: v.vl_proposto || "" }, { n: "ds_condicoes", r: "Condicoes", t: "textarea", full: true },
      { n: "autorizar", r: "Registrar minha autorizacao para desconto acima de 10% (administrador)", t: "checkbox", full: true }],
    enviar: async (f) => { const r = await post("/api/propostas", { ...f, id_proposta_respondida: v.id_proposta_respondida }); toast(`Proposta ${r.id_proposta} registrada.`, "ok"); await depois(); },
  });
}
async function carregarPropostas() {
  const d = await api("/api/propostas?" + new URLSearchParams({ situacao: $("#propostas-situacao").value }));
  montarTabela($("#propostas-tabela"), [
    { t: "No", v: (p) => p.id_proposta + (p.id_proposta_respondida ? ` <small class="muted">responde ${p.id_proposta_respondida}</small>` : ""), cls: "num" },
    { t: "Data", v: (p) => dataBR(p.dt_proposta) }, { t: "Imovel", v: (p) => esc(p.cd_imobizi) }, { t: "Cliente", v: (p) => esc(p.cliente) }, { t: "Corretor", v: (p) => esc(p.corretor) },
    { t: "Proposto", v: (p) => brl(p.vl_proposto), cls: "num" }, { t: "Anunciado", v: (p) => brl(p.vl_anunciado), cls: "num" },
    { t: "Desconto", v: (p) => `${num(p.pc_desconto)}%${p.autorizador ? ` <small class="muted">aut. ${esc(p.autorizador)}</small>` : ""}`, cls: "num" },
    { t: "Situacao", v: (p) => st(p.st_proposta) },
    { t: "Acoes", v: (p) => p.id_contrato ? `<button class="fk-link" data-contrato="${p.id_contrato}">contrato ${p.id_contrato}</button> ${st(p.st_contrato)}` :
      p.st_proposta === "pendente" ? `${btn("aceitar", `data-st="aceita" data-id="${p.id_proposta}"`, "ghost-button small")}${btn("recusar", `data-st="recusada" data-id="${p.id_proposta}"`, "ghost-button small")}${btn("contraproposta", `data-contra="${p.id_proposta}"`, "ghost-button small")}` :
      p.st_proposta === "aceita" ? btn("gerar contrato", `data-gerar="${p.id_proposta}"`, "secondary-button small") : "" },
  ], d.propostas);
  const el = $("#propostas-tabela");
  $$("[data-st]", el).forEach((b) => (b.onclick = async () => { await acao(() => patch(`/api/propostas/${b.dataset.id}`, { st_proposta: b.dataset.st }), "Proposta atualizada (auditada: RN40)."); await depois(); }));
  $$("[data-contra]", el).forEach((b) => (b.onclick = () => { const p = d.propostas.find((x) => x.id_proposta === Number(b.dataset.contra)); novaProposta({ ...p, id_proposta_respondida: p.id_proposta, vl_proposto: "" }); }));
  $$("[data-contrato]", el).forEach((b) => (b.onclick = () => abrirContrato(Number(b.dataset.contrato))));
  $$("[data-gerar]", el).forEach((b) => (b.onclick = () => gerarContrato(d.propostas.find((x) => x.id_proposta === Number(b.dataset.gerar)))));
}
function gerarContrato(p) {
  const loc = p.tp_finalidade === "locacao";
  formulario({
    titulo: `Contrato da proposta ${p.id_proposta}`,
    ajuda: "O contrato nasce em <b>rascunho</b> e so vale depois da assinatura (RN36). Locacao exige inicio, termino, taxa de administracao e dia de vencimento (CHECK ck_contrato_tp_contrato_pc_administracao, RN19). FECHA e 1:1: a mesma proposta nao gera dois contratos (UNIQUE).",
    campos: [{ n: "tp_contrato", r: "Tipo", t: "select", v: loc ? "locacao" : "venda", op: [["venda", "venda"], ["locacao", "locacao"]] },
      { n: "tp_condicao_pagamento", r: "Condicao de pagamento", t: "select", op: [["a_vista", "a vista"], ["financiado", "financiado"], ["parcelado_direto", "parcelado direto"]] },
      { n: "vl_final", r: "Valor final", t: "number", step: "0.01", v: p.vl_proposto }, { n: "pc_corretagem", r: "% corretagem (intermediacao)", t: "number", step: "0.01", v: loc ? 100 : 6 },
      { n: "pc_administracao", r: "% administracao (locacao)", t: "number", step: "0.01", v: loc ? 10 : "" }, { n: "nr_dia_vencimento", r: "Dia de vencimento (locacao)", t: "number", v: loc ? 10 : "" },
      { n: "dt_inicio", r: "Inicio", t: "date", v: loc ? hoje() : "" }, { n: "dt_fim", r: "Termino previsto", t: "date" }],
    enviar: async (f) => { const r = await post(`/api/propostas/${p.id_proposta}/contrato`, f); toast(`Contrato ${r.id_contrato} criado em rascunho.`, "ok"); await recarregarView(); abrirContrato(r.id_contrato); },
  });
}
async function carregarContratos() {
  const d = await api("/api/contratos");
  montarTabela($("#contratos-tabela"), [
    { t: "No", v: (c) => c.id_contrato, cls: "num" }, { t: "Tipo", v: (c) => esc(rotulo(c.tp_contrato)) }, { t: "Imovel", v: (c) => esc(c.cd_imobizi) },
    { t: "Cliente", v: (c) => esc(c.cliente) }, { t: "Proprietario", v: (c) => esc(c.proprietario) }, { t: "Corretor", v: (c) => esc(c.corretor) },
    { t: "Valor final", v: (c) => brl(c.vl_final), cls: "num" }, { t: "Corretagem (derivada)", v: (c) => brl(c.vl_corretagem), cls: "num" },
    { t: "Assinatura", v: (c) => dataBR(c.dt_assinatura) }, { t: "Situacao", v: (c) => st(c.st_contrato) },
  ], d.contratos, (c) => abrirContrato(c.id_contrato));
}
async function abrirContrato(id) {
  S.drawer = { tipo: "contrato", id };
  const d = await api(`/api/contratos/${id}`);
  const c = d.contrato;
  const loc = c.tp_contrato === "locacao";
  const somaCom = d.comissoes.filter((x) => x.st_comissao !== "cancelada").reduce((a, x) => a + Number(x.pc_comissao), 0);
  const botoes = [
    c.st_contrato === "rascunho" && btn("Assinar", 'id="ct-assinar"', "primary-button small"),
    ["rascunho", "vigente"].includes(c.st_contrato) && btn("Cancelar", 'id="ct-cancelar"', "danger-button small"),
    c.st_contrato === "vigente" && loc && btn("Rescindir", 'id="ct-rescindir"', "danger-button small"),
    c.st_contrato === "vigente" && btn("Encerrar", 'id="ct-encerrar"'),
    c.st_contrato === "vigente" && loc && btn("Lancar aluguel", 'id="ct-aluguel"'),
    btn("Ver tabela contrato", 'data-modelo="contrato"', "ghost-button small"),
  ].filter(Boolean).join("");
  const html =
    secao("Contrato", kv([["Tipo", esc(rotulo(c.tp_contrato))], ["Condicao de pagamento", esc(rotulo(c.tp_condicao_pagamento))], ["Situacao", st(c.st_contrato)],
      ["Imovel", `<button class="fk-link" data-abrir="imovel:${c.id_imovel}">${esc(c.cd_imobizi)}</button> ${esc(c.nm_bairro)}`],
      ["Cliente", `<button class="fk-link" data-abrir="pessoa:${c.id_cliente}">${esc(c.cliente)}</button>`], ["Proprietario", `<button class="fk-link" data-abrir="pessoa:${c.id_proprietario}">${esc(c.proprietario)}</button>`],
      ["Corretor da proposta", esc(c.corretor)], ["Proposta (FECHA)", `no ${c.id_proposta} · anunciado ${brl(c.vl_anunciado)}`],
      ["Valor final", brl(c.vl_final)], ["Corretagem", `${num(c.pc_corretagem)}% = <b>${brl(c.vl_corretagem)}</b> <small class="muted">(derivado: vw_contrato)</small>`],
      loc && ["Administracao", `${num(c.pc_administracao)}% · vence dia ${c.nr_dia_vencimento ?? "—"}`],
      ["Assinatura", dataBR(c.dt_assinatura)], ["Vigencia", `${dataBR(c.dt_inicio)} a ${dataBR(c.dt_fim)}`],
      c.dt_termino && ["Termino", `${dataBR(c.dt_termino)} · ${esc(c.ds_motivo_termino || "")}${c.tp_iniciativa_rescisao ? " · iniciativa: " + esc(rotulo(c.tp_iniciativa_rescisao)) : ""}`],
    ]) + `<div class="button-row wrap" style="margin-top:8px">${botoes}</div>` +
      regra("Rascunho → vigente (assinatura) → encerrado, rescindido ou cancelado. Cada termino e um procedimento do banco que grava tudo numa transacao (RN37, RN43, RN44); contrato nunca e excluido (PO04).")) +
    secao("Comissoes", lista(d.comissoes.map((x) => item(`<b>${esc(x.corretor)}</b> ${num(x.pc_comissao)}% = ${brl(x.vl_comissao)} <small>regra: ${esc(rotulo(x.tp_regra_pagamento))}${x.aprovador ? " · aprovada por " + esc(x.aprovador) : ""}</small>`,
      `${st(x.st_comissao)} ${x.st_comissao === "pendente" ? btn("liberar", `data-liberar="${x.id_corretor}"`, "ghost-button small") + btn("cancelar", `data-cancelar-com="${x.id_corretor}"`, "ghost-button small") : ""}${x.id_conta_pagar ? ` <button class="fk-link" data-abrir="pagar:${x.id_conta_pagar}">conta ${x.id_conta_pagar}</button>` : ""}`)), "Nenhuma comissao.") +
      `<div class="inline-form"><select id="ct-com-corretor">${opCorretores(true).map(([v, l]) => `<option value="${v}">${esc(l)}</option>`).join("")}</select><input id="ct-com-pc" type="number" step="0.01" placeholder="%" style="flex:0 0 80px">
       <select id="ct-com-regra" style="flex:0 0 150px"><option value="assinatura">na assinatura</option><option value="recebimento">no recebimento</option><option value="liberacao_credito">na liberacao do credito</option></select>${btn("Adicionar", 'id="ct-add-com"')}</div>` +
      regra(`Soma atual das comissoes nao canceladas: <b>${num(somaCom)}%</b>. O gatilho tg_comissao_soma bloqueia o contrato e recusa qualquer gravacao que passe de 100% (RN20). Liberar exige o administrador (PO01) e gera a conta a pagar ao corretor (LANCA).`), "", "associativa CONTRATO × CORRETOR (RECEBE)") +
    (c.tp_condicao_pagamento === "financiado" || d.financiamento ? secao("Financiamento", d.financiamento ? kv([["Instituicao", esc(d.financiamento.instituicao)], ["Financiado", brl(d.financiamento.vl_financiado)], ["Entrada", brl(d.financiamento.vl_entrada)],
      ["Parcelas · juros", `${d.financiamento.nr_parcelas ?? "—"} · ${num(d.financiamento.pc_juros_aa)}% a.a.`], ["Situacao", st(d.financiamento.st_financiamento)], ["Aprovacao · liberacao", `${dataBR(d.financiamento.dt_aprovacao)} · ${dataBR(d.financiamento.dt_liberacao)}`]]) +
      `<div class="button-row" style="margin-top:6px">${btn("Atualizar situacao", 'id="ct-fin-st"')}</div>` : `<div class="button-row">${btn("Registrar financiamento", 'id="ct-fin-novo"')}</div>`, "", "fraca 1:1 de contrato (RN22)") : "") +
    secao("Documentos", lista(d.documentos.map((x) => item(`${x.nr_documento}. ${esc(x.nm_tipo_documento)} <small class="muted">(tipo_documento)</small>`, `<small class="mono">${esc(x.ds_url)}</small>`)), "Nenhum documento.")) +
    secao("Contas a receber", lista(d.receber.map((x) => item(`${esc(x.ds_conta)} <small>vence ${dataBR(x.dt_vencimento)} · ${x.baixas.length} baixa(s)</small>`, `${brl(x.vl_receber)} ${st(x.st_conta)}`, `data-abrir="receber:${x.id_conta_receber}"`)), "Nenhuma conta.")) +
    secao("Contas a pagar", lista(d.pagar.map((x) => item(`${esc(x.ds_conta)} <small>${esc(x.nm_categoria)} · vence ${dataBR(x.dt_vencimento)}</small>`, `${brl(x.vl_pagar)} ${st(x.st_conta)}`, `data-abrir="pagar:${x.id_conta_pagar}"`)), "Nenhuma conta.")) +
    secao("Trilha de auditoria", trilha(d.auditoria), "", "gravada pelos gatilhos (RN40)");
  abrirDrawer(`Contrato ${c.id_contrato}`, `${esc(rotulo(c.tp_contrato))} · ${esc(c.cd_imobizi)} · ${esc(c.cliente)}`, html);
  ligarDrawer();
  const corpo = $("#drawer-corpo");
  const on = (sel, fn) => { const el = $(sel, corpo); if (el) el.onclick = fn; };
  on("#ct-assinar", () => formulario({ titulo: "Assinar contrato", ajuda: loc ? "Na locacao, o gatilho tg_contrato_inquilino torna o cliente inquilino (RN33). O prototipo tambem lanca a conta da intermediacao, paga pelo proprietario." : "O prototipo lanca a conta da corretagem, paga pelo proprietario.",
    campos: [{ n: "dt_assinatura", r: "Data da assinatura", t: "date", v: hoje() }], enviar: async (f) => { await post(`/api/contratos/${id}/assinar`, f); toast("Contrato vigente.", "ok"); await carregarMeta(); await depois(); } }));
  on("#ct-cancelar", () => formulario({ titulo: "Cancelar contrato", ajuda: "Procedimento cancelar_contrato (RN37): grava situacao, data e motivo e cancela as contas em aberto, numa transacao so.",
    campos: [{ n: "data", r: "Data", t: "date", v: hoje() }, { n: "motivo", r: "Motivo", t: "textarea", full: true, obrig: true }], enviar: async (f) => { await post(`/api/contratos/${id}/cancelar`, f); toast("Contrato cancelado.", "ok"); await depois(); } }));
  on("#ct-rescindir", () => formulario({ titulo: "Rescindir locacao", ajuda: "Procedimento rescindir_contrato (RN43): encerra o papel de inquilino, cancela os alugueis futuros e lanca a multa, se houver. Comum acordo nao gera multa.",
    campos: [{ n: "data", r: "Data", t: "date", v: hoje() }, { n: "iniciativa", r: "Iniciativa", t: "select", op: [["cliente", "cliente (inquilino)"], ["proprietario", "proprietario"], ["comum_acordo", "comum acordo"]] },
      { n: "vl_multa", r: "Multa", t: "number", step: "0.01" }, { n: "vencimento_multa", r: "Vencimento da multa", t: "date" }, { n: "motivo", r: "Motivo", t: "textarea", full: true, obrig: true }],
    enviar: async (f) => { await post(`/api/contratos/${id}/rescindir`, f); toast("Contrato rescindido.", "ok"); await depois(); } }));
  on("#ct-encerrar", () => formulario({ titulo: "Encerrar contrato", ajuda: "Procedimento encerrar_contrato (RN44): a locacao so encerra a partir da data de termino; a venda, so com todas as contas quitadas. Antes disso o banco recusa.",
    campos: [{ n: "data", r: "Data", t: "date", v: hoje() }], enviar: async (f) => { await post(`/api/contratos/${id}/encerrar`, f); toast("Contrato encerrado.", "ok"); await depois(); } }));
  on("#ct-aluguel", () => formulario({ titulo: "Lancar aluguel", ajuda: "Conta a receber do inquilino (o banco confere o papel, RN32). Quando ela for paga, o gatilho gera o repasse ao proprietario (RN30).",
    campos: [{ n: "competencia", r: "Competencia (mes)", t: "month", v: hoje().slice(0, 7) }], enviar: async (f) => { await post(`/api/contratos/${id}/aluguel`, f); toast("Aluguel lancado.", "ok"); await depois(); } }));
  on("#ct-add-com", async () => { await acao(() => post(`/api/contratos/${id}/comissoes`, { id_corretor: $("#ct-com-corretor").value, pc_comissao: $("#ct-com-pc").value, tp_regra_pagamento: $("#ct-com-regra").value }), "Comissao incluida."); await depois(); });
  $$("[data-liberar]", corpo).forEach((b) => (b.onclick = async () => { await acao(() => post(`/api/contratos/${id}/comissoes/${b.dataset.liberar}/liberar`), (r) => `Comissao liberada; conta a pagar ${r.id_conta_pagar} gerada.`); await depois(); }));
  $$("[data-cancelar-com]", corpo).forEach((b) => (b.onclick = async () => { await acao(() => patch(`/api/contratos/${id}/comissoes/${b.dataset.cancelarCom}`, { st_comissao: "cancelada" }), "Comissao cancelada."); await depois(); }));
  on("#ct-fin-novo", () => formulario({ titulo: "Registrar financiamento", campos: [{ n: "id_instituicao", r: "Instituicao", t: "select", op: S.meta.instituicoes.map((u) => [u.id_usuario, u.nm_usuario]) },
      { n: "vl_financiado", r: "Valor financiado", t: "number", step: "0.01", obrig: true }, { n: "vl_entrada", r: "Entrada", t: "number", step: "0.01" }, { n: "nr_parcelas", r: "Parcelas", t: "number" }, { n: "pc_juros_aa", r: "Juros a.a. (%)", t: "number", step: "0.01" }],
    enviar: async (f) => { await post(`/api/contratos/${id}/financiamento`, f); toast("Financiamento registrado.", "ok"); await depois(); } }));
  on("#ct-fin-st", () => formulario({ titulo: "Situacao do financiamento", ajuda: "Financiamento liberado precisa da data da liberacao (CHECK, RN23).",
    campos: [{ n: "st_financiamento", r: "Situacao", t: "select", v: d.financiamento.st_financiamento, op: ["em_analise", "aprovado", "reprovado", "liberado", "cancelado"].map((x) => [x, rotulo(x)]) }, { n: "dt_aprovacao", r: "Aprovacao", t: "date" }, { n: "dt_liberacao", r: "Liberacao", t: "date" }],
    enviar: async (f) => { await post(`/api/contratos/${id}/financiamento`, f); toast("Financiamento atualizado.", "ok"); await depois(); } }));
}
function trilha(regs) {
  if (!regs.length) return '<div class="vazio">Sem registros.</div>';
  return `<ul class="timeline">${regs.map((a) => `<li style="--dot:${a.tp_acao === "criacao" ? "#0369a1" : a.tp_acao === "cancelamento" ? "#be123c" : "#b45309"}">${st(a.tp_acao)} <b>${esc(a.registro)}</b> <small>${dataHoraBR(a.dt_acao)} · ${esc(a.usuario)}</small>
    ${a.campos.length ? `<div class="mono" style="margin:3px 0 6px">${a.campos.map((f) => `${esc(f.campo)}: ${esc(f.antes ?? "∅")} → ${esc(f.depois ?? "∅")}`).join("<br>")}</div>` : ""}</li>`).join("")}</ul>`;
}

// ---------------------------------------------------------------------------------------------
// financeiro
// ---------------------------------------------------------------------------------------------
async function carregarReceber() {
  const d = await api("/api/financeiro/receber?" + new URLSearchParams({ situacao: $("#receber-situacao").value, busca: $("#receber-busca").value }));
  montarTabela($("#receber-tabela"), [
    { t: "No", v: (c) => c.id_conta_receber, cls: "num" }, { t: "Descricao", v: (c) => esc(c.ds_conta) }, { t: "Pagador", v: (c) => `${esc(c.pagador)} <small class="muted">${esc(rotulo(c.tp_papel_pagador))}</small>` },
    { t: "Categoria", v: (c) => esc(c.nm_categoria) }, { t: "Vencimento", v: (c) => dataBR(c.dt_vencimento) }, { t: "Valor", v: (c) => brl(c.vl_receber), cls: "num" },
    { t: "Baixado", v: (c) => brl(c.vl_baixado), cls: "num" }, { t: "Situacao (derivada)", v: (c) => st(c.st_conta) },
  ], d.contas, (c) => abrirContaReceber(c.id_conta_receber));
}
async function abrirContaReceber(id) {
  S.drawer = { tipo: "receber", id };
  const d = await api(`/api/financeiro/receber/${id}`);
  const c = d.conta;
  const falta = Math.max(0, Number(c.vl_receber) - Number(c.vl_baixado));
  const html = secao("Conta a receber", kv([["Descricao", esc(c.ds_conta)], ["Pagador", `<button class="fk-link" data-abrir="pessoa:${c.id_pagador}">${esc(c.pagador)}</button> <small class="muted">no papel de ${esc(rotulo(c.tp_papel_pagador))}</small>`],
      ["Categoria", `${esc(c.nm_categoria)} <small class="muted">(a categoria define a natureza da receita, RN26)</small>`], c.id_contrato && ["Contrato", `<button class="fk-link" data-abrir="contrato:${c.id_contrato}">contrato ${c.id_contrato}</button>`],
      ["Competencia", dataBR(c.dt_competencia)], ["Vencimento", dataBR(c.dt_vencimento)], ["Valor", brl(c.vl_receber)], ["Baixado", brl(c.vl_baixado)], ["Situacao", `${st(c.st_conta)} <small class="muted">(derivada das baixas)</small>`]]) +
      `<div class="button-row" style="margin-top:8px">${c.st_conta !== "quitada" && c.st_conta !== "cancelada" ? btn("Registrar recebimento", 'id="cr-baixa"', "primary-button small") : ""}${btn("Ver tabela recebimento", 'data-modelo="recebimento"', "ghost-button small")}</div>`) +
    secao("Baixas (recebimentos)", lista(d.baixas.map((b) => item(`No ${b.nr_recebimento} · ${dataBR(b.dt_recebimento)} · ${esc(b.nm_forma_pagamento)} <small>${esc(b.nm_apelido)}${b.nr_movimento ? " · conciliado com o movimento " + b.nr_movimento : " · nao conciliado"}</small>`,
      `${brl(b.vl_recebido)}${b.repasse ? ` <button class="fk-link" data-abrir="pagar:${b.repasse}">repasse ${b.repasse}: ${brl(b.vl_repasse)}</button>` : ""}`)), "Nenhuma baixa.") +
      regra("Fraca de CONTA_RECEBER: chave (id_conta_receber, nr_recebimento). A soma das baixas nao passa do valor (RN29). Em aluguel, cada baixa, mesmo parcial, gera um repasse ao proprietario (REPASSA, RN30) — feito pelo gatilho tg_recebimento_repasse."), "", "fraca: uma conta, varias baixas");
  abrirDrawer(`Conta a receber ${c.id_conta_receber}`, `${esc(c.pagador)} · ${brl(c.vl_receber)}`, html);
  ligarDrawer();
  const b = $("#cr-baixa");
  if (b) b.onclick = () => formulario({
    titulo: "Registrar recebimento",
    ajuda: `Falta receber ${brl(falta)}. Tente um valor maior para ver o banco recusar (RN29).`,
    campos: [{ n: "id_conta", r: "Conta bancaria", t: "select", op: S.meta.contas.map((x) => [x.id_conta, x.nm_apelido]), v: 2 }, { n: "dt_recebimento", r: "Data", t: "date", v: hoje() },
      { n: "vl_recebido", r: "Valor", t: "number", step: "0.01", v: falta.toFixed(2) }, { n: "id_forma_pagamento", r: "Forma (forma_pagamento)", t: "select", op: S.meta.formas.map((x) => [x.id_forma_pagamento, x.nm_forma_pagamento]) }],
    enviar: async (f) => { const r = await post(`/api/financeiro/receber/${id}/baixa`, f); toast(r.repasse ? `Recebimento gravado. O gatilho gerou o repasse ${r.repasse.id_conta_pagar} (${brl(r.repasse.vl_pagar)}, vence ${dataBR(r.repasse.dt_vencimento)}).` : "Recebimento gravado.", "ok"); await depois(); },
  });
}
async function carregarPagar() {
  const d = await api("/api/financeiro/pagar?" + new URLSearchParams({ situacao: $("#pagar-situacao").value, tipo: $("#pagar-tipo").value, busca: $("#pagar-busca").value }));
  montarTabela($("#pagar-tabela"), [
    { t: "No", v: (c) => c.id_conta_pagar, cls: "num" }, { t: "Descricao", v: (c) => esc(c.ds_conta) }, { t: "Categoria", v: (c) => esc(c.nm_categoria) },
    { t: "Favorecido", v: (c) => esc(c.favorecido || "—") }, { t: "Quem arca", v: (c) => `${esc(rotulo(c.tp_papel_custeio))}${c.custeador ? ` <small class="muted">${esc(c.custeador)}</small>` : ""}` },
    { t: "Vencimento", v: (c) => dataBR(c.dt_vencimento) }, { t: "Valor", v: (c) => brl(c.vl_pagar), cls: "num" }, { t: "Situacao (derivada)", v: (c) => st(c.st_conta) },
  ], d.contas, (c) => abrirContaPagar(c.id_conta_pagar));
}
async function abrirContaPagar(id) {
  S.drawer = { tipo: "pagar", id };
  const d = await api(`/api/financeiro/pagar/${id}`);
  const c = d.conta;
  const falta = Math.max(0, Number(c.vl_pagar) - Number(c.vl_baixado));
  const html = secao("Conta a pagar", kv([["Descricao", esc(c.ds_conta)], ["Categoria", `${esc(c.nm_categoria)} <small class="muted">(define a natureza da despesa, RN26)</small>`],
      ["Favorecido", c.id_favorecido ? `<button class="fk-link" data-abrir="pessoa:${c.id_favorecido}">${esc(c.favorecido)}</button>` : "—"],
      ["Quem arca com o custo", `${esc(rotulo(c.tp_papel_custeio))}${c.custeador ? ` · <button class="fk-link" data-abrir="pessoa:${c.id_custeador}">${esc(c.custeador)}</button>` : ""} <small class="muted">(RN28)</small>`],
      c.id_contrato && ["Contrato", `<button class="fk-link" data-abrir="contrato:${c.id_contrato}">contrato ${c.id_contrato}</button>`],
      c.id_conta_receber_origem && ["Origem (REPASSA)", `<button class="fk-link" data-abrir="receber:${c.id_conta_receber_origem}">recebimento ${c.id_conta_receber_origem}/${c.nr_recebimento_origem}</button> · ${esc(c.origem_ds)} · ${brl(c.origem_valor)} em ${dataBR(c.origem_data)}`],
      d.comissao && ["Comissao (LANCA)", `contrato ${d.comissao.id_contrato} · ${num(d.comissao.pc_comissao)}% = ${brl(d.comissao.vl_comissao)}`],
      ["Vencimento", dataBR(c.dt_vencimento)], ["Valor", brl(c.vl_pagar)], ["Pago", brl(c.vl_baixado)], ["Situacao", st(c.st_conta)]]) +
      `<div class="button-row" style="margin-top:8px">${c.st_conta !== "paga" && c.st_conta !== "cancelada" ? btn("Registrar pagamento", 'id="cp-baixa"', "primary-button small") : ""}${btn("Ver tabela pagamento", 'data-modelo="pagamento"', "ghost-button small")}</div>`) +
    secao("Baixas (pagamentos)", lista(d.baixas.map((b) => item(`No ${b.nr_pagamento} · ${dataBR(b.dt_pagamento)} · ${esc(b.nm_forma_pagamento)} <small>${esc(b.nm_apelido)} · efetivado por ${esc(b.efetivado_por)}${b.nr_movimento ? " · conciliado" : ""}</small>`, brl(b.vl_pago))), "Nenhuma baixa.") +
      regra("Quem efetiva o pagamento e o usuario que esta agindo (id_usuario): precisa ser administrador ou financeiro (RN39), e comissao so pelo administrador (PO01). Troque “Agindo como” no topo para ver o banco recusar."));
  abrirDrawer(`Conta a pagar ${c.id_conta_pagar}`, `${esc(c.nm_categoria)} · ${brl(c.vl_pagar)}`, html);
  ligarDrawer();
  const b = $("#cp-baixa");
  if (b) b.onclick = () => formulario({
    titulo: "Registrar pagamento",
    ajuda: `Agindo como <b>${esc(nomeUsuario(S.usuario))}</b>. Falta pagar ${brl(falta)}.`,
    campos: [{ n: "id_conta", r: "Conta bancaria", t: "select", op: S.meta.contas.map((x) => [x.id_conta, x.nm_apelido]) }, { n: "dt_pagamento", r: "Data", t: "date", v: hoje() },
      { n: "vl_pago", r: "Valor", t: "number", step: "0.01", v: falta.toFixed(2) }, { n: "id_forma_pagamento", r: "Forma (forma_pagamento)", t: "select", op: S.meta.formas.map((x) => [x.id_forma_pagamento, x.nm_forma_pagamento]) }],
    enviar: async (f) => { await post(`/api/financeiro/pagar/${id}/baixa`, f); toast("Pagamento gravado.", "ok"); await depois(); },
  });
}
function novaDespesa() {
  formulario({
    titulo: "Nova despesa",
    ajuda: "Quem arca com o custo: a imobiliaria (sem pessoa), o proprietario ou o inquilino (pessoa obrigatoria, no papel certo — CHECK e gatilho, RN28). A categoria precisa ser de despesa (RN26); repasses e comissoes sao gerados pelo sistema.",
    campos: [{ n: "ds_conta", r: "Descricao", full: true, obrig: true }, { n: "vl_pagar", r: "Valor", t: "number", step: "0.01", obrig: true }, { n: "dt_vencimento", r: "Vencimento", t: "date", v: hoje() },
      { n: "id_categoria", r: "Categoria", t: "select", op: S.meta.categorias.filter((x) => x.tp_categoria === "despesa" && !["repasse", "comissao"].includes(x.cd_categoria)).map((x) => [x.id_categoria, x.nm_categoria]) },
      { n: "tp_papel_custeio", r: "Quem arca", t: "select", op: [["imobiliaria", "imobiliaria"], ["proprietario", "proprietario"], ["inquilino", "inquilino"]] },
      { n: "id_custeador", r: "Pessoa que arca (proprietario/inquilino)", t: "select", op: [["", "—"], ...S.meta.proprietarios.map((u) => [u.id_usuario, u.nm_usuario + " (proprietario)"]), ...S.meta.inquilinos.map((u) => [u.id_usuario, u.nm_usuario + " (inquilino)"])] },
      { n: "id_favorecido", r: "Favorecido (fornecedor)", t: "select", op: [["", "—"], ...S.meta.fornecedores.map((u) => [u.id_usuario, u.nm_usuario])] }],
    enviar: async (f) => { const r = await post("/api/financeiro/despesas", f); toast(`Despesa ${r.id_conta_pagar} lancada.`, "ok"); await recarregarView(); abrirContaPagar(r.id_conta_pagar); },
  });
}
async function carregarConciliacao() {
  const d = await api("/api/conciliacao?" + new URLSearchParams({ conta: S.conciliacao.conta || "" }));
  S.conciliacao.conta = d.conta;
  $("#conciliacao-contas").innerHTML = d.contas.map((c) => `<button class="${c.id_conta === d.conta ? "primary-button" : "secondary-button"}" data-conta="${c.id_conta}">${esc(c.nm_apelido)} <small>(${c.pendentes} a conciliar)</small></button>`).join("") +
    `<p class="hint">Escolha um movimento do extrato (a esquerda) e clique em “conciliar” na baixa correspondente. O banco confere a conta, a direcao (credito × debito) e o valor (RN45).</p>`;
  $$("[data-conta]").forEach((b) => (b.onclick = () => { S.conciliacao = { conta: Number(b.dataset.conta), movimento: null }; carregarConciliacao(); }));
  const sel = S.conciliacao.movimento;
  montarTabela($("#conciliacao-movimentos"), [
    { t: "", v: (m) => `<input type="radio" name="mov" ${sel === m.nr_movimento ? "checked" : ""}>` }, { t: "No", v: (m) => m.nr_movimento, cls: "num" }, { t: "Data", v: (m) => dataBR(m.dt_movimento) },
    { t: "Historico", v: (m) => `${esc(m.ds_historico || "")} <small class="muted mono">${esc(m.cd_transacao_banco)}</small>` }, { t: "Tipo", v: (m) => esc(rotulo(m.tp_movimento)) },
    { t: "Valor", v: (m) => brl(m.vl_movimento), cls: "num" }, { t: "Conciliado", v: (m) => brl(m.vl_conciliado), cls: "num" }, { t: "Situacao", v: (m) => st(m.st_conciliacao) },
  ], d.movimentos, (m) => { S.conciliacao.movimento = m.nr_movimento; carregarConciliacao(); }, "Sem movimentos.");
  montarTabela($("#conciliacao-baixas"), [
    { t: "Tipo", v: (b) => esc(b.tipo) }, { t: "Data", v: (b) => dataBR(b.data) }, { t: "Descricao", v: (b) => `${esc(b.ds_conta)} <small class="muted">${esc(b.pessoa)}</small>` },
    { t: "Valor", v: (b) => brl(b.valor), cls: "num" },
    { t: "Movimento", v: (b) => b.nr_movimento ? `no ${b.nr_movimento} <button class="ghost-button small" data-desfazer="${esc(JSON.stringify(b))}">desfazer</button>` : (sel ? `<button class="secondary-button small" data-conciliar="${esc(JSON.stringify(b))}">conciliar com no ${sel}</button>` : '<span class="muted">—</span>') },
  ], d.baixas, null, "Sem baixas nesta conta.");
  $$("[data-conciliar]").forEach((b) => (b.onclick = async () => { const x = JSON.parse(b.dataset.conciliar); await acao(() => post("/api/conciliacao", { ...x, nr_movimento: sel }), "Conciliado."); carregarConciliacao(); }));
  $$("[data-desfazer]").forEach((b) => (b.onclick = async () => { const x = JSON.parse(b.dataset.desfazer); await acao(() => post("/api/conciliacao", { ...x, nr_movimento: null }), "Conciliacao desfeita."); carregarConciliacao(); }));
}

// ---------------------------------------------------------------------------------------------
// automacao N8N
// ---------------------------------------------------------------------------------------------
async function carregarAutomacao() {
  const [d, p] = await Promise.all([api("/api/automacao"), api("/api/integration/leads/pending")]);
  const el = $("#view-automacao");
  el.innerHTML = `<div class="two-cols">
    <section class="panel"><div class="panel-head"><h2>API de integracao (N8N)</h2><span class="muted">mesmos caminhos do app original, agora sobre o banco</span></div>
      <ul class="n8n-doc">
        <li><code>GET /api/integration/leads/pending</code> — conversas abertas com mensagem recebida depois da ultima execucao (${p.count} agora)</li>
        <li><code>GET /api/integration/leads/&lt;id&gt;</code> — lead, mensagens e a demanda (vinda do perfil de interesse)</li>
        <li><code>POST /api/integration/selector/search</code> — seletor de imoveis pelo perfil</li>
        <li><code>POST /api/integration/leads/&lt;id&gt;/automation-result</code> — grava a execucao (RN31: a mesma demanda nao e processada duas vezes)</li>
        <li><code>POST /api/integration/leads/&lt;id&gt;/automation-log</code> — grava um passo no log da execucao</li>
        <li><code>POST /api/integration/whatsapp/mensagem</code> — webhook de mensagem recebida (RN31: o mesmo wamid e recusado)</li>
      </ul>
      <p class="muted">Token opcional no cabecalho <code>X-Integration-Token</code> (variavel CRM_INTEGRATION_TOKEN), como no app original.</p></section>
    <section class="panel"><div class="panel-head"><h2>Simular o fluxo</h2><span class="muted">o que o N8N faria</span></div>
      <div class="form-grid two">
        <label class="field"><span>Conversa (lead)</span><select id="n8n-lead">${p.leads.map((l) => `<option value="${l.lead_id}">${l.lead_id} · ${esc(l.nome)}</option>`).join("") || '<option value="">nenhuma pendente</option>'}</select></label>
        <label class="field"><span>wamid da mensagem</span><input id="n8n-wamid" value="wamid.TESTE${Date.now().toString().slice(-6)}"></label>
      </div>
      <div class="button-row wrap">${btn("1. Ler lead e demanda", 'id="n8n-ler"')}${btn("2. Consultar seletor", 'id="n8n-seletor"')}${btn("3. Registrar envio", 'id="n8n-resultado"')}${btn("Webhook: mensagem recebida", 'id="n8n-msg"')}</div>
      <pre class="codigo" id="n8n-saida" style="margin-top:10px;max-height:240px">Clique nos passos. Tente registrar o envio duas vezes ou mandar a mesma mensagem (mesmo wamid) duas vezes: o banco recusa a repeticao (RN31).</pre></section></div>
    <section class="panel" style="margin-top:14px"><div class="panel-head"><h2>Execucoes</h2><span class="muted">${d.resumo.map((r) => `${rotulo(r.st_execucao)}: ${r.qt}`).join(" · ")}</span></div>
      <div class="lista">${d.execucoes.map((e) => `<div data-conversa="${e.id_conversa}" style="cursor:pointer">${execucaoHTML(e)}</div>`).join("")}</div></section>`;
  $$("[data-conversa]", el).forEach((x) => (x.onclick = () => abrirConversa(Number(x.dataset.conversa))));
  const saida = (o) => ($("#n8n-saida").textContent = typeof o === "string" ? o : JSON.stringify(o, null, 2));
  const lead = () => $("#n8n-lead").value;
  let ultimo = null;
  $("#n8n-ler").onclick = async () => { try { ultimo = await api(`/api/integration/leads/${lead()}`); saida(ultimo); } catch (e) { saida(erroTexto(e)); } };
  $("#n8n-seletor").onclick = async () => { try { saida(await post("/api/integration/selector/search", { lead_id: lead(), max_results: 3 })); } catch (e) { saida(erroTexto(e)); } };
  $("#n8n-resultado").onclick = async () => {
    try {
      const l = ultimo?.lead?.id_conversa == lead() ? ultimo : await api(`/api/integration/leads/${lead()}`);
      const sel = await post("/api/integration/selector/search", { lead_id: lead(), max_results: 3 }).catch(() => ({ opcoes: [] }));
      const msg = `${(l.lead.nome || "").split(" ")[0]}, separei ${sel.opcoes.length} opcoes para voce: ${sel.opcoes.map((o) => o.cd_imobizi).join(", ")}`;
      saida(await post(`/api/integration/leads/${lead()}/automation-result`, { status: "enviada", demanda: l.demanda || {}, mensagem: msg, resumo: "Simulacao pelo prototipo",
        logs: [{ evento: "demanda_recebida", descricao: "Simulacao" }, { evento: "seletor_consultado", descricao: `${sel.opcoes.length} imoveis` }, { evento: "disparo_enviado", descricao: "Mensagem registrada" }] }));
    } catch (e) { saida(erroTexto(e)); }
  };
  $("#n8n-msg").onclick = async () => { try { saida(await post("/api/integration/whatsapp/mensagem", { lead_id: lead(), wamid: $("#n8n-wamid").value, texto: "Oi! Ainda tem opcoes nessa regiao?" })); } catch (e) { saida(erroTexto(e)); } };
}

// ---------------------------------------------------------------------------------------------
// auditoria e consultas
// ---------------------------------------------------------------------------------------------
async function carregarAuditoria() {
  const d = await api("/api/auditoria?" + new URLSearchParams({ tabela: $("#aud-tabela").value, acao: $("#aud-acao").value, usuario: $("#aud-usuario").value }));
  const su = $("#aud-usuario");
  const atual = su.value;
  su.innerHTML = `<option value="">Todos</option>` + d.usuarios.map((u) => `<option value="${u.id_usuario}">${esc(u.nm_usuario)}</option>`).join("");
  su.value = atual;
  montarTabela($("#aud-tabela-lista"), [
    { t: "No", v: (a) => a.id_auditoria, cls: "num" }, { t: "Quando", v: (a) => dataHoraBR(a.dt_acao) }, { t: "Usuario", v: (a) => esc(a.usuario) },
    { t: "Acao", v: (a) => st(a.tp_acao) }, { t: "Registro (uma das 7 FKs)", v: (a) => esc(a.registro) },
    { t: "Campos alterados (auditoria_campo)", v: (a) => a.campos.length ? `<span class="mono">${a.campos.map((f) => `${esc(f.campo)}: ${esc(f.antes ?? "∅")} → ${esc(f.depois ?? "∅")}`).join("<br>")}</span>` : '<span class="muted">—</span>' },
  ], d.registros);
}
async function carregarConsultas(tipo) {
  if (!S.consultasCache) S.consultasCache = await api("/api/consultas");
  const itens = S.consultasCache[tipo];
  const el = $(tipo === "gerenciais" ? "#gerenciais-lista" : "#verificacoes-lista");
  el.innerHTML = itens.map((c) => `<article class="consulta" id="consulta-${c.id}"><header data-id="${c.id}"><span class="id">${c.id}</span><div><h3>${esc(c.titulo)}</h3><p>${esc(c.pergunta || c.verifica)}</p></div>${btn("Executar", "", "secondary-button small")}</header><div class="resultado" hidden></div></article>`).join("");
  $$("header[data-id]", el).forEach((h) => (h.onclick = () => abrirConsulta(h.dataset.id)));
}
async function abrirConsulta(id) {
  const art = $(`#consulta-${id}`);
  if (!art) return;
  const box = $(".resultado", art);
  if (!box.hidden && box.dataset.ok) { box.hidden = true; return; }
  box.hidden = false;
  box.innerHTML = '<span class="muted">Executando…</span>';
  art.scrollIntoView({ behavior: "smooth", block: "start" });
  try {
    const r = await api(`/api/consultas/${id}`);
    box.dataset.ok = "1";
    box.innerHTML = `<p class="decisao ${r.acao ? "acao" : ""}"><b>${r.decisao ? "Decisao" : "O que fazer"}:</b> ${esc(r.decisao || r.acao)}</p>
      <div class="table-wrap" style="max-height:360px">${tabelaSimples(r.colunas, r.linhas)}</div><p class="muted">${r.total} linha(s)</p>
      <details class="sql"><summary>SQL</summary><pre class="codigo">${esc(r.sql)}</pre></details>`;
  } catch (e) { box.innerHTML = `<div class="erro-banco">${erroHTML(e)}</div>`; }
}

// ---------------------------------------------------------------------------------------------
// modelo logico
// ---------------------------------------------------------------------------------------------
async function carregarModelo() {
  if (!S.modelo.lista.length) {
    const d = await api("/api/modelo");
    S.modelo.lista = d.tabelas;
    S.modelo.grupos = d.grupos;
    S.modelo.folhas = d.folhas;
    S.modelo.visoes = d.visoes;
    S.modelo.alteracoes = d.alteracoes;
  }
  const idx = $("#modelo-indice");
  idx.innerHTML = `<input id="modelo-busca" type="search" placeholder="Filtrar tabelas">
    <p class="muted" style="margin:0 0 6px">${S.modelo.lista.length} tabelas · ${S.modelo.lista.reduce((a, t) => a + t.linhas, 0)} linhas</p>` +
    S.modelo.grupos.map((g) => `<div class="grupo"><div class="grupo-titulo"><i style="background:${g.cor}"></i>${esc(g.nome)}</div>${S.modelo.lista.filter((t) => t.area === g.nome).map((t) =>
      `<button class="tabela-link ${t.nome === S.modelo.tabela ? "ativa" : ""}" data-t="${t.nome}"><span class="mono">${t.nome}</span><small>${t.linhas}</small></button>`).join("")}</div>`).join("");
  $$(".tabela-link", idx).forEach((b) => (b.onclick = () => { S.modelo.tabela = b.dataset.t; S.modelo.aba = "colunas"; carregarModelo(); }));
  $("#modelo-busca").oninput = (ev) => { const q = ev.target.value.toLowerCase(); $$(".tabela-link", idx).forEach((b) => (b.style.display = b.dataset.t.includes(q) ? "" : "none")); };
  if (!S.modelo.tabela) S.modelo.tabela = "usuario";
  await mostrarTabela(S.modelo.tabela);
}
function tipoColuna(c) {
  const t = { "character varying": "varchar", character: "char", "timestamp without time zone": "timestamp" }[c.tipo] || c.tipo;
  if (c.tamanho) return `${t}(${c.tamanho})`;
  if (c.tipo === "numeric") return `numeric(${c.precisao},${c.escala})`;
  return t;
}
async function mostrarTabela(nome) {
  const d = await api(`/api/modelo/${nome}`);
  const m = d.meta;
  const info = S.modelo.lista.find((t) => t.nome === nome);
  const el = $("#modelo-detalhe");
  const abas = [["colunas", `Colunas (${d.colunas.length})`], ["relacionamentos", `Chaves estrangeiras (${m.fks.length} + ${d.referenciada_por.length})`], ["restricoes", `Restricoes (${d.restricoes.length})`], ["gatilhos", `Gatilhos e indices (${d.gatilhos.length + d.indices.length})`], ["dados", `Dados (${info.linhas})`]];
  el.innerHTML = `<h2>${esc(nome)}</h2>
    <div class="sub"><span class="st" style="background:${info.cor};color:#fff">${esc(info.area)}</span><span class="st info">${esc(m.entidade)}</span><span class="st off">${esc(m.tipo)}</span>
      <span class="muted">folha ${m.folha} do diagrama · ${info.linhas} linha(s)</span> <button class="fk-link" id="md-folha">ver diagrama</button></div>
    <p style="margin:0 0 8px">${esc(info.descricao)}</p>
    ${regra(`<b>Chave primaria (${esc(m.pk_tipo)}):</b> <span class="mono">${esc(m.pk.join(", "))}</span> — ${esc(m.pk_por_que)}`)}
    <div class="abas">${abas.map(([k, t]) => `<button class="aba ${S.modelo.aba === k ? "ativa" : ""}" data-aba="${k}">${t}</button>`).join("")}</div>
    <div id="md-conteudo"></div>`;
  $$(".aba", el).forEach((b) => (b.onclick = () => { S.modelo.aba = b.dataset.aba; mostrarTabela(nome); }));
  $("#md-folha").onclick = () => { S.diagramaFolha = m.folha; setView("diagramas"); };
  const box = $("#md-conteudo");
  const aba = S.modelo.aba;
  if (aba === "colunas") {
    montarTabela(box, [
      { t: "Coluna", v: (c) => `${c.pk ? '<span class="chave pk">PK</span>' : ""}${c.fk ? '<span class="chave fk">FK</span>' : ""}${c.uk ? '<span class="chave uk">UK</span>' : ""}<span class="mono">${esc(c.nome)}</span>` },
      { t: "Tipo", v: (c) => `<span class="mono">${esc(tipoColuna(c))}</span>${c.identidade ? ' <small class="muted">identidade</small>' : ""}` },
      { t: "Nulo", v: (c) => (c.aceita_nulo ? "permitido" : "<b>NOT NULL</b>") }, { t: "Padrao", v: (c) => `<span class="mono">${esc((c.padrao || "").replace(/::[a-z ]+/g, "") || "—")}</span>` },
      { t: "Descricao (COMMENT ON)", v: (c) => esc(c.descricao || "—") },
    ], d.colunas);
  } else if (aba === "relacionamentos") {
    box.innerHTML = `<h3 style="font-size:14px">Chaves estrangeiras desta tabela (relacionamentos do DER)</h3>${m.fks.length ? "" : '<div class="vazio">Nenhuma: tabela sem chave estrangeira.</div>'}<div id="md-fks"></div>
      <h3 style="font-size:14px;margin-top:16px">Tabelas que apontam para ${esc(nome)}</h3><div id="md-refs"></div>`;
    if (m.fks.length) montarTabela($("#md-fks"), [
      { t: "Restricao", v: (f) => `<span class="mono">${esc(f.nome)}</span>` }, { t: "Colunas → tabela", v: (f) => `<span class="mono">${esc(f.colunas.join(", "))}</span> → <button class="fk-link" data-ir-tabela="${f.ref}">${esc(f.ref)}</button>` },
      { t: "Relacionamento", v: (f) => `<b>${esc(f.relacionamento)}</b><br><small class="muted">${esc(f.cardinalidade)}</small>` }, { t: "Regra", v: (f) => esc(f.regra) },
      { t: "Ao excluir o referenciado", v: (f) => `<b>${esc(f.ao_excluir)}</b>${f.ao_atualizar !== "NO ACTION" ? ` · ao atualizar: ${esc(f.ao_atualizar)}` : ""}<br><small class="muted">${esc(f.por_que)}</small>` },
    ], m.fks);
    montarTabela($("#md-refs"), [{ t: "Tabela", v: (r) => `<button class="fk-link" data-ir-tabela="${r.tabela}">${esc(r.tabela)}</button>` }, { t: "Restricao", v: (r) => `<span class="mono">${esc(r.nome)}</span>` }, { t: "Definicao", v: (r) => `<span class="mono">${esc(r.definicao)}</span>` }], d.referenciada_por, null, "Nenhuma tabela aponta para esta.");
    $$("[data-ir-tabela]", box).forEach((b) => (b.onclick = () => { S.modelo.tabela = b.dataset.irTabela; carregarModelo(); }));
  } else if (aba === "restricoes") {
    const tipos = { p: "PRIMARY KEY", f: "FOREIGN KEY", u: "UNIQUE", c: "CHECK" };
    montarTabela(box, [
      { t: "Tipo", v: (k) => `<b>${tipos[k.tipo] || k.tipo}</b>` }, { t: "Nome", v: (k) => `<span class="mono">${esc(k.nome)}</span>` },
      { t: "Definicao", v: (k) => `<span class="mono">${esc(k.definicao)}</span>` }, { t: "Por que existe", v: (k) => esc(k.por_que || "—") },
    ], d.restricoes);
  } else if (aba === "gatilhos") {
    box.innerHTML = `<div id="md-trig"></div><h3 style="font-size:14px;margin-top:16px">Indices</h3><div id="md-idx"></div>`;
    montarTabela($("#md-trig"), [{ t: "Gatilho", v: (g) => `<span class="mono">${esc(g.nome)}</span>` }, { t: "Funcao", v: (g) => `<span class="mono">${esc(g.funcao)}</span>` }, { t: "Regra garantida", v: (g) => esc(g.por_que || "—") }, { t: "Definicao", v: (g) => `<span class="mono" style="font-size:11px">${esc(g.definicao)}</span>` }], d.gatilhos, null, "Nenhum gatilho nesta tabela.");
    montarTabela($("#md-idx"), [{ t: "Indice", v: (i) => `<span class="mono">${esc(i.nome)}</span>` }, { t: "Definicao", v: (i) => `<span class="mono" style="font-size:11px">${esc(i.definicao)}</span>` }], d.indices);
  } else {
    await abaDados(nome, info, box);
  }
}
// aba Dados: procurar em qualquer tabela (texto em todas as colunas) e, na tabela imovel, pelos filtros da busca de imoveis (RF37)
const SITUACOES_IMOVEL = ["disponivel", "reservado", "alugado", "vendido", "inativo"];
async function abaDados(nome, info, box) {
  const f = S.modelo.filtro[nome] || (S.modelo.filtro[nome] = {});
  const im = nome === "imovel";
  const sel = (n, rot, ops, todos = "Todos") => `<label class="field"><span>${rot}</span><select name="${n}"><option value="">${todos}</option>${ops.map(([v, l]) =>
    `<option value="${esc(v)}" ${String(f[n] ?? "") === String(v) ? "selected" : ""}>${esc(l)}</option>`).join("")}</select></label>`;
  const opB = (cid) => bairrosDa(cid).map((b) => [b.id_bairro, cid ? b.nm_bairro : `${b.nm_bairro} (${b.nm_cidade})`]);
  box.innerHTML = `<form class="toolbar busca-dados" id="md-busca" autocomplete="off">
      <label class="field compact"><span>${im ? "Procurar (codigo, rua, bairro, tipo ou proprietario)" : "Procurar em todas as colunas"}</span>
        <input name="busca" type="search" value="${esc(f.busca || "")}" placeholder="${im ? "ex.: Tatuape ou IMB-3519" : "digite e tecle Enter"}"></label>
      ${im ? sel("tipo", "Tipo", S.meta.tipos_imovel.map((t) => [t.id_tipo_imovel, t.nm_tipo_imovel])) +
        sel("finalidade", "Finalidade", [["venda", "Venda"], ["locacao", "Locacao"]], "Todas") +
        sel("situacao", "Situacao", SITUACOES_IMOVEL.map((s) => [s, s]), "Todas") +
        sel("cidade", "Cidade", S.meta.cidades.map((c) => [c.id_cidade, `${c.nm_cidade}/${c.sg_uf}`]), "Todas") +
        sel("bairro", "Bairro", opB(f.cidade)) +
        `<label class="field"><span>Quartos (min.)</span><input name="quartos" type="number" min="0" value="${esc(f.quartos || "")}" style="width:90px"></label>
         <label class="field"><span>Valor ate (R$)</span><input name="valor_max" type="number" min="0" step="0.01" value="${esc(f.valor_max || "")}" style="width:130px"></label>` : ""}
      <div class="button-row"><button class="primary-button small" type="submit">Procurar</button><button class="ghost-button small" type="button" id="md-limpar">Limpar</button></div>
    </form><div id="md-resultado"><div class="vazio">Carregando...</div></div>`;
  const form = $("#md-busca");
  if (im) form.elements.cidade.onchange = () => { form.elements.bairro.innerHTML = '<option value="">Todos</option>' + opB(form.elements.cidade.value).map(([v, l]) => `<option value="${v}">${esc(l)}</option>`).join(""); };
  form.onsubmit = (ev) => { ev.preventDefault(); S.modelo.filtro[nome] = Object.fromEntries(new FormData(form)); abaDados(nome, info, box); };
  $("#md-limpar").onclick = () => { S.modelo.filtro[nome] = {}; abaDados(nome, info, box); };
  const p = new URLSearchParams({ limite: 100, ...Object.fromEntries(Object.entries(f).filter(([, v]) => String(v).trim() !== "")) });
  const r = await api(`/api/modelo/${nome}/dados?${p}`);
  const out = $("#md-resultado");
  out.innerHTML = `<p class="muted" style="margin:6px 0">${r.filtrado ? `<b>${r.total}</b> linha(s) encontrada(s) de ${info.linhas}` : `${r.linhas.length} de ${r.total} linha(s)`}, na ordem da chave primaria${r.linhas.length < r.total ? ` (mostrando as ${r.linhas.length} primeiras)` : ""}.${im && r.linhas.length ? " Clique numa linha para abrir o imovel." : ""}</p>
    ${im ? regra("As primeiras colunas, com ponto no nome (<span class=\"mono\">bairro.nm_bairro</span>, <span class=\"mono\">cidade.nm_cidade</span>...), nao sao da tabela imovel: vem das tabelas ligadas pelas chaves estrangeiras (JOIN). Depois delas vem as colunas da propria tabela imovel. O bairro e procurado pela chave <span class=\"mono\">id_bairro</span>, e nao por um texto digitado: por isso a busca nao erra com Tatuape escrito de outro jeito.") : ""}
    <div class="table-wrap dados-tabela" style="max-height:calc(100vh - 470px)">${tabelaSimples(r.colunas, r.linhas)}</div>
    <details class="sql" ${r.filtrado ? "open" : ""}><summary>SQL executado</summary><pre class="codigo">${esc(r.sql)}</pre></details>`;
  r.colunas.forEach((c, n) => { if (c.includes(".")) $$(`.dados-tabela tr > :nth-child(${n + 1})`, out).forEach((x) => x.classList.add("col-join")); });
  if (im) {
    const k = r.colunas.indexOf("id_imovel");
    $$("tbody tr", out).forEach((tr, n) => { tr.classList.add("clicavel"); tr.onclick = () => abrirImovel(r.linhas[n][k]); });
  }
}
function carregarDiagramas() {
  const el = $("#view-diagramas");
  const render = () => {
    el.innerHTML = `<section class="panel"><div class="panel-head"><h2>Folhas do modelo logico</h2><span class="muted">sem nenhuma linha cruzando outra · clique para ampliar</span></div>
      <div class="button-row wrap">${S.modelo.folhas.map((f, i) => `<button class="${S.diagramaFolha === i + 1 ? "primary-button" : "secondary-button"} small" data-folha="${i + 1}">${i + 1}. ${esc(f)}</button>`).join("")}</div>
      <div class="diagramas" style="margin-top:12px">${S.modelo.folhas.map((f, i) => (S.diagramaFolha && S.diagramaFolha !== i + 1) ? "" : `<figure><figcaption>Folha ${i + 1} — ${esc(f)}</figcaption><a href="/docs/modelo-logico/logico-${i + 1}.png" target="_blank"><img loading="lazy" src="/docs/modelo-logico/logico-${i + 1}.png" alt="Modelo logico folha ${i + 1}"></a></figure>`).join("")}</div></section>
      <section class="panel" style="margin-top:14px"><div class="panel-head"><h2>Do app original a entrega final</h2><span class="muted">o que mudou, como era, como ficou e por que (Etapa 2)</span></div>
      <div class="table-wrap tall" id="dg-alteracoes"></div></section>
      <section class="panel" style="margin-top:14px"><div class="panel-head"><h2>Visoes dos atributos derivados</h2><span class="muted">calculados na consulta, nunca armazenados (3FN)</span></div>
      ${S.modelo.visoes.map((v) => `<details class="sql"><summary class="mono">${esc(v.viewname)}</summary><pre class="codigo">${esc(v.definition.trim())}</pre></details>`).join("")}</section>`;
    montarTabela($("#dg-alteracoes"), [{ t: "Fase", v: (a) => st(a.fase) }, { t: "O que foi alterado", v: (a) => `<b>${esc(a.item)}</b>` }, { t: "Como era", v: (a) => esc(a.antes) }, { t: "Como ficou", v: (a) => esc(a.depois) }, { t: "Por que", v: (a) => esc(a.porque) }], S.modelo.alteracoes);
    $$("[data-folha]", el).forEach((b) => (b.onclick = () => { const n = Number(b.dataset.folha); S.diagramaFolha = S.diagramaFolha === n ? null : n; render(); }));
  };
  if (!S.modelo.lista.length) return api("/api/modelo").then((d) => { Object.assign(S.modelo, { lista: d.tabelas, grupos: d.grupos, folhas: d.folhas, visoes: d.visoes, alteracoes: d.alteracoes }); render(); });
  render();
}
const EXEMPLOS_SQL = [
  ["Pessoas com mais de um papel", "SELECT u.nm_usuario, count(*) AS papeis\n  FROM usuario u\n  JOIN (SELECT id_usuario FROM cliente UNION ALL SELECT id_usuario FROM proprietario UNION ALL SELECT id_usuario FROM inquilino\n        UNION ALL SELECT id_usuario FROM corretor) p USING (id_usuario)\n GROUP BY u.nm_usuario HAVING count(*) > 1;"],
  ["Telefones compartilhados", "SELECT t.nr_telefone, u.nm_usuario, t.nr_sequencia, t.fl_titular\n  FROM telefone t JOIN usuario u USING (id_usuario)\n WHERE t.nr_telefone IN (SELECT nr_telefone FROM telefone GROUP BY 1 HAVING count(*) > 1)\n ORDER BY t.nr_telefone, t.fl_titular DESC;"],
  ["Imoveis por tipo", "SELECT t.nm_tipo_imovel AS tipo, count(i.id_imovel) AS imoveis\n  FROM tipo_imovel t LEFT JOIN imovel i USING (id_tipo_imovel)\n GROUP BY t.nm_tipo_imovel ORDER BY imoveis DESC;"],
  ["Tipos aceitos por perfil (N:N)", "SELECT u.nm_usuario, p.nr_perfil, string_agg(t.nm_tipo_imovel, ', ') AS tipos\n  FROM perfil_interesse p JOIN usuario u USING (id_usuario)\n  LEFT JOIN perfil_interesse_tipo pt USING (id_usuario, nr_perfil)\n  LEFT JOIN tipo_imovel t USING (id_tipo_imovel)\n GROUP BY u.nm_usuario, p.nr_perfil ORDER BY 1, 2;"],
  ["Repasses gerados por recebimento", "SELECT cr.ds_conta, r.nr_recebimento, r.vl_recebido, cp.id_conta_pagar AS repasse, cp.vl_pagar\n  FROM recebimento r JOIN conta_receber cr USING (id_conta_receber)\n  JOIN conta_pagar cp ON cp.id_conta_receber_origem = r.id_conta_receber AND cp.nr_recebimento_origem = r.nr_recebimento\n ORDER BY r.dt_recebimento DESC LIMIT 20;"],
  ["Bairro, cidade e UF do imovel pelas chaves (3FN)", "SELECT i.cd_imobizi, b.nm_bairro, i.nr_cep, c.nm_cidade, uf.nm_uf\n  FROM imovel i\n  JOIN bairro b ON b.id_bairro = i.id_bairro\n  JOIN cep ON cep.nr_cep = i.nr_cep\n  JOIN cidade c ON c.id_cidade = cep.id_cidade\n  JOIN uf ON uf.sg_uf = c.sg_uf\n ORDER BY c.nm_cidade, b.nm_bairro;"],
  ["Tentar apagar (recusado)", "DELETE FROM tag;"],
];
function carregarSQL() {
  $("#sql-exemplos").innerHTML = EXEMPLOS_SQL.map(([t], i) => `<button class="ghost-button small" data-ex="${i}">${esc(t)}</button>`).join("");
  $$("[data-ex]").forEach((b) => (b.onclick = () => { $("#sql-texto").value = EXEMPLOS_SQL[b.dataset.ex][1]; rodarSQL(); }));
}
async function rodarSQL() {
  const out = $("#sql-resultado");
  out.innerHTML = '<span class="muted">Executando…</span>';
  try {
    const r = await post("/api/sql", { sql: $("#sql-texto").value });
    $("#sql-info").textContent = `${r.total}${r.cortado ? "+" : ""} linha(s)`;
    out.innerHTML = tabelaSimples(r.colunas, r.linhas);
  } catch (e) { $("#sql-info").textContent = ""; out.innerHTML = `<div class="erro-banco">${erroHTML(e)}</div>`; }
}

// ---------------------------------------------------------------------------------------------
// inicio
// ---------------------------------------------------------------------------------------------
async function carregarMeta() {
  S.meta = await api("/api/meta");
  const sel = $("#usuario-atual");
  sel.innerHTML = S.meta.internos.map((u) => `<option value="${u.id_usuario}">${esc(u.nm_usuario)} — ${esc(u.papeis)}${u.encerrado ? " (encerrado)" : ""}</option>`).join("");
  sel.value = S.usuario;
  const opc = (el, itens, todos) => { const v = el.value; el.innerHTML = `<option value="">${todos}</option>` + itens.join(""); el.value = v; };
  opc($("#crm-corretor"), S.meta.corretores.map((u) => `<option value="${u.id_usuario}">${esc(u.nm_usuario)}${u.dt_fim ? " (saiu)" : ""}</option>`), "Todos");
  opc($("#crm-tag"), S.meta.tags.map((t) => `<option value="${t.id_tag}">${esc(t.nm_tag)}</option>`), "Todas");
  opc($("#pessoas-papel"), S.meta.papeis.map((p) => `<option value="${p}">${esc(rotulo(p))}</option>`), "Todos");
  opc($("#imoveis-cidade"), S.meta.cidades.map((c) => `<option value="${c.id_cidade}">${esc(c.nm_cidade)}/${esc(c.sg_uf)}</option>`), "Todas");
  opc($("#imoveis-tipo"), S.meta.tipos_imovel.map((t) => `<option value="${t.id_tipo_imovel}">${esc(t.nm_tipo_imovel)}</option>`), "Todos");
  opc($("#pagar-tipo"), S.meta.categorias.filter((x) => x.tp_categoria === "despesa").map((x) => `<option value="${esc(x.cd_categoria)}">${esc(x.nm_categoria)}</option>`), "Todas");
}
async function iniciar() {
  try {
    const h = await api("/api/health");
    $("#health-status").textContent = `Banco ${h.banco} · ${h.tabelas} tabelas`;
  } catch (e) {
    $("#health-status").textContent = "Sem conexao com o banco";
    document.querySelector(".workspace").insertAdjacentHTML("afterbegin", `<div class="erro-banco"><b>Nao consegui conectar ao PostgreSQL.</b>${esc(e.dados?.erro || e.message)}<br>${esc(e.dados?.dica || "")}</div>`);
    return;
  }
  await carregarMeta();
  $$("[data-view]").forEach((b) => b.addEventListener("click", () => setView(b.dataset.view)));
  $("#usuario-atual").onchange = (ev) => { S.usuario = Number(ev.target.value); try { localStorage.setItem("crmoveis.usuario", S.usuario); } catch (_) {} toast(`Agindo como ${nomeUsuario(S.usuario)}.`); recarregarDrawer(); };
  $("#drawer-fechar").onclick = fecharDrawer;
  $("#modal-fechar").onclick = fecharModal;
  $("#modal").addEventListener("click", (ev) => { if (ev.target.id === "modal") fecharModal(); });
  document.addEventListener("keydown", (ev) => { if (ev.key === "Escape") { if (!$("#modal").hidden) fecharModal(); else fecharDrawer(); } });
  const recarregar = debounce(recarregarView);
  ["#crm-busca", "#pessoas-busca", "#imoveis-busca", "#receber-busca", "#pagar-busca"].forEach((s) => $(s).addEventListener("input", recarregar));
  ["#crm-corretor", "#crm-tag", "#crm-situacao", "#pessoas-papel", "#imoveis-cidade", "#imoveis-bairro", "#imoveis-finalidade", "#imoveis-tipo", "#imoveis-situacao", "#imoveis-quartos", "#seletor-perfil",
    "#visitas-situacao", "#propostas-situacao", "#receber-situacao", "#pagar-situacao", "#pagar-tipo", "#aud-tabela", "#aud-acao", "#aud-usuario"].forEach((s) => $(s).addEventListener("change", recarregar));
  $("#sql-rodar").onclick = rodarSQL;
  $("#sql-texto").addEventListener("keydown", (ev) => { if (ev.key === "Enter" && (ev.ctrlKey || ev.metaKey)) rodarSQL(); });
  const inicial = location.hash.slice(1);
  setView(VIEWS[inicial] ? inicial : "painel");
}
iniciar();

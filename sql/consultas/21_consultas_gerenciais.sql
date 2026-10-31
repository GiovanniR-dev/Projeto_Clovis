-- =====================================================================
-- CRMoveis - Consultas gerenciais (Etapa 18): pergunta do negocio + SQL + informacao para decisao
-- Projeto Integrador - Modelagem de Dados - Prof. Clovis - Grupo 4
-- Rode depois da massa de dados: psql -d crmoveis -f <este arquivo>
-- =====================================================================

-- ------------------------------------------------------------------
-- G01 - Funil comercial
-- Pergunta: Quantas conversas chegaram a cada etapa do funil e quanto se perde de uma etapa para a outra?
-- Decisao:  Mostra em que etapa os clientes desistem. Se a queda maior esta entre visita e proposta, o problema e a selecao dos imoveis visitados; se esta no comeco, e o tempo de resposta.
-- ------------------------------------------------------------------
SELECT fe.nr_ordem AS ordem, fe.nm_estagio AS etapa,
       count(DISTINCT h.id_conversa) AS conversas_que_chegaram,
       round(100.0 * count(DISTINCT h.id_conversa) / (SELECT count(*) FROM conversa), 1) AS pct_do_total
  FROM funil_estagio fe
  LEFT JOIN historico_estagio h ON h.id_estagio = fe.id_estagio
 GROUP BY fe.id_estagio, fe.nr_ordem, fe.nm_estagio
 ORDER BY fe.nr_ordem;

-- ------------------------------------------------------------------
-- G02 - Origem dos clientes
-- Pergunta: De onde vem os clientes que fecham negocio?
-- Decisao:  Indica onde investir a divulgacao: o canal com mais contratos por cliente merece mais verba; o que so traz contatos precisa de outra abordagem.
-- ------------------------------------------------------------------
SELECT coalesce(oc.nm_origem, '(nao informada)') AS origem,
       count(DISTINCT cl.id_usuario) AS clientes,
       count(DISTINCT cv.id_conversa) AS conversas,
       count(DISTINCT ct.id_contrato) FILTER (WHERE ct.dt_assinatura IS NOT NULL) AS contratos_assinados,
       round(100.0 * count(DISTINCT ct.id_contrato) FILTER (WHERE ct.dt_assinatura IS NOT NULL)
             / NULLIF(count(DISTINCT cl.id_usuario), 0), 1) AS conversao_pct
  FROM cliente cl
  JOIN usuario u ON u.id_usuario = cl.id_usuario
  LEFT JOIN origem_contato oc ON oc.id_origem = u.id_origem
  LEFT JOIN conversa cv ON cv.id_cliente = cl.id_usuario
  LEFT JOIN proposta p ON p.id_cliente = cl.id_usuario
  LEFT JOIN contrato ct ON ct.id_proposta = p.id_proposta
 GROUP BY oc.nm_origem
 ORDER BY contratos_assinados DESC, clientes DESC;

-- ------------------------------------------------------------------
-- G03 - Desempenho dos corretores
-- Pergunta: Quanto cada corretor atende, visita, propoe e fecha, e quanto ja tem de comissao liberada?
-- Decisao:  Apoia a distribuicao de novos contatos e o acompanhamento individual: quem visita muito e fecha pouco precisa de apoio na negociacao.
-- ------------------------------------------------------------------
SELECT u.nm_usuario AS corretor,
       CASE WHEN co.dt_fim IS NULL THEN 'ativo' ELSE 'saiu em ' || to_char(co.dt_fim, 'DD/MM/YYYY') END AS situacao,
       (SELECT count(*) FROM conversa c WHERE c.id_corretor = co.id_usuario) AS conversas,
       (SELECT count(*) FROM visita v WHERE v.id_corretor = co.id_usuario AND v.st_visita = 'realizada') AS visitas,
       (SELECT count(*) FROM proposta p WHERE p.id_corretor = co.id_usuario) AS propostas,
       (SELECT count(*) FROM proposta p JOIN contrato ct ON ct.id_proposta = p.id_proposta
         WHERE p.id_corretor = co.id_usuario AND ct.dt_assinatura IS NOT NULL) AS contratos,
       (SELECT coalesce(sum(vc.vl_comissao), 0) FROM vw_comissao vc
         WHERE vc.id_corretor = co.id_usuario AND vc.st_comissao = 'liberada') AS comissao_liberada
  FROM corretor co
  JOIN usuario u ON u.id_usuario = co.id_usuario
 ORDER BY contratos DESC, visitas DESC;

-- ------------------------------------------------------------------
-- G04 - Receita por mes
-- Pergunta: Quanto a imobiliaria faturou por mes, separando corretagem, taxa de administracao e multas?
-- Decisao:  Mostra a dependencia das vendas (receita irregular) e das locacoes (receita recorrente) e ajuda a planejar o caixa e as metas.
-- ------------------------------------------------------------------
WITH receitas AS (
    SELECT date_trunc('month', r.dt_recebimento)::date AS mes,
           CASE WHEN cf.cd_categoria IN ('corretagem_venda', 'intermediacao_locacao') THEN r.vl_recebido ELSE 0 END AS corretagem,
           CASE WHEN cf.cd_categoria = 'aluguel' THEN r.vl_recebido - cp.vl_pagar ELSE 0 END AS taxa_administracao,
           CASE WHEN cf.cd_categoria = 'multa_rescisoria' THEN r.vl_recebido ELSE 0 END AS multa
      FROM recebimento r
      JOIN conta_receber cr ON cr.id_conta_receber = r.id_conta_receber
      JOIN categoria_financeira cf ON cf.id_categoria = cr.id_categoria
      LEFT JOIN conta_pagar cp ON cp.id_conta_receber_origem = r.id_conta_receber
                              AND cp.nr_recebimento_origem = r.nr_recebimento)
SELECT to_char(mes, 'MM/YYYY') AS mes,
       sum(corretagem) AS corretagem_e_intermediacao,
       sum(taxa_administracao) AS taxa_de_administracao,
       sum(multa) AS multas,
       sum(corretagem + taxa_administracao + multa) AS receita_total
  FROM receitas
 WHERE mes >= DATE '2026-01-01'
 GROUP BY mes
 ORDER BY mes;

-- ------------------------------------------------------------------
-- G05 - Inadimplencia
-- Pergunta: Quais alugueis estao em atraso, de quem e ha quantos dias?
-- Decisao:  Define a ordem da cobranca e quando acionar a garantia do contrato; tambem mostra se um inquilino atrasa com frequencia.
-- ------------------------------------------------------------------
SELECT u.nm_usuario AS inquilino, cr.id_contrato AS contrato, cr.ds_conta AS conta,
       to_char(cr.dt_vencimento, 'DD/MM/YYYY') AS vencimento,
       cr.vl_receber AS valor, cr.vl_baixado AS recebido, cr.vl_receber - cr.vl_baixado AS saldo,
       CURRENT_DATE - cr.dt_vencimento AS dias_de_atraso
  FROM vw_conta_receber cr
  JOIN usuario u ON u.id_usuario = cr.id_pagador
 WHERE cr.st_conta = 'atrasada'
 ORDER BY dias_de_atraso DESC;

-- ------------------------------------------------------------------
-- G06 - Repasses aos proprietarios
-- Pergunta: Quais repasses estao para vencer ou atrasados?
-- Decisao:  O repasse tem prazo de 5 dias uteis (PO05): a lista organiza os pagamentos do financeiro e evita multa e desgaste com o proprietario.
-- ------------------------------------------------------------------
SELECT u.nm_usuario AS proprietario, cp.ds_conta AS conta,
       to_char(cp.dt_vencimento, 'DD/MM/YYYY') AS vencimento, cp.vl_pagar AS valor, cp.st_conta AS situacao
  FROM vw_conta_pagar cp
  JOIN categoria_financeira cf ON cf.id_categoria = cp.id_categoria
  JOIN usuario u ON u.id_usuario = cp.id_favorecido
 WHERE cf.cd_categoria = 'repasse' AND cp.st_conta IN ('prevista', 'parcial', 'atrasada')
 ORDER BY cp.dt_vencimento;

-- ------------------------------------------------------------------
-- G07 - Imoveis mais procurados
-- Pergunta: Quais imoveis despertam mais interesse, visitas e propostas?
-- Decisao:  Mostra o perfil de imovel que o mercado procura: orienta a captacao de imoveis parecidos e o destaque nos anuncios.
-- ------------------------------------------------------------------
SELECT i.cd_imobizi AS codigo, t.nm_tipo_imovel AS tipo, b.nm_bairro AS bairro, ci.nm_cidade AS cidade, i.st_imovel AS situacao,
       count(DISTINCT x.id_conversa) AS interesses, count(DISTINCT v.id_visita) AS visitas, count(DISTINCT p.id_proposta) AS propostas
  FROM imovel i
  JOIN tipo_imovel t ON t.id_tipo_imovel = i.id_tipo_imovel
  JOIN bairro b ON b.id_bairro = i.id_bairro
  JOIN cep ON cep.nr_cep = i.nr_cep
  JOIN cidade ci ON ci.id_cidade = cep.id_cidade
  LEFT JOIN conversa_imovel x ON x.id_imovel = i.id_imovel
  LEFT JOIN visita v ON v.id_imovel = i.id_imovel
  LEFT JOIN proposta p ON p.id_imovel = i.id_imovel
 GROUP BY i.id_imovel, t.nm_tipo_imovel, b.nm_bairro, ci.nm_cidade
 ORDER BY interesses DESC, visitas DESC, propostas DESC
 LIMIT 10;

-- ------------------------------------------------------------------
-- G08 - Imoveis parados
-- Pergunta: Quais imoveis disponiveis nao recebem visita ha mais de 60 dias?
-- Decisao:  Candidatos a rever preco, fotos ou anuncio, ou a conversar com o proprietario sobre a exclusividade.
-- ------------------------------------------------------------------
SELECT i.cd_imobizi AS codigo, t.nm_tipo_imovel AS tipo, b.nm_bairro AS bairro, i.tp_finalidade AS finalidade,
       coalesce(i.vl_venda, i.vl_aluguel) AS valor, to_char(max(v.dt_visita), 'DD/MM/YYYY') AS ultima_visita,
       CURRENT_DATE - i.dt_cadastro::date AS dias_na_carteira
  FROM imovel i
  JOIN tipo_imovel t ON t.id_tipo_imovel = i.id_tipo_imovel
  JOIN bairro b ON b.id_bairro = i.id_bairro
  LEFT JOIN visita v ON v.id_imovel = i.id_imovel AND v.st_visita = 'realizada'
 WHERE i.st_imovel = 'disponivel'
 GROUP BY i.id_imovel, t.nm_tipo_imovel, b.nm_bairro
HAVING max(v.dt_visita) IS NULL OR max(v.dt_visita) < CURRENT_DATE - 60
 ORDER BY max(v.dt_visita) NULLS FIRST, dias_na_carteira DESC;

-- ------------------------------------------------------------------
-- G09 - Demanda x oferta por regiao
-- Pergunta: Onde ha mais clientes procurando do que imoveis disponiveis?
-- Decisao:  Indica onde captar novos imoveis: regiao com muitos perfis e pouca oferta e oportunidade perdida.
-- ------------------------------------------------------------------
WITH demanda AS (   -- cada bairro aceito conta o perfil (ABRANGE); perfil sem bairro aceita qualquer bairro da cidade
    SELECT p.id_cidade, pb.id_bairro, p.tp_finalidade, count(*) AS perfis
      FROM perfil_interesse p
      LEFT JOIN perfil_interesse_bairro pb ON pb.id_usuario = p.id_usuario AND pb.nr_perfil = p.nr_perfil
     GROUP BY p.id_cidade, pb.id_bairro, p.tp_finalidade)
SELECT ci.nm_cidade AS cidade, coalesce(b.nm_bairro, '(qualquer bairro)') AS bairro, d.tp_finalidade AS finalidade, d.perfis,
       (SELECT count(*) FROM imovel i JOIN cep ce ON ce.nr_cep = i.nr_cep
         WHERE i.st_imovel = 'disponivel' AND ce.id_cidade = d.id_cidade
           AND (d.id_bairro IS NULL OR i.id_bairro = d.id_bairro)
           AND i.tp_finalidade IN (d.tp_finalidade, 'ambas')) AS imoveis_disponiveis
  FROM demanda d
  JOIN cidade ci ON ci.id_cidade = d.id_cidade
  LEFT JOIN bairro b ON b.id_bairro = d.id_bairro
 ORDER BY d.perfis DESC, imoveis_disponiveis, cidade, bairro;

-- ------------------------------------------------------------------
-- G10 - Tempo ate o contrato
-- Pergunta: Quanto tempo leva, em media, do primeiro contato ate a assinatura?
-- Decisao:  Ajuda a prever o fechamento das negociacoes em andamento e a medir se as melhorias no atendimento encurtam o ciclo.
-- ------------------------------------------------------------------
SELECT ct.tp_contrato AS tipo, count(*) AS contratos,
       round(avg(ct.dt_assinatura - x.primeiro_contato)) AS dias_em_media,
       min(ct.dt_assinatura - x.primeiro_contato) AS menor, max(ct.dt_assinatura - x.primeiro_contato) AS maior
  FROM contrato ct
  JOIN proposta p ON p.id_proposta = ct.id_proposta
  JOIN LATERAL (SELECT min(cv.dt_inicio)::date AS primeiro_contato
                  FROM conversa cv JOIN conversa_imovel ci ON ci.id_conversa = cv.id_conversa
                 WHERE cv.id_cliente = p.id_cliente AND ci.id_imovel = p.id_imovel) x ON TRUE
 WHERE ct.dt_assinatura IS NOT NULL
 GROUP BY ct.tp_contrato;

-- ------------------------------------------------------------------
-- G11 - Descontos nas propostas
-- Pergunta: Qual e o desconto medio pedido e quantas propostas precisaram de autorizacao?
-- Decisao:  Calibra o preco anunciado: descontos altos e frequentes indicam imoveis acima do mercado; autorizacoes frequentes indicam a regra de 10% muito apertada.
-- ------------------------------------------------------------------
SELECT st_proposta AS situacao, count(*) AS propostas,
       round(avg(100 * (1 - vl_proposto / vl_anunciado)), 1) AS desconto_medio_pct,
       count(*) FILTER (WHERE id_autorizador IS NOT NULL) AS com_autorizacao
  FROM proposta
 GROUP BY st_proposta
 ORDER BY propostas DESC;

-- ------------------------------------------------------------------
-- G12 - Receita recorrente prevista
-- Pergunta: Quanto de aluguel e de taxa de administracao esta previsto para os proximos tres meses?
-- Decisao:  Base do planejamento de caixa: a receita recorrente das locacoes cobre os custos fixos?
-- ------------------------------------------------------------------
SELECT to_char(m, 'MM/YYYY') AS mes, count(*) AS locacoes_vigentes,
       sum(ct.vl_final) AS aluguel_previsto,
       round(sum(ct.vl_final * ct.pc_administracao / 100), 2) AS taxa_prevista
  FROM contrato ct
 CROSS JOIN generate_series(date_trunc('month', CURRENT_DATE) + INTERVAL '1 month',
                            date_trunc('month', CURRENT_DATE) + INTERVAL '3 month', INTERVAL '1 month') AS m
 WHERE ct.tp_contrato = 'locacao' AND ct.st_contrato = 'vigente' AND m::date <= ct.dt_fim
 GROUP BY m
 ORDER BY m;

-- ------------------------------------------------------------------
-- G13 - Tempo de primeira resposta
-- Pergunta: Quanto tempo cada corretor leva para responder o primeiro contato no WhatsApp?
-- Decisao:  Mede o atendimento contra a meta do RNF05; corretor com resposta lenta perde clientes no comeco do funil.
-- ------------------------------------------------------------------
WITH t AS (
    SELECT cv.id_conversa, cv.id_corretor,
           min(m.dt_mensagem) FILTER (WHERE m.tp_direcao = 'entrada') AS primeira_entrada,
           min(m.dt_mensagem) FILTER (WHERE m.tp_direcao = 'saida') AS primeira_saida
      FROM conversa cv JOIN mensagem m ON m.id_conversa = cv.id_conversa
     GROUP BY cv.id_conversa, cv.id_corretor)
SELECT coalesce(u.nm_usuario, '(sem corretor)') AS corretor, count(*) AS conversas,
       round(avg(extract(epoch FROM primeira_saida - primeira_entrada) / 60)) AS minutos_em_media
  FROM t LEFT JOIN usuario u ON u.id_usuario = t.id_corretor
 WHERE primeira_saida > primeira_entrada
 GROUP BY u.nm_usuario
 ORDER BY minutos_em_media;

-- ------------------------------------------------------------------
-- G14 - Automacao N8N
-- Pergunta: Quantas demandas a automacao recebeu, enviou e em quantas falhou?
-- Decisao:  Mostra se a automacao esta cumprindo o papel de responder sozinha e quando e preciso revisar o fluxo do N8N ou o seletor de imoveis.
-- ------------------------------------------------------------------
SELECT st_execucao AS situacao, count(*) AS execucoes,
       round(100.0 * count(*) / sum(count(*)) OVER (), 1) AS pct,
       round(avg(extract(epoch FROM dt_envio - dt_execucao) / 60), 1) AS minutos_ate_enviar
  FROM automacao_execucao
 GROUP BY st_execucao
 ORDER BY execucoes DESC;

-- ------------------------------------------------------------------
-- G15 - Demanda x oferta por tipo de imovel
-- Pergunta: Quais tipos de imovel os clientes procuram, comparados com os imoveis disponiveis de cada tipo?
-- Decisao:  Orienta a captacao: tipo com muitos perfis e pouca oferta e o primeiro a captar; tipo com oferta e sem procura pede revisao de preco ou de anuncio. Perfis sem tipo aceitam qualquer tipo e nao entram na contagem.
-- ------------------------------------------------------------------
WITH demanda AS (
    SELECT pt.id_tipo_imovel, p.tp_finalidade, count(*) AS perfis
      FROM perfil_interesse_tipo pt
      JOIN perfil_interesse p ON p.id_usuario = pt.id_usuario AND p.nr_perfil = pt.nr_perfil
     GROUP BY pt.id_tipo_imovel, p.tp_finalidade),
oferta AS (
    SELECT i.id_tipo_imovel, f.fin AS tp_finalidade, count(*) AS imoveis
      FROM imovel i
     CROSS JOIN (VALUES ('venda'), ('locacao')) AS f(fin)
     WHERE i.st_imovel = 'disponivel' AND i.tp_finalidade IN (f.fin, 'ambas')
     GROUP BY i.id_tipo_imovel, f.fin)
SELECT t.nm_tipo_imovel AS tipo, x.fin AS finalidade,
       coalesce(d.perfis, 0) AS perfis_que_aceitam, coalesce(o.imoveis, 0) AS imoveis_disponiveis
  FROM tipo_imovel t
 CROSS JOIN (VALUES ('venda'), ('locacao')) AS x(fin)
  LEFT JOIN demanda d ON d.id_tipo_imovel = t.id_tipo_imovel AND d.tp_finalidade = x.fin
  LEFT JOIN oferta o ON o.id_tipo_imovel = t.id_tipo_imovel AND o.tp_finalidade = x.fin
 WHERE d.perfis IS NOT NULL OR o.imoveis IS NOT NULL
 ORDER BY perfis_que_aceitam DESC, imoveis_disponiveis, tipo;

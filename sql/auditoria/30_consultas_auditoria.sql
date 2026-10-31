-- =====================================================================
-- CRMoveis - Consultas de auditoria (Etapa 19): verificam a qualidade e a consistencia dos dados
-- Projeto Integrador - Modelagem de Dados - Prof. Clovis - Grupo 4
-- Rode depois da massa de dados: psql -d crmoveis -f <este arquivo>
-- =====================================================================

-- ------------------------------------------------------------------
-- A01 - Extrato sem lancamento
-- O que verifica: Movimentos do extrato bancario que nao tem baixa ligada (pendentes) ou cuja soma das baixas nao chega ao valor (parciais).
-- O que fazer:    O financeiro identifica cada um: tarifa a lancar como despesa, recebimento esquecido ou credito de origem desconhecida.
-- ------------------------------------------------------------------
SELECT cb.nm_apelido AS conta, mb.nr_movimento, to_char(mb.dt_movimento, 'DD/MM/YYYY') AS data,
       mb.tp_movimento AS tipo, mb.vl_movimento AS valor, mb.vl_conciliado AS conciliado,
       mb.st_conciliacao AS situacao, mb.ds_historico AS historico
  FROM vw_movimento_bancario mb
  JOIN conta_bancaria cb ON cb.id_conta = mb.id_conta
 WHERE mb.st_conciliacao <> 'conciliado'
 ORDER BY mb.dt_movimento;

-- ------------------------------------------------------------------
-- A02 - Baixas sem extrato
-- O que verifica: Recebimentos e pagamentos registrados ha mais de 3 dias, em periodo com extrato importado, que ainda nao foram conferidos com o extrato.
-- O que fazer:    Uma baixa que nao aparece no banco pode ser lancamento errado (valor, data ou conta) ou dinheiro que nao entrou.
-- ------------------------------------------------------------------
SELECT 'recebimento' AS baixa, r.id_conta_receber AS conta, r.nr_recebimento AS numero, cb.nm_apelido AS conta_bancaria,
       to_char(r.dt_recebimento, 'DD/MM/YYYY') AS data, r.vl_recebido AS valor
  FROM recebimento r JOIN conta_bancaria cb ON cb.id_conta = r.id_conta
 WHERE r.nr_movimento IS NULL AND r.dt_recebimento < CURRENT_DATE - 3
   AND r.dt_recebimento >= (SELECT min(mb.dt_movimento) FROM movimento_bancario mb WHERE mb.id_conta = r.id_conta)
UNION ALL
SELECT 'pagamento', p.id_conta_pagar, p.nr_pagamento, cb.nm_apelido, to_char(p.dt_pagamento, 'DD/MM/YYYY'), p.vl_pago
  FROM pagamento p JOIN conta_bancaria cb ON cb.id_conta = p.id_conta
 WHERE p.nr_movimento IS NULL AND p.dt_pagamento < CURRENT_DATE - 3
   AND p.dt_pagamento >= (SELECT min(mb.dt_movimento) FROM movimento_bancario mb WHERE mb.id_conta = p.id_conta)
 ORDER BY data;

-- ------------------------------------------------------------------
-- A03 - Repasses atrasados
-- O que verifica: Repasses ao proprietario vencidos e nao pagos (o prazo e de 5 dias uteis, PO05).
-- O que fazer:    Pagar com prioridade e registrar o motivo do atraso.
-- ------------------------------------------------------------------
SELECT cp.id_conta_pagar, u.nm_usuario AS proprietario, cp.ds_conta AS conta,
       to_char(cp.dt_vencimento, 'DD/MM/YYYY') AS vencimento, cp.vl_pagar - cp.vl_baixado AS saldo,
       CURRENT_DATE - cp.dt_vencimento AS dias_de_atraso
  FROM vw_conta_pagar cp
  JOIN categoria_financeira cf ON cf.id_categoria = cp.id_categoria
  JOIN usuario u ON u.id_usuario = cp.id_favorecido
 WHERE cf.cd_categoria = 'repasse' AND cp.st_conta = 'atrasada'
 ORDER BY cp.dt_vencimento;

-- ------------------------------------------------------------------
-- A04 - Comissao sem conta a pagar
-- O que verifica: Comissoes liberadas sem a conta a pagar ao corretor (RN25) e contas a pagar de comissao que nao estao ligadas a nenhuma comissao.
-- O que fazer:    Lancar a conta que falta ou corrigir a ligacao; evita comissao esquecida ou paga sem aprovacao.
-- ------------------------------------------------------------------
SELECT 'comissao liberada sem conta' AS problema, cm.id_contrato AS contrato, u.nm_usuario AS corretor, NULL::integer AS conta_pagar
  FROM comissao cm JOIN usuario u ON u.id_usuario = cm.id_corretor
 WHERE cm.st_comissao = 'liberada' AND cm.id_conta_pagar IS NULL
UNION ALL
SELECT 'conta de comissao sem comissao', cp.id_contrato, u.nm_usuario, cp.id_conta_pagar
  FROM conta_pagar cp
  JOIN categoria_financeira cf ON cf.id_categoria = cp.id_categoria
  LEFT JOIN usuario u ON u.id_usuario = cp.id_favorecido
 WHERE cf.cd_categoria = 'comissao' AND NOT cp.fl_cancelada
   AND NOT EXISTS (SELECT 1 FROM comissao cm WHERE cm.id_conta_pagar = cp.id_conta_pagar);

-- ------------------------------------------------------------------
-- A05 - Negocios parados
-- O que verifica: Propostas aceitas sem contrato ha mais de 7 dias e contratos ainda em rascunho mais de 3 dias depois do aceite da proposta.
-- O que fazer:    O corretor responsavel retoma o negocio antes que o cliente desista.
-- ------------------------------------------------------------------
SELECT 'proposta aceita sem contrato' AS situacao, p.id_proposta AS registro, u.nm_usuario AS cliente,
       to_char(p.dt_proposta, 'DD/MM/YYYY') AS desde, CURRENT_DATE - p.dt_proposta::date AS dias
  FROM proposta p JOIN usuario u ON u.id_usuario = p.id_cliente
 WHERE p.st_proposta = 'aceita' AND NOT EXISTS (SELECT 1 FROM contrato ct WHERE ct.id_proposta = p.id_proposta)
   AND p.dt_proposta < CURRENT_DATE - 7
UNION ALL
SELECT 'contrato em rascunho', ct.id_contrato, u.nm_usuario,
       to_char(p.dt_proposta, 'DD/MM/YYYY'), CURRENT_DATE - p.dt_proposta::date
  FROM contrato ct JOIN proposta p ON p.id_proposta = ct.id_proposta JOIN usuario u ON u.id_usuario = p.id_cliente
 WHERE ct.st_contrato = 'rascunho' AND p.dt_proposta < CURRENT_DATE - 3
 ORDER BY dias DESC;

-- ------------------------------------------------------------------
-- A06 - Conversas sem atendimento
-- O que verifica: Conversas abertas sem corretor ou sem nenhuma mensagem nos ultimos 7 dias.
-- O que fazer:    Distribuir para um corretor ou retomar o contato antes que o cliente esfrie.
-- ------------------------------------------------------------------
SELECT cv.id_conversa, u.nm_usuario AS cliente, coalesce(c.nm_usuario, '(sem corretor)') AS corretor, fe.nm_estagio AS etapa,
       to_char(vc.dt_atualizacao, 'DD/MM/YYYY') AS ultima_mensagem, CURRENT_DATE - vc.dt_atualizacao::date AS dias_sem_contato
  FROM vw_conversa vc
  JOIN conversa cv ON cv.id_conversa = vc.id_conversa
  JOIN usuario u ON u.id_usuario = cv.id_cliente
  LEFT JOIN usuario c ON c.id_usuario = cv.id_corretor
  JOIN funil_estagio fe ON fe.id_estagio = cv.id_estagio
 WHERE cv.st_conversa = 'aberta' AND (cv.id_corretor IS NULL OR vc.dt_atualizacao < CURRENT_DATE - 7)
 ORDER BY dias_sem_contato DESC;

-- ------------------------------------------------------------------
-- A07 - Tarefas vencidas
-- O que verifica: Tarefas pendentes com prazo vencido, por corretor.
-- O que fazer:    Cobrar a execucao ou redistribuir as tarefas de quem esta sobrecarregado.
-- ------------------------------------------------------------------
SELECT u.nm_usuario AS corretor, count(*) AS tarefas_vencidas,
       min(t.dt_vencimento)::date AS mais_antiga, string_agg(t.ds_titulo || ' (conversa ' || t.id_conversa || ')', '; ' ORDER BY t.dt_vencimento) AS tarefas
  FROM tarefa t JOIN usuario u ON u.id_usuario = t.id_corretor
 WHERE t.st_tarefa = 'pendente' AND t.dt_vencimento < CURRENT_DATE
 GROUP BY u.nm_usuario
 ORDER BY tarefas_vencidas DESC;

-- ------------------------------------------------------------------
-- A08 - Anuncios incompletos
-- O que verifica: Imoveis disponiveis sem corretor responsavel, com menos de 3 fotos ou sem nenhuma caracteristica.
-- O que fazer:    Completar o cadastro antes de divulgar: anuncio incompleto gera menos interesse.
-- ------------------------------------------------------------------
SELECT i.cd_imobizi AS codigo, t.nm_tipo_imovel AS tipo, b.nm_bairro AS bairro,
       (i.id_corretor_responsavel IS NULL) AS sem_corretor,
       (SELECT count(*) FROM foto f WHERE f.id_imovel = i.id_imovel) AS fotos,
       (SELECT count(*) FROM imovel_caracteristica x WHERE x.id_imovel = i.id_imovel) AS caracteristicas
  FROM imovel i
  JOIN tipo_imovel t ON t.id_tipo_imovel = i.id_tipo_imovel
  JOIN bairro b ON b.id_bairro = i.id_bairro
 WHERE i.st_imovel = 'disponivel'
   AND (i.id_corretor_responsavel IS NULL
        OR (SELECT count(*) FROM foto f WHERE f.id_imovel = i.id_imovel) < 3
        OR NOT EXISTS (SELECT 1 FROM imovel_caracteristica x WHERE x.id_imovel = i.id_imovel))
 ORDER BY fotos;

-- ------------------------------------------------------------------
-- A09 - Numeros compartilhados
-- O que verifica: Numeros que estao no cadastro de mais de uma pessoa, com o titular de cada um (RN03). Celular ou fixo se deduz do numero.
-- O que fazer:    Confirmar com o cliente quem e o titular: e por ele que a automacao identifica quem mandou a mensagem.
-- ------------------------------------------------------------------
SELECT t.nr_telefone AS telefone,
       CASE WHEN length(t.nr_telefone) = 11 AND substr(t.nr_telefone, 3, 1) = '9' THEN 'celular' ELSE 'fixo' END AS tipo,
       count(*) AS pessoas,
       max(u.nm_usuario) FILTER (WHERE t.fl_titular) AS titular,
       string_agg(u.nm_usuario, ', ' ORDER BY u.nm_usuario) FILTER (WHERE NOT t.fl_titular) AS tambem_usam
  FROM telefone t
  JOIN usuario u ON u.id_usuario = t.id_usuario
 GROUP BY t.nr_telefone
HAVING count(*) > 1;

-- ------------------------------------------------------------------
-- A10 - Papel encerrado ainda em uso
-- O que verifica: Pessoas com papel encerrado (data de fim) que ainda aparecem como corretor de conversa aberta ou de imovel disponivel, ou como inquilino de locacao vigente.
-- O que fazer:    Transferir os registros para quem exerce o papel hoje (RN02, RN32).
-- ------------------------------------------------------------------
SELECT 'corretor de conversa aberta' AS situacao, u.nm_usuario AS pessoa, cv.id_conversa AS registro
  FROM conversa cv JOIN corretor co ON co.id_usuario = cv.id_corretor JOIN usuario u ON u.id_usuario = co.id_usuario
 WHERE cv.st_conversa = 'aberta' AND co.dt_fim IS NOT NULL
UNION ALL
SELECT 'corretor de imovel disponivel', u.nm_usuario, i.id_imovel
  FROM imovel i JOIN corretor co ON co.id_usuario = i.id_corretor_responsavel JOIN usuario u ON u.id_usuario = co.id_usuario
 WHERE i.st_imovel = 'disponivel' AND co.dt_fim IS NOT NULL
UNION ALL
SELECT 'inquilino de locacao vigente', u.nm_usuario, ct.id_contrato
  FROM contrato ct JOIN proposta p ON p.id_proposta = ct.id_proposta JOIN inquilino iq ON iq.id_usuario = p.id_cliente
  JOIN usuario u ON u.id_usuario = iq.id_usuario
 WHERE ct.tp_contrato = 'locacao' AND ct.st_contrato = 'vigente' AND iq.dt_fim IS NOT NULL;

-- ------------------------------------------------------------------
-- A11 - Estagio da conversa x historico
-- O que verifica: Conversas cujo estagio atual e diferente do ultimo registro do historico (redundancia controlada, RN14).
-- O que fazer:    Se aparecer algum registro, a gravacao do estagio e do historico nao foi feita na mesma operacao; corrigir pelo historico.
-- ------------------------------------------------------------------
SELECT cv.id_conversa, fa.nm_estagio AS estagio_na_conversa, fh.nm_estagio AS ultimo_no_historico
  FROM conversa cv
  JOIN funil_estagio fa ON fa.id_estagio = cv.id_estagio
  JOIN LATERAL (SELECT h.id_estagio FROM historico_estagio h WHERE h.id_conversa = cv.id_conversa
                 ORDER BY h.dt_alteracao DESC LIMIT 1) ult ON TRUE
  JOIN funil_estagio fh ON fh.id_estagio = ult.id_estagio
 WHERE ult.id_estagio <> cv.id_estagio;

-- ------------------------------------------------------------------
-- A12 - Trilha de contratos e comissoes
-- O que verifica: Alteracoes e cancelamentos feitos em contratos e comissoes, com quem fez e o que mudou (RN40).
-- O que fazer:    Conferir se cada mudanca sensivel foi feita por quem tinha permissao e se o motivo esta registrado.
-- ------------------------------------------------------------------
SELECT a.id_auditoria, to_char(a.dt_acao, 'DD/MM/YYYY HH24:MI') AS quando, u.nm_usuario AS quem, a.tp_acao AS acao,
       CASE WHEN a.id_contrato IS NOT NULL THEN 'contrato ' || a.id_contrato
            ELSE 'comissao ' || a.id_comissao_contrato || '/' || a.id_comissao_corretor END AS registro,
       string_agg(c.nm_campo || ': ' || coalesce(c.ds_valor_anterior, 'vazio') || ' -> ' || coalesce(c.ds_valor_novo, 'vazio'), '; ' ORDER BY c.nm_campo) AS campos
  FROM auditoria a
  JOIN usuario u ON u.id_usuario = a.id_usuario
  LEFT JOIN auditoria_campo c ON c.id_auditoria = a.id_auditoria
 WHERE (a.id_contrato IS NOT NULL OR a.id_comissao_contrato IS NOT NULL) AND a.tp_acao <> 'criacao'
 GROUP BY a.id_auditoria, u.nm_usuario
 ORDER BY a.id_auditoria;

-- ------------------------------------------------------------------
-- A13 - Contas incoerentes
-- O que verifica: Contas canceladas que receberam baixa, contas com baixas acima do valor e contratos encerrados ou rescindidos com contas de periodo futuro em aberto.
-- O que fazer:    Nenhuma linha e o esperado: as regras do banco impedem esses casos. Se aparecer algo, houve carga fora das regras.
-- ------------------------------------------------------------------
SELECT 'conta a receber cancelada com baixa' AS problema, cr.id_conta_receber AS conta
  FROM vw_conta_receber cr WHERE cr.fl_cancelada AND cr.vl_baixado > 0
UNION ALL
SELECT 'baixas acima do valor (receber)', cr.id_conta_receber FROM vw_conta_receber cr WHERE cr.vl_baixado > cr.vl_receber
UNION ALL
SELECT 'baixas acima do valor (pagar)', cp.id_conta_pagar FROM vw_conta_pagar cp WHERE cp.vl_baixado > cp.vl_pagar
UNION ALL
SELECT 'contrato terminado com aluguel futuro em aberto', cr.id_conta_receber
  FROM vw_conta_receber cr JOIN contrato ct ON ct.id_contrato = cr.id_contrato
  JOIN categoria_financeira cf ON cf.id_categoria = cr.id_categoria
 WHERE ct.st_contrato IN ('rescindido', 'encerrado') AND cf.cd_categoria = 'aluguel'
   AND cr.dt_competencia > ct.dt_termino AND cr.st_conta NOT IN ('cancelada', 'quitada');

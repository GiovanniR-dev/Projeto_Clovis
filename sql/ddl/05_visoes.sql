-- =====================================================================
-- CRMoveis - Visoes dos atributos derivados
-- Projeto Integrador - Modelagem de Dados - Prof. Clovis - Grupo 4
-- PostgreSQL 13 ou superior - depois do 04
-- =====================================================================

-- =====================================================================
-- ATRIBUTOS DERIVADOS (calculados em visoes, nao armazenados)
-- =====================================================================
CREATE VIEW vw_contrato AS
SELECT c.*, round(c.vl_final * c.pc_corretagem / 100, 2) AS vl_corretagem
  FROM contrato c;

CREATE VIEW vw_comissao AS
SELECT cm.*, round(c.vl_final * c.pc_corretagem / 100 * cm.pc_comissao / 100, 2) AS vl_comissao
  FROM comissao cm JOIN contrato c ON c.id_contrato = cm.id_contrato;

CREATE VIEW vw_conversa AS
SELECT cv.*, COALESCE((SELECT max(m.dt_mensagem) FROM mensagem m WHERE m.id_conversa = cv.id_conversa), cv.dt_inicio) AS dt_atualizacao
  FROM conversa cv;

CREATE VIEW vw_conta_receber AS
SELECT cr.*, COALESCE(b.vl_baixado, 0) AS vl_baixado,
       CASE WHEN cr.fl_cancelada THEN 'cancelada'
            WHEN COALESCE(b.vl_baixado, 0) >= cr.vl_receber THEN 'quitada'
            WHEN cr.dt_vencimento < CURRENT_DATE THEN 'atrasada'
            WHEN COALESCE(b.vl_baixado, 0) > 0 THEN 'parcial'
            ELSE 'prevista' END AS st_conta
  FROM conta_receber cr
  LEFT JOIN (SELECT id_conta_receber, SUM(vl_recebido) AS vl_baixado FROM recebimento GROUP BY id_conta_receber) b
         ON b.id_conta_receber = cr.id_conta_receber;

CREATE VIEW vw_conta_pagar AS
SELECT cp.*, COALESCE(b.vl_baixado, 0) AS vl_baixado,
       CASE WHEN cp.fl_cancelada THEN 'cancelada'
            WHEN COALESCE(b.vl_baixado, 0) >= cp.vl_pagar THEN 'paga'
            WHEN cp.dt_vencimento < CURRENT_DATE THEN 'atrasada'
            WHEN COALESCE(b.vl_baixado, 0) > 0 THEN 'parcial'
            ELSE 'prevista' END AS st_conta
  FROM conta_pagar cp
  LEFT JOIN (SELECT id_conta_pagar, SUM(vl_pago) AS vl_baixado FROM pagamento GROUP BY id_conta_pagar) b
         ON b.id_conta_pagar = cp.id_conta_pagar;

-- RN45: pendente (nenhuma baixa), parcial (baixas abaixo do valor) ou conciliado.
CREATE VIEW vw_movimento_bancario AS
SELECT mb.*, COALESCE(b.vl_conciliado, 0) AS vl_conciliado,
       CASE WHEN COALESCE(b.vl_conciliado, 0) = 0 THEN 'pendente'
            WHEN b.vl_conciliado < mb.vl_movimento THEN 'parcial'
            ELSE 'conciliado' END AS st_conciliacao
  FROM movimento_bancario mb
  LEFT JOIN (SELECT id_conta, nr_movimento, SUM(vl_recebido) AS vl_conciliado FROM recebimento
              WHERE nr_movimento IS NOT NULL GROUP BY id_conta, nr_movimento
             UNION ALL
             SELECT id_conta, nr_movimento, SUM(vl_pago) FROM pagamento
              WHERE nr_movimento IS NOT NULL GROUP BY id_conta, nr_movimento) b
         ON b.id_conta = mb.id_conta AND b.nr_movimento = mb.nr_movimento;

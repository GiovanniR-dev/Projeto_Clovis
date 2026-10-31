-- =====================================================================
-- CRMoveis - Testes das regras de negocio garantidas pelo banco
-- Projeto Integrador - Modelagem de Dados - Prof. Clovis - Grupo 4
-- PostgreSQL 13 ou superior - banco separado crmoveis_testes
-- =====================================================================

-- 61 cenarios: cada um tenta gravar algo e confere se o banco aceitou ou recusou como a regra manda.
-- Rodam num banco SEPARADO, para nao misturar os dados de teste com a massa de dados:
--   psql -U postgres -d postgres -c "DROP DATABASE IF EXISTS crmoveis_testes" -c "CREATE DATABASE crmoveis_testes TEMPLATE template0 ENCODING 'UTF8'"
--   (rodar sql/ddl/01 a 06 e sql/dados/07 em crmoveis_testes)
--   psql -d crmoveis_testes -f sql/testes/40_testes_regras.sql
-- Os scripts executar_tudo.* fazem tudo isso. Cada cenario roda isolado; o que e recusado e desfeito,
-- o que e aceito fica gravado para o cenario seguinte. O resultado aparece na consulta final.
-- @@ preparacao
SET crmoveis.id_usuario = '1';   -- usuario responsavel pelas gravacoes (auditoria, RN40)
CREATE TEMP TABLE resultado_teste (id TEXT, ponto SMALLINT, cenario TEXT, esperado TEXT, obtido TEXT, ok BOOLEAN);
CREATE FUNCTION pg_temp.cat(p_nome TEXT) RETURNS INTEGER LANGUAGE sql AS
    $$ SELECT id_categoria FROM categoria_financeira WHERE cd_categoria = p_nome $$;
CREATE FUNCTION pg_temp.brl(p_valor NUMERIC) RETURNS TEXT LANGUAGE sql AS   -- formata R$ 1.234,56
    $$ SELECT 'R$ ' || translate(to_char(p_valor, 'FM999,999,990.00'), ',.', '.,') $$;
-- @@ dados de exemplo
BEGIN;
INSERT INTO usuario (id_usuario, nm_usuario, nr_cpf_cnpj, ds_email, id_origem) VALUES
    (1, 'Carla Mendes', '11111111111', 'carla@crmoveis.example', 6),
    (2, 'Fabio Torres', '22222222222', 'fabio@crmoveis.example', 6),
    (3, 'Rui Almeida', '33333333333', 'rui@crmoveis.example', 6),
    (4, 'Lia Martins', '44444444444', 'lia@crmoveis.example', 6),
    (5, 'Ana Souza', '55555555555', 'ana@email.example', 1),
    (6, 'Bruno Lima', '66666666666', 'bruno@email.example', 5),
    (7, 'Banco Exemplo S.A.', '00000000000191', 'credito@banco.example', 6),
    (8, 'Marta Rocha', '88888888888', 'marta@email.example', 2),
    (9, 'Paulo Nunes', '99999999999', 'paulo@crmoveis.example', 6),
    (10, 'Sergio Dias', '10101010101', 'sergio@crmoveis.example', 6);
INSERT INTO administrador (id_usuario, dt_inicio) VALUES (1, '2025-01-02');
INSERT INTO financeiro (id_usuario, dt_inicio) VALUES (2, '2025-01-02');
INSERT INTO corretor (id_usuario, nr_creci, dt_inicio, dt_fim) VALUES
    (3, 'CRECI-SP 101010', '2025-01-02', NULL), (4, 'CRECI-SP 202020', '2025-02-01', NULL),
    (9, 'CRECI-SP 303030', '2025-03-01', NULL), (10, 'CRECI-SP 404040', '2024-05-01', '2026-01-31');
INSERT INTO cliente (id_usuario, dt_inicio) VALUES (5, '2026-01-10'), (6, '2026-01-15');
INSERT INTO proprietario (id_usuario, dt_inicio) VALUES (5, '2025-11-20'), (8, '2025-10-01');
INSERT INTO instituicao_financeira (id_usuario, dt_inicio) VALUES (7, '2026-02-01');
INSERT INTO telefone (id_usuario, nr_sequencia, nr_telefone, fl_principal, fl_titular) VALUES
    (5, 1, '1133334444', FALSE, TRUE), (6, 1, '1133334444', FALSE, FALSE), (5, 2, '11988880005', TRUE, TRUE), (6, 2, '11988880006', TRUE, TRUE);
INSERT INTO cidade (id_cidade, nm_cidade, sg_uf) VALUES (1, 'Sao Paulo', 'SP'), (2, 'Guarulhos', 'SP');
INSERT INTO cep (nr_cep, id_cidade, tp_cep) VALUES ('01310100', 1, 'logradouro'), ('04538133', 1, 'logradouro'), ('07010000', 2, 'logradouro');
INSERT INTO bairro (id_bairro, id_cidade, nm_bairro) VALUES (1, 1, 'Bela Vista'), (2, 1, 'Itaim Bibi'), (3, 2, 'Centro');
INSERT INTO conta_bancaria (id_conta, nm_apelido, nm_instituicao, tp_conta_bancaria) VALUES
    (1, 'Conta movimento', 'Banco Exemplo', 'corrente');
INSERT INTO imovel (id_imovel, id_proprietario, id_corretor_responsavel, nr_cep, id_tipo_imovel, tp_finalidade,
                    nm_logradouro, nr_endereco, id_bairro, vl_aluguel, vl_venda, st_imovel) VALUES
    (10, 8, 3, '01310100', 1, 'locacao', 'Avenida Paulista', '1000', 1, 2000, NULL, 'alugado'),
    (11, 5, 4, '04538133', 2, 'venda', 'Rua Exemplo', '45', 2, NULL, 500000, 'reservado'),
    (12, 8, 4, '04538133', 1, 'venda', 'Rua Exemplo', '90', 2, NULL, 300000, 'reservado');
INSERT INTO proposta (id_proposta, id_imovel, id_cliente, id_corretor, vl_proposto, vl_anunciado, st_proposta) VALUES
    (100, 10, 6, 3, 2000, 2000, 'aceita'), (101, 11, 6, 4, 480000, 500000, 'aceita'), (102, 12, 6, 4, 300000, 300000, 'aceita');
INSERT INTO contrato (id_contrato, id_proposta, tp_contrato, tp_condicao_pagamento, vl_final, pc_corretagem, pc_administracao,
                      nr_dia_vencimento, dt_assinatura, dt_inicio, dt_fim, st_contrato) VALUES
    (200, 100, 'locacao', 'parcelado_direto', 2000, 100, 10, 5, '2026-03-01', '2026-03-01', '2027-02-28', 'vigente'),
    (201, 101, 'venda', 'a_vista', 480000, 6, NULL, NULL, '2026-04-10', NULL, NULL, 'vigente'),
    (202, 102, 'venda', 'financiado', 300000, 6, NULL, NULL, '2026-04-15', NULL, NULL, 'vigente');
INSERT INTO financiamento (id_contrato, id_instituicao, vl_financiado, vl_entrada, nr_parcelas, st_financiamento) VALUES
    (202, 7, 240000, 60000, 360, 'reprovado');
INSERT INTO conta_pagar (id_conta_pagar, id_contrato, id_categoria, id_favorecido, tp_papel_custeio,
                         ds_conta, vl_pagar, dt_vencimento) VALUES
    (300, 200, pg_temp.cat('comissao'), 3, 'imobiliaria', 'Comissao de Rui no contrato 200', 1400, '2026-03-10');
INSERT INTO comissao (id_contrato, id_corretor, pc_comissao, tp_regra_pagamento, st_comissao, id_aprovador, dt_aprovacao, id_conta_pagar) VALUES
    (200, 3, 70, 'assinatura', 'liberada', 1, '2026-03-02', 300),
    (200, 9, 30, 'recebimento', 'pendente', NULL, NULL, NULL),
    (202, 4, 100, 'liberacao_credito', 'pendente', NULL, NULL, NULL);
INSERT INTO conta_receber (id_conta_receber, id_contrato, id_categoria, id_pagador, tp_papel_pagador,
                           ds_conta, dt_competencia, vl_receber, dt_vencimento) VALUES
    (400, 200, pg_temp.cat('aluguel'), 6, 'inquilino', 'Aluguel 04/2026', '2026-04-01', 2000, '2026-04-05'),
    (401, 200, pg_temp.cat('aluguel'), 6, 'inquilino', 'Aluguel 05/2026', '2026-05-01', 2000, '2026-05-05'),
    (402, 200, pg_temp.cat('aluguel'), 6, 'inquilino', 'Aluguel 06/2026', '2026-06-01', 2000, '2026-06-05'),
    (403, 200, pg_temp.cat('aluguel'), 6, 'inquilino', 'Aluguel 07/2026', '2026-07-01', 2000, '2026-07-05'),
    (404, 200, pg_temp.cat('aluguel'), 6, 'inquilino', 'Aluguel 08/2026', '2026-08-01', 2000, '2026-08-05'),
    (410, 201, pg_temp.cat('corretagem_venda'), 5, 'proprietario', 'Corretagem da venda 201', NULL, 28800, '2026-04-20'),
    (411, 202, pg_temp.cat('corretagem_venda'), 6, 'cliente', 'Corretagem da venda 202', NULL, 18000, '2026-05-10');
COMMIT;
-- @@ sequencias
SELECT setval(pg_get_serial_sequence('usuario', 'id_usuario'), 1000);
SELECT setval(pg_get_serial_sequence('origem_contato', 'id_origem'), 1000);
SELECT setval(pg_get_serial_sequence('cidade', 'id_cidade'), 1000);
SELECT setval(pg_get_serial_sequence('bairro', 'id_bairro'), 1000);
SELECT setval(pg_get_serial_sequence('tipo_imovel', 'id_tipo_imovel'), 1000);
SELECT setval(pg_get_serial_sequence('imovel', 'id_imovel'), 1000);
SELECT setval(pg_get_serial_sequence('caracteristica', 'id_caracteristica'), 1000);
SELECT setval(pg_get_serial_sequence('funil_estagio', 'id_estagio'), 1000);
SELECT setval(pg_get_serial_sequence('conversa', 'id_conversa'), 1000);
SELECT setval(pg_get_serial_sequence('tarefa', 'id_tarefa'), 1000);
SELECT setval(pg_get_serial_sequence('tag', 'id_tag'), 1000);
SELECT setval(pg_get_serial_sequence('visita', 'id_visita'), 1000);
SELECT setval(pg_get_serial_sequence('proposta', 'id_proposta'), 1000);
SELECT setval(pg_get_serial_sequence('contrato', 'id_contrato'), 1000);
SELECT setval(pg_get_serial_sequence('tipo_documento', 'id_tipo_documento'), 1000);
SELECT setval(pg_get_serial_sequence('categoria_financeira', 'id_categoria'), 1000);
SELECT setval(pg_get_serial_sequence('conta_bancaria', 'id_conta'), 1000);
SELECT setval(pg_get_serial_sequence('conta_receber', 'id_conta_receber'), 1000);
SELECT setval(pg_get_serial_sequence('conta_pagar', 'id_conta_pagar'), 1000);
SELECT setval(pg_get_serial_sequence('forma_pagamento', 'id_forma_pagamento'), 1000);
SELECT setval(pg_get_serial_sequence('auditoria', 'id_auditoria'), 1000);
-- @@ 1.1 - Cadastrar uma pessoa com dois papeis ao mesmo tempo (cliente e fornecedora)
DO $t$
DECLARE v_erro TEXT; v_ok BOOLEAN; v_obtido TEXT;
BEGIN
    BEGIN
        INSERT INTO usuario (id_usuario, nm_usuario, id_origem) VALUES (11, 'Nina Prado', 1);
        INSERT INTO cliente (id_usuario) VALUES (11);
        INSERT INTO fornecedor (id_usuario) VALUES (11);
        SET CONSTRAINTS ALL IMMEDIATE;   -- confere agora as regras verificadas no fim da transacao
    EXCEPTION WHEN OTHERS THEN
        v_erro := SQLERRM;
    END;
    IF v_erro IS NULL THEN
        v_ok := (EXISTS (SELECT 1 FROM cliente WHERE id_usuario = 11) AND EXISTS (SELECT 1 FROM fornecedor WHERE id_usuario = 11));
        v_obtido := 'aceito: ' || ('usuaria 11 gravada como cliente e fornecedora');
    ELSE
        v_ok := FALSE; v_obtido := 'recusado: ' || v_erro;
    END IF;
    INSERT INTO resultado_teste VALUES ($q$1.1$q$, 1, $q$Cadastrar uma pessoa com dois papeis ao mesmo tempo (cliente e fornecedora)$q$, $q$aceito$q$, v_obtido, v_ok);
END $t$;

-- @@ 1.2 - Cadastrar um usuario sem nenhum papel
DO $t$
DECLARE v_erro TEXT; v_ok BOOLEAN; v_obtido TEXT;
BEGIN
    BEGIN
        INSERT INTO usuario (id_usuario, nm_usuario) VALUES (12, 'Sem Papel');
        SET CONSTRAINTS ALL IMMEDIATE;   -- confere agora as regras verificadas no fim da transacao
    EXCEPTION WHEN OTHERS THEN
        v_erro := SQLERRM;
    END;
    IF v_erro IS NULL THEN
        v_ok := FALSE; v_obtido := 'aceito (deveria ter sido recusado)';
    ELSE
        v_ok := strpos(v_erro, $q$RN01$q$) > 0; v_obtido := 'recusado: ' || v_erro;
    END IF;
    INSERT INTO resultado_teste VALUES ($q$1.2$q$, 1, $q$Cadastrar um usuario sem nenhum papel$q$, $q$recusado (RN01)$q$, v_obtido, v_ok);
END $t$;

-- @@ 1.3 - Anunciar um imovel em nome de quem nao e proprietario (Bruno e so cliente)
DO $t$
DECLARE v_erro TEXT; v_ok BOOLEAN; v_obtido TEXT;
BEGIN
    BEGIN
        INSERT INTO imovel (id_proprietario, nr_cep, id_tipo_imovel, tp_finalidade, nm_logradouro, nr_endereco, id_bairro, vl_venda)
        VALUES (6, '01310100', 2, 'venda', 'Rua Teste', '1', 1, 100000);
        SET CONSTRAINTS ALL IMMEDIATE;   -- confere agora as regras verificadas no fim da transacao
    EXCEPTION WHEN OTHERS THEN
        v_erro := SQLERRM;
    END;
    IF v_erro IS NULL THEN
        v_ok := FALSE; v_obtido := 'aceito (deveria ter sido recusado)';
    ELSE
        v_ok := strpos(v_erro, $q$RN32$q$) > 0; v_obtido := 'recusado: ' || v_erro;
    END IF;
    INSERT INTO resultado_teste VALUES ($q$1.3$q$, 1, $q$Anunciar um imovel em nome de quem nao e proprietario (Bruno e so cliente)$q$, $q$recusado (RN32)$q$, v_obtido, v_ok);
END $t$;

-- @@ 1.4 - Atribuir uma conversa nova a um corretor cujo papel ja terminou (Sergio)
DO $t$
DECLARE v_erro TEXT; v_ok BOOLEAN; v_obtido TEXT;
BEGIN
    BEGIN
        INSERT INTO conversa (id_cliente, id_corretor, id_estagio) VALUES (5, 10, (SELECT min(id_estagio) FROM funil_estagio));
        SET CONSTRAINTS ALL IMMEDIATE;   -- confere agora as regras verificadas no fim da transacao
    EXCEPTION WHEN OTHERS THEN
        v_erro := SQLERRM;
    END;
    IF v_erro IS NULL THEN
        v_ok := FALSE; v_obtido := 'aceito (deveria ter sido recusado)';
    ELSE
        v_ok := strpos(v_erro, $q$RN32$q$) > 0; v_obtido := 'recusado: ' || v_erro;
    END IF;
    INSERT INTO resultado_teste VALUES ($q$1.4$q$, 1, $q$Atribuir uma conversa nova a um corretor cujo papel ja terminou (Sergio)$q$, $q$recusado (RN32)$q$, v_obtido, v_ok);
END $t$;

-- @@ 1.5 - Lancar conta a receber com Ana como inquilina (ela e cliente e proprietaria)
DO $t$
DECLARE v_erro TEXT; v_ok BOOLEAN; v_obtido TEXT;
BEGIN
    BEGIN
        INSERT INTO conta_receber (id_contrato, id_categoria, id_pagador, tp_papel_pagador, vl_receber, dt_vencimento)
        VALUES (201, pg_temp.cat('corretagem_venda'), 5, 'inquilino', 100, '2026-05-01');
        SET CONSTRAINTS ALL IMMEDIATE;   -- confere agora as regras verificadas no fim da transacao
    EXCEPTION WHEN OTHERS THEN
        v_erro := SQLERRM;
    END;
    IF v_erro IS NULL THEN
        v_ok := FALSE; v_obtido := 'aceito (deveria ter sido recusado)';
    ELSE
        v_ok := strpos(v_erro, $q$RN32$q$) > 0; v_obtido := 'recusado: ' || v_erro;
    END IF;
    INSERT INTO resultado_teste VALUES ($q$1.5$q$, 1, $q$Lancar conta a receber com Ana como inquilina (ela e cliente e proprietaria)$q$, $q$recusado (RN32)$q$, v_obtido, v_ok);
END $t$;

-- @@ 1.6 - Cobrar do banco uma conta de contrato que ele nao financiou
DO $t$
DECLARE v_erro TEXT; v_ok BOOLEAN; v_obtido TEXT;
BEGIN
    BEGIN
        INSERT INTO conta_receber (id_contrato, id_categoria, id_pagador, tp_papel_pagador, vl_receber, dt_vencimento)
        VALUES (201, pg_temp.cat('corretagem_venda'), 7, 'instituicao_financeira', 100, '2026-05-01');
        SET CONSTRAINTS ALL IMMEDIATE;   -- confere agora as regras verificadas no fim da transacao
    EXCEPTION WHEN OTHERS THEN
        v_erro := SQLERRM;
    END;
    IF v_erro IS NULL THEN
        v_ok := FALSE; v_obtido := 'aceito (deveria ter sido recusado)';
    ELSE
        v_ok := strpos(v_erro, $q$RN27$q$) > 0; v_obtido := 'recusado: ' || v_erro;
    END IF;
    INSERT INTO resultado_teste VALUES ($q$1.6$q$, 1, $q$Cobrar do banco uma conta de contrato que ele nao financiou$q$, $q$recusado (RN27)$q$, v_obtido, v_ok);
END $t$;

-- @@ 1.7 - Pagamento de comissao efetivado pelo financeiro (Fabio)
DO $t$
DECLARE v_erro TEXT; v_ok BOOLEAN; v_obtido TEXT;
BEGIN
    BEGIN
        INSERT INTO pagamento VALUES (300, 1, 1, 2, '2026-03-10', 1400, 1, NULL, NULL);
        SET CONSTRAINTS ALL IMMEDIATE;   -- confere agora as regras verificadas no fim da transacao
    EXCEPTION WHEN OTHERS THEN
        v_erro := SQLERRM;
    END;
    IF v_erro IS NULL THEN
        v_ok := FALSE; v_obtido := 'aceito (deveria ter sido recusado)';
    ELSE
        v_ok := strpos(v_erro, $q$PO01$q$) > 0; v_obtido := 'recusado: ' || v_erro;
    END IF;
    INSERT INTO resultado_teste VALUES ($q$1.7$q$, 1, $q$Pagamento de comissao efetivado pelo financeiro (Fabio)$q$, $q$recusado (PO01)$q$, v_obtido, v_ok);
END $t$;

-- @@ 1.8 - Pagamento da mesma comissao efetivado pela administradora (Carla)
DO $t$
DECLARE v_erro TEXT; v_ok BOOLEAN; v_obtido TEXT;
BEGIN
    BEGIN
        INSERT INTO pagamento VALUES (300, 1, 1, 1, '2026-03-10', 1400, 1, NULL, NULL);
        SET CONSTRAINTS ALL IMMEDIATE;   -- confere agora as regras verificadas no fim da transacao
    EXCEPTION WHEN OTHERS THEN
        v_erro := SQLERRM;
    END;
    IF v_erro IS NULL THEN
        v_ok := ((SELECT st_conta FROM vw_conta_pagar WHERE id_conta_pagar = 300) = 'paga');
        v_obtido := 'aceito: ' || ('conta 300 ' || (SELECT st_conta FROM vw_conta_pagar WHERE id_conta_pagar = 300));
    ELSE
        v_ok := FALSE; v_obtido := 'recusado: ' || v_erro;
    END IF;
    INSERT INTO resultado_teste VALUES ($q$1.8$q$, 1, $q$Pagamento da mesma comissao efetivado pela administradora (Carla)$q$, $q$aceito$q$, v_obtido, v_ok);
END $t$;

-- @@ 2.1 - Numero de WhatsApp compartilhado por Ana (titular) e Bruno
DO $t$
DECLARE v_erro TEXT; v_ok BOOLEAN; v_obtido TEXT;
BEGIN
    BEGIN
        INSERT INTO telefone (id_usuario, nr_sequencia, nr_telefone, fl_principal, fl_titular) VALUES
        (5, 3, '11977776666', FALSE, TRUE), (6, 3, '11977776666', FALSE, FALSE);
        SET CONSTRAINTS ALL IMMEDIATE;   -- confere agora as regras verificadas no fim da transacao
    EXCEPTION WHEN OTHERS THEN
        v_erro := SQLERRM;
    END;
    IF v_erro IS NULL THEN
        v_ok := ((SELECT count(*) FROM telefone WHERE nr_telefone = '11977776666') = 2 AND (SELECT count(*) FROM telefone WHERE nr_telefone = '11977776666' AND fl_titular) = 1);
        v_obtido := 'aceito: ' || ('2 pessoas com o numero, 1 titular');
    ELSE
        v_ok := FALSE; v_obtido := 'recusado: ' || v_erro;
    END IF;
    INSERT INTO resultado_teste VALUES ($q$2.1$q$, 2, $q$Numero de WhatsApp compartilhado por Ana (titular) e Bruno$q$, $q$aceito$q$, v_obtido, v_ok);
END $t$;

-- @@ 2.2 - Marcar Bruno como segundo titular do mesmo numero
DO $t$
DECLARE v_erro TEXT; v_ok BOOLEAN; v_obtido TEXT;
BEGIN
    BEGIN
        UPDATE telefone SET fl_titular = TRUE WHERE id_usuario = 6 AND nr_telefone = '11977776666';
        SET CONSTRAINTS ALL IMMEDIATE;   -- confere agora as regras verificadas no fim da transacao
    EXCEPTION WHEN OTHERS THEN
        v_erro := SQLERRM;
    END;
    IF v_erro IS NULL THEN
        v_ok := FALSE; v_obtido := 'aceito (deveria ter sido recusado)';
    ELSE
        v_ok := strpos(v_erro, $q$ux_telefone_titular$q$) > 0; v_obtido := 'recusado: ' || v_erro;
    END IF;
    INSERT INTO resultado_teste VALUES ($q$2.2$q$, 2, $q$Marcar Bruno como segundo titular do mesmo numero$q$, $q$recusado (ux_telefone_titular)$q$, v_obtido, v_ok);
END $t$;

-- @@ 2.3 - Cadastrar um numero sem titular
DO $t$
DECLARE v_erro TEXT; v_ok BOOLEAN; v_obtido TEXT;
BEGIN
    BEGIN
        INSERT INTO telefone (id_usuario, nr_sequencia, nr_telefone, fl_principal, fl_titular) VALUES (6, 4, '11955554444', FALSE, FALSE);
        SET CONSTRAINTS ALL IMMEDIATE;   -- confere agora as regras verificadas no fim da transacao
    EXCEPTION WHEN OTHERS THEN
        v_erro := SQLERRM;
    END;
    IF v_erro IS NULL THEN
        v_ok := FALSE; v_obtido := 'aceito (deveria ter sido recusado)';
    ELSE
        v_ok := strpos(v_erro, $q$RN03$q$) > 0; v_obtido := 'recusado: ' || v_erro;
    END IF;
    INSERT INTO resultado_teste VALUES ($q$2.3$q$, 2, $q$Cadastrar um numero sem titular$q$, $q$recusado (RN03)$q$, v_obtido, v_ok);
END $t$;

-- @@ 2.4 - Repetir o mesmo numero no cadastro da mesma pessoa
DO $t$
DECLARE v_erro TEXT; v_ok BOOLEAN; v_obtido TEXT;
BEGIN
    BEGIN
        INSERT INTO telefone (id_usuario, nr_sequencia, nr_telefone, fl_principal, fl_titular) VALUES (5, 4, '1133334444', FALSE, FALSE);
        SET CONSTRAINTS ALL IMMEDIATE;   -- confere agora as regras verificadas no fim da transacao
    EXCEPTION WHEN OTHERS THEN
        v_erro := SQLERRM;
    END;
    IF v_erro IS NULL THEN
        v_ok := FALSE; v_obtido := 'aceito (deveria ter sido recusado)';
    ELSE
        v_ok := strpos(v_erro, $q$uk_telefone_id_usuario_nr_telefone$q$) > 0; v_obtido := 'recusado: ' || v_erro;
    END IF;
    INSERT INTO resultado_teste VALUES ($q$2.4$q$, 2, $q$Repetir o mesmo numero no cadastro da mesma pessoa$q$, $q$recusado (uk_telefone_id_usuario_nr_telefone)$q$, v_obtido, v_ok);
END $t$;

-- @@ 2.5 - Passar a titularidade do fixo do casal de Ana para Bruno (em dois passos)
DO $t$
DECLARE v_erro TEXT; v_ok BOOLEAN; v_obtido TEXT;
BEGIN
    BEGIN
        UPDATE telefone SET fl_titular = FALSE WHERE id_usuario = 5 AND nr_telefone = '1133334444';
        UPDATE telefone SET fl_titular = TRUE WHERE id_usuario = 6 AND nr_telefone = '1133334444';
        SET CONSTRAINTS ALL IMMEDIATE;   -- confere agora as regras verificadas no fim da transacao
    EXCEPTION WHEN OTHERS THEN
        v_erro := SQLERRM;
    END;
    IF v_erro IS NULL THEN
        v_ok := ((SELECT id_usuario FROM telefone WHERE nr_telefone = '1133334444' AND fl_titular) = 6);
        v_obtido := 'aceito: ' || ('titular do fixo agora e o Bruno; o banco so confere no fim da transacao');
    ELSE
        v_ok := FALSE; v_obtido := 'recusado: ' || v_erro;
    END IF;
    INSERT INTO resultado_teste VALUES ($q$2.5$q$, 2, $q$Passar a titularidade do fixo do casal de Ana para Bruno (em dois passos)$q$, $q$aceito$q$, v_obtido, v_ok);
END $t$;

-- @@ 2.6 - Gravar um telefone com letras e simbolos
DO $t$
DECLARE v_erro TEXT; v_ok BOOLEAN; v_obtido TEXT;
BEGIN
    BEGIN
        INSERT INTO telefone (id_usuario, nr_sequencia, nr_telefone, fl_principal, fl_titular) VALUES (5, 5, '11-9999-0000', FALSE, TRUE);
        SET CONSTRAINTS ALL IMMEDIATE;   -- confere agora as regras verificadas no fim da transacao
    EXCEPTION WHEN OTHERS THEN
        v_erro := SQLERRM;
    END;
    IF v_erro IS NULL THEN
        v_ok := FALSE; v_obtido := 'aceito (deveria ter sido recusado)';
    ELSE
        v_ok := strpos(v_erro, $q$ck_telefone_nr_telefone$q$) > 0; v_obtido := 'recusado: ' || v_erro;
    END IF;
    INSERT INTO resultado_teste VALUES ($q$2.6$q$, 2, $q$Gravar um telefone com letras e simbolos$q$, $q$recusado (ck_telefone_nr_telefone)$q$, v_obtido, v_ok);
END $t$;

-- @@ 2.7 - Tirar o numero do cadastro do titular (Bruno) sem passar a titularidade a Ana
DO $t$
DECLARE v_erro TEXT; v_ok BOOLEAN; v_obtido TEXT;
BEGIN
    BEGIN
        DELETE FROM telefone WHERE id_usuario = 6 AND nr_telefone = '1133334444';
        SET CONSTRAINTS ALL IMMEDIATE;   -- confere agora as regras verificadas no fim da transacao
    EXCEPTION WHEN OTHERS THEN
        v_erro := SQLERRM;
    END;
    IF v_erro IS NULL THEN
        v_ok := FALSE; v_obtido := 'aceito (deveria ter sido recusado)';
    ELSE
        v_ok := strpos(v_erro, $q$RN03$q$) > 0; v_obtido := 'recusado: ' || v_erro;
    END IF;
    INSERT INTO resultado_teste VALUES ($q$2.7$q$, 2, $q$Tirar o numero do cadastro do titular (Bruno) sem passar a titularidade a Ana$q$, $q$recusado (RN03)$q$, v_obtido, v_ok);
END $t$;

-- @@ 3.1 - Inquilino paga R$ 1.200,00 do aluguel de R$ 2.000,00 (domingo, 05/04)
DO $t$
DECLARE v_erro TEXT; v_ok BOOLEAN; v_obtido TEXT;
BEGIN
    BEGIN
        INSERT INTO recebimento (id_conta_receber, nr_recebimento, id_conta, dt_recebimento, vl_recebido, id_forma_pagamento) VALUES (400, 1, 1, '2026-04-05', 1200, 1);
        SET CONSTRAINTS ALL IMMEDIATE;   -- confere agora as regras verificadas no fim da transacao
    EXCEPTION WHEN OTHERS THEN
        v_erro := SQLERRM;
    END;
    IF v_erro IS NULL THEN
        v_ok := (EXISTS (SELECT 1 FROM conta_pagar WHERE id_conta_receber_origem = 400 AND nr_recebimento_origem = 1 AND id_categoria = pg_temp.cat('repasse') AND id_favorecido = 8 AND vl_pagar = 1080 AND dt_vencimento = '2026-04-10'));
        v_obtido := 'aceito: ' || ((SELECT format('repasse de %s a Marta, vencendo em %s; aluguel com %s recebidos de %s', pg_temp.brl(vl_pagar), to_char(dt_vencimento, 'DD/MM/YYYY'), (SELECT pg_temp.brl(vl_baixado) FROM vw_conta_receber WHERE id_conta_receber = 400), pg_temp.brl(2000)) FROM conta_pagar WHERE id_conta_receber_origem = 400 AND nr_recebimento_origem = 1));
    ELSE
        v_ok := FALSE; v_obtido := 'recusado: ' || v_erro;
    END IF;
    INSERT INTO resultado_teste VALUES ($q$3.1$q$, 3, $q$Inquilino paga R$ 1.200,00 do aluguel de R$ 2.000,00 (domingo, 05/04)$q$, $q$aceito$q$, v_obtido, v_ok);
END $t$;

-- @@ 3.2 - Inquilino paga os R$ 800,00 restantes (segunda, 20/04)
DO $t$
DECLARE v_erro TEXT; v_ok BOOLEAN; v_obtido TEXT;
BEGIN
    BEGIN
        INSERT INTO recebimento (id_conta_receber, nr_recebimento, id_conta, dt_recebimento, vl_recebido, id_forma_pagamento) VALUES (400, 2, 1, '2026-04-20', 800, 1);
        SET CONSTRAINTS ALL IMMEDIATE;   -- confere agora as regras verificadas no fim da transacao
    EXCEPTION WHEN OTHERS THEN
        v_erro := SQLERRM;
    END;
    IF v_erro IS NULL THEN
        v_ok := (EXISTS (SELECT 1 FROM conta_pagar WHERE id_conta_receber_origem = 400 AND nr_recebimento_origem = 2 AND vl_pagar = 720 AND dt_vencimento = '2026-04-27') AND (SELECT st_conta FROM vw_conta_receber WHERE id_conta_receber = 400) = 'quitada' AND (SELECT sum(vl_pagar) FROM conta_pagar WHERE id_conta_receber_origem = 400) = 1800);
        v_obtido := 'aceito: ' || ((SELECT format('repasse de %s, vencendo em %s; aluguel quitado; repasses somam %s', pg_temp.brl(vl_pagar), to_char(dt_vencimento, 'DD/MM/YYYY'), (SELECT pg_temp.brl(sum(vl_pagar)) FROM conta_pagar WHERE id_conta_receber_origem = 400)) FROM conta_pagar WHERE id_conta_receber_origem = 400 AND nr_recebimento_origem = 2));
    ELSE
        v_ok := FALSE; v_obtido := 'recusado: ' || v_erro;
    END IF;
    INSERT INTO resultado_teste VALUES ($q$3.2$q$, 3, $q$Inquilino paga os R$ 800,00 restantes (segunda, 20/04)$q$, $q$aceito$q$, v_obtido, v_ok);
END $t$;

-- @@ 3.3 - Receber mais R$ 10,00 no aluguel ja quitado
DO $t$
DECLARE v_erro TEXT; v_ok BOOLEAN; v_obtido TEXT;
BEGIN
    BEGIN
        INSERT INTO recebimento (id_conta_receber, nr_recebimento, id_conta, dt_recebimento, vl_recebido, id_forma_pagamento) VALUES (400, 3, 1, '2026-04-21', 10, 1);
        SET CONSTRAINTS ALL IMMEDIATE;   -- confere agora as regras verificadas no fim da transacao
    EXCEPTION WHEN OTHERS THEN
        v_erro := SQLERRM;
    END;
    IF v_erro IS NULL THEN
        v_ok := FALSE; v_obtido := 'aceito (deveria ter sido recusado)';
    ELSE
        v_ok := strpos(v_erro, $q$RN29$q$) > 0; v_obtido := 'recusado: ' || v_erro;
    END IF;
    INSERT INTO resultado_teste VALUES ($q$3.3$q$, 3, $q$Receber mais R$ 10,00 no aluguel ja quitado$q$, $q$recusado (RN29)$q$, v_obtido, v_ok);
END $t$;

-- @@ 3.4 - Alterar o valor de um recebimento que ja gerou repasse
DO $t$
DECLARE v_erro TEXT; v_ok BOOLEAN; v_obtido TEXT;
BEGIN
    BEGIN
        UPDATE recebimento SET vl_recebido = 1000 WHERE id_conta_receber = 400 AND nr_recebimento = 1;
        SET CONSTRAINTS ALL IMMEDIATE;   -- confere agora as regras verificadas no fim da transacao
    EXCEPTION WHEN OTHERS THEN
        v_erro := SQLERRM;
    END;
    IF v_erro IS NULL THEN
        v_ok := FALSE; v_obtido := 'aceito (deveria ter sido recusado)';
    ELSE
        v_ok := strpos(v_erro, $q$RN30$q$) > 0; v_obtido := 'recusado: ' || v_erro;
    END IF;
    INSERT INTO resultado_teste VALUES ($q$3.4$q$, 3, $q$Alterar o valor de um recebimento que ja gerou repasse$q$, $q$recusado (RN30)$q$, v_obtido, v_ok);
END $t$;

-- @@ 7.1 - Dividir a comissao da venda 201: Rui 60% e Lia 40%
DO $t$
DECLARE v_erro TEXT; v_ok BOOLEAN; v_obtido TEXT;
BEGIN
    BEGIN
        INSERT INTO comissao (id_contrato, id_corretor, pc_comissao, tp_regra_pagamento) VALUES (201, 3, 60, 'recebimento'), (201, 4, 40, 'recebimento');
        SET CONSTRAINTS ALL IMMEDIATE;   -- confere agora as regras verificadas no fim da transacao
    EXCEPTION WHEN OTHERS THEN
        v_erro := SQLERRM;
    END;
    IF v_erro IS NULL THEN
        v_ok := ((SELECT sum(pc_comissao) FROM comissao WHERE id_contrato = 201) = 100);
        v_obtido := 'aceito: ' || ('soma = ' || (SELECT round(sum(pc_comissao)) FROM comissao WHERE id_contrato = 201) || '%');
    ELSE
        v_ok := FALSE; v_obtido := 'recusado: ' || v_erro;
    END IF;
    INSERT INTO resultado_teste VALUES ($q$7.1$q$, 7, $q$Dividir a comissao da venda 201: Rui 60% e Lia 40%$q$, $q$aceito$q$, v_obtido, v_ok);
END $t$;

-- @@ 7.2 - Incluir Paulo com 1% no mesmo contrato
DO $t$
DECLARE v_erro TEXT; v_ok BOOLEAN; v_obtido TEXT;
BEGIN
    BEGIN
        INSERT INTO comissao (id_contrato, id_corretor, pc_comissao, tp_regra_pagamento) VALUES (201, 9, 1, 'recebimento');
        SET CONSTRAINTS ALL IMMEDIATE;   -- confere agora as regras verificadas no fim da transacao
    EXCEPTION WHEN OTHERS THEN
        v_erro := SQLERRM;
    END;
    IF v_erro IS NULL THEN
        v_ok := FALSE; v_obtido := 'aceito (deveria ter sido recusado)';
    ELSE
        v_ok := strpos(v_erro, $q$RN20$q$) > 0; v_obtido := 'recusado: ' || v_erro;
    END IF;
    INSERT INTO resultado_teste VALUES ($q$7.2$q$, 7, $q$Incluir Paulo com 1% no mesmo contrato$q$, $q$recusado (RN20)$q$, v_obtido, v_ok);
END $t$;

-- @@ 7.3 - Aumentar a parte de Lia de 40% para 45%
DO $t$
DECLARE v_erro TEXT; v_ok BOOLEAN; v_obtido TEXT;
BEGIN
    BEGIN
        UPDATE comissao SET pc_comissao = 45 WHERE id_contrato = 201 AND id_corretor = 4;
        SET CONSTRAINTS ALL IMMEDIATE;   -- confere agora as regras verificadas no fim da transacao
    EXCEPTION WHEN OTHERS THEN
        v_erro := SQLERRM;
    END;
    IF v_erro IS NULL THEN
        v_ok := FALSE; v_obtido := 'aceito (deveria ter sido recusado)';
    ELSE
        v_ok := strpos(v_erro, $q$RN20$q$) > 0; v_obtido := 'recusado: ' || v_erro;
    END IF;
    INSERT INTO resultado_teste VALUES ($q$7.3$q$, 7, $q$Aumentar a parte de Lia de 40% para 45%$q$, $q$recusado (RN20)$q$, v_obtido, v_ok);
END $t$;

-- @@ 7.4 - Gravar comissao com percentual 0
DO $t$
DECLARE v_erro TEXT; v_ok BOOLEAN; v_obtido TEXT;
BEGIN
    BEGIN
        INSERT INTO comissao (id_contrato, id_corretor, pc_comissao, tp_regra_pagamento) VALUES (201, 9, 0, 'recebimento');
        SET CONSTRAINTS ALL IMMEDIATE;   -- confere agora as regras verificadas no fim da transacao
    EXCEPTION WHEN OTHERS THEN
        v_erro := SQLERRM;
    END;
    IF v_erro IS NULL THEN
        v_ok := FALSE; v_obtido := 'aceito (deveria ter sido recusado)';
    ELSE
        v_ok := strpos(v_erro, $q$ck_comissao_pc_comissao$q$) > 0; v_obtido := 'recusado: ' || v_erro;
    END IF;
    INSERT INTO resultado_teste VALUES ($q$7.4$q$, 7, $q$Gravar comissao com percentual 0$q$, $q$recusado (ck_comissao_pc_comissao)$q$, v_obtido, v_ok);
END $t$;

-- @@ 7.5 - Cancelar a comissao de Lia e incluir Paulo com 40%
DO $t$
DECLARE v_erro TEXT; v_ok BOOLEAN; v_obtido TEXT;
BEGIN
    BEGIN
        UPDATE comissao SET st_comissao = 'cancelada' WHERE id_contrato = 201 AND id_corretor = 4;
        INSERT INTO comissao (id_contrato, id_corretor, pc_comissao, tp_regra_pagamento) VALUES (201, 9, 40, 'recebimento');
        SET CONSTRAINTS ALL IMMEDIATE;   -- confere agora as regras verificadas no fim da transacao
    EXCEPTION WHEN OTHERS THEN
        v_erro := SQLERRM;
    END;
    IF v_erro IS NULL THEN
        v_ok := ((SELECT sum(pc_comissao) FROM comissao WHERE id_contrato = 201 AND st_comissao <> 'cancelada') = 100);
        v_obtido := 'aceito: ' || ('soma das nao canceladas = ' || (SELECT round(sum(pc_comissao)) FROM comissao WHERE id_contrato = 201 AND st_comissao <> 'cancelada') || '%; comissao de Paulo = ' || (SELECT pg_temp.brl(vl_comissao) FROM vw_comissao WHERE id_contrato = 201 AND id_corretor = 9));
    ELSE
        v_ok := FALSE; v_obtido := 'recusado: ' || v_erro;
    END IF;
    INSERT INTO resultado_teste VALUES ($q$7.5$q$, 7, $q$Cancelar a comissao de Lia e incluir Paulo com 40%$q$, $q$aceito$q$, v_obtido, v_ok);
END $t$;

-- @@ 5.1 - Importar o extrato de abril (4 movimentos)
DO $t$
DECLARE v_erro TEXT; v_ok BOOLEAN; v_obtido TEXT;
BEGIN
    BEGIN
        INSERT INTO movimento_bancario (id_conta, nr_movimento, cd_transacao_banco, dt_movimento, vl_movimento, tp_movimento, ds_historico) VALUES
        (1, 1, 'TX-0405-001', '2026-04-05', 1200, 'credito', 'PIX RECEBIDO BRUNO LIMA'),
        (1, 2, 'TX-0420-002', '2026-04-20', 800, 'credito', 'PIX RECEBIDO BRUNO LIMA'),
        (1, 3, 'TX-0410-003', '2026-04-10', 1080, 'debito', 'PIX ENVIADO MARTA ROCHA'),
        (1, 4, 'TX-0415-004', '2026-04-15', 350, 'credito', 'TED RECEBIDA');
        SET CONSTRAINTS ALL IMMEDIATE;   -- confere agora as regras verificadas no fim da transacao
    EXCEPTION WHEN OTHERS THEN
        v_erro := SQLERRM;
    END;
    IF v_erro IS NULL THEN
        v_ok := ((SELECT count(*) FROM vw_movimento_bancario WHERE st_conciliacao = 'pendente') = 4);
        v_obtido := 'aceito: ' || ('4 movimentos importados, todos pendentes');
    ELSE
        v_ok := FALSE; v_obtido := 'recusado: ' || v_erro;
    END IF;
    INSERT INTO resultado_teste VALUES ($q$5.1$q$, 5, $q$Importar o extrato de abril (4 movimentos)$q$, $q$aceito$q$, v_obtido, v_ok);
END $t$;

-- @@ 5.2 - Importar de novo a mesma transacao do banco
DO $t$
DECLARE v_erro TEXT; v_ok BOOLEAN; v_obtido TEXT;
BEGIN
    BEGIN
        INSERT INTO movimento_bancario VALUES (1, 5, 'TX-0405-001', '2026-04-05', 1200, 'credito', 'PIX RECEBIDO BRUNO LIMA', DEFAULT);
        SET CONSTRAINTS ALL IMMEDIATE;   -- confere agora as regras verificadas no fim da transacao
    EXCEPTION WHEN OTHERS THEN
        v_erro := SQLERRM;
    END;
    IF v_erro IS NULL THEN
        v_ok := FALSE; v_obtido := 'aceito (deveria ter sido recusado)';
    ELSE
        v_ok := strpos(v_erro, $q$uk_movimento_bancario_id_conta_cd_transacao_banco$q$) > 0; v_obtido := 'recusado: ' || v_erro;
    END IF;
    INSERT INTO resultado_teste VALUES ($q$5.2$q$, 5, $q$Importar de novo a mesma transacao do banco$q$, $q$recusado (uk_movimento_bancario_id_conta_cd_transacao_banco)$q$, v_obtido, v_ok);
END $t$;

-- @@ 5.3 - Conciliar o recebimento de R$ 1.200,00 com o credito de R$ 1.200,00
DO $t$
DECLARE v_erro TEXT; v_ok BOOLEAN; v_obtido TEXT;
BEGIN
    BEGIN
        UPDATE recebimento SET nr_movimento = 1, dt_conciliacao = '2026-04-06' WHERE id_conta_receber = 400 AND nr_recebimento = 1;
        SET CONSTRAINTS ALL IMMEDIATE;   -- confere agora as regras verificadas no fim da transacao
    EXCEPTION WHEN OTHERS THEN
        v_erro := SQLERRM;
    END;
    IF v_erro IS NULL THEN
        v_ok := ((SELECT st_conciliacao FROM vw_movimento_bancario WHERE nr_movimento = 1) = 'conciliado');
        v_obtido := 'aceito: ' || ('movimento 1 ' || (SELECT st_conciliacao FROM vw_movimento_bancario WHERE nr_movimento = 1));
    ELSE
        v_ok := FALSE; v_obtido := 'recusado: ' || v_erro;
    END IF;
    INSERT INTO resultado_teste VALUES ($q$5.3$q$, 5, $q$Conciliar o recebimento de R$ 1.200,00 com o credito de R$ 1.200,00$q$, $q$aceito$q$, v_obtido, v_ok);
END $t$;

-- @@ 5.4 - Conferir o pagamento do repasse com um movimento de credito
DO $t$
DECLARE v_erro TEXT; v_ok BOOLEAN; v_obtido TEXT;
BEGIN
    BEGIN
        INSERT INTO pagamento VALUES ((SELECT id_conta_pagar FROM conta_pagar WHERE id_conta_receber_origem = 400 AND nr_recebimento_origem = 1),
        1, 1, 2, '2026-04-10', 1080, 1, 1, '2026-04-11');
        SET CONSTRAINTS ALL IMMEDIATE;   -- confere agora as regras verificadas no fim da transacao
    EXCEPTION WHEN OTHERS THEN
        v_erro := SQLERRM;
    END;
    IF v_erro IS NULL THEN
        v_ok := FALSE; v_obtido := 'aceito (deveria ter sido recusado)';
    ELSE
        v_ok := strpos(v_erro, $q$RN45$q$) > 0; v_obtido := 'recusado: ' || v_erro;
    END IF;
    INSERT INTO resultado_teste VALUES ($q$5.4$q$, 5, $q$Conferir o pagamento do repasse com um movimento de credito$q$, $q$recusado (RN45)$q$, v_obtido, v_ok);
END $t$;

-- @@ 5.5 - Pagar o repasse de R$ 1.080,00 e conferir com o debito do extrato
DO $t$
DECLARE v_erro TEXT; v_ok BOOLEAN; v_obtido TEXT;
BEGIN
    BEGIN
        INSERT INTO pagamento VALUES ((SELECT id_conta_pagar FROM conta_pagar WHERE id_conta_receber_origem = 400 AND nr_recebimento_origem = 1),
        1, 1, 2, '2026-04-10', 1080, 1, 3, '2026-04-11');
        SET CONSTRAINTS ALL IMMEDIATE;   -- confere agora as regras verificadas no fim da transacao
    EXCEPTION WHEN OTHERS THEN
        v_erro := SQLERRM;
    END;
    IF v_erro IS NULL THEN
        v_ok := ((SELECT st_conciliacao FROM vw_movimento_bancario WHERE nr_movimento = 3) = 'conciliado');
        v_obtido := 'aceito: ' || ('repasse pago pelo financeiro; movimento 3 ' || (SELECT st_conciliacao FROM vw_movimento_bancario WHERE nr_movimento = 3));
    ELSE
        v_ok := FALSE; v_obtido := 'recusado: ' || v_erro;
    END IF;
    INSERT INTO resultado_teste VALUES ($q$5.5$q$, 5, $q$Pagar o repasse de R$ 1.080,00 e conferir com o debito do extrato$q$, $q$aceito$q$, v_obtido, v_ok);
END $t$;

-- @@ 5.6 - Conciliar o recebimento de R$ 800,00 com um credito de R$ 350,00
DO $t$
DECLARE v_erro TEXT; v_ok BOOLEAN; v_obtido TEXT;
BEGIN
    BEGIN
        UPDATE recebimento SET nr_movimento = 4, dt_conciliacao = '2026-04-21' WHERE id_conta_receber = 400 AND nr_recebimento = 2;
        SET CONSTRAINTS ALL IMMEDIATE;   -- confere agora as regras verificadas no fim da transacao
    EXCEPTION WHEN OTHERS THEN
        v_erro := SQLERRM;
    END;
    IF v_erro IS NULL THEN
        v_ok := FALSE; v_obtido := 'aceito (deveria ter sido recusado)';
    ELSE
        v_ok := strpos(v_erro, $q$RN45$q$) > 0; v_obtido := 'recusado: ' || v_erro;
    END IF;
    INSERT INTO resultado_teste VALUES ($q$5.6$q$, 5, $q$Conciliar o recebimento de R$ 800,00 com um credito de R$ 350,00$q$, $q$recusado (RN45)$q$, v_obtido, v_ok);
END $t$;

-- @@ 5.7 - Conciliar os R$ 800,00 com o credito certo; o credito de R$ 350,00 fica pendente
DO $t$
DECLARE v_erro TEXT; v_ok BOOLEAN; v_obtido TEXT;
BEGIN
    BEGIN
        UPDATE recebimento SET nr_movimento = 2, dt_conciliacao = '2026-04-21' WHERE id_conta_receber = 400 AND nr_recebimento = 2;
        SET CONSTRAINTS ALL IMMEDIATE;   -- confere agora as regras verificadas no fim da transacao
    EXCEPTION WHEN OTHERS THEN
        v_erro := SQLERRM;
    END;
    IF v_erro IS NULL THEN
        v_ok := ((SELECT st_conciliacao FROM vw_movimento_bancario WHERE nr_movimento = 2) = 'conciliado' AND (SELECT st_conciliacao FROM vw_movimento_bancario WHERE nr_movimento = 4) = 'pendente');
        v_obtido := 'aceito: ' || ((SELECT string_agg(format('mov. %s: %s', nr_movimento, st_conciliacao), '; ' ORDER BY nr_movimento) FROM vw_movimento_bancario));
    ELSE
        v_ok := FALSE; v_obtido := 'recusado: ' || v_erro;
    END IF;
    INSERT INTO resultado_teste VALUES ($q$5.7$q$, 5, $q$Conciliar os R$ 800,00 com o credito certo; o credito de R$ 350,00 fica pendente$q$, $q$aceito$q$, v_obtido, v_ok);
END $t$;

-- @@ 4.1 - Encerrar a locacao antes da data de termino (15/06/2026)
DO $t$
DECLARE v_erro TEXT; v_ok BOOLEAN; v_obtido TEXT;
BEGIN
    BEGIN
        CALL encerrar_contrato(200, '2026-06-15');
        SET CONSTRAINTS ALL IMMEDIATE;   -- confere agora as regras verificadas no fim da transacao
    EXCEPTION WHEN OTHERS THEN
        v_erro := SQLERRM;
    END;
    IF v_erro IS NULL THEN
        v_ok := FALSE; v_obtido := 'aceito (deveria ter sido recusado)';
    ELSE
        v_ok := strpos(v_erro, $q$RN44$q$) > 0; v_obtido := 'recusado: ' || v_erro;
    END IF;
    INSERT INTO resultado_teste VALUES ($q$4.1$q$, 4, $q$Encerrar a locacao antes da data de termino (15/06/2026)$q$, $q$recusado (RN44)$q$, v_obtido, v_ok);
END $t$;

-- @@ 4.2 - Rescindir a locacao em 15/06/2026 a pedido do inquilino, com multa de R$ 4.000,00
DO $t$
DECLARE v_erro TEXT; v_ok BOOLEAN; v_obtido TEXT;
BEGIN
    BEGIN
        CALL rescindir_contrato(200, '2026-06-15', 'Inquilino mudou de cidade', 'cliente', 4000);
        SET CONSTRAINTS ALL IMMEDIATE;   -- confere agora as regras verificadas no fim da transacao
    EXCEPTION WHEN OTHERS THEN
        v_erro := SQLERRM;
    END;
    IF v_erro IS NULL THEN
        v_ok := ((SELECT st_contrato FROM contrato WHERE id_contrato = 200) = 'rescindido'
     AND (SELECT array_agg(id_conta_receber ORDER BY id_conta_receber) FROM conta_receber WHERE id_contrato = 200 AND fl_cancelada) = ARRAY[403, 404]
     AND EXISTS (SELECT 1 FROM conta_receber WHERE id_contrato = 200 AND id_categoria = pg_temp.cat('multa_rescisoria') AND vl_receber = 4000 AND id_pagador = 6 AND tp_papel_pagador = 'inquilino')
     AND (SELECT st_comissao FROM comissao WHERE id_contrato = 200 AND id_corretor = 9) = 'cancelada'
     AND (SELECT st_comissao FROM comissao WHERE id_contrato = 200 AND id_corretor = 3) = 'liberada'
     AND (SELECT st_imovel FROM imovel WHERE id_imovel = 10) = 'disponivel'
     AND (SELECT dt_fim FROM inquilino WHERE id_usuario = 6) = '2026-06-15'
     AND NOT EXISTS (SELECT 1 FROM conta_pagar WHERE id_conta_receber_origem = 400 AND fl_cancelada));
        v_obtido := 'aceito: ' || ('canceladas as contas de julho e agosto; maio e junho continuam devidas; multa de R$ 4.000,00 lancada; comissao pendente cancelada e liberada mantida; repasses mantidos; imovel ' || (SELECT st_imovel FROM imovel WHERE id_imovel = 10) || '; papel de inquilino ate ' || (SELECT to_char(dt_fim, 'DD/MM/YYYY') FROM inquilino WHERE id_usuario = 6));
    ELSE
        v_ok := FALSE; v_obtido := 'recusado: ' || v_erro;
    END IF;
    INSERT INTO resultado_teste VALUES ($q$4.2$q$, 4, $q$Rescindir a locacao em 15/06/2026 a pedido do inquilino, com multa de R$ 4.000,00$q$, $q$aceito$q$, v_obtido, v_ok);
END $t$;

-- @@ 4.3 - Cancelar o contrato ja rescindido
DO $t$
DECLARE v_erro TEXT; v_ok BOOLEAN; v_obtido TEXT;
BEGIN
    BEGIN
        CALL cancelar_contrato(200, '2026-06-20', 'Teste');
        SET CONSTRAINTS ALL IMMEDIATE;   -- confere agora as regras verificadas no fim da transacao
    EXCEPTION WHEN OTHERS THEN
        v_erro := SQLERRM;
    END;
    IF v_erro IS NULL THEN
        v_ok := FALSE; v_obtido := 'aceito (deveria ter sido recusado)';
    ELSE
        v_ok := strpos(v_erro, $q$RN37$q$) > 0; v_obtido := 'recusado: ' || v_erro;
    END IF;
    INSERT INTO resultado_teste VALUES ($q$4.3$q$, 4, $q$Cancelar o contrato ja rescindido$q$, $q$recusado (RN37)$q$, v_obtido, v_ok);
END $t$;

-- @@ 4.4 - Cancelar a venda 202 porque o banco reprovou o financiamento
DO $t$
DECLARE v_erro TEXT; v_ok BOOLEAN; v_obtido TEXT;
BEGIN
    BEGIN
        CALL cancelar_contrato(202, '2026-05-02', 'Financiamento reprovado pelo banco');
        SET CONSTRAINTS ALL IMMEDIATE;   -- confere agora as regras verificadas no fim da transacao
    EXCEPTION WHEN OTHERS THEN
        v_erro := SQLERRM;
    END;
    IF v_erro IS NULL THEN
        v_ok := ((SELECT st_contrato FROM contrato WHERE id_contrato = 202) = 'cancelado'
     AND (SELECT fl_cancelada FROM conta_receber WHERE id_conta_receber = 411)
     AND (SELECT st_comissao FROM comissao WHERE id_contrato = 202 AND id_corretor = 4) = 'cancelada'
     AND (SELECT st_imovel FROM imovel WHERE id_imovel = 12) = 'disponivel');
        v_obtido := 'aceito: ' || ('contrato cancelado; corretagem sem baixa cancelada; comissao cancelada; imovel ' || (SELECT st_imovel FROM imovel WHERE id_imovel = 12));
    ELSE
        v_ok := FALSE; v_obtido := 'recusado: ' || v_erro;
    END IF;
    INSERT INTO resultado_teste VALUES ($q$4.4$q$, 4, $q$Cancelar a venda 202 porque o banco reprovou o financiamento$q$, $q$aceito$q$, v_obtido, v_ok);
END $t$;

-- @@ 4.5 - Encerrar a venda 201 com a corretagem ainda em aberto
DO $t$
DECLARE v_erro TEXT; v_ok BOOLEAN; v_obtido TEXT;
BEGIN
    BEGIN
        CALL encerrar_contrato(201, '2026-04-30');
        SET CONSTRAINTS ALL IMMEDIATE;   -- confere agora as regras verificadas no fim da transacao
    EXCEPTION WHEN OTHERS THEN
        v_erro := SQLERRM;
    END;
    IF v_erro IS NULL THEN
        v_ok := FALSE; v_obtido := 'aceito (deveria ter sido recusado)';
    ELSE
        v_ok := strpos(v_erro, $q$RN44$q$) > 0; v_obtido := 'recusado: ' || v_erro;
    END IF;
    INSERT INTO resultado_teste VALUES ($q$4.5$q$, 4, $q$Encerrar a venda 201 com a corretagem ainda em aberto$q$, $q$recusado (RN44)$q$, v_obtido, v_ok);
END $t$;

-- @@ 4.6 - Receber a corretagem da venda 201 e encerrar o contrato
DO $t$
DECLARE v_erro TEXT; v_ok BOOLEAN; v_obtido TEXT;
BEGIN
    BEGIN
        INSERT INTO recebimento (id_conta_receber, nr_recebimento, id_conta, dt_recebimento, vl_recebido, id_forma_pagamento) VALUES (410, 1, 1, '2026-04-20', 28800, 2);
        CALL encerrar_contrato(201, '2026-04-30');
        SET CONSTRAINTS ALL IMMEDIATE;   -- confere agora as regras verificadas no fim da transacao
    EXCEPTION WHEN OTHERS THEN
        v_erro := SQLERRM;
    END;
    IF v_erro IS NULL THEN
        v_ok := ((SELECT st_contrato FROM contrato WHERE id_contrato = 201) = 'encerrado'
     AND (SELECT st_imovel FROM imovel WHERE id_imovel = 11) = 'vendido'
     AND NOT EXISTS (SELECT 1 FROM conta_pagar WHERE id_conta_receber_origem = 410));
        v_obtido := 'aceito: ' || ('contrato encerrado; nenhum lancamento cancelado; imovel ' || (SELECT st_imovel FROM imovel WHERE id_imovel = 11));
    ELSE
        v_ok := FALSE; v_obtido := 'recusado: ' || v_erro;
    END IF;
    INSERT INTO resultado_teste VALUES ($q$4.6$q$, 4, $q$Receber a corretagem da venda 201 e encerrar o contrato$q$, $q$aceito$q$, v_obtido, v_ok);
END $t$;

-- @@ 6.1 - Conferir a trilha de auditoria gravada pela rescisao do contrato 200
DO $t$
DECLARE v_erro TEXT; v_ok BOOLEAN; v_obtido TEXT;
BEGIN
    BEGIN
        NULL;
        SET CONSTRAINTS ALL IMMEDIATE;   -- confere agora as regras verificadas no fim da transacao
    EXCEPTION WHEN OTHERS THEN
        v_erro := SQLERRM;
    END;
    IF v_erro IS NULL THEN
        v_ok := (EXISTS (SELECT 1 FROM auditoria a JOIN auditoria_campo c ON c.id_auditoria = a.id_auditoria
              WHERE a.id_contrato = 200 AND c.nm_campo = 'st_contrato' AND c.ds_valor_anterior = 'vigente' AND c.ds_valor_novo = 'rescindido')
     AND (SELECT count(*) FROM auditoria WHERE id_conta_receber IN (403, 404) AND tp_acao = 'cancelamento') = 2
     AND NOT EXISTS (SELECT 1 FROM auditoria WHERE num_nonnulls(id_contrato, id_proposta, id_comissao_contrato, id_conta_receber,
                                                                id_recebimento_conta, id_conta_pagar, id_pagamento_conta) <> 1));
        v_obtido := 'aceito: ' || ((SELECT count(*) FROM auditoria) || ' registros de auditoria, todos com exatamente uma referencia; st_contrato: vigente -> rescindido');
    ELSE
        v_ok := FALSE; v_obtido := 'recusado: ' || v_erro;
    END IF;
    INSERT INTO resultado_teste VALUES ($q$6.1$q$, 6, $q$Conferir a trilha de auditoria gravada pela rescisao do contrato 200$q$, $q$aceito$q$, v_obtido, v_ok);
END $t$;

-- @@ 6.2 - Gravar auditoria apontando para dois registros (contrato e proposta)
DO $t$
DECLARE v_erro TEXT; v_ok BOOLEAN; v_obtido TEXT;
BEGIN
    BEGIN
        INSERT INTO auditoria (id_usuario, tp_acao, id_contrato, id_proposta) VALUES (1, 'alteracao', 200, 100);
        SET CONSTRAINTS ALL IMMEDIATE;   -- confere agora as regras verificadas no fim da transacao
    EXCEPTION WHEN OTHERS THEN
        v_erro := SQLERRM;
    END;
    IF v_erro IS NULL THEN
        v_ok := FALSE; v_obtido := 'aceito (deveria ter sido recusado)';
    ELSE
        v_ok := strpos(v_erro, $q$ck_auditoria_arco_exclusivo$q$) > 0; v_obtido := 'recusado: ' || v_erro;
    END IF;
    INSERT INTO resultado_teste VALUES ($q$6.2$q$, 6, $q$Gravar auditoria apontando para dois registros (contrato e proposta)$q$, $q$recusado (ck_auditoria_arco_exclusivo)$q$, v_obtido, v_ok);
END $t$;

-- @@ 6.3 - Gravar auditoria sem apontar para nenhum registro
DO $t$
DECLARE v_erro TEXT; v_ok BOOLEAN; v_obtido TEXT;
BEGIN
    BEGIN
        INSERT INTO auditoria (id_usuario, tp_acao) VALUES (1, 'alteracao');
        SET CONSTRAINTS ALL IMMEDIATE;   -- confere agora as regras verificadas no fim da transacao
    EXCEPTION WHEN OTHERS THEN
        v_erro := SQLERRM;
    END;
    IF v_erro IS NULL THEN
        v_ok := FALSE; v_obtido := 'aceito (deveria ter sido recusado)';
    ELSE
        v_ok := strpos(v_erro, $q$ck_auditoria_arco_exclusivo$q$) > 0; v_obtido := 'recusado: ' || v_erro;
    END IF;
    INSERT INTO resultado_teste VALUES ($q$6.3$q$, 6, $q$Gravar auditoria sem apontar para nenhum registro$q$, $q$recusado (ck_auditoria_arco_exclusivo)$q$, v_obtido, v_ok);
END $t$;

-- @@ 6.4 - Gravar auditoria de um contrato que nao existe
DO $t$
DECLARE v_erro TEXT; v_ok BOOLEAN; v_obtido TEXT;
BEGIN
    BEGIN
        INSERT INTO auditoria (id_usuario, tp_acao, id_contrato) VALUES (1, 'alteracao', 999);
        SET CONSTRAINTS ALL IMMEDIATE;   -- confere agora as regras verificadas no fim da transacao
    EXCEPTION WHEN OTHERS THEN
        v_erro := SQLERRM;
    END;
    IF v_erro IS NULL THEN
        v_ok := FALSE; v_obtido := 'aceito (deveria ter sido recusado)';
    ELSE
        v_ok := strpos(v_erro, $q$fk_auditoria_audita_contrato$q$) > 0; v_obtido := 'recusado: ' || v_erro;
    END IF;
    INSERT INTO resultado_teste VALUES ($q$6.4$q$, 6, $q$Gravar auditoria de um contrato que nao existe$q$, $q$recusado (fk_auditoria_audita_contrato)$q$, v_obtido, v_ok);
END $t$;

-- @@ 6.5 - Alterar um registro de auditoria
DO $t$
DECLARE v_erro TEXT; v_ok BOOLEAN; v_obtido TEXT;
BEGIN
    BEGIN
        UPDATE auditoria SET tp_acao = 'alteracao' WHERE id_auditoria = (SELECT min(id_auditoria) FROM auditoria);
        SET CONSTRAINTS ALL IMMEDIATE;   -- confere agora as regras verificadas no fim da transacao
    EXCEPTION WHEN OTHERS THEN
        v_erro := SQLERRM;
    END;
    IF v_erro IS NULL THEN
        v_ok := FALSE; v_obtido := 'aceito (deveria ter sido recusado)';
    ELSE
        v_ok := strpos(v_erro, $q$RNF04$q$) > 0; v_obtido := 'recusado: ' || v_erro;
    END IF;
    INSERT INTO resultado_teste VALUES ($q$6.5$q$, 6, $q$Alterar um registro de auditoria$q$, $q$recusado (RNF04)$q$, v_obtido, v_ok);
END $t$;

-- @@ 6.6 - Excluir um contrato auditado
DO $t$
DECLARE v_erro TEXT; v_ok BOOLEAN; v_obtido TEXT;
BEGIN
    BEGIN
        DELETE FROM contrato WHERE id_contrato = 200;
        SET CONSTRAINTS ALL IMMEDIATE;   -- confere agora as regras verificadas no fim da transacao
    EXCEPTION WHEN OTHERS THEN
        v_erro := SQLERRM;
    END;
    IF v_erro IS NULL THEN
        v_ok := FALSE; v_obtido := 'aceito (deveria ter sido recusado)';
    ELSE
        v_ok := strpos(v_erro, $q$PO04$q$) > 0; v_obtido := 'recusado: ' || v_erro;
    END IF;
    INSERT INTO resultado_teste VALUES ($q$6.6$q$, 6, $q$Excluir um contrato auditado$q$, $q$recusado (PO04)$q$, v_obtido, v_ok);
END $t$;

-- @@ 6.7 - Lancar uma conta sem informar o usuario responsavel
DO $t$
DECLARE v_erro TEXT; v_ok BOOLEAN; v_obtido TEXT;
BEGIN
    BEGIN
        PERFORM set_config('crmoveis.id_usuario', '', TRUE);
        INSERT INTO conta_receber (id_contrato, id_categoria, id_pagador, tp_papel_pagador, vl_receber, dt_vencimento)
        VALUES (201, pg_temp.cat('servico'), 5, 'proprietario', 100, '2026-05-01');
        SET CONSTRAINTS ALL IMMEDIATE;   -- confere agora as regras verificadas no fim da transacao
    EXCEPTION WHEN OTHERS THEN
        v_erro := SQLERRM;
    END;
    IF v_erro IS NULL THEN
        v_ok := FALSE; v_obtido := 'aceito (deveria ter sido recusado)';
    ELSE
        v_ok := strpos(v_erro, $q$RN40$q$) > 0; v_obtido := 'recusado: ' || v_erro;
    END IF;
    INSERT INTO resultado_teste VALUES ($q$6.7$q$, 6, $q$Lancar uma conta sem informar o usuario responsavel$q$, $q$recusado (RN40)$q$, v_obtido, v_ok);
END $t$;

-- @@ 8.1 - Cadastrar um imovel com um tipo que nao existe na lista de tipos
DO $t$
DECLARE v_erro TEXT; v_ok BOOLEAN; v_obtido TEXT;
BEGIN
    BEGIN
        INSERT INTO imovel (id_proprietario, nr_cep, id_tipo_imovel, tp_finalidade, nm_logradouro, nr_endereco, id_bairro, vl_venda)
        VALUES (8, '01310100', 99, 'venda', 'Rua Teste', '2', 1, 100000);
        SET CONSTRAINTS ALL IMMEDIATE;   -- confere agora as regras verificadas no fim da transacao
    EXCEPTION WHEN OTHERS THEN
        v_erro := SQLERRM;
    END;
    IF v_erro IS NULL THEN
        v_ok := FALSE; v_obtido := 'aceito (deveria ter sido recusado)';
    ELSE
        v_ok := strpos(v_erro, $q$fk_imovel_tipifica$q$) > 0; v_obtido := 'recusado: ' || v_erro;
    END IF;
    INSERT INTO resultado_teste VALUES ($q$8.1$q$, 8, $q$Cadastrar um imovel com um tipo que nao existe na lista de tipos$q$, $q$recusado (fk_imovel_tipifica)$q$, v_obtido, v_ok);
END $t$;

-- @@ 8.2 - Perfil de Bruno aceitando apartamento e cobertura
DO $t$
DECLARE v_erro TEXT; v_ok BOOLEAN; v_obtido TEXT;
BEGIN
    BEGIN
        INSERT INTO perfil_interesse (id_usuario, nr_perfil, id_cidade, tp_finalidade, vl_minimo, vl_maximo) VALUES (6, 1, 1, 'venda', 300000, 600000);
        INSERT INTO perfil_interesse_tipo (id_usuario, nr_perfil, id_tipo_imovel) VALUES (6, 1, 1), (6, 1, 4);
        SET CONSTRAINTS ALL IMMEDIATE;   -- confere agora as regras verificadas no fim da transacao
    EXCEPTION WHEN OTHERS THEN
        v_erro := SQLERRM;
    END;
    IF v_erro IS NULL THEN
        v_ok := ((SELECT count(*) FROM perfil_interesse_tipo WHERE id_usuario = 6 AND nr_perfil = 1) = 2);
        v_obtido := 'aceito: ' || ((SELECT 'tipos do perfil: ' || string_agg(t.nm_tipo_imovel, ' e ' ORDER BY t.nm_tipo_imovel) FROM perfil_interesse_tipo p JOIN tipo_imovel t USING (id_tipo_imovel) WHERE p.id_usuario = 6));
    ELSE
        v_ok := FALSE; v_obtido := 'recusado: ' || v_erro;
    END IF;
    INSERT INTO resultado_teste VALUES ($q$8.2$q$, 8, $q$Perfil de Bruno aceitando apartamento e cobertura$q$, $q$aceito$q$, v_obtido, v_ok);
END $t$;

-- @@ 8.3 - Repetir o mesmo tipo no mesmo perfil
DO $t$
DECLARE v_erro TEXT; v_ok BOOLEAN; v_obtido TEXT;
BEGIN
    BEGIN
        INSERT INTO perfil_interesse_tipo (id_usuario, nr_perfil, id_tipo_imovel) VALUES (6, 1, 1);
        SET CONSTRAINTS ALL IMMEDIATE;   -- confere agora as regras verificadas no fim da transacao
    EXCEPTION WHEN OTHERS THEN
        v_erro := SQLERRM;
    END;
    IF v_erro IS NULL THEN
        v_ok := FALSE; v_obtido := 'aceito (deveria ter sido recusado)';
    ELSE
        v_ok := strpos(v_erro, $q$pk_perfil_interesse_tipo$q$) > 0; v_obtido := 'recusado: ' || v_erro;
    END IF;
    INSERT INTO resultado_teste VALUES ($q$8.3$q$, 8, $q$Repetir o mesmo tipo no mesmo perfil$q$, $q$recusado (pk_perfil_interesse_tipo)$q$, v_obtido, v_ok);
END $t$;

-- @@ 8.4 - Excluir da lista o tipo Casa, que classifica um imovel
DO $t$
DECLARE v_erro TEXT; v_ok BOOLEAN; v_obtido TEXT;
BEGIN
    BEGIN
        DELETE FROM tipo_imovel WHERE id_tipo_imovel = 2;
        SET CONSTRAINTS ALL IMMEDIATE;   -- confere agora as regras verificadas no fim da transacao
    EXCEPTION WHEN OTHERS THEN
        v_erro := SQLERRM;
    END;
    IF v_erro IS NULL THEN
        v_ok := FALSE; v_obtido := 'aceito (deveria ter sido recusado)';
    ELSE
        v_ok := strpos(v_erro, $q$fk_imovel_tipifica$q$) > 0; v_obtido := 'recusado: ' || v_erro;
    END IF;
    INSERT INTO resultado_teste VALUES ($q$8.4$q$, 8, $q$Excluir da lista o tipo Casa, que classifica um imovel$q$, $q$recusado (fk_imovel_tipifica)$q$, v_obtido, v_ok);
END $t$;

-- @@ 8.5 - Lancar conta a receber numa categoria de despesa (Imposto)
DO $t$
DECLARE v_erro TEXT; v_ok BOOLEAN; v_obtido TEXT;
BEGIN
    BEGIN
        INSERT INTO conta_receber (id_contrato, id_categoria, id_pagador, tp_papel_pagador, vl_receber, dt_vencimento)
        VALUES (201, pg_temp.cat('imposto'), 5, 'proprietario', 100, '2026-05-01');
        SET CONSTRAINTS ALL IMMEDIATE;   -- confere agora as regras verificadas no fim da transacao
    EXCEPTION WHEN OTHERS THEN
        v_erro := SQLERRM;
    END;
    IF v_erro IS NULL THEN
        v_ok := FALSE; v_obtido := 'aceito (deveria ter sido recusado)';
    ELSE
        v_ok := strpos(v_erro, $q$RN26$q$) > 0; v_obtido := 'recusado: ' || v_erro;
    END IF;
    INSERT INTO resultado_teste VALUES ($q$8.5$q$, 8, $q$Lancar conta a receber numa categoria de despesa (Imposto)$q$, $q$recusado (RN26)$q$, v_obtido, v_ok);
END $t$;

-- @@ 8.6 - Mudar o codigo da categoria de repasse, usada pelas regras
DO $t$
DECLARE v_erro TEXT; v_ok BOOLEAN; v_obtido TEXT;
BEGIN
    BEGIN
        UPDATE categoria_financeira SET cd_categoria = 'repasse_aluguel' WHERE cd_categoria = 'repasse';
        SET CONSTRAINTS ALL IMMEDIATE;   -- confere agora as regras verificadas no fim da transacao
    EXCEPTION WHEN OTHERS THEN
        v_erro := SQLERRM;
    END;
    IF v_erro IS NULL THEN
        v_ok := FALSE; v_obtido := 'aceito (deveria ter sido recusado)';
    ELSE
        v_ok := strpos(v_erro, $q$RN26$q$) > 0; v_obtido := 'recusado: ' || v_erro;
    END IF;
    INSERT INTO resultado_teste VALUES ($q$8.6$q$, 8, $q$Mudar o codigo da categoria de repasse, usada pelas regras$q$, $q$recusado (RN26)$q$, v_obtido, v_ok);
END $t$;

-- @@ 8.7 - Registrar um recebimento com uma forma de pagamento que nao existe
DO $t$
DECLARE v_erro TEXT; v_ok BOOLEAN; v_obtido TEXT;
BEGIN
    BEGIN
        INSERT INTO recebimento (id_conta_receber, nr_recebimento, id_conta, dt_recebimento, vl_recebido, id_forma_pagamento) VALUES (402, 1, 1, '2026-06-05', 100, 99);
        SET CONSTRAINTS ALL IMMEDIATE;   -- confere agora as regras verificadas no fim da transacao
    EXCEPTION WHEN OTHERS THEN
        v_erro := SQLERRM;
    END;
    IF v_erro IS NULL THEN
        v_ok := FALSE; v_obtido := 'aceito (deveria ter sido recusado)';
    ELSE
        v_ok := strpos(v_erro, $q$fk_recebimento_recebido_via$q$) > 0; v_obtido := 'recusado: ' || v_erro;
    END IF;
    INSERT INTO resultado_teste VALUES ($q$8.7$q$, 8, $q$Registrar um recebimento com uma forma de pagamento que nao existe$q$, $q$recusado (fk_recebimento_recebido_via)$q$, v_obtido, v_ok);
END $t$;

-- @@ 9.1 - Cadastrar um imovel no CEP de Sao Paulo com um bairro de Guarulhos
DO $t$
DECLARE v_erro TEXT; v_ok BOOLEAN; v_obtido TEXT;
BEGIN
    BEGIN
        INSERT INTO imovel (id_proprietario, nr_cep, id_tipo_imovel, tp_finalidade, nm_logradouro, nr_endereco, id_bairro, vl_venda)
        VALUES (8, '01310100', 1, 'venda', 'Rua Teste', '3', 3, 100000);
        SET CONSTRAINTS ALL IMMEDIATE;   -- confere agora as regras verificadas no fim da transacao
    EXCEPTION WHEN OTHERS THEN
        v_erro := SQLERRM;
    END;
    IF v_erro IS NULL THEN
        v_ok := FALSE; v_obtido := 'aceito (deveria ter sido recusado)';
    ELSE
        v_ok := strpos(v_erro, $q$RN51$q$) > 0; v_obtido := 'recusado: ' || v_erro;
    END IF;
    INSERT INTO resultado_teste VALUES ($q$9.1$q$, 9, $q$Cadastrar um imovel no CEP de Sao Paulo com um bairro de Guarulhos$q$, $q$recusado (RN51)$q$, v_obtido, v_ok);
END $t$;

-- @@ 9.2 - Cadastrar o bairro Centro tambem em Sao Paulo (ja existe em Guarulhos)
DO $t$
DECLARE v_erro TEXT; v_ok BOOLEAN; v_obtido TEXT;
BEGIN
    BEGIN
        INSERT INTO bairro (id_cidade, nm_bairro) VALUES (1, 'Centro');
        SET CONSTRAINTS ALL IMMEDIATE;   -- confere agora as regras verificadas no fim da transacao
    EXCEPTION WHEN OTHERS THEN
        v_erro := SQLERRM;
    END;
    IF v_erro IS NULL THEN
        v_ok := ((SELECT count(*) FROM bairro WHERE nm_bairro = 'Centro') = 2);
        v_obtido := 'aceito: ' || ((SELECT 'Centro em ' || string_agg(c.nm_cidade, ' e ' ORDER BY c.nm_cidade) FROM bairro b JOIN cidade c USING (id_cidade) WHERE b.nm_bairro = 'Centro'));
    ELSE
        v_ok := FALSE; v_obtido := 'recusado: ' || v_erro;
    END IF;
    INSERT INTO resultado_teste VALUES ($q$9.2$q$, 9, $q$Cadastrar o bairro Centro tambem em Sao Paulo (ja existe em Guarulhos)$q$, $q$aceito$q$, v_obtido, v_ok);
END $t$;

-- @@ 9.3 - Cadastrar de novo o bairro Bela Vista na mesma cidade
DO $t$
DECLARE v_erro TEXT; v_ok BOOLEAN; v_obtido TEXT;
BEGIN
    BEGIN
        INSERT INTO bairro (id_cidade, nm_bairro) VALUES (1, 'Bela Vista');
        SET CONSTRAINTS ALL IMMEDIATE;   -- confere agora as regras verificadas no fim da transacao
    EXCEPTION WHEN OTHERS THEN
        v_erro := SQLERRM;
    END;
    IF v_erro IS NULL THEN
        v_ok := FALSE; v_obtido := 'aceito (deveria ter sido recusado)';
    ELSE
        v_ok := strpos(v_erro, $q$uk_bairro_id_cidade_nm_bairro$q$) > 0; v_obtido := 'recusado: ' || v_erro;
    END IF;
    INSERT INTO resultado_teste VALUES ($q$9.3$q$, 9, $q$Cadastrar de novo o bairro Bela Vista na mesma cidade$q$, $q$recusado (uk_bairro_id_cidade_nm_bairro)$q$, v_obtido, v_ok);
END $t$;

-- @@ 9.4 - Perfil de Bruno (Sao Paulo) aceitando os bairros Bela Vista e Itaim Bibi
DO $t$
DECLARE v_erro TEXT; v_ok BOOLEAN; v_obtido TEXT;
BEGIN
    BEGIN
        INSERT INTO perfil_interesse_bairro (id_usuario, nr_perfil, id_bairro) VALUES (6, 1, 1), (6, 1, 2);
        SET CONSTRAINTS ALL IMMEDIATE;   -- confere agora as regras verificadas no fim da transacao
    EXCEPTION WHEN OTHERS THEN
        v_erro := SQLERRM;
    END;
    IF v_erro IS NULL THEN
        v_ok := ((SELECT count(*) FROM perfil_interesse_bairro WHERE id_usuario = 6 AND nr_perfil = 1) = 2);
        v_obtido := 'aceito: ' || ((SELECT 'bairros do perfil: ' || string_agg(b.nm_bairro, ' e ' ORDER BY b.nm_bairro) FROM perfil_interesse_bairro p JOIN bairro b USING (id_bairro) WHERE p.id_usuario = 6));
    ELSE
        v_ok := FALSE; v_obtido := 'recusado: ' || v_erro;
    END IF;
    INSERT INTO resultado_teste VALUES ($q$9.4$q$, 9, $q$Perfil de Bruno (Sao Paulo) aceitando os bairros Bela Vista e Itaim Bibi$q$, $q$aceito$q$, v_obtido, v_ok);
END $t$;

-- @@ 9.5 - Perfil de Sao Paulo aceitando o Centro de Guarulhos
DO $t$
DECLARE v_erro TEXT; v_ok BOOLEAN; v_obtido TEXT;
BEGIN
    BEGIN
        INSERT INTO perfil_interesse_bairro (id_usuario, nr_perfil, id_bairro) VALUES (6, 1, 3);
        SET CONSTRAINTS ALL IMMEDIATE;   -- confere agora as regras verificadas no fim da transacao
    EXCEPTION WHEN OTHERS THEN
        v_erro := SQLERRM;
    END;
    IF v_erro IS NULL THEN
        v_ok := FALSE; v_obtido := 'aceito (deveria ter sido recusado)';
    ELSE
        v_ok := strpos(v_erro, $q$RN52$q$) > 0; v_obtido := 'recusado: ' || v_erro;
    END IF;
    INSERT INTO resultado_teste VALUES ($q$9.5$q$, 9, $q$Perfil de Sao Paulo aceitando o Centro de Guarulhos$q$, $q$recusado (RN52)$q$, v_obtido, v_ok);
END $t$;

-- @@ 9.6 - Trocar para Guarulhos a cidade do perfil que tem bairros de Sao Paulo
DO $t$
DECLARE v_erro TEXT; v_ok BOOLEAN; v_obtido TEXT;
BEGIN
    BEGIN
        UPDATE perfil_interesse SET id_cidade = 2 WHERE id_usuario = 6 AND nr_perfil = 1;
        SET CONSTRAINTS ALL IMMEDIATE;   -- confere agora as regras verificadas no fim da transacao
    EXCEPTION WHEN OTHERS THEN
        v_erro := SQLERRM;
    END;
    IF v_erro IS NULL THEN
        v_ok := FALSE; v_obtido := 'aceito (deveria ter sido recusado)';
    ELSE
        v_ok := strpos(v_erro, $q$RN52$q$) > 0; v_obtido := 'recusado: ' || v_erro;
    END IF;
    INSERT INTO resultado_teste VALUES ($q$9.6$q$, 9, $q$Trocar para Guarulhos a cidade do perfil que tem bairros de Sao Paulo$q$, $q$recusado (RN52)$q$, v_obtido, v_ok);
END $t$;

-- @@ 9.7 - Passar para Guarulhos o bairro Bela Vista, que ja tem imovel
DO $t$
DECLARE v_erro TEXT; v_ok BOOLEAN; v_obtido TEXT;
BEGIN
    BEGIN
        UPDATE bairro SET id_cidade = 2 WHERE id_bairro = 1;
        SET CONSTRAINTS ALL IMMEDIATE;   -- confere agora as regras verificadas no fim da transacao
    EXCEPTION WHEN OTHERS THEN
        v_erro := SQLERRM;
    END;
    IF v_erro IS NULL THEN
        v_ok := FALSE; v_obtido := 'aceito (deveria ter sido recusado)';
    ELSE
        v_ok := strpos(v_erro, $q$RN51$q$) > 0; v_obtido := 'recusado: ' || v_erro;
    END IF;
    INSERT INTO resultado_teste VALUES ($q$9.7$q$, 9, $q$Passar para Guarulhos o bairro Bela Vista, que ja tem imovel$q$, $q$recusado (RN51)$q$, v_obtido, v_ok);
END $t$;

-- @@ 9.8 - Cadastrar uma cidade com a UF XX, que nao existe
DO $t$
DECLARE v_erro TEXT; v_ok BOOLEAN; v_obtido TEXT;
BEGIN
    BEGIN
        INSERT INTO cidade (nm_cidade, sg_uf) VALUES ('Cidade Teste', 'XX');
        SET CONSTRAINTS ALL IMMEDIATE;   -- confere agora as regras verificadas no fim da transacao
    EXCEPTION WHEN OTHERS THEN
        v_erro := SQLERRM;
    END;
    IF v_erro IS NULL THEN
        v_ok := FALSE; v_obtido := 'aceito (deveria ter sido recusado)';
    ELSE
        v_ok := strpos(v_erro, $q$fk_cidade_compreende$q$) > 0; v_obtido := 'recusado: ' || v_erro;
    END IF;
    INSERT INTO resultado_teste VALUES ($q$9.8$q$, 9, $q$Cadastrar uma cidade com a UF XX, que nao existe$q$, $q$recusado (fk_cidade_compreende)$q$, v_obtido, v_ok);
END $t$;

-- @@ 9.9 - Anexar ao contrato um documento de um tipo que nao existe
DO $t$
DECLARE v_erro TEXT; v_ok BOOLEAN; v_obtido TEXT;
BEGIN
    BEGIN
        INSERT INTO documento (id_contrato, nr_documento, id_tipo_documento, ds_url) VALUES (201, 1, 99, 'https://docs.crmoveis.example/t/1.pdf');
        SET CONSTRAINTS ALL IMMEDIATE;   -- confere agora as regras verificadas no fim da transacao
    EXCEPTION WHEN OTHERS THEN
        v_erro := SQLERRM;
    END;
    IF v_erro IS NULL THEN
        v_ok := FALSE; v_obtido := 'aceito (deveria ter sido recusado)';
    ELSE
        v_ok := strpos(v_erro, $q$fk_documento_qualifica$q$) > 0; v_obtido := 'recusado: ' || v_erro;
    END IF;
    INSERT INTO resultado_teste VALUES ($q$9.9$q$, 9, $q$Anexar ao contrato um documento de um tipo que nao existe$q$, $q$recusado (fk_documento_qualifica)$q$, v_obtido, v_ok);
END $t$;

-- @@ 9.10 - Anexar ao contrato a matricula do imovel, escolhida da lista de tipos
DO $t$
DECLARE v_erro TEXT; v_ok BOOLEAN; v_obtido TEXT;
BEGIN
    BEGIN
        INSERT INTO documento (id_contrato, nr_documento, id_tipo_documento, ds_url) VALUES (201, 1, 3, 'https://docs.crmoveis.example/t/1.pdf');
        SET CONSTRAINTS ALL IMMEDIATE;   -- confere agora as regras verificadas no fim da transacao
    EXCEPTION WHEN OTHERS THEN
        v_erro := SQLERRM;
    END;
    IF v_erro IS NULL THEN
        v_ok := (EXISTS (SELECT 1 FROM documento WHERE id_contrato = 201 AND nr_documento = 1));
        v_obtido := 'aceito: ' || ((SELECT 'documento: ' || t.nm_tipo_documento FROM documento d JOIN tipo_documento t USING (id_tipo_documento) WHERE d.id_contrato = 201 AND d.nr_documento = 1));
    ELSE
        v_ok := FALSE; v_obtido := 'recusado: ' || v_erro;
    END IF;
    INSERT INTO resultado_teste VALUES ($q$9.10$q$, 9, $q$Anexar ao contrato a matricula do imovel, escolhida da lista de tipos$q$, $q$aceito$q$, v_obtido, v_ok);
END $t$;
-- @@ resultado
SELECT id, cenario, esperado, obtido, CASE WHEN ok THEN 'OK' ELSE 'FALHOU' END AS resultado
  FROM resultado_teste ORDER BY ponto, string_to_array(id, $s$.$s$)::int[];

-- =====================================================================
-- CRMoveis - SELECT, JOIN, UPDATE e DELETE com sentido de negocio (Etapa 14)
-- Projeto Integrador - Modelagem de Dados - Prof. Clovis - Grupo 4
-- Rode depois da massa de dados: psql -d crmoveis -f sql/consultas/20_select_join_update_delete.sql
-- As alteracoes de demonstracao ficam dentro de BEGIN ... ROLLBACK, para nao mudar a massa de dados.
-- As operacoes que o banco deve recusar estao em blocos DO, que mostram a mensagem da regra.
-- =====================================================================
\set ON_ERROR_STOP on
SET crmoveis.id_usuario = '1';   -- usuario responsavel pelas gravacoes (auditoria, RN40)

-- ---------------------------------------------------------------------
-- 1. SELECT - Buscar imoveis cadastrados: apartamentos para alugar em Guarulhos ate R$ 2.500
--    (o tipo vem da tabela tipo_imovel, RN48; o bairro, da tabela bairro, RN51; cidade e UF vem do CEP, RN41)
-- ---------------------------------------------------------------------
SELECT i.cd_imobizi AS codigo, t.nm_tipo_imovel AS tipo, b.nm_bairro AS bairro, ci.nm_cidade AS cidade, uf.nm_uf AS estado,
       i.qt_quartos AS quartos, i.vl_aluguel AS aluguel
  FROM imovel i
  JOIN tipo_imovel t ON t.id_tipo_imovel = i.id_tipo_imovel
  JOIN bairro b ON b.id_bairro = i.id_bairro
  JOIN cep ON cep.nr_cep = i.nr_cep
  JOIN cidade ci ON ci.id_cidade = cep.id_cidade
  JOIN uf ON uf.sg_uf = ci.sg_uf
 WHERE i.st_imovel = 'disponivel' AND i.tp_finalidade IN ('locacao', 'ambas')
   AND t.nm_tipo_imovel = 'Apartamento'
   AND ci.nm_cidade = 'Guarulhos' AND i.vl_aluguel <= 2500
 ORDER BY i.vl_aluguel;

-- ---------------------------------------------------------------------
-- 1a. SELECT - Quantos imoveis cadastrados de cada tipo, e quantos estao disponiveis
--     (LEFT JOIN: os tipos sem nenhum imovel tambem aparecem, com zero)
-- ---------------------------------------------------------------------
SELECT t.nm_tipo_imovel AS tipo, count(i.id_imovel) AS cadastrados,
       count(i.id_imovel) FILTER (WHERE i.st_imovel = 'disponivel') AS disponiveis
  FROM tipo_imovel t
  LEFT JOIN imovel i ON i.id_tipo_imovel = t.id_tipo_imovel
 GROUP BY t.id_tipo_imovel, t.nm_tipo_imovel
 ORDER BY cadastrados DESC, tipo;

-- ---------------------------------------------------------------------
-- 1b. INSERT - Cadastrar um imovel novo: o tipo e o bairro sao escolhidos das listas (FK), e o banco confere
--     o papel do proprietario (RN32), o valor exigido pela finalidade (CHECK) e se o bairro e da cidade do CEP (RN51)
-- ---------------------------------------------------------------------
BEGIN;
INSERT INTO imovel (cd_imobizi, id_proprietario, id_corretor_responsavel, nr_cep, id_tipo_imovel, tp_finalidade,
                    nm_logradouro, nr_endereco, ds_complemento, id_bairro, vl_area_util, vl_area_total,
                    qt_quartos, qt_banheiros, qt_vagas_garagem, vl_venda, vl_aluguel, ds_anuncio)
VALUES ('IMB-3531', 15, 5, '07061000', (SELECT id_tipo_imovel FROM tipo_imovel WHERE nm_tipo_imovel = 'Cobertura'), 'venda',
        'Avenida Emilio Ribas', '880', 'Cobertura 2',
        (SELECT b.id_bairro FROM bairro b JOIN cidade c ON c.id_cidade = b.id_cidade WHERE b.nm_bairro = 'Vila Galvao' AND c.nm_cidade = 'Guarulhos'),
        140, 160, 3, 3, 2, 980000, NULL, 'Cobertura de 3 dormitorios na Vila Galvao, 140 m2 de area util');
SELECT i.id_imovel, i.cd_imobizi AS codigo, t.nm_tipo_imovel AS tipo, b.nm_bairro AS bairro, ci.nm_cidade AS cidade, i.vl_venda AS venda
  FROM imovel i JOIN tipo_imovel t ON t.id_tipo_imovel = i.id_tipo_imovel
  JOIN bairro b ON b.id_bairro = i.id_bairro
  JOIN cep ON cep.nr_cep = i.nr_cep JOIN cidade ci ON ci.id_cidade = cep.id_cidade
 WHERE i.cd_imobizi = 'IMB-3531';
ROLLBACK;

-- ---------------------------------------------------------------------
-- 1c. INSERT recusado - Imovel com CEP de Guarulhos e o bairro Tatuape, de Sao Paulo (RN51)
-- ---------------------------------------------------------------------
DO $$
BEGIN
    INSERT INTO imovel (id_proprietario, nr_cep, id_tipo_imovel, tp_finalidade, nm_logradouro, nr_endereco, id_bairro, vl_venda)
    VALUES (15, '07061000', 1, 'venda', 'Avenida Emilio Ribas', '881',
            (SELECT b.id_bairro FROM bairro b JOIN cidade c ON c.id_cidade = b.id_cidade WHERE b.nm_bairro = 'Tatuape' AND c.nm_cidade = 'Sao Paulo'), 500000);
    RAISE NOTICE 'ERRO: a gravacao deveria ter sido recusada';
EXCEPTION WHEN OTHERS THEN
    RAISE NOTICE 'Recusado pelo banco: %', SQLERRM;
END $$;

-- ---------------------------------------------------------------------
-- 2. JOIN - Contratos com cliente, imovel, proprietario, corretor e situacao
--    (o cliente e o corretor vem da proposta que originou o contrato, FECHA)
-- ---------------------------------------------------------------------
SELECT ct.id_contrato AS contrato, ct.tp_contrato AS tipo, ct.st_contrato AS situacao,
       cli.nm_usuario AS cliente, i.cd_imobizi AS imovel, pro.nm_usuario AS proprietario, cor.nm_usuario AS corretor,
       ct.vl_final AS valor, vc.vl_corretagem AS corretagem
  FROM contrato ct
  JOIN vw_contrato vc ON vc.id_contrato = ct.id_contrato
  JOIN proposta p ON p.id_proposta = ct.id_proposta
  JOIN usuario cli ON cli.id_usuario = p.id_cliente
  JOIN usuario cor ON cor.id_usuario = p.id_corretor
  JOIN imovel i ON i.id_imovel = p.id_imovel
  JOIN usuario pro ON pro.id_usuario = i.id_proprietario
 ORDER BY ct.id_contrato;

-- ---------------------------------------------------------------------
-- 3. LEFT JOIN - Todos os corretores, inclusive quem nao tem conversa aberta
-- ---------------------------------------------------------------------
SELECT u.nm_usuario AS corretor, co.nr_creci AS creci, count(cv.id_conversa) AS conversas_abertas
  FROM corretor co
  JOIN usuario u ON u.id_usuario = co.id_usuario
  LEFT JOIN conversa cv ON cv.id_corretor = co.id_usuario AND cv.st_conversa = 'aberta'
 GROUP BY u.nm_usuario, co.nr_creci
 ORDER BY conversas_abertas DESC;

-- ---------------------------------------------------------------------
-- 3a. JOIN com N:N - Perfis de interesse com os tipos de imovel (DESEJA, RN47) e os bairros (ABRANGE, RN52)
--     que cada um aceita (perfil sem tipo aceita qualquer tipo; sem bairro, qualquer bairro da cidade)
-- ---------------------------------------------------------------------
SELECT u.nm_usuario AS cliente, p.nr_perfil AS perfil, p.tp_finalidade AS finalidade, ci.nm_cidade AS cidade,
       coalesce((SELECT string_agg(t.nm_tipo_imovel, ', ' ORDER BY t.nm_tipo_imovel)
                   FROM perfil_interesse_tipo pt JOIN tipo_imovel t ON t.id_tipo_imovel = pt.id_tipo_imovel
                  WHERE pt.id_usuario = p.id_usuario AND pt.nr_perfil = p.nr_perfil), '(qualquer tipo)') AS tipos_aceitos,
       coalesce((SELECT string_agg(b.nm_bairro, ', ' ORDER BY b.nm_bairro)
                   FROM perfil_interesse_bairro pb JOIN bairro b ON b.id_bairro = pb.id_bairro
                  WHERE pb.id_usuario = p.id_usuario AND pb.nr_perfil = p.nr_perfil), '(qualquer bairro)') AS bairros_aceitos
  FROM perfil_interesse p
  JOIN usuario u ON u.id_usuario = p.id_usuario
  LEFT JOIN cidade ci ON ci.id_cidade = p.id_cidade
 ORDER BY (SELECT count(*) FROM perfil_interesse_tipo pt WHERE pt.id_usuario = p.id_usuario AND pt.nr_perfil = p.nr_perfil)
        + (SELECT count(*) FROM perfil_interesse_bairro pb WHERE pb.id_usuario = p.id_usuario AND pb.nr_perfil = p.nr_perfil) DESC, u.nm_usuario
 LIMIT 12;

-- ---------------------------------------------------------------------
-- 4. Especializacao compartilhada - Pessoas com mais de um papel (RN02)
-- ---------------------------------------------------------------------
SELECT u.id_usuario, u.nm_usuario AS pessoa, string_agg(p.papel, ', ' ORDER BY p.papel) AS papeis
  FROM usuario u
  JOIN (SELECT id_usuario, 'cliente' AS papel FROM cliente UNION ALL
        SELECT id_usuario, 'proprietario' FROM proprietario UNION ALL
        SELECT id_usuario, 'inquilino' FROM inquilino UNION ALL
        SELECT id_usuario, 'corretor' FROM corretor UNION ALL
        SELECT id_usuario, 'financeiro' FROM financeiro UNION ALL
        SELECT id_usuario, 'fornecedor' FROM fornecedor UNION ALL
        SELECT id_usuario, 'administrador' FROM administrador UNION ALL
        SELECT id_usuario, 'instituicao_financeira' FROM instituicao_financeira) p ON p.id_usuario = u.id_usuario
 GROUP BY u.id_usuario
HAVING count(*) > 1
 ORDER BY u.id_usuario;

-- ---------------------------------------------------------------------
-- 5. UPDATE - Mover uma conversa de etapa no funil
--    O estagio atual e o historico sao gravados na mesma transacao (RN14).
-- ---------------------------------------------------------------------
BEGIN;
UPDATE conversa SET id_estagio = (SELECT id_estagio FROM funil_estagio WHERE nm_estagio = 'Visita')
 WHERE id_conversa = 21;
INSERT INTO historico_estagio (id_conversa, dt_alteracao, id_estagio, id_usuario)
VALUES (21, CURRENT_TIMESTAMP, (SELECT id_estagio FROM funil_estagio WHERE nm_estagio = 'Visita'), 4);
SELECT cv.id_conversa, fe.nm_estagio AS etapa_atual, count(h.*) AS registros_no_historico
  FROM conversa cv JOIN funil_estagio fe ON fe.id_estagio = cv.id_estagio
  JOIN historico_estagio h ON h.id_conversa = cv.id_conversa
 WHERE cv.id_conversa = 21 GROUP BY cv.id_conversa, fe.nm_estagio;
ROLLBACK;

-- ---------------------------------------------------------------------
-- 6. UPDATE - O proprietario reduziu o preco de venda; a auditoria NAO registra imoveis,
--    mas uma proposta alterada e auditada com o valor anterior e o novo (RN40)
-- ---------------------------------------------------------------------
BEGIN;
UPDATE imovel SET vl_venda = vl_venda * 0.95 WHERE cd_imobizi = 'IMB-3521';
UPDATE proposta SET ds_condicoes = 'A vista; cliente aceita assinar em 30 dias' WHERE id_proposta = 14;
SELECT a.tp_acao, c.nm_campo, c.ds_valor_anterior, c.ds_valor_novo
  FROM auditoria a JOIN auditoria_campo c ON c.id_auditoria = a.id_auditoria
 WHERE a.id_proposta = 14 ORDER BY a.id_auditoria DESC LIMIT 1;
ROLLBACK;

-- ---------------------------------------------------------------------
-- 7. UPDATE recusado - Aumentar uma comissao a ponto de a soma passar de 100% (RN20)
-- ---------------------------------------------------------------------
DO $$
BEGIN
    UPDATE comissao SET pc_comissao = 95 WHERE id_contrato = 5 AND id_corretor = 7;   -- 95 + 10 = 105
    RAISE NOTICE 'ERRO: a gravacao deveria ter sido recusada';
EXCEPTION WHEN OTHERS THEN
    RAISE NOTICE 'Recusado pelo banco: %', SQLERRM;
END $$;

-- ---------------------------------------------------------------------
-- 8. DELETE - Remover uma etiqueta de uma conversa (ligacao N:N sem atributos)
-- ---------------------------------------------------------------------
BEGIN;
DELETE FROM conversa_tag WHERE id_conversa = 6 AND id_tag = (SELECT id_tag FROM tag WHERE nm_tag = 'primeira compra');
SELECT count(*) AS etiquetas_restantes_na_conversa_6 FROM conversa_tag WHERE id_conversa = 6;
ROLLBACK;

-- ---------------------------------------------------------------------
-- 9. DELETE com CASCADE - Um contato novo, sem nenhum negocio, pede para ser excluido (PO07):
--    os papeis, o telefone (entidade fraca), o perfil de interesse e os tipos do perfil saem junto (ON DELETE CASCADE)
-- ---------------------------------------------------------------------
BEGIN;
INSERT INTO usuario (id_usuario, nm_usuario, id_origem) VALUES (900, 'Contato de teste', (SELECT id_origem FROM origem_contato WHERE nm_origem = 'Site'));
INSERT INTO cliente (id_usuario) VALUES (900);
INSERT INTO telefone (id_usuario, nr_sequencia, nr_telefone, fl_principal, fl_titular) VALUES (900, 1, '11900009999', TRUE, TRUE);
INSERT INTO perfil_interesse (id_usuario, nr_perfil, tp_finalidade) VALUES (900, 1, 'locacao');
INSERT INTO perfil_interesse_tipo (id_usuario, nr_perfil, id_tipo_imovel) VALUES (900, 1, 1), (900, 1, 5);
DELETE FROM usuario WHERE id_usuario = 900;     -- cliente, telefone, perfil e tipos do perfil saem em cascata
SELECT (SELECT count(*) FROM cliente WHERE id_usuario = 900) AS papel_cliente,
       (SELECT count(*) FROM telefone WHERE id_usuario = 900) AS telefones,
       (SELECT count(*) FROM perfil_interesse WHERE id_usuario = 900) AS perfis,
       (SELECT count(*) FROM perfil_interesse_tipo WHERE id_usuario = 900) AS tipos_do_perfil;
ROLLBACK;

-- ---------------------------------------------------------------------
-- 10. DELETE com SET NULL - Excluir uma conversa mantem a tarefa do corretor, sem a conversa
-- ---------------------------------------------------------------------
BEGIN;
INSERT INTO conversa (id_conversa, id_cliente, id_corretor, id_estagio) VALUES (900, 50, 5, 1);
INSERT INTO historico_estagio (id_conversa, id_estagio) VALUES (900, 1);
INSERT INTO tarefa (id_tarefa, id_conversa, id_corretor, ds_titulo, dt_vencimento) VALUES (900, 900, 5, 'Ligar para o cliente', CURRENT_DATE + 1);
DELETE FROM conversa WHERE id_conversa = 900;   -- historico sai em cascata; a tarefa fica com id_conversa nulo
SELECT id_tarefa, id_conversa, ds_titulo FROM tarefa WHERE id_tarefa = 900;
ROLLBACK;

-- ---------------------------------------------------------------------
-- 11. DELETE recusado - Contrato e imovel com historico nao sao excluidos (PO04, RESTRICT)
-- ---------------------------------------------------------------------
DO $$
BEGIN
    DELETE FROM contrato WHERE id_contrato = 8;
    RAISE NOTICE 'ERRO: a exclusao deveria ter sido recusada';
EXCEPTION WHEN OTHERS THEN
    RAISE NOTICE 'Contrato: recusado pelo banco: %', SQLERRM;
END $$;
DO $$
BEGIN
    DELETE FROM imovel WHERE id_imovel = 106;
    RAISE NOTICE 'ERRO: a exclusao deveria ter sido recusada';
EXCEPTION WHEN OTHERS THEN
    RAISE NOTICE 'Imovel com historico (interesses, visitas, propostas): recusado pelo banco: %', SQLERRM;
END $$;
DO $$
BEGIN
    DELETE FROM tipo_imovel WHERE nm_tipo_imovel = 'Apartamento';
    RAISE NOTICE 'ERRO: a exclusao deveria ter sido recusada';
EXCEPTION WHEN OTHERS THEN
    RAISE NOTICE 'Tipo de imovel em uso (RN48, RESTRICT): recusado pelo banco: %', SQLERRM;
END $$;

-- =====================================================================
-- CRMoveis - Dados de referencia
-- Projeto Integrador - Modelagem de Dados - Prof. Clovis - Grupo 4
-- PostgreSQL 13 ou superior - depois da DDL
-- =====================================================================

-- Dados sem os quais o sistema nao funciona: as listas de dominio (tipos de imovel, origens de contato,
-- formas de pagamento, unidades federativas e tipos de documento), as categorias usadas pelos gatilhos e
-- procedimentos e os estagios do funil comercial.
-- Os codigos tem numero fixo para que a massa de dados e os testes possam se referir a eles.
INSERT INTO tipo_imovel (id_tipo_imovel, nm_tipo_imovel) VALUES
    (1, 'Apartamento'), (2, 'Casa'), (3, 'Casa em condominio'), (4, 'Cobertura'), (5, 'Kitnet'),
    (6, 'Terreno'), (7, 'Sala comercial'), (8, 'Loja'), (9, 'Galpao'), (10, 'Chacara');
INSERT INTO origem_contato (id_origem, nm_origem) VALUES
    (1, 'Site'), (2, 'Indicacao'), (3, 'Portal imobiliario'), (4, 'Instagram'), (5, 'WhatsApp'), (6, 'Interno'), (7, 'Placa no imovel');
INSERT INTO forma_pagamento (id_forma_pagamento, nm_forma_pagamento) VALUES
    (1, 'Pix'), (2, 'TED'), (3, 'Boleto'), (4, 'Dinheiro'), (5, 'Cartao');
INSERT INTO uf (sg_uf, nm_uf) VALUES
    ('AC', 'Acre'), ('AL', 'Alagoas'), ('AP', 'Amapa'), ('AM', 'Amazonas'), ('BA', 'Bahia'), ('CE', 'Ceara'), ('DF', 'Distrito Federal'),
    ('ES', 'Espirito Santo'), ('GO', 'Goias'), ('MA', 'Maranhao'), ('MT', 'Mato Grosso'), ('MS', 'Mato Grosso do Sul'), ('MG', 'Minas Gerais'),
    ('PA', 'Para'), ('PB', 'Paraiba'), ('PR', 'Parana'), ('PE', 'Pernambuco'), ('PI', 'Piaui'), ('RJ', 'Rio de Janeiro'),
    ('RN', 'Rio Grande do Norte'), ('RS', 'Rio Grande do Sul'), ('RO', 'Rondonia'), ('RR', 'Roraima'), ('SC', 'Santa Catarina'),
    ('SP', 'Sao Paulo'), ('SE', 'Sergipe'), ('TO', 'Tocantins');
INSERT INTO tipo_documento (id_tipo_documento, nm_tipo_documento) VALUES
    (1, 'Contrato assinado'), (2, 'Documento do cliente'), (3, 'Matricula do imovel'), (4, 'Laudo de vistoria'),
    (5, 'Comprovante de renda'), (6, 'Certidao negativa de debitos');
INSERT INTO categoria_financeira (id_categoria, cd_categoria, nm_categoria, tp_categoria) VALUES
    (1, 'corretagem_venda', 'Corretagem de venda', 'receita'), (2, 'intermediacao_locacao', 'Intermediacao de locacao', 'receita'),
    (3, 'aluguel', 'Aluguel', 'receita'), (4, 'taxa_administracao', 'Taxa de administracao', 'receita'),
    (5, 'multa_rescisoria', 'Multa rescisoria', 'receita'), (6, 'servico', 'Servicos', 'receita'),
    (7, 'comissao', 'Comissao de corretor', 'despesa'), (8, 'repasse', 'Repasse de aluguel', 'despesa'),
    (9, 'despesa_operacional', 'Despesa operacional', 'despesa'), (10, 'imposto', 'Imposto', 'despesa');
SELECT setval(pg_get_serial_sequence('tipo_imovel', 'id_tipo_imovel'), (SELECT max(id_tipo_imovel) FROM tipo_imovel));
SELECT setval(pg_get_serial_sequence('origem_contato', 'id_origem'), (SELECT max(id_origem) FROM origem_contato));
SELECT setval(pg_get_serial_sequence('forma_pagamento', 'id_forma_pagamento'), (SELECT max(id_forma_pagamento) FROM forma_pagamento));
SELECT setval(pg_get_serial_sequence('tipo_documento', 'id_tipo_documento'), (SELECT max(id_tipo_documento) FROM tipo_documento));
SELECT setval(pg_get_serial_sequence('categoria_financeira', 'id_categoria'), (SELECT max(id_categoria) FROM categoria_financeira));

INSERT INTO funil_estagio (id_estagio, nm_estagio, nr_ordem, ds_cor) VALUES
    (1, 'Novo contato', 1, '#64748B'),
    (2, 'Qualificacao', 2, '#0EA5E9'),
    (3, 'Visita', 3, '#8B5CF6'),
    (4, 'Proposta', 4, '#F59E0B'),
    (5, 'Contrato', 5, '#10B981'),
    (6, 'Ganho', 6, '#15803D'),
    (7, 'Perdido', 7, '#BE123C');
SELECT setval(pg_get_serial_sequence('funil_estagio', 'id_estagio'), (SELECT max(id_estagio) FROM funil_estagio));

-- =====================================================================
-- CRMoveis - Indices
-- Projeto Integrador - Modelagem de Dados - Prof. Clovis - Grupo 4
-- PostgreSQL 13 ou superior - depois do 02
-- =====================================================================

-- =====================================================================
-- INDICES UNICOS PARCIAIS
-- =====================================================================
-- RN03: no maximo um titular por numero e um telefone principal por usuario.
CREATE UNIQUE INDEX ux_telefone_titular   ON telefone (nr_telefone) WHERE fl_titular;
CREATE UNIQUE INDEX ux_telefone_principal ON telefone (id_usuario)  WHERE fl_principal;

-- Indices das chaves estrangeiras (54): o PostgreSQL nao cria indice para FK automaticamente.
-- Eles aceleram as juncoes (JOIN) e a conferencia da FK quando o registro referenciado e excluido ou alterado.
-- FKs que ja comecam a chave primaria ou uma restricao unica nao precisam de outro indice.
CREATE INDEX ix_usuario_id_origem ON usuario (id_origem);
CREATE INDEX ix_cidade_sg_uf ON cidade (sg_uf);
CREATE INDEX ix_cep_id_cidade ON cep (id_cidade);
CREATE INDEX ix_perfil_interesse_id_cidade ON perfil_interesse (id_cidade);
CREATE INDEX ix_perfil_interesse_tipo_id_tipo_imovel ON perfil_interesse_tipo (id_tipo_imovel);
CREATE INDEX ix_perfil_interesse_bairro_id_bairro ON perfil_interesse_bairro (id_bairro);
CREATE INDEX ix_imovel_id_proprietario ON imovel (id_proprietario);
CREATE INDEX ix_imovel_id_corretor_responsavel ON imovel (id_corretor_responsavel);
CREATE INDEX ix_imovel_nr_cep ON imovel (nr_cep);
CREATE INDEX ix_imovel_id_tipo_imovel ON imovel (id_tipo_imovel);
CREATE INDEX ix_imovel_id_bairro ON imovel (id_bairro);
CREATE INDEX ix_imovel_caracteristica_id_imovel ON imovel_caracteristica (id_imovel);
CREATE INDEX ix_conversa_id_cliente ON conversa (id_cliente);
CREATE INDEX ix_conversa_id_corretor ON conversa (id_corretor);
CREATE INDEX ix_conversa_id_estagio ON conversa (id_estagio);
CREATE INDEX ix_conversa_imovel_id_conversa ON conversa_imovel (id_conversa);
CREATE INDEX ix_historico_estagio_id_estagio ON historico_estagio (id_estagio);
CREATE INDEX ix_historico_estagio_id_usuario ON historico_estagio (id_usuario);
CREATE INDEX ix_tarefa_id_conversa ON tarefa (id_conversa);
CREATE INDEX ix_tarefa_id_corretor ON tarefa (id_corretor);
CREATE INDEX ix_conversa_tag_id_tag ON conversa_tag (id_tag);
CREATE INDEX ix_visita_id_cliente ON visita (id_cliente);
CREATE INDEX ix_visita_id_corretor ON visita (id_corretor);
CREATE INDEX ix_proposta_id_imovel ON proposta (id_imovel);
CREATE INDEX ix_proposta_id_cliente ON proposta (id_cliente);
CREATE INDEX ix_proposta_id_corretor ON proposta (id_corretor);
CREATE INDEX ix_proposta_id_autorizador ON proposta (id_autorizador);
CREATE INDEX ix_proposta_id_visita ON proposta (id_visita);
CREATE INDEX ix_documento_id_tipo_documento ON documento (id_tipo_documento);
CREATE INDEX ix_comissao_id_corretor ON comissao (id_corretor);
CREATE INDEX ix_comissao_id_aprovador ON comissao (id_aprovador);
CREATE INDEX ix_financiamento_id_instituicao ON financiamento (id_instituicao);
CREATE INDEX ix_conta_receber_id_contrato ON conta_receber (id_contrato);
CREATE INDEX ix_conta_receber_id_categoria ON conta_receber (id_categoria);
CREATE INDEX ix_conta_receber_id_pagador ON conta_receber (id_pagador);
CREATE INDEX ix_recebimento_id_conta ON recebimento (id_conta);
CREATE INDEX ix_recebimento_id_forma_pagamento ON recebimento (id_forma_pagamento);
CREATE INDEX ix_recebimento_id_conta_nr_movimento ON recebimento (id_conta, nr_movimento) WHERE nr_movimento IS NOT NULL;
CREATE INDEX ix_conta_pagar_id_contrato ON conta_pagar (id_contrato);
CREATE INDEX ix_conta_pagar_id_categoria ON conta_pagar (id_categoria);
CREATE INDEX ix_conta_pagar_id_favorecido ON conta_pagar (id_favorecido);
CREATE INDEX ix_conta_pagar_id_custeador ON conta_pagar (id_custeador);
CREATE INDEX ix_pagamento_id_conta ON pagamento (id_conta);
CREATE INDEX ix_pagamento_id_forma_pagamento ON pagamento (id_forma_pagamento);
CREATE INDEX ix_pagamento_id_usuario ON pagamento (id_usuario);
CREATE INDEX ix_pagamento_id_conta_nr_movimento ON pagamento (id_conta, nr_movimento) WHERE nr_movimento IS NOT NULL;
CREATE INDEX ix_auditoria_id_usuario ON auditoria (id_usuario);
CREATE INDEX ix_auditoria_id_contrato ON auditoria (id_contrato);
CREATE INDEX ix_auditoria_id_proposta ON auditoria (id_proposta);
CREATE INDEX ix_auditoria_id_comissao_contrato_id_comissao_corretor ON auditoria (id_comissao_contrato, id_comissao_corretor) WHERE id_comissao_corretor IS NOT NULL;
CREATE INDEX ix_auditoria_id_conta_receber ON auditoria (id_conta_receber);
CREATE INDEX ix_auditoria_id_recebimento_conta_nr_recebimento ON auditoria (id_recebimento_conta, nr_recebimento) WHERE nr_recebimento IS NOT NULL;
CREATE INDEX ix_auditoria_id_conta_pagar ON auditoria (id_conta_pagar);
CREATE INDEX ix_auditoria_id_pagamento_conta_nr_pagamento ON auditoria (id_pagamento_conta, nr_pagamento) WHERE nr_pagamento IS NOT NULL;

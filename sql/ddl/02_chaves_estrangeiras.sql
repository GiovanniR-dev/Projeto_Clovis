-- =====================================================================
-- CRMoveis - Chaves estrangeiras e integridade referencial
-- Projeto Integrador - Modelagem de Dados - Prof. Clovis - Grupo 4
-- PostgreSQL 13 ou superior - depois do 01
-- =====================================================================

-- 87 chaves estrangeiras. Politica ao excluir o registro referenciado:
--   RESTRICT (padrao): preserva o historico: nao se exclui o que ainda e referenciado (contratos e lancamentos nunca sao excluidos).
--   CASCADE:           o registro dependente nao existe sem o referenciado (subtipo, entidade fraca ou ligacao N:N).
--   SET NULL:          a participacao e opcional (minimo 0): o registro continua valido sem a referencia.
-- ON UPDATE: as chaves substitutas (IDENTITY) nunca mudam; so o CEP, que e chave natural, propaga a correcao (ON UPDATE CASCADE).

-- CAPTA: id_origem -> origem_contato
ALTER TABLE usuario ADD CONSTRAINT fk_usuario_capta
    FOREIGN KEY (id_origem) REFERENCES origem_contato (id_origem) ON DELETE RESTRICT;
-- especializacao: id_usuario -> usuario
ALTER TABLE cliente ADD CONSTRAINT fk_cliente_usuario
    FOREIGN KEY (id_usuario) REFERENCES usuario (id_usuario) ON DELETE CASCADE;
-- especializacao: id_usuario -> usuario
ALTER TABLE proprietario ADD CONSTRAINT fk_proprietario_usuario
    FOREIGN KEY (id_usuario) REFERENCES usuario (id_usuario) ON DELETE CASCADE;
-- especializacao: id_usuario -> usuario
ALTER TABLE inquilino ADD CONSTRAINT fk_inquilino_usuario
    FOREIGN KEY (id_usuario) REFERENCES usuario (id_usuario) ON DELETE CASCADE;
-- especializacao: id_usuario -> usuario
ALTER TABLE corretor ADD CONSTRAINT fk_corretor_usuario
    FOREIGN KEY (id_usuario) REFERENCES usuario (id_usuario) ON DELETE CASCADE;
-- especializacao: id_usuario -> usuario
ALTER TABLE financeiro ADD CONSTRAINT fk_financeiro_usuario
    FOREIGN KEY (id_usuario) REFERENCES usuario (id_usuario) ON DELETE CASCADE;
-- especializacao: id_usuario -> usuario
ALTER TABLE fornecedor ADD CONSTRAINT fk_fornecedor_usuario
    FOREIGN KEY (id_usuario) REFERENCES usuario (id_usuario) ON DELETE CASCADE;
-- especializacao: id_usuario -> usuario
ALTER TABLE administrador ADD CONSTRAINT fk_administrador_usuario
    FOREIGN KEY (id_usuario) REFERENCES usuario (id_usuario) ON DELETE CASCADE;
-- especializacao: id_usuario -> usuario
ALTER TABLE instituicao_financeira ADD CONSTRAINT fk_instituicao_financeira_usuario
    FOREIGN KEY (id_usuario) REFERENCES usuario (id_usuario) ON DELETE CASCADE;
-- POSSUI: id_usuario -> usuario
ALTER TABLE telefone ADD CONSTRAINT fk_telefone_possui
    FOREIGN KEY (id_usuario) REFERENCES usuario (id_usuario) ON DELETE CASCADE;
-- COMPREENDE: sg_uf -> uf
ALTER TABLE cidade ADD CONSTRAINT fk_cidade_compreende
    FOREIGN KEY (sg_uf) REFERENCES uf (sg_uf) ON DELETE RESTRICT;
-- AGRUPA: id_cidade -> cidade
ALTER TABLE cep ADD CONSTRAINT fk_cep_agrupa
    FOREIGN KEY (id_cidade) REFERENCES cidade (id_cidade) ON DELETE RESTRICT;
-- DIVIDE: id_cidade -> cidade
ALTER TABLE bairro ADD CONSTRAINT fk_bairro_divide
    FOREIGN KEY (id_cidade) REFERENCES cidade (id_cidade) ON DELETE RESTRICT;
-- BUSCA: id_usuario -> cliente
ALTER TABLE perfil_interesse ADD CONSTRAINT fk_perfil_interesse_busca
    FOREIGN KEY (id_usuario) REFERENCES cliente (id_usuario) ON DELETE CASCADE;
-- PREFERE: id_cidade -> cidade
ALTER TABLE perfil_interesse ADD CONSTRAINT fk_perfil_interesse_prefere
    FOREIGN KEY (id_cidade) REFERENCES cidade (id_cidade) ON DELETE RESTRICT;
-- DESEJA: id_usuario, nr_perfil -> perfil_interesse
ALTER TABLE perfil_interesse_tipo ADD CONSTRAINT fk_perfil_interesse_tipo_perfil_interesse
    FOREIGN KEY (id_usuario, nr_perfil) REFERENCES perfil_interesse (id_usuario, nr_perfil) ON DELETE CASCADE;
-- DESEJA: id_tipo_imovel -> tipo_imovel
ALTER TABLE perfil_interesse_tipo ADD CONSTRAINT fk_perfil_interesse_tipo_tipo_imovel
    FOREIGN KEY (id_tipo_imovel) REFERENCES tipo_imovel (id_tipo_imovel) ON DELETE RESTRICT;
-- ABRANGE: id_usuario, nr_perfil -> perfil_interesse
ALTER TABLE perfil_interesse_bairro ADD CONSTRAINT fk_perfil_interesse_bairro_perfil_interesse
    FOREIGN KEY (id_usuario, nr_perfil) REFERENCES perfil_interesse (id_usuario, nr_perfil) ON DELETE CASCADE;
-- ABRANGE: id_bairro -> bairro
ALTER TABLE perfil_interesse_bairro ADD CONSTRAINT fk_perfil_interesse_bairro_bairro
    FOREIGN KEY (id_bairro) REFERENCES bairro (id_bairro) ON DELETE RESTRICT;
-- ANUNCIA: id_proprietario -> proprietario
ALTER TABLE imovel ADD CONSTRAINT fk_imovel_anuncia
    FOREIGN KEY (id_proprietario) REFERENCES proprietario (id_usuario) ON DELETE RESTRICT;
-- RESPONSAVEL: id_corretor_responsavel -> corretor
ALTER TABLE imovel ADD CONSTRAINT fk_imovel_responsavel
    FOREIGN KEY (id_corretor_responsavel) REFERENCES corretor (id_usuario) ON DELETE RESTRICT;
-- LOCALIZA: nr_cep -> cep
ALTER TABLE imovel ADD CONSTRAINT fk_imovel_localiza
    FOREIGN KEY (nr_cep) REFERENCES cep (nr_cep) ON DELETE RESTRICT ON UPDATE CASCADE;
-- TIPIFICA: id_tipo_imovel -> tipo_imovel
ALTER TABLE imovel ADD CONSTRAINT fk_imovel_tipifica
    FOREIGN KEY (id_tipo_imovel) REFERENCES tipo_imovel (id_tipo_imovel) ON DELETE RESTRICT;
-- SITUA: id_bairro -> bairro
ALTER TABLE imovel ADD CONSTRAINT fk_imovel_situa
    FOREIGN KEY (id_bairro) REFERENCES bairro (id_bairro) ON DELETE RESTRICT;
-- TEM: id_imovel -> imovel
ALTER TABLE foto ADD CONSTRAINT fk_foto_tem
    FOREIGN KEY (id_imovel) REFERENCES imovel (id_imovel) ON DELETE CASCADE;
-- APRESENTA: id_caracteristica -> caracteristica
ALTER TABLE imovel_caracteristica ADD CONSTRAINT fk_imovel_caracteristica_caracteristica
    FOREIGN KEY (id_caracteristica) REFERENCES caracteristica (id_caracteristica) ON DELETE RESTRICT;
-- APRESENTA: id_imovel -> imovel
ALTER TABLE imovel_caracteristica ADD CONSTRAINT fk_imovel_caracteristica_imovel
    FOREIGN KEY (id_imovel) REFERENCES imovel (id_imovel) ON DELETE CASCADE;
-- INICIA: id_cliente -> cliente
ALTER TABLE conversa ADD CONSTRAINT fk_conversa_inicia
    FOREIGN KEY (id_cliente) REFERENCES cliente (id_usuario) ON DELETE RESTRICT;
-- ATENDE: id_corretor -> corretor
ALTER TABLE conversa ADD CONSTRAINT fk_conversa_atende
    FOREIGN KEY (id_corretor) REFERENCES corretor (id_usuario) ON DELETE RESTRICT;
-- PERTENCE A: id_estagio -> funil_estagio
ALTER TABLE conversa ADD CONSTRAINT fk_conversa_pertence_a
    FOREIGN KEY (id_estagio) REFERENCES funil_estagio (id_estagio) ON DELETE RESTRICT;
-- INTERESSA: id_imovel -> imovel
ALTER TABLE conversa_imovel ADD CONSTRAINT fk_conversa_imovel_imovel
    FOREIGN KEY (id_imovel) REFERENCES imovel (id_imovel) ON DELETE RESTRICT;
-- INTERESSA: id_conversa -> conversa
ALTER TABLE conversa_imovel ADD CONSTRAINT fk_conversa_imovel_conversa
    FOREIGN KEY (id_conversa) REFERENCES conversa (id_conversa) ON DELETE CASCADE;
-- CONTEM: id_conversa -> conversa
ALTER TABLE mensagem ADD CONSTRAINT fk_mensagem_contem
    FOREIGN KEY (id_conversa) REFERENCES conversa (id_conversa) ON DELETE CASCADE;
-- MOVE: id_conversa -> conversa
ALTER TABLE historico_estagio ADD CONSTRAINT fk_historico_estagio_conversa
    FOREIGN KEY (id_conversa) REFERENCES conversa (id_conversa) ON DELETE CASCADE;
-- MOVE: id_estagio -> funil_estagio
ALTER TABLE historico_estagio ADD CONSTRAINT fk_historico_estagio_funil_estagio
    FOREIGN KEY (id_estagio) REFERENCES funil_estagio (id_estagio) ON DELETE RESTRICT;
-- REGISTRA: id_usuario -> usuario
ALTER TABLE historico_estagio ADD CONSTRAINT fk_historico_estagio_registra
    FOREIGN KEY (id_usuario) REFERENCES usuario (id_usuario) ON DELETE SET NULL;
-- GERA TAREFA: id_conversa -> conversa
ALTER TABLE tarefa ADD CONSTRAINT fk_tarefa_gera_tarefa
    FOREIGN KEY (id_conversa) REFERENCES conversa (id_conversa) ON DELETE SET NULL;
-- EXECUTA: id_corretor -> corretor
ALTER TABLE tarefa ADD CONSTRAINT fk_tarefa_executa
    FOREIGN KEY (id_corretor) REFERENCES corretor (id_usuario) ON DELETE RESTRICT;
-- MARCA: id_conversa -> conversa
ALTER TABLE conversa_tag ADD CONSTRAINT fk_conversa_tag_conversa
    FOREIGN KEY (id_conversa) REFERENCES conversa (id_conversa) ON DELETE CASCADE;
-- MARCA: id_tag -> tag
ALTER TABLE conversa_tag ADD CONSTRAINT fk_conversa_tag_tag
    FOREIGN KEY (id_tag) REFERENCES tag (id_tag) ON DELETE CASCADE;
-- VISITA: id_imovel -> imovel
ALTER TABLE visita ADD CONSTRAINT fk_visita_imovel
    FOREIGN KEY (id_imovel) REFERENCES imovel (id_imovel) ON DELETE RESTRICT;
-- VISITA: id_cliente -> cliente
ALTER TABLE visita ADD CONSTRAINT fk_visita_cliente
    FOREIGN KEY (id_cliente) REFERENCES cliente (id_usuario) ON DELETE RESTRICT;
-- ACOMPANHA: id_corretor -> corretor
ALTER TABLE visita ADD CONSTRAINT fk_visita_acompanha
    FOREIGN KEY (id_corretor) REFERENCES corretor (id_usuario) ON DELETE RESTRICT;
-- PROPOE: id_imovel -> imovel
ALTER TABLE proposta ADD CONSTRAINT fk_proposta_imovel
    FOREIGN KEY (id_imovel) REFERENCES imovel (id_imovel) ON DELETE RESTRICT;
-- PROPOE: id_cliente -> cliente
ALTER TABLE proposta ADD CONSTRAINT fk_proposta_cliente
    FOREIGN KEY (id_cliente) REFERENCES cliente (id_usuario) ON DELETE RESTRICT;
-- NEGOCIA: id_corretor -> corretor
ALTER TABLE proposta ADD CONSTRAINT fk_proposta_negocia
    FOREIGN KEY (id_corretor) REFERENCES corretor (id_usuario) ON DELETE RESTRICT;
-- AUTORIZA: id_autorizador -> administrador
ALTER TABLE proposta ADD CONSTRAINT fk_proposta_autoriza
    FOREIGN KEY (id_autorizador) REFERENCES administrador (id_usuario) ON DELETE RESTRICT;
-- RESPONDE: id_proposta_respondida -> proposta
ALTER TABLE proposta ADD CONSTRAINT fk_proposta_responde
    FOREIGN KEY (id_proposta_respondida) REFERENCES proposta (id_proposta) ON DELETE RESTRICT;
-- ORIGINA: id_visita -> visita
ALTER TABLE proposta ADD CONSTRAINT fk_proposta_origina
    FOREIGN KEY (id_visita) REFERENCES visita (id_visita) ON DELETE RESTRICT;
-- FECHA: id_proposta -> proposta
ALTER TABLE contrato ADD CONSTRAINT fk_contrato_fecha
    FOREIGN KEY (id_proposta) REFERENCES proposta (id_proposta) ON DELETE RESTRICT;
-- ANEXA: id_contrato -> contrato
ALTER TABLE documento ADD CONSTRAINT fk_documento_anexa
    FOREIGN KEY (id_contrato) REFERENCES contrato (id_contrato) ON DELETE RESTRICT;
-- QUALIFICA: id_tipo_documento -> tipo_documento
ALTER TABLE documento ADD CONSTRAINT fk_documento_qualifica
    FOREIGN KEY (id_tipo_documento) REFERENCES tipo_documento (id_tipo_documento) ON DELETE RESTRICT;
-- RECEBE: id_contrato -> contrato
ALTER TABLE comissao ADD CONSTRAINT fk_comissao_contrato
    FOREIGN KEY (id_contrato) REFERENCES contrato (id_contrato) ON DELETE RESTRICT;
-- RECEBE: id_corretor -> corretor
ALTER TABLE comissao ADD CONSTRAINT fk_comissao_corretor
    FOREIGN KEY (id_corretor) REFERENCES corretor (id_usuario) ON DELETE RESTRICT;
-- APROVA: id_aprovador -> administrador
ALTER TABLE comissao ADD CONSTRAINT fk_comissao_aprova
    FOREIGN KEY (id_aprovador) REFERENCES administrador (id_usuario) ON DELETE RESTRICT;
-- LANCA: id_conta_pagar -> conta_pagar
ALTER TABLE comissao ADD CONSTRAINT fk_comissao_lanca
    FOREIGN KEY (id_conta_pagar) REFERENCES conta_pagar (id_conta_pagar) ON DELETE RESTRICT;
-- FINANCIA: id_contrato -> contrato
ALTER TABLE financiamento ADD CONSTRAINT fk_financiamento_financia
    FOREIGN KEY (id_contrato) REFERENCES contrato (id_contrato) ON DELETE RESTRICT;
-- CONCEDE: id_instituicao -> instituicao_financeira
ALTER TABLE financiamento ADD CONSTRAINT fk_financiamento_concede
    FOREIGN KEY (id_instituicao) REFERENCES instituicao_financeira (id_usuario) ON DELETE RESTRICT;
-- LISTA: id_conta -> conta_bancaria
ALTER TABLE movimento_bancario ADD CONSTRAINT fk_movimento_bancario_lista
    FOREIGN KEY (id_conta) REFERENCES conta_bancaria (id_conta) ON DELETE RESTRICT;
-- GERA RECEITA: id_contrato -> contrato
ALTER TABLE conta_receber ADD CONSTRAINT fk_conta_receber_gera_receita
    FOREIGN KEY (id_contrato) REFERENCES contrato (id_contrato) ON DELETE RESTRICT;
-- CLASSIFICA: id_categoria -> categoria_financeira
ALTER TABLE conta_receber ADD CONSTRAINT fk_conta_receber_classifica
    FOREIGN KEY (id_categoria) REFERENCES categoria_financeira (id_categoria) ON DELETE RESTRICT;
-- PAGA: id_pagador -> usuario
ALTER TABLE conta_receber ADD CONSTRAINT fk_conta_receber_paga
    FOREIGN KEY (id_pagador) REFERENCES usuario (id_usuario) ON DELETE RESTRICT;
-- QUITA: id_conta_receber -> conta_receber
ALTER TABLE recebimento ADD CONSTRAINT fk_recebimento_quita
    FOREIGN KEY (id_conta_receber) REFERENCES conta_receber (id_conta_receber) ON DELETE RESTRICT;
-- CREDITA: id_conta -> conta_bancaria
ALTER TABLE recebimento ADD CONSTRAINT fk_recebimento_credita
    FOREIGN KEY (id_conta) REFERENCES conta_bancaria (id_conta) ON DELETE RESTRICT;
-- RECEBIDO VIA: id_forma_pagamento -> forma_pagamento
ALTER TABLE recebimento ADD CONSTRAINT fk_recebimento_recebido_via
    FOREIGN KEY (id_forma_pagamento) REFERENCES forma_pagamento (id_forma_pagamento) ON DELETE RESTRICT;
-- CONCILIA: id_conta, nr_movimento -> movimento_bancario
ALTER TABLE recebimento ADD CONSTRAINT fk_recebimento_concilia
    FOREIGN KEY (id_conta, nr_movimento) REFERENCES movimento_bancario (id_conta, nr_movimento) ON DELETE RESTRICT;
-- GERA DESPESA: id_contrato -> contrato
ALTER TABLE conta_pagar ADD CONSTRAINT fk_conta_pagar_gera_despesa
    FOREIGN KEY (id_contrato) REFERENCES contrato (id_contrato) ON DELETE RESTRICT;
-- CATEGORIZA: id_categoria -> categoria_financeira
ALTER TABLE conta_pagar ADD CONSTRAINT fk_conta_pagar_categoriza
    FOREIGN KEY (id_categoria) REFERENCES categoria_financeira (id_categoria) ON DELETE RESTRICT;
-- FAVORECE: id_favorecido -> usuario
ALTER TABLE conta_pagar ADD CONSTRAINT fk_conta_pagar_favorece
    FOREIGN KEY (id_favorecido) REFERENCES usuario (id_usuario) ON DELETE RESTRICT;
-- CUSTEIA: id_custeador -> usuario
ALTER TABLE conta_pagar ADD CONSTRAINT fk_conta_pagar_custeia
    FOREIGN KEY (id_custeador) REFERENCES usuario (id_usuario) ON DELETE RESTRICT;
-- REPASSA: id_conta_receber_origem, nr_recebimento_origem -> recebimento
ALTER TABLE conta_pagar ADD CONSTRAINT fk_conta_pagar_repassa
    FOREIGN KEY (id_conta_receber_origem, nr_recebimento_origem) REFERENCES recebimento (id_conta_receber, nr_recebimento) ON DELETE RESTRICT;
-- LIQUIDA: id_conta_pagar -> conta_pagar
ALTER TABLE pagamento ADD CONSTRAINT fk_pagamento_liquida
    FOREIGN KEY (id_conta_pagar) REFERENCES conta_pagar (id_conta_pagar) ON DELETE RESTRICT;
-- DEBITA: id_conta -> conta_bancaria
ALTER TABLE pagamento ADD CONSTRAINT fk_pagamento_debita
    FOREIGN KEY (id_conta) REFERENCES conta_bancaria (id_conta) ON DELETE RESTRICT;
-- PAGO VIA: id_forma_pagamento -> forma_pagamento
ALTER TABLE pagamento ADD CONSTRAINT fk_pagamento_pago_via
    FOREIGN KEY (id_forma_pagamento) REFERENCES forma_pagamento (id_forma_pagamento) ON DELETE RESTRICT;
-- EFETIVA: id_usuario -> usuario
ALTER TABLE pagamento ADD CONSTRAINT fk_pagamento_efetiva
    FOREIGN KEY (id_usuario) REFERENCES usuario (id_usuario) ON DELETE RESTRICT;
-- CONFERE: id_conta, nr_movimento -> movimento_bancario
ALTER TABLE pagamento ADD CONSTRAINT fk_pagamento_confere
    FOREIGN KEY (id_conta, nr_movimento) REFERENCES movimento_bancario (id_conta, nr_movimento) ON DELETE RESTRICT;
-- DISPARA: id_conversa -> conversa
ALTER TABLE automacao_execucao ADD CONSTRAINT fk_automacao_execucao_dispara
    FOREIGN KEY (id_conversa) REFERENCES conversa (id_conversa) ON DELETE CASCADE;
-- GRAVA: id_conversa, nr_execucao -> automacao_execucao
ALTER TABLE automacao_log ADD CONSTRAINT fk_automacao_log_grava
    FOREIGN KEY (id_conversa, nr_execucao) REFERENCES automacao_execucao (id_conversa, nr_execucao) ON DELETE CASCADE;
-- PRATICA: id_usuario -> usuario
ALTER TABLE auditoria ADD CONSTRAINT fk_auditoria_pratica
    FOREIGN KEY (id_usuario) REFERENCES usuario (id_usuario) ON DELETE RESTRICT;
-- AUDITA CONTRATO: id_contrato -> contrato
ALTER TABLE auditoria ADD CONSTRAINT fk_auditoria_audita_contrato
    FOREIGN KEY (id_contrato) REFERENCES contrato (id_contrato) ON DELETE RESTRICT;
-- AUDITA PROPOSTA: id_proposta -> proposta
ALTER TABLE auditoria ADD CONSTRAINT fk_auditoria_audita_proposta
    FOREIGN KEY (id_proposta) REFERENCES proposta (id_proposta) ON DELETE RESTRICT;
-- AUDITA COMISSAO: id_comissao_contrato, id_comissao_corretor -> comissao
ALTER TABLE auditoria ADD CONSTRAINT fk_auditoria_audita_comissao
    FOREIGN KEY (id_comissao_contrato, id_comissao_corretor) REFERENCES comissao (id_contrato, id_corretor) ON DELETE RESTRICT;
-- AUDITA CONTA_RECEBER: id_conta_receber -> conta_receber
ALTER TABLE auditoria ADD CONSTRAINT fk_auditoria_audita_conta_receber
    FOREIGN KEY (id_conta_receber) REFERENCES conta_receber (id_conta_receber) ON DELETE RESTRICT;
-- AUDITA RECEBIMENTO: id_recebimento_conta, nr_recebimento -> recebimento
ALTER TABLE auditoria ADD CONSTRAINT fk_auditoria_audita_recebimento
    FOREIGN KEY (id_recebimento_conta, nr_recebimento) REFERENCES recebimento (id_conta_receber, nr_recebimento) ON DELETE RESTRICT;
-- AUDITA CONTA_PAGAR: id_conta_pagar -> conta_pagar
ALTER TABLE auditoria ADD CONSTRAINT fk_auditoria_audita_conta_pagar
    FOREIGN KEY (id_conta_pagar) REFERENCES conta_pagar (id_conta_pagar) ON DELETE RESTRICT;
-- AUDITA PAGAMENTO: id_pagamento_conta, nr_pagamento -> pagamento
ALTER TABLE auditoria ADD CONSTRAINT fk_auditoria_audita_pagamento
    FOREIGN KEY (id_pagamento_conta, nr_pagamento) REFERENCES pagamento (id_conta_pagar, nr_pagamento) ON DELETE RESTRICT;
-- DETALHA: id_auditoria -> auditoria
ALTER TABLE auditoria_campo ADD CONSTRAINT fk_auditoria_campo_detalha
    FOREIGN KEY (id_auditoria) REFERENCES auditoria (id_auditoria) ON DELETE RESTRICT;

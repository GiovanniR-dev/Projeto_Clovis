# CRMoveis — Dicionario de dados (banco implementado)

Gerado do **catalogo do PostgreSQL** depois de executar os scripts de `sql/`: tipo, tamanho, nulos, padrao e restricoes sao lidos do banco, e as descricoes vem dos comentarios (`COMMENT ON`) criados por `sql/ddl/06_comentarios.sql`. Se o SQL mudar, o dicionario gerado muda junto.

Colunas sugeridas pelo manual (Etapa 13): Tabela, Atributo, Descricao, Tipo, Tamanho, PK, FK, NULL, UNIQUE, DEFAULT e Regra/Restricao.

**Totais:** 50 tabelas · 285 colunas.

**Indice:** [usuario](#usuario) · [origem_contato](#origem_contato) · [cliente](#cliente) · [proprietario](#proprietario) · [inquilino](#inquilino) · [corretor](#corretor) · [financeiro](#financeiro) · [fornecedor](#fornecedor) · [administrador](#administrador) · [instituicao_financeira](#instituicao_financeira) · [telefone](#telefone) · [uf](#uf) · [cidade](#cidade) · [cep](#cep) · [bairro](#bairro) · [perfil_interesse](#perfil_interesse) · [perfil_interesse_tipo](#perfil_interesse_tipo) · [perfil_interesse_bairro](#perfil_interesse_bairro) · [tipo_imovel](#tipo_imovel) · [imovel](#imovel) · [foto](#foto) · [caracteristica](#caracteristica) · [imovel_caracteristica](#imovel_caracteristica) · [funil_estagio](#funil_estagio) · [conversa](#conversa) · [conversa_imovel](#conversa_imovel) · [mensagem](#mensagem) · [historico_estagio](#historico_estagio) · [tarefa](#tarefa) · [tag](#tag) · [conversa_tag](#conversa_tag) · [visita](#visita) · [proposta](#proposta) · [contrato](#contrato) · [documento](#documento) · [tipo_documento](#tipo_documento) · [comissao](#comissao) · [financiamento](#financiamento) · [categoria_financeira](#categoria_financeira) · [conta_bancaria](#conta_bancaria) · [movimento_bancario](#movimento_bancario) · [conta_receber](#conta_receber) · [recebimento](#recebimento) · [conta_pagar](#conta_pagar) · [pagamento](#pagamento) · [forma_pagamento](#forma_pagamento) · [automacao_execucao](#automacao_execucao) · [automacao_log](#automacao_log) · [auditoria](#auditoria) · [auditoria_campo](#auditoria_campo)

## usuario

*Entidade USUARIO (forte). Supertipo da especializacao dos papeis.* · 55 linhas na massa de dados.

| Tabela | Atributo | Descricao | Tipo | Tamanho | PK | FK | NULL | UNIQUE | DEFAULT | Regra/Restricao |
|---|---|---|---|---|---|---|---|---|---|---|
| usuario | id_usuario | Identificador do usuario | INTEGER (identidade) | — | sim | nao | nao permitido | nao | — | Identificacao unica; herdado pelos subtipos |
| usuario | nm_usuario | Nome completo ou razao social | VARCHAR | 150 | nao | nao | nao permitido | nao | — | — |
| usuario | nr_cpf_cnpj | CPF ou CNPJ | VARCHAR | 14 | nao | nao | permitido | sim | — | Nao pode se repetir; obrigatorio para proprietario, instituicao financeira e quem assina contrato (RN04); apagado na anonimizacao (PO07) |
| usuario | ds_email | E-mail de contato e de acesso | VARCHAR | 150 | nao | nao | permitido | sim | — | Nao pode se repetir; obrigatorio para quem acessa o sistema |
| usuario | ds_senha_hash | Senha de acesso, guardada como hash | VARCHAR | 255 | nao | nao | permitido | nao | — | So para quem acessa o sistema; nunca em texto (RNF02) |
| usuario | id_origem | Referencia a origem_contato | INTEGER | — | nao | origem_contato.id_origem | permitido | nao | — | — |
| usuario | fl_ativo | Indica se o cadastro esta ativo | BOOLEAN | — | nao | nao | nao permitido | nao | verdadeiro | Cadastro inativo nao acessa o sistema |
| usuario | dt_cadastro | Data do cadastro | TIMESTAMP | — | nao | nao | nao permitido | nao | data e hora atual | Preenchida automaticamente |
| usuario | dt_anonimizacao | Data em que os dados pessoais foram anonimizados | TIMESTAMP | — | nao | nao | permitido | nao | — | Preenchida quando o titular pede a exclusao e ha obrigacao de guarda (PO07) |

## origem_contato

*Entidade ORIGEM_CONTATO (forte). Dominio: canais de captacao (antes um CHECK em usuario.tp_origem).* · 7 linhas na massa de dados.

| Tabela | Atributo | Descricao | Tipo | Tamanho | PK | FK | NULL | UNIQUE | DEFAULT | Regra/Restricao |
|---|---|---|---|---|---|---|---|---|---|---|
| origem_contato | id_origem | Identificador da origem | INTEGER (identidade) | — | sim | nao | nao permitido | nao | — | Identificacao unica |
| origem_contato | nm_origem | Canal pelo qual o contato chegou (site, indicacao, portal, Instagram, WhatsApp...) | VARCHAR | 40 | nao | nao | nao permitido | sim | — | Nao pode se repetir (RN49) |

## cliente

*Entidade CLIENTE (subtipo). Subtipo de USUARIO (especializacao total e compartilhada). Um registro por pessoa que exerce o papel; nunca e apagado, recebe dt_fim (RN02).* · 34 linhas na massa de dados.

| Tabela | Atributo | Descricao | Tipo | Tamanho | PK | FK | NULL | UNIQUE | DEFAULT | Regra/Restricao |
|---|---|---|---|---|---|---|---|---|---|---|
| cliente | id_usuario | Referencia a usuario | INTEGER | — | sim | usuario.id_usuario | nao permitido | nao | — | — |
| cliente | dt_inicio | Data em que a pessoa passou a ser cliente | DATE | — | nao | nao | nao permitido | nao | data atual | CHECK ck_cliente_dt_inicio_dt_fim |
| cliente | dt_fim | Data em que deixou de ser cliente | DATE | — | nao | nao | permitido | nao | — | Preenchida quando a pessoa deixa o papel; o registro nao e apagado (RN02) · CHECK ck_cliente_dt_inicio_dt_fim |

## proprietario

*Entidade PROPRIETARIO (subtipo). Subtipo de USUARIO (especializacao total e compartilhada). Um registro por pessoa que exerce o papel; nunca e apagado, recebe dt_fim (RN02).* · 10 linhas na massa de dados.

| Tabela | Atributo | Descricao | Tipo | Tamanho | PK | FK | NULL | UNIQUE | DEFAULT | Regra/Restricao |
|---|---|---|---|---|---|---|---|---|---|---|
| proprietario | id_usuario | Referencia a usuario | INTEGER | — | sim | usuario.id_usuario | nao permitido | nao | — | — |
| proprietario | dt_inicio | Data em que a pessoa passou a ser proprietario | DATE | — | nao | nao | nao permitido | nao | data atual | CHECK ck_proprietario_dt_inicio_dt_fim |
| proprietario | dt_fim | Data em que deixou de ser proprietario | DATE | — | nao | nao | permitido | nao | — | Preenchida quando a pessoa deixa o papel; o registro nao e apagado (RN02) · CHECK ck_proprietario_dt_inicio_dt_fim |

## inquilino

*Entidade INQUILINO (subtipo). Subtipo de USUARIO (especializacao total e compartilhada). Um registro por pessoa que exerce o papel; nunca e apagado, recebe dt_fim (RN02).* · 5 linhas na massa de dados.

| Tabela | Atributo | Descricao | Tipo | Tamanho | PK | FK | NULL | UNIQUE | DEFAULT | Regra/Restricao |
|---|---|---|---|---|---|---|---|---|---|---|
| inquilino | id_usuario | Referencia a usuario | INTEGER | — | sim | usuario.id_usuario | nao permitido | nao | — | — |
| inquilino | dt_inicio | Data em que a pessoa passou a ser inquilino | DATE | — | nao | nao | nao permitido | nao | data atual | Data da assinatura do contrato de locacao (RN33) · CHECK ck_inquilino_dt_inicio_dt_fim |
| inquilino | dt_fim | Data em que deixou de ser inquilino | DATE | — | nao | nao | permitido | nao | — | Preenchida no encerramento ou na rescisao da locacao (RN33, RN43, RN44); o registro nao e apagado (RN02) · CHECK ck_inquilino_dt_inicio_dt_fim |

## corretor

*Entidade CORRETOR (subtipo). Subtipo de USUARIO (especializacao total e compartilhada). Um registro por pessoa que exerce o papel; nunca e apagado, recebe dt_fim (RN02).* · 5 linhas na massa de dados.

| Tabela | Atributo | Descricao | Tipo | Tamanho | PK | FK | NULL | UNIQUE | DEFAULT | Regra/Restricao |
|---|---|---|---|---|---|---|---|---|---|---|
| corretor | id_usuario | Referencia a usuario | INTEGER | — | sim | usuario.id_usuario | nao permitido | nao | — | — |
| corretor | nr_creci | Registro do corretor no CRECI | VARCHAR | 20 | nao | nao | nao permitido | sim | — | Nao pode se repetir; so existe para corretores |
| corretor | dt_inicio | Data em que a pessoa passou a ser corretor | DATE | — | nao | nao | nao permitido | nao | data atual | CHECK ck_corretor_dt_inicio_dt_fim |
| corretor | dt_fim | Data em que deixou de ser corretor | DATE | — | nao | nao | permitido | nao | — | Preenchida quando a pessoa deixa o papel; o registro nao e apagado (RN02) · CHECK ck_corretor_dt_inicio_dt_fim |

## financeiro

*Entidade FINANCEIRO (subtipo). Subtipo de USUARIO (especializacao total e compartilhada). Um registro por pessoa que exerce o papel; nunca e apagado, recebe dt_fim (RN02).* · 2 linhas na massa de dados.

| Tabela | Atributo | Descricao | Tipo | Tamanho | PK | FK | NULL | UNIQUE | DEFAULT | Regra/Restricao |
|---|---|---|---|---|---|---|---|---|---|---|
| financeiro | id_usuario | Referencia a usuario | INTEGER | — | sim | usuario.id_usuario | nao permitido | nao | — | — |
| financeiro | dt_inicio | Data em que a pessoa passou a ser financeiro | DATE | — | nao | nao | nao permitido | nao | data atual | CHECK ck_financeiro_dt_inicio_dt_fim |
| financeiro | dt_fim | Data em que deixou de ser financeiro | DATE | — | nao | nao | permitido | nao | — | Preenchida quando a pessoa deixa o papel; o registro nao e apagado (RN02) · CHECK ck_financeiro_dt_inicio_dt_fim |

## fornecedor

*Entidade FORNECEDOR (subtipo). Subtipo de USUARIO (especializacao total e compartilhada). Um registro por pessoa que exerce o papel; nunca e apagado, recebe dt_fim (RN02).* · 3 linhas na massa de dados.

| Tabela | Atributo | Descricao | Tipo | Tamanho | PK | FK | NULL | UNIQUE | DEFAULT | Regra/Restricao |
|---|---|---|---|---|---|---|---|---|---|---|
| fornecedor | id_usuario | Referencia a usuario | INTEGER | — | sim | usuario.id_usuario | nao permitido | nao | — | — |
| fornecedor | dt_inicio | Data em que a pessoa passou a ser fornecedor | DATE | — | nao | nao | nao permitido | nao | data atual | CHECK ck_fornecedor_dt_inicio_dt_fim |
| fornecedor | dt_fim | Data em que deixou de ser fornecedor | DATE | — | nao | nao | permitido | nao | — | Preenchida quando a pessoa deixa o papel; o registro nao e apagado (RN02) · CHECK ck_fornecedor_dt_inicio_dt_fim |

## administrador

*Entidade ADMINISTRADOR (subtipo). Subtipo de USUARIO (especializacao total e compartilhada). Um registro por pessoa que exerce o papel; nunca e apagado, recebe dt_fim (RN02).* · 1 linhas na massa de dados.

| Tabela | Atributo | Descricao | Tipo | Tamanho | PK | FK | NULL | UNIQUE | DEFAULT | Regra/Restricao |
|---|---|---|---|---|---|---|---|---|---|---|
| administrador | id_usuario | Referencia a usuario | INTEGER | — | sim | usuario.id_usuario | nao permitido | nao | — | — |
| administrador | dt_inicio | Data em que a pessoa passou a ser administrador | DATE | — | nao | nao | nao permitido | nao | data atual | CHECK ck_administrador_dt_inicio_dt_fim |
| administrador | dt_fim | Data em que deixou de ser administrador | DATE | — | nao | nao | permitido | nao | — | Preenchida quando a pessoa deixa o papel; o registro nao e apagado (RN02) · CHECK ck_administrador_dt_inicio_dt_fim |

## instituicao_financeira

*Entidade INSTITUICAO_FINANCEIRA (subtipo). Subtipo de USUARIO (especializacao total e compartilhada). Um registro por pessoa que exerce o papel; nunca e apagado, recebe dt_fim (RN02).* · 2 linhas na massa de dados.

| Tabela | Atributo | Descricao | Tipo | Tamanho | PK | FK | NULL | UNIQUE | DEFAULT | Regra/Restricao |
|---|---|---|---|---|---|---|---|---|---|---|
| instituicao_financeira | id_usuario | Referencia a usuario | INTEGER | — | sim | usuario.id_usuario | nao permitido | nao | — | — |
| instituicao_financeira | dt_inicio | Data em que a pessoa passou a ser instituicao financeira | DATE | — | nao | nao | nao permitido | nao | data atual | Data do primeiro financiamento concedido (RN33) · CHECK ck_instituicao_financeira_dt_inicio_dt_fim |
| instituicao_financeira | dt_fim | Data em que deixou de ser instituicao financeira | DATE | — | nao | nao | permitido | nao | — | Preenchida quando a pessoa deixa o papel; o registro nao e apagado (RN02) · CHECK ck_instituicao_financeira_dt_inicio_dt_fim |

## telefone

*Entidade TELEFONE (fraca). Entidade fraca de USUARIO: o numero nao e chave; um numero compartilhado aparece uma vez para cada pessoa, com um unico titular (RN03).* · 62 linhas na massa de dados.

| Tabela | Atributo | Descricao | Tipo | Tamanho | PK | FK | NULL | UNIQUE | DEFAULT | Regra/Restricao |
|---|---|---|---|---|---|---|---|---|---|---|
| telefone | id_usuario | Referencia a usuario | INTEGER | — | sim | usuario.id_usuario | nao permitido | com nr_telefone; um por id_usuario quando fl_principal (indice parcial) | — | — |
| telefone | nr_sequencia | Numero do telefone dentro do cadastro da pessoa (1, 2, 3...) | SMALLINT | — | sim | nao | nao permitido | nao | — | Identificador parcial: o telefone e identificado pelo usuario + a sequencia, e nunca pelo numero |
| telefone | nr_telefone | Numero com DDD, so digitos | VARCHAR | 13 | nao | nao | nao permitido | com id_usuario; um por nr_telefone quando fl_titular (indice parcial) | — | A mesma pessoa nao repete o numero; o mesmo numero pode estar no cadastro de outra pessoa (casal, socios), com um unico titular (RN03) · CHECK ck_telefone_nr_telefone |
| telefone | fl_principal | Indica o telefone principal da pessoa | BOOLEAN | — | nao | nao | nao permitido | nao | falso | No maximo um principal por pessoa |
| telefone | fl_titular | Indica se a pessoa e a titular do numero | BOOLEAN | — | nao | nao | nao permitido | nao | falso | Exatamente um titular por numero; e pelo titular que a automacao identifica quem escreveu (RN03) |

## uf

*Entidade UF (forte). Dominio: as 27 unidades federativas (antes a sigla era texto livre em cidade).* · 27 linhas na massa de dados.

| Tabela | Atributo | Descricao | Tipo | Tamanho | PK | FK | NULL | UNIQUE | DEFAULT | Regra/Restricao |
|---|---|---|---|---|---|---|---|---|---|---|
| uf | sg_uf | Sigla da unidade federativa (SP, RJ, MG...) | CHAR | 2 | sim | nao | nao permitido | nao | — | Identificacao unica; duas letras maiusculas · CHECK ck_uf_sg_uf |
| uf | nm_uf | Nome da unidade federativa | VARCHAR | 30 | nao | nao | nao permitido | sim | — | Nao pode se repetir |

## cidade

*Entidade CIDADE (forte). 3FN: cidade e UF ficam aqui, e nao no imovel.* · 3 linhas na massa de dados.

| Tabela | Atributo | Descricao | Tipo | Tamanho | PK | FK | NULL | UNIQUE | DEFAULT | Regra/Restricao |
|---|---|---|---|---|---|---|---|---|---|---|
| cidade | id_cidade | Identificador da cidade | INTEGER (identidade) | — | sim | nao | nao permitido | nao | — | Identificacao unica |
| cidade | nm_cidade | Nome da cidade | VARCHAR | 100 | nao | nao | nao permitido | com sg_uf | — | Nao se repete dentro da mesma UF |
| cidade | sg_uf | Sigla da UF (referencia a uf) | CHAR | 2 | nao | uf.sg_uf | nao permitido | com nm_cidade | — | — |

## cep

*Entidade CEP (forte). 3FN: CEP -> cidade e UF.* · 15 linhas na massa de dados.

| Tabela | Atributo | Descricao | Tipo | Tamanho | PK | FK | NULL | UNIQUE | DEFAULT | Regra/Restricao |
|---|---|---|---|---|---|---|---|---|---|---|
| cep | nr_cep | CEP com 8 digitos | CHAR | 8 | sim | nao | nao permitido | nao | — | Identificacao unica; determina a cidade (RN41) |
| cep | id_cidade | Referencia a cidade | INTEGER | — | nao | cidade.id_cidade | nao permitido | nao | — | — |
| cep | tp_cep | Abrangencia do CEP | VARCHAR | 15 | nao | nao | nao permitido | nao | — | Geral (a cidade inteira) ou de logradouro; como um CEP geral nao indica rua, a rua continua no imovel · CHECK ck_cep_tp_cep |

## bairro

*Entidade BAIRRO (forte). Dominio: bairros de cada cidade (antes um texto repetido em imovel e em perfil_interesse) (RN51).* · 15 linhas na massa de dados.

| Tabela | Atributo | Descricao | Tipo | Tamanho | PK | FK | NULL | UNIQUE | DEFAULT | Regra/Restricao |
|---|---|---|---|---|---|---|---|---|---|---|
| bairro | id_bairro | Identificador do bairro | INTEGER (identidade) | — | sim | nao | nao permitido | nao | — | Identificacao unica |
| bairro | id_cidade | Referencia a cidade | INTEGER | — | nao | cidade.id_cidade | nao permitido | com nm_bairro | — | — |
| bairro | nm_bairro | Nome do bairro | VARCHAR | 100 | nao | nao | nao permitido | com id_cidade | — | Nao se repete dentro da mesma cidade; o mesmo nome pode existir em cidades diferentes (RN51) |

## perfil_interesse

*Entidade PERFIL_INTERESSE (fraca). Entidade fraca do CLIENTE.* · 30 linhas na massa de dados.

| Tabela | Atributo | Descricao | Tipo | Tamanho | PK | FK | NULL | UNIQUE | DEFAULT | Regra/Restricao |
|---|---|---|---|---|---|---|---|---|---|---|
| perfil_interesse | id_usuario | Referencia a cliente | INTEGER | — | sim | cliente.id_usuario | nao permitido | nao | — | — |
| perfil_interesse | nr_perfil | Numero do perfil dentro do cliente | SMALLINT | — | sim | nao | nao permitido | nao | — | Identificador parcial |
| perfil_interesse | id_cidade | Referencia a cidade | INTEGER | — | nao | cidade.id_cidade | permitido | nao | — | — |
| perfil_interesse | tp_finalidade | Venda ou locacao | VARCHAR | 10 | nao | nao | nao permitido | nao | — | Mesmo vocabulario de IMOVEL · CHECK ck_perfil_interesse_tp_finalidade |
| perfil_interesse | vl_minimo | Valor minimo aceito | NUMERIC | 12,2 | nao | nao | permitido | nao | — | Nao pode ser maior que o valor maximo · CHECK ck_perfil_interesse_vl_minimo_vl_maximo |
| perfil_interesse | vl_maximo | Valor maximo aceito | NUMERIC | 12,2 | nao | nao | permitido | nao | — | Maior ou igual ao minimo · CHECK ck_perfil_interesse_vl_minimo_vl_maximo |
| perfil_interesse | qt_quartos_min | Quantidade minima de quartos | SMALLINT | — | nao | nao | permitido | nao | — | — |

## perfil_interesse_tipo

*Relacionamento N:N DESEJA. Relacionamento N:N DESEJA: os tipos de imovel aceitos pelo perfil; perfil sem tipo aceita qualquer tipo (RN47).* · 42 linhas na massa de dados.

| Tabela | Atributo | Descricao | Tipo | Tamanho | PK | FK | NULL | UNIQUE | DEFAULT | Regra/Restricao |
|---|---|---|---|---|---|---|---|---|---|---|
| perfil_interesse_tipo | id_usuario | Referencia a perfil_interesse | INTEGER | — | sim | perfil_interesse.id_usuario | nao permitido | nao | — | — |
| perfil_interesse_tipo | nr_perfil | Referencia a perfil_interesse | SMALLINT | — | sim | perfil_interesse.nr_perfil | nao permitido | nao | — | — |
| perfil_interesse_tipo | id_tipo_imovel | Referencia a tipo_imovel | INTEGER | — | sim | tipo_imovel.id_tipo_imovel | nao permitido | nao | — | — |

## perfil_interesse_bairro

*Relacionamento N:N ABRANGE. Relacionamento N:N ABRANGE: os bairros aceitos pelo perfil, todos da cidade do perfil; perfil sem bairro aceita qualquer bairro (RN52).* · 40 linhas na massa de dados.

| Tabela | Atributo | Descricao | Tipo | Tamanho | PK | FK | NULL | UNIQUE | DEFAULT | Regra/Restricao |
|---|---|---|---|---|---|---|---|---|---|---|
| perfil_interesse_bairro | id_usuario | Referencia a perfil_interesse | INTEGER | — | sim | perfil_interesse.id_usuario | nao permitido | nao | — | — |
| perfil_interesse_bairro | nr_perfil | Referencia a perfil_interesse | SMALLINT | — | sim | perfil_interesse.nr_perfil | nao permitido | nao | — | — |
| perfil_interesse_bairro | id_bairro | Referencia a bairro | INTEGER | — | sim | bairro.id_bairro | nao permitido | nao | — | — |

## tipo_imovel

*Entidade TIPO_IMOVEL (forte). Dominio: tipos de imovel (antes um CHECK repetido em imovel e em perfil_interesse) (RN48).* · 10 linhas na massa de dados.

| Tabela | Atributo | Descricao | Tipo | Tamanho | PK | FK | NULL | UNIQUE | DEFAULT | Regra/Restricao |
|---|---|---|---|---|---|---|---|---|---|---|
| tipo_imovel | id_tipo_imovel | Identificador do tipo | INTEGER (identidade) | — | sim | nao | nao permitido | nao | — | Identificacao unica |
| tipo_imovel | nm_tipo_imovel | Nome do tipo (apartamento, casa, cobertura, terreno, sala comercial...) | VARCHAR | 40 | nao | nao | nao permitido | sim | — | Nao pode se repetir (RN48) |

## imovel

*Entidade IMOVEL (forte). 1FN: endereco em colunas atomicas. 3FN: cidade e UF vem do CEP.* · 30 linhas na massa de dados.

| Tabela | Atributo | Descricao | Tipo | Tamanho | PK | FK | NULL | UNIQUE | DEFAULT | Regra/Restricao |
|---|---|---|---|---|---|---|---|---|---|---|
| imovel | id_imovel | Identificador do imovel | INTEGER (identidade) | — | sim | nao | nao permitido | nao | — | Identificacao unica |
| imovel | cd_imobizi | Codigo do imovel no IMOBIZI | VARCHAR | 30 | nao | nao | permitido | sim | — | Nao pode se repetir; obrigatorio nos imoveis importados (RF14) |
| imovel | id_proprietario | Referencia a proprietario | INTEGER | — | nao | proprietario.id_usuario | nao permitido | nao | — | — |
| imovel | id_corretor_responsavel | Referencia a corretor | INTEGER | — | nao | corretor.id_usuario | permitido | nao | — | — |
| imovel | nr_cep | Referencia a cep | CHAR | 8 | nao | cep.nr_cep | nao permitido | nao | — | — |
| imovel | id_tipo_imovel | Referencia a tipo_imovel | INTEGER | — | nao | tipo_imovel.id_tipo_imovel | nao permitido | nao | — | — |
| imovel | tp_finalidade | Venda, locacao ou ambas | VARCHAR | 10 | nao | nao | nao permitido | nao | — | Define quais valores sao obrigatorios (17.24) · CHECK ck_imovel_tp_finalidade, ck_imovel_tp_finalidade_vl_venda, ck_imovel_tp_finalidade_vl_aluguel |
| imovel | nm_logradouro | Logradouro (rua, avenida etc.) | VARCHAR | 150 | nao | nao | nao permitido | nao | — | — |
| imovel | nr_endereco | Numero do endereco | VARCHAR | 10 | nao | nao | nao permitido | nao | — | — |
| imovel | ds_complemento | Complemento (apartamento, bloco, sala) | VARCHAR | 60 | nao | nao | permitido | nao | — | — |
| imovel | id_bairro | Bairro onde o imovel fica (referencia a bairro) | INTEGER | — | nao | bairro.id_bairro | nao permitido | nao | — | — |
| imovel | vl_area_util | Area util em m2 | NUMERIC | 10,2 | nao | nao | permitido | nao | — | — |
| imovel | vl_area_total | Area total em m2 | NUMERIC | 10,2 | nao | nao | permitido | nao | — | Maior ou igual a area util |
| imovel | qt_quartos | Quantidade de quartos | SMALLINT | — | nao | nao | permitido | nao | — | — |
| imovel | qt_banheiros | Quantidade de banheiros | SMALLINT | — | nao | nao | permitido | nao | — | — |
| imovel | qt_vagas_garagem | Quantidade de vagas de garagem | SMALLINT | — | nao | nao | permitido | nao | — | — |
| imovel | vl_venda | Preco de venda | NUMERIC | 12,2 | nao | nao | permitido | nao | — | Obrigatorio quando a finalidade e venda ou ambas · CHECK ck_imovel_tp_finalidade_vl_venda |
| imovel | vl_aluguel | Aluguel mensal pedido | NUMERIC | 12,2 | nao | nao | permitido | nao | — | Obrigatorio quando a finalidade e locacao ou ambas · CHECK ck_imovel_tp_finalidade_vl_aluguel |
| imovel | st_imovel | Situacao do imovel | VARCHAR | 15 | nao | nao | nao permitido | nao | 'disponivel' | Disponivel, reservado, vendido, alugado ou inativo; vendido, alugado ou inativo nao recebe visita nem proposta (RN10) · CHECK ck_imovel_st_imovel |
| imovel | ds_anuncio | Texto do anuncio | TEXT | — | nao | nao | permitido | nao | — | — |
| imovel | dt_cadastro | Data do cadastro | TIMESTAMP | — | nao | nao | nao permitido | nao | data e hora atual | Preenchida automaticamente |

## foto

*Entidade FOTO (fraca)* · 168 linhas na massa de dados.

| Tabela | Atributo | Descricao | Tipo | Tamanho | PK | FK | NULL | UNIQUE | DEFAULT | Regra/Restricao |
|---|---|---|---|---|---|---|---|---|---|---|
| foto | id_imovel | Referencia a imovel | INTEGER | — | sim | imovel.id_imovel | nao permitido | nao | — | — |
| foto | nr_foto | Numero da foto dentro do imovel | SMALLINT | — | sim | nao | nao permitido | nao | — | Identificador parcial; nao muda quando a galeria e reordenada |
| foto | nr_ordem | Posicao da foto na galeria | SMALLINT | — | nao | nao | nao permitido | nao | — | Pode ser alterada |
| foto | ds_url | Endereco do arquivo da foto | VARCHAR | 500 | nao | nao | nao permitido | nao | — | — |

## caracteristica

*Entidade CARACTERISTICA (forte)* · 15 linhas na massa de dados.

| Tabela | Atributo | Descricao | Tipo | Tamanho | PK | FK | NULL | UNIQUE | DEFAULT | Regra/Restricao |
|---|---|---|---|---|---|---|---|---|---|---|
| caracteristica | id_caracteristica | Identificador da caracteristica | INTEGER (identidade) | — | sim | nao | nao permitido | nao | — | Identificacao unica |
| caracteristica | nm_caracteristica | Nome (piscina, elevador, aceita pet...) | VARCHAR | 60 | nao | nao | nao permitido | sim | — | Nao pode se repetir |

## imovel_caracteristica

*Relacionamento N:N APRESENTA. Relacionamento N:N APRESENTA.* · 121 linhas na massa de dados.

| Tabela | Atributo | Descricao | Tipo | Tamanho | PK | FK | NULL | UNIQUE | DEFAULT | Regra/Restricao |
|---|---|---|---|---|---|---|---|---|---|---|
| imovel_caracteristica | id_caracteristica | Referencia a caracteristica | INTEGER | — | sim | caracteristica.id_caracteristica | nao permitido | nao | — | — |
| imovel_caracteristica | id_imovel | Referencia a imovel | INTEGER | — | sim | imovel.id_imovel | nao permitido | nao | — | — |

## funil_estagio

*Entidade FUNIL_ESTAGIO (forte)* · 7 linhas na massa de dados.

| Tabela | Atributo | Descricao | Tipo | Tamanho | PK | FK | NULL | UNIQUE | DEFAULT | Regra/Restricao |
|---|---|---|---|---|---|---|---|---|---|---|
| funil_estagio | id_estagio | Identificador do estagio | INTEGER (identidade) | — | sim | nao | nao permitido | nao | — | Identificacao unica |
| funil_estagio | nm_estagio | Nome do estagio | VARCHAR | 40 | nao | nao | nao permitido | sim | — | Nao pode se repetir |
| funil_estagio | nr_ordem | Posicao do estagio no funil | SMALLINT | — | nao | nao | nao permitido | sim | — | — |
| funil_estagio | ds_cor | Cor usada no quadro do funil | CHAR | 7 | nao | nao | permitido | nao | — | — |

## conversa

*Entidade CONVERSA (forte). dt_atualizacao e derivada e nao e armazenada.* · 45 linhas na massa de dados.

| Tabela | Atributo | Descricao | Tipo | Tamanho | PK | FK | NULL | UNIQUE | DEFAULT | Regra/Restricao |
|---|---|---|---|---|---|---|---|---|---|---|
| conversa | id_conversa | Identificador da conversa | INTEGER (identidade) | — | sim | nao | nao permitido | nao | — | Identificacao unica |
| conversa | id_cliente | Referencia a cliente | INTEGER | — | nao | cliente.id_usuario | nao permitido | nao | — | — |
| conversa | id_corretor | Referencia a corretor | INTEGER | — | nao | corretor.id_usuario | permitido | nao | — | — |
| conversa | id_estagio | Referencia a funil_estagio | INTEGER | — | nao | funil_estagio.id_estagio | nao permitido | nao | — | — |
| conversa | st_conversa | Situacao da conversa | VARCHAR | 10 | nao | nao | nao permitido | nao | 'aberta' | Aberta ou encerrada (RN34) · CHECK ck_conversa_st_conversa |
| conversa | ds_notas | Anotacoes do corretor sobre o atendimento | TEXT | — | nao | nao | permitido | nao | — | — |
| conversa | dt_inicio | Data de abertura da conversa | TIMESTAMP | — | nao | nao | nao permitido | nao | data e hora atual | Preenchida automaticamente |

## conversa_imovel

*Entidade CONVERSA_IMOVEL (associativa). Entidade associativa CONVERSA_IMOVEL (INTERESSA).* · 86 linhas na massa de dados.

| Tabela | Atributo | Descricao | Tipo | Tamanho | PK | FK | NULL | UNIQUE | DEFAULT | Regra/Restricao |
|---|---|---|---|---|---|---|---|---|---|---|
| conversa_imovel | id_imovel | Referencia a imovel | INTEGER | — | sim | imovel.id_imovel | nao permitido | nao | — | — |
| conversa_imovel | id_conversa | Referencia a conversa | INTEGER | — | sim | conversa.id_conversa | nao permitido | nao | — | — |
| conversa_imovel | dt_interesse | Quando o imovel passou a interessar na conversa | TIMESTAMP | — | nao | nao | nao permitido | nao | data e hora atual | Atributo do relacionamento |

## mensagem

*Entidade MENSAGEM (fraca)* · 353 linhas na massa de dados.

| Tabela | Atributo | Descricao | Tipo | Tamanho | PK | FK | NULL | UNIQUE | DEFAULT | Regra/Restricao |
|---|---|---|---|---|---|---|---|---|---|---|
| mensagem | id_conversa | Referencia a conversa | INTEGER | — | sim | conversa.id_conversa | nao permitido | com cd_externo | — | — |
| mensagem | nr_mensagem | Numero da mensagem dentro da conversa | INTEGER | — | sim | nao | nao permitido | nao | — | Identificador parcial |
| mensagem | cd_externo | Codigo da mensagem no WhatsApp | VARCHAR | 64 | nao | nao | permitido | com id_conversa | — | Nao se repete na mesma conversa, o que impede registrar a mesma mensagem duas vezes (RN31); vazio nas notas internas |
| mensagem | tp_direcao | Entrada (cliente) ou saida (imobiliaria) | VARCHAR | 10 | nao | nao | permitido | nao | — | Em branco quando for nota interna · CHECK ck_mensagem_tp_direcao |
| mensagem | tp_canal | Meio da mensagem | VARCHAR | 15 | nao | nao | nao permitido | nao | — | WhatsApp, e-mail ou nota interna · CHECK ck_mensagem_tp_canal |
| mensagem | ds_corpo | Conteudo da mensagem | TEXT | — | nao | nao | nao permitido | nao | — | — |
| mensagem | dt_mensagem | Data e hora da mensagem | TIMESTAMP | — | nao | nao | nao permitido | nao | data e hora atual | — |

## historico_estagio

*Entidade HISTORICO_ESTAGIO (associativa). Entidade associativa HISTORICO_ESTAGIO (MOVE).* · 139 linhas na massa de dados.

| Tabela | Atributo | Descricao | Tipo | Tamanho | PK | FK | NULL | UNIQUE | DEFAULT | Regra/Restricao |
|---|---|---|---|---|---|---|---|---|---|---|
| historico_estagio | id_conversa | Referencia a conversa | INTEGER | — | sim | conversa.id_conversa | nao permitido | nao | — | — |
| historico_estagio | dt_alteracao | Data e hora da mudanca de estagio | TIMESTAMP | — | sim | nao | nao permitido | nao | data e hora atual | Identificador parcial; toda mudanca gera um registro e o mais recente e o estagio atual (RN14) |
| historico_estagio | id_estagio | Referencia a funil_estagio | INTEGER | — | nao | funil_estagio.id_estagio | nao permitido | nao | — | — |
| historico_estagio | id_usuario | Referencia a usuario | INTEGER | — | nao | usuario.id_usuario | permitido | nao | — | — |

## tarefa

*Entidade TAREFA (forte)* · 104 linhas na massa de dados.

| Tabela | Atributo | Descricao | Tipo | Tamanho | PK | FK | NULL | UNIQUE | DEFAULT | Regra/Restricao |
|---|---|---|---|---|---|---|---|---|---|---|
| tarefa | id_tarefa | Identificador da tarefa | INTEGER (identidade) | — | sim | nao | nao permitido | nao | — | Identificacao unica |
| tarefa | id_conversa | Referencia a conversa | INTEGER | — | nao | conversa.id_conversa | permitido | nao | — | — |
| tarefa | id_corretor | Referencia a corretor | INTEGER | — | nao | corretor.id_usuario | nao permitido | nao | — | — |
| tarefa | ds_titulo | Resumo da tarefa | VARCHAR | 120 | nao | nao | nao permitido | nao | — | — |
| tarefa | ds_tarefa | Detalhes | TEXT | — | nao | nao | permitido | nao | — | — |
| tarefa | dt_vencimento | Prazo da tarefa | TIMESTAMP | — | nao | nao | nao permitido | nao | — | A situacao “atrasada” e calculada a partir do prazo e nao e armazenada |
| tarefa | st_tarefa | Situacao | VARCHAR | 15 | nao | nao | nao permitido | nao | 'pendente' | Pendente, concluida ou cancelada · CHECK ck_tarefa_st_tarefa |

## tag

*Entidade TAG (forte)* · 8 linhas na massa de dados.

| Tabela | Atributo | Descricao | Tipo | Tamanho | PK | FK | NULL | UNIQUE | DEFAULT | Regra/Restricao |
|---|---|---|---|---|---|---|---|---|---|---|
| tag | id_tag | Identificador da tag | INTEGER (identidade) | — | sim | nao | nao permitido | nao | — | Identificacao unica |
| tag | nm_tag | Texto da etiqueta | VARCHAR | 40 | nao | nao | nao permitido | sim | — | Nao pode se repetir |

## conversa_tag

*Relacionamento N:N MARCA. Relacionamento N:N MARCA.* · 46 linhas na massa de dados.

| Tabela | Atributo | Descricao | Tipo | Tamanho | PK | FK | NULL | UNIQUE | DEFAULT | Regra/Restricao |
|---|---|---|---|---|---|---|---|---|---|---|
| conversa_tag | id_conversa | Referencia a conversa | INTEGER | — | sim | conversa.id_conversa | nao permitido | nao | — | — |
| conversa_tag | id_tag | Referencia a tag | INTEGER | — | sim | tag.id_tag | nao permitido | nao | — | — |

## visita

*Entidade VISITA (associativa). Entidade associativa VISITA (CLIENTE x IMOVEL).* · 31 linhas na massa de dados.

| Tabela | Atributo | Descricao | Tipo | Tamanho | PK | FK | NULL | UNIQUE | DEFAULT | Regra/Restricao |
|---|---|---|---|---|---|---|---|---|---|---|
| visita | id_visita | Identificador da visita | INTEGER (identidade) | — | sim | nao | nao permitido | nao | — | Identificacao unica |
| visita | id_imovel | Referencia a imovel | INTEGER | — | nao | imovel.id_imovel | nao permitido | com id_cliente, dt_visita | — | — |
| visita | id_cliente | Referencia a cliente | INTEGER | — | nao | cliente.id_usuario | nao permitido | com id_imovel, dt_visita | — | — |
| visita | id_corretor | Referencia a corretor | INTEGER | — | nao | corretor.id_usuario | nao permitido | nao | — | — |
| visita | dt_visita | Data e hora da visita | TIMESTAMP | — | nao | nao | nao permitido | com id_imovel, id_cliente | — | O mesmo cliente nao visita o mesmo imovel duas vezes no mesmo horario (RN16) |
| visita | st_visita | Situacao | VARCHAR | 15 | nao | nao | nao permitido | nao | 'agendada' | Agendada, realizada ou cancelada · CHECK ck_visita_st_visita |
| visita | ds_feedback | Impressao do cliente apos a visita | TEXT | — | nao | nao | permitido | nao | — | Preenchido quando a visita e realizada |

## proposta

*Entidade PROPOSTA (associativa). Entidade associativa PROPOSTA (CLIENTE x IMOVEL). vl_anunciado e o valor congelado no momento da proposta.* · 16 linhas na massa de dados.

| Tabela | Atributo | Descricao | Tipo | Tamanho | PK | FK | NULL | UNIQUE | DEFAULT | Regra/Restricao |
|---|---|---|---|---|---|---|---|---|---|---|
| proposta | id_proposta | Identificador da proposta | INTEGER (identidade) | — | sim | nao | nao permitido | nao | — | Identificacao unica · CHECK ck_proposta_id_proposta_id_proposta_respondida |
| proposta | id_imovel | Referencia a imovel | INTEGER | — | nao | imovel.id_imovel | nao permitido | nao | — | — |
| proposta | id_cliente | Referencia a cliente | INTEGER | — | nao | cliente.id_usuario | nao permitido | nao | — | — |
| proposta | id_corretor | Referencia a corretor | INTEGER | — | nao | corretor.id_usuario | nao permitido | nao | — | — |
| proposta | id_autorizador | Referencia a administrador | INTEGER | — | nao | administrador.id_usuario | permitido | nao | — | CHECK ck_proposta_id_autorizador_vl_proposto |
| proposta | id_proposta_respondida | Referencia a proposta | INTEGER | — | nao | proposta.id_proposta | permitido | sim | — | CHECK ck_proposta_id_proposta_id_proposta_respondida |
| proposta | id_visita | Referencia a visita | INTEGER | — | nao | visita.id_visita | permitido | nao | — | — |
| proposta | vl_proposto | Valor oferecido | NUMERIC | 12,2 | nao | nao | nao permitido | nao | — | Desconto acima de 10% sobre o valor anunciado exige aprovacao (PO03) · CHECK ck_proposta_vl_proposto_vl_anunciado, ck_proposta_id_autorizador_vl_proposto |
| proposta | vl_anunciado | Valor anunciado do imovel no momento da proposta | NUMERIC | 12,2 | nao | nao | nao permitido | nao | — | Base para calcular o desconto (PO03, 17.19) · CHECK ck_proposta_vl_proposto_vl_anunciado, ck_proposta_id_autorizador_vl_proposto |
| proposta | ds_condicoes | Forma de pagamento, prazos e financiamento | TEXT | — | nao | nao | permitido | nao | — | — |
| proposta | st_proposta | Situacao | VARCHAR | 15 | nao | nao | nao permitido | nao | 'pendente' | Pendente, aceita, recusada ou substituida (respondida por contraproposta, RN35) · CHECK ck_proposta_st_proposta |
| proposta | dt_proposta | Data da proposta | TIMESTAMP | — | nao | nao | nao permitido | nao | data e hora atual | — |
| proposta | dt_autorizacao | Data da autorizacao do administrador | TIMESTAMP | — | nao | nao | permitido | nao | — | Obrigatoria quando o desconto passa de 10% (PO03); atributo do relacionamento AUTORIZA · CHECK ck_proposta_id_autorizador_vl_proposto |

## contrato

*Entidade CONTRATO (forte). vl_corretagem = vl_final x pc_corretagem e derivado e nao e armazenado.* · 9 linhas na massa de dados.

| Tabela | Atributo | Descricao | Tipo | Tamanho | PK | FK | NULL | UNIQUE | DEFAULT | Regra/Restricao |
|---|---|---|---|---|---|---|---|---|---|---|
| contrato | id_contrato | Identificador do contrato | INTEGER (identidade) | — | sim | nao | nao permitido | nao | — | Identificacao unica |
| contrato | id_proposta | Referencia a proposta | INTEGER | — | nao | proposta.id_proposta | nao permitido | sim | — | — |
| contrato | tp_contrato | Venda ou locacao | VARCHAR | 10 | nao | nao | nao permitido | nao | — | RN19 · CHECK ck_contrato_tp_contrato, ck_contrato_tp_contrato_pc_administracao |
| contrato | tp_condicao_pagamento | Condicao de pagamento do comprador | VARCHAR | 20 | nao | nao | nao permitido | nao | — | A vista, financiado ou parcelado direto; "financiado" se, e somente se, houver financiamento (RN22). Nao confundir com a forma de cada baixa (FORMA_PAGAMENTO) · CHECK ck_contrato_tp_condicao_pagamento |
| contrato | vl_final | Valor fechado; na locacao, o aluguel mensal | NUMERIC | 12,2 | nao | nao | nao permitido | nao | — | — |
| contrato | pc_corretagem | Percentual de corretagem sobre o valor final | NUMERIC | 5,2 | nao | nao | nao permitido | nao | — | Na locacao, incide sobre o aluguel mensal (taxa de intermediacao); base da conta a receber da corretagem (RF24) · CHECK ck_contrato_pc_corretagem |
| contrato | pc_administracao | Percentual retido do aluguel pela imobiliaria | NUMERIC | 5,2 | nao | nao | permitido | nao | — | Obrigatorio na locacao; define o repasse ao proprietario (RN30) · CHECK ck_contrato_pc_administracao, ck_contrato_tp_contrato_pc_administracao |
| contrato | nr_dia_vencimento | Dia do mes em que vence o aluguel | SMALLINT | — | nao | nao | permitido | nao | — | Obrigatorio na locacao (RF27) · CHECK ck_contrato_tp_contrato_pc_administracao |
| contrato | dt_assinatura | Data da assinatura | DATE | — | nao | nao | permitido | nao | — | Vazia enquanto o contrato e rascunho (RN36) · CHECK ck_contrato_dt_assinatura_st_contrato |
| contrato | dt_inicio | Inicio da vigencia | DATE | — | nao | nao | permitido | nao | — | Obrigatoria na locacao (RN19) · CHECK ck_contrato_tp_contrato_pc_administracao |
| contrato | dt_fim | Data prevista para o termino | DATE | — | nao | nao | permitido | nao | — | Obrigatoria na locacao (RN19); a data em que o contrato realmente terminou e dt_termino · CHECK ck_contrato_tp_contrato_pc_administracao |
| contrato | st_contrato | Situacao | VARCHAR | 12 | nao | nao | nao permitido | nao | 'rascunho' | Rascunho, vigente, encerrado, rescindido ou cancelado; contrato assinado nao e excluido (PO04) · CHECK ck_contrato_st_contrato, ck_contrato_dt_assinatura_st_contrato, ck_contrato_st_contrato_dt_termino, ck_contrato_st_contrato_ds_motivo_termino, ck_contrato_st_contrato_tp_iniciativa_rescisao |
| contrato | dt_termino | Data em que o contrato terminou | DATE | — | nao | nao | permitido | nao | — | Obrigatoria quando encerrado, rescindido ou cancelado (RN37, RN43, RN44) · CHECK ck_contrato_st_contrato_dt_termino |
| contrato | ds_motivo_termino | Motivo do termino | TEXT | — | nao | nao | permitido | nao | — | Obrigatorio na rescisao e no cancelamento (RN37, RN43) · CHECK ck_contrato_st_contrato_ds_motivo_termino |
| contrato | tp_iniciativa_rescisao | Quem pediu a rescisao | VARCHAR | 15 | nao | nao | permitido | nao | — | Cliente, proprietario ou comum acordo; obrigatorio na rescisao (RN43) · CHECK ck_contrato_st_contrato_tp_iniciativa_rescisao, ck_contrato_tp_iniciativa_rescisao |

## documento

*Entidade DOCUMENTO (fraca)* · 24 linhas na massa de dados.

| Tabela | Atributo | Descricao | Tipo | Tamanho | PK | FK | NULL | UNIQUE | DEFAULT | Regra/Restricao |
|---|---|---|---|---|---|---|---|---|---|---|
| documento | id_contrato | Referencia a contrato | INTEGER | — | sim | contrato.id_contrato | nao permitido | nao | — | — |
| documento | nr_documento | Numero do documento dentro do contrato | SMALLINT | — | sim | nao | nao permitido | nao | — | Identificador parcial |
| documento | id_tipo_documento | Tipo do documento (referencia a tipo_documento) | INTEGER | — | nao | tipo_documento.id_tipo_documento | nao permitido | nao | — | — |
| documento | ds_url | Endereco do arquivo | VARCHAR | 500 | nao | nao | nao permitido | nao | — | — |

## tipo_documento

*Entidade TIPO_DOCUMENTO (forte). Dominio: tipos de documento do contrato (antes o nome era digitado em cada documento) (RN53).* · 6 linhas na massa de dados.

| Tabela | Atributo | Descricao | Tipo | Tamanho | PK | FK | NULL | UNIQUE | DEFAULT | Regra/Restricao |
|---|---|---|---|---|---|---|---|---|---|---|
| tipo_documento | id_tipo_documento | Identificador do tipo de documento | INTEGER (identidade) | — | sim | nao | nao permitido | nao | — | Identificacao unica |
| tipo_documento | nm_tipo_documento | Nome do tipo (contrato assinado, documento do cliente, matricula do imovel, laudo de vistoria...) | VARCHAR | 60 | nao | nao | nao permitido | sim | — | Nao pode se repetir (RN53) |

## comissao

*Entidade COMISSAO (associativa). Entidade associativa COMISSAO (RECEBE). vl_comissao e derivado e nao e armazenado.* · 10 linhas na massa de dados.

| Tabela | Atributo | Descricao | Tipo | Tamanho | PK | FK | NULL | UNIQUE | DEFAULT | Regra/Restricao |
|---|---|---|---|---|---|---|---|---|---|---|
| comissao | id_contrato | Referencia a contrato | INTEGER | — | sim | contrato.id_contrato | nao permitido | nao | — | — |
| comissao | id_corretor | Referencia a corretor | INTEGER | — | sim | corretor.id_usuario | nao permitido | nao | — | — |
| comissao | pc_comissao | Percentual do corretor sobre a corretagem do contrato | NUMERIC | 5,2 | nao | nao | nao permitido | nao | — | A soma no contrato nao passa de 100% (RN20) · CHECK ck_comissao_pc_comissao |
| comissao | tp_regra_pagamento | Quando a comissao pode ser paga | VARCHAR | 20 | nao | nao | nao permitido | nao | — | Na assinatura, na liberacao do credito ou no recebimento (RN24) · CHECK ck_comissao_tp_regra_pagamento |
| comissao | st_comissao | Situacao | VARCHAR | 10 | nao | nao | nao permitido | nao | 'pendente' | Pendente, liberada ou cancelada; “paga” nao e armazenada, pois deriva da conta a pagar ligada por LANCA (17.20) · CHECK ck_comissao_st_comissao |
| comissao | id_aprovador | Referencia a administrador | INTEGER | — | nao | administrador.id_usuario | permitido | nao | — | CHECK ck_comissao_id_aprovador_dt_aprovacao |
| comissao | dt_aprovacao | Data da aprovacao do administrador | TIMESTAMP | — | nao | nao | permitido | nao | — | Obrigatoria antes do pagamento (PO01); atributo do relacionamento APROVA · CHECK ck_comissao_id_aprovador_dt_aprovacao |
| comissao | id_conta_pagar | Referencia a conta_pagar | INTEGER | — | nao | conta_pagar.id_conta_pagar | permitido | sim | — | — |

## financiamento

*Entidade FINANCIAMENTO (fraca). Identificado pelo proprio contrato (1:1).* · 2 linhas na massa de dados.

| Tabela | Atributo | Descricao | Tipo | Tamanho | PK | FK | NULL | UNIQUE | DEFAULT | Regra/Restricao |
|---|---|---|---|---|---|---|---|---|---|---|
| financiamento | id_contrato | Referencia a contrato | INTEGER | — | sim | contrato.id_contrato | nao permitido | nao | — | — |
| financiamento | id_instituicao | Referencia a instituicao_financeira | INTEGER | — | nao | instituicao_financeira.id_usuario | nao permitido | nao | — | — |
| financiamento | vl_financiado | Valor financiado | NUMERIC | 12,2 | nao | nao | nao permitido | nao | — | — |
| financiamento | vl_entrada | Valor de entrada | NUMERIC | 12,2 | nao | nao | permitido | nao | — | — |
| financiamento | nr_parcelas | Quantidade de parcelas | SMALLINT | — | nao | nao | permitido | nao | — | — |
| financiamento | pc_juros_aa | Taxa de juros ao ano | NUMERIC | 5,2 | nao | nao | permitido | nao | — | — |
| financiamento | st_financiamento | Situacao | VARCHAR | 15 | nao | nao | nao permitido | nao | 'em_analise' | Em analise, aprovado, reprovado, liberado ou cancelado · CHECK ck_financiamento_st_financiamento, ck_financiamento_st_financiamento_dt_liberacao |
| financiamento | dt_aprovacao | Data da aprovacao do credito | DATE | — | nao | nao | permitido | nao | — | — |
| financiamento | dt_liberacao | Data em que o banco libera o credito | DATE | — | nao | nao | permitido | nao | — | Condiciona o recebimento da corretagem (RN23) · CHECK ck_financiamento_st_financiamento_dt_liberacao |

## categoria_financeira

*Entidade CATEGORIA_FINANCEIRA (forte). Plano de contas: a categoria define a natureza do lancamento; as regras a encontram pelo codigo (RN26).* · 10 linhas na massa de dados.

| Tabela | Atributo | Descricao | Tipo | Tamanho | PK | FK | NULL | UNIQUE | DEFAULT | Regra/Restricao |
|---|---|---|---|---|---|---|---|---|---|---|
| categoria_financeira | id_categoria | Identificador da categoria | INTEGER (identidade) | — | sim | nao | nao permitido | nao | — | Identificacao unica |
| categoria_financeira | cd_categoria | Codigo fixo da categoria (aluguel, repasse, comissao...) | VARCHAR | 30 | nao | nao | nao permitido | sim | — | Nao pode se repetir e nao muda; e por ele que os gatilhos encontram a categoria (RN26) · CHECK ck_categoria_financeira_cd_categoria |
| categoria_financeira | nm_categoria | Nome da categoria | VARCHAR | 60 | nao | nao | nao permitido | sim | — | Nao pode se repetir; pode ser renomeado sem afetar as regras |
| categoria_financeira | tp_categoria | Receita ou despesa | VARCHAR | 10 | nao | nao | nao permitido | nao | — | Receita para conta a receber, despesa para conta a pagar (RN26); nao muda enquanto houver conta na categoria · CHECK ck_categoria_financeira_tp_categoria |

## conta_bancaria

*Entidade CONTA_BANCARIA (forte)* · 3 linhas na massa de dados.

| Tabela | Atributo | Descricao | Tipo | Tamanho | PK | FK | NULL | UNIQUE | DEFAULT | Regra/Restricao |
|---|---|---|---|---|---|---|---|---|---|---|
| conta_bancaria | id_conta | Identificador da conta | INTEGER (identidade) | — | sim | nao | nao permitido | nao | — | Identificacao unica |
| conta_bancaria | nm_apelido | Nome de referencia da conta | VARCHAR | 60 | nao | nao | nao permitido | sim | — | Nao pode se repetir |
| conta_bancaria | nm_instituicao | Banco | VARCHAR | 100 | nao | nao | permitido | nao | — | — |
| conta_bancaria | tp_conta_bancaria | Tipo | VARCHAR | 15 | nao | nao | nao permitido | nao | — | Corrente, poupanca ou caixa · CHECK ck_conta_bancaria_tp_conta_bancaria |
| conta_bancaria | fl_ativa | Indica se a conta esta em uso | BOOLEAN | — | nao | nao | nao permitido | nao | verdadeiro | — |

## movimento_bancario

*Entidade MOVIMENTO_BANCARIO (fraca). Entidade fraca da conta bancaria: o extrato importado (RN45, RN46). st_conciliacao e derivado e nao e armazenado.* · 84 linhas na massa de dados.

| Tabela | Atributo | Descricao | Tipo | Tamanho | PK | FK | NULL | UNIQUE | DEFAULT | Regra/Restricao |
|---|---|---|---|---|---|---|---|---|---|---|
| movimento_bancario | id_conta | Referencia a conta_bancaria | INTEGER | — | sim | conta_bancaria.id_conta | nao permitido | com cd_transacao_banco | — | — |
| movimento_bancario | nr_movimento | Numero do movimento dentro da conta | INTEGER | — | sim | nao | nao permitido | nao | — | Identificador parcial |
| movimento_bancario | cd_transacao_banco | Codigo da transacao informado pelo banco | VARCHAR | 60 | nao | nao | nao permitido | com id_conta | — | Nao se repete na mesma conta: o mesmo extrato nao e importado duas vezes (RN46) |
| movimento_bancario | dt_movimento | Data do lancamento no banco | DATE | — | nao | nao | nao permitido | nao | — | — |
| movimento_bancario | vl_movimento | Valor do lancamento | NUMERIC | 12,2 | nao | nao | nao permitido | nao | — | Maior que zero · CHECK ck_movimento_bancario_vl_movimento |
| movimento_bancario | tp_movimento | Credito ou debito | VARCHAR | 10 | nao | nao | nao permitido | nao | — | Credito comprova recebimentos; debito comprova pagamentos (RN45) · CHECK ck_movimento_bancario_tp_movimento |
| movimento_bancario | ds_historico | Historico do lancamento no extrato | VARCHAR | 200 | nao | nao | permitido | nao | — | — |
| movimento_bancario | dt_importacao | Data e hora da importacao | TIMESTAMP | — | nao | nao | nao permitido | nao | data e hora atual | Preenchida automaticamente |

## conta_receber

*Entidade CONTA_RECEBER (forte). st_conta e derivada das baixas e do vencimento e nao e armazenada (RN38).* · 45 linhas na massa de dados.

| Tabela | Atributo | Descricao | Tipo | Tamanho | PK | FK | NULL | UNIQUE | DEFAULT | Regra/Restricao |
|---|---|---|---|---|---|---|---|---|---|---|
| conta_receber | id_conta_receber | Identificador da conta a receber | INTEGER (identidade) | — | sim | nao | nao permitido | nao | — | Identificacao unica |
| conta_receber | id_contrato | Referencia a contrato | INTEGER | — | nao | contrato.id_contrato | permitido | nao | — | — |
| conta_receber | id_categoria | Referencia a categoria_financeira | INTEGER | — | nao | categoria_financeira.id_categoria | nao permitido | nao | — | — |
| conta_receber | id_pagador | Referencia a usuario | INTEGER | — | nao | usuario.id_usuario | nao permitido | nao | — | — |
| conta_receber | tp_papel_pagador | Papel exercido por quem paga | VARCHAR | 25 | nao | nao | nao permitido | nao | — | Cliente, inquilino, proprietario ou instituicao financeira; o pagador precisa exercer esse papel (RN27, RN32) · CHECK ck_conta_receber_tp_papel_pagador |
| conta_receber | ds_conta | Descricao | VARCHAR | 200 | nao | nao | permitido | nao | — | — |
| conta_receber | dt_competencia | Mes de referencia | DATE | — | nao | nao | permitido | nao | — | Obrigatorio na locacao |
| conta_receber | vl_receber | Valor a receber | NUMERIC | 12,2 | nao | nao | nao permitido | nao | — | CHECK ck_conta_receber_vl_receber |
| conta_receber | dt_vencimento | Data de vencimento | DATE | — | nao | nao | nao permitido | nao | — | — |
| conta_receber | fl_cancelada | Indica conta cancelada | BOOLEAN | — | nao | nao | nao permitido | nao | falso | Unico estado armazenado (RN37, RN38) |

## recebimento

*Entidade RECEBIMENTO (fraca)* · 42 linhas na massa de dados.

| Tabela | Atributo | Descricao | Tipo | Tamanho | PK | FK | NULL | UNIQUE | DEFAULT | Regra/Restricao |
|---|---|---|---|---|---|---|---|---|---|---|
| recebimento | id_conta_receber | Referencia a conta_receber | INTEGER | — | sim | conta_receber.id_conta_receber | nao permitido | nao | — | — |
| recebimento | nr_recebimento | Numero do recebimento dentro da conta | SMALLINT | — | sim | nao | nao permitido | nao | — | Identificador parcial |
| recebimento | id_conta | Referencia a conta_bancaria e a movimento_bancario | INTEGER | — | nao | conta_bancaria.id_conta, movimento_bancario.id_conta | nao permitido | nao | — | — |
| recebimento | dt_recebimento | Data do recebimento | DATE | — | nao | nao | nao permitido | nao | — | — |
| recebimento | vl_recebido | Valor recebido | NUMERIC | 12,2 | nao | nao | nao permitido | nao | — | A soma nao passa do valor da conta (RN29) · CHECK ck_recebimento_vl_recebido |
| recebimento | id_forma_pagamento | Referencia a forma_pagamento | INTEGER | — | nao | forma_pagamento.id_forma_pagamento | nao permitido | nao | — | — |
| recebimento | nr_movimento | Referencia a movimento_bancario | INTEGER | — | nao | movimento_bancario.nr_movimento | permitido | nao | — | CHECK ck_recebimento_nr_movimento_dt_conciliacao |
| recebimento | dt_conciliacao | Data em que a baixa foi conferida com o extrato | DATE | — | nao | nao | permitido | nao | — | Preenchida quando a baixa e ligada a um movimento do extrato (RN45) · CHECK ck_recebimento_nr_movimento_dt_conciliacao |

## conta_pagar

*Entidade CONTA_PAGAR (forte). st_conta e derivada e nao e armazenada (RN38). No repasse, vl_pagar e dt_vencimento sao calculados na geracao e ficam congelados.* · 49 linhas na massa de dados.

| Tabela | Atributo | Descricao | Tipo | Tamanho | PK | FK | NULL | UNIQUE | DEFAULT | Regra/Restricao |
|---|---|---|---|---|---|---|---|---|---|---|
| conta_pagar | id_conta_pagar | Identificador da conta a pagar | INTEGER (identidade) | — | sim | nao | nao permitido | nao | — | Identificacao unica |
| conta_pagar | id_contrato | Referencia a contrato | INTEGER | — | nao | contrato.id_contrato | permitido | nao | — | — |
| conta_pagar | id_categoria | Referencia a categoria_financeira | INTEGER | — | nao | categoria_financeira.id_categoria | nao permitido | nao | — | — |
| conta_pagar | id_favorecido | Referencia a usuario | INTEGER | — | nao | usuario.id_usuario | permitido | nao | — | — |
| conta_pagar | id_custeador | Referencia a usuario | INTEGER | — | nao | usuario.id_usuario | permitido | nao | — | CHECK ck_conta_pagar_id_custeador_tp_papel_custeio |
| conta_pagar | id_conta_receber_origem | Referencia a recebimento | INTEGER | — | nao | recebimento.id_conta_receber | permitido | com nr_recebimento_origem | — | CHECK ck_conta_pagar_id_conta_receber_origem_nr_recebimento_origem |
| conta_pagar | nr_recebimento_origem | Referencia a recebimento | SMALLINT | — | nao | recebimento.nr_recebimento | permitido | com id_conta_receber_origem | — | CHECK ck_conta_pagar_id_conta_receber_origem_nr_recebimento_origem |
| conta_pagar | tp_papel_custeio | Papel de quem arca com o custo final | VARCHAR | 15 | nao | nao | nao permitido | nao | — | Imobiliaria, proprietario ou inquilino; quem arca precisa exercer esse papel (RN28, RN32) · CHECK ck_conta_pagar_tp_papel_custeio, ck_conta_pagar_id_custeador_tp_papel_custeio |
| conta_pagar | ds_conta | Descricao | VARCHAR | 200 | nao | nao | permitido | nao | — | — |
| conta_pagar | dt_competencia | Mes de referencia | DATE | — | nao | nao | permitido | nao | — | Obrigatorio no repasse de aluguel |
| conta_pagar | vl_pagar | Valor a pagar | NUMERIC | 12,2 | nao | nao | nao permitido | nao | — | CHECK ck_conta_pagar_vl_pagar |
| conta_pagar | dt_vencimento | Data de vencimento | DATE | — | nao | nao | nao permitido | nao | — | No repasse, ate 5 dias uteis apos o recebimento que o originou (PO05, RN30) |
| conta_pagar | fl_cancelada | Indica conta cancelada | BOOLEAN | — | nao | nao | nao permitido | nao | falso | Unico estado armazenado (RN37, RN38) |

## pagamento

*Entidade PAGAMENTO (fraca)* · 45 linhas na massa de dados.

| Tabela | Atributo | Descricao | Tipo | Tamanho | PK | FK | NULL | UNIQUE | DEFAULT | Regra/Restricao |
|---|---|---|---|---|---|---|---|---|---|---|
| pagamento | id_conta_pagar | Referencia a conta_pagar | INTEGER | — | sim | conta_pagar.id_conta_pagar | nao permitido | nao | — | — |
| pagamento | nr_pagamento | Numero do pagamento dentro da conta | SMALLINT | — | sim | nao | nao permitido | nao | — | Identificador parcial |
| pagamento | id_conta | Referencia a conta_bancaria e a movimento_bancario | INTEGER | — | nao | conta_bancaria.id_conta, movimento_bancario.id_conta | nao permitido | nao | — | — |
| pagamento | id_usuario | Referencia a usuario | INTEGER | — | nao | usuario.id_usuario | nao permitido | nao | — | — |
| pagamento | dt_pagamento | Data do pagamento | DATE | — | nao | nao | nao permitido | nao | — | — |
| pagamento | vl_pago | Valor pago | NUMERIC | 12,2 | nao | nao | nao permitido | nao | — | A soma nao passa do valor da conta (RN29) · CHECK ck_pagamento_vl_pago |
| pagamento | id_forma_pagamento | Referencia a forma_pagamento | INTEGER | — | nao | forma_pagamento.id_forma_pagamento | nao permitido | nao | — | — |
| pagamento | nr_movimento | Referencia a movimento_bancario | INTEGER | — | nao | movimento_bancario.nr_movimento | permitido | nao | — | CHECK ck_pagamento_nr_movimento_dt_conciliacao |
| pagamento | dt_conciliacao | Data em que a baixa foi conferida com o extrato | DATE | — | nao | nao | permitido | nao | — | Preenchida quando a baixa e ligada a um movimento do extrato (RN45) · CHECK ck_pagamento_nr_movimento_dt_conciliacao |

## forma_pagamento

*Entidade FORMA_PAGAMENTO (forte). Dominio: meios de pagamento das baixas, o mesmo para recebimento e pagamento (antes um CHECK repetido nas duas tabelas) (RN50).* · 5 linhas na massa de dados.

| Tabela | Atributo | Descricao | Tipo | Tamanho | PK | FK | NULL | UNIQUE | DEFAULT | Regra/Restricao |
|---|---|---|---|---|---|---|---|---|---|---|
| forma_pagamento | id_forma_pagamento | Identificador da forma de pagamento | INTEGER (identidade) | — | sim | nao | nao permitido | nao | — | Identificacao unica |
| forma_pagamento | nm_forma_pagamento | Meio usado na baixa (Pix, TED, boleto, dinheiro, cartao...) | VARCHAR | 40 | nao | nao | nao permitido | sim | — | Nao pode se repetir (RN50) |

## automacao_execucao

*Entidade AUTOMACAO_EXECUCAO (fraca)* · 34 linhas na massa de dados.

| Tabela | Atributo | Descricao | Tipo | Tamanho | PK | FK | NULL | UNIQUE | DEFAULT | Regra/Restricao |
|---|---|---|---|---|---|---|---|---|---|---|
| automacao_execucao | id_conversa | Referencia a conversa | INTEGER | — | sim | conversa.id_conversa | nao permitido | com cd_demanda | — | — |
| automacao_execucao | nr_execucao | Numero da execucao dentro da conversa | INTEGER | — | sim | nao | nao permitido | nao | — | Identificador parcial |
| automacao_execucao | cd_demanda | Resumo que identifica a demanda | VARCHAR | 64 | nao | nao | nao permitido | com id_conversa | — | Nao se repete na mesma conversa (RN31) |
| automacao_execucao | st_execucao | Situacao da execucao | VARCHAR | 15 | nao | nao | nao permitido | nao | 'recebida' | CHECK ck_automacao_execucao_st_execucao |
| automacao_execucao | ds_demanda | O que o cliente pediu, extraido da mensagem | TEXT | — | nao | nao | permitido | nao | — | — |
| automacao_execucao | ds_criterios | Criterios usados para escolher os imoveis | TEXT | — | nao | nao | permitido | nao | — | — |
| automacao_execucao | ds_conteudo_enviado | Conteudo enviado ao cliente | TEXT | — | nao | nao | permitido | nao | — | — |
| automacao_execucao | ds_resumo | Resumo da execucao | TEXT | — | nao | nao | permitido | nao | — | — |
| automacao_execucao | ds_erro | Erro ocorrido | TEXT | — | nao | nao | permitido | nao | — | Preenchido apenas quando ha erro |
| automacao_execucao | dt_execucao | Data e hora da execucao | TIMESTAMP | — | nao | nao | nao permitido | nao | data e hora atual | — |
| automacao_execucao | dt_envio | Data e hora do envio ao cliente | TIMESTAMP | — | nao | nao | permitido | nao | — | Preenchida quando ha envio |

## automacao_log

*Entidade AUTOMACAO_LOG (fraca)* · 128 linhas na massa de dados.

| Tabela | Atributo | Descricao | Tipo | Tamanho | PK | FK | NULL | UNIQUE | DEFAULT | Regra/Restricao |
|---|---|---|---|---|---|---|---|---|---|---|
| automacao_log | id_conversa | Referencia a automacao_execucao | INTEGER | — | sim | automacao_execucao.id_conversa | nao permitido | nao | — | — |
| automacao_log | nr_execucao | Referencia a automacao_execucao | INTEGER | — | sim | automacao_execucao.nr_execucao | nao permitido | nao | — | — |
| automacao_log | nr_log | Numero do evento dentro da execucao | INTEGER | — | sim | nao | nao permitido | nao | — | Identificador parcial |
| automacao_log | nm_evento | Nome do evento | VARCHAR | 60 | nao | nao | nao permitido | nao | — | — |
| automacao_log | ds_evento | Descricao do evento | TEXT | — | nao | nao | permitido | nao | — | — |
| automacao_log | ds_dados | Dados tecnicos do evento | TEXT | — | nao | nao | permitido | nao | — | — |
| automacao_log | dt_log | Data e hora do evento | TIMESTAMP | — | nao | nao | nao permitido | nao | data e hora atual | — |

## auditoria

*Entidade AUDITORIA (forte). Arco exclusivo: exatamente uma das sete referencias e preenchida (RN40).* · 312 linhas na massa de dados.

| Tabela | Atributo | Descricao | Tipo | Tamanho | PK | FK | NULL | UNIQUE | DEFAULT | Regra/Restricao |
|---|---|---|---|---|---|---|---|---|---|---|
| auditoria | id_auditoria | Identificador do registro de auditoria | INTEGER (identidade) | — | sim | nao | nao permitido | nao | — | Identificacao unica |
| auditoria | id_usuario | Referencia a usuario | INTEGER | — | nao | usuario.id_usuario | nao permitido | nao | — | — |
| auditoria | tp_acao | Acao praticada | VARCHAR | 15 | nao | nao | nao permitido | nao | — | Criacao, alteracao ou cancelamento (RN40) · CHECK ck_auditoria_tp_acao |
| auditoria | dt_acao | Data e hora da acao | TIMESTAMP | — | nao | nao | nao permitido | nao | data e hora atual | Preenchida automaticamente; o registro nunca e alterado (RNF04) |
| auditoria | id_contrato | Referencia a contrato | INTEGER | — | nao | contrato.id_contrato | permitido | nao | — | CHECK ck_auditoria_arco_exclusivo |
| auditoria | id_proposta | Referencia a proposta | INTEGER | — | nao | proposta.id_proposta | permitido | nao | — | CHECK ck_auditoria_arco_exclusivo |
| auditoria | id_comissao_contrato | Referencia a comissao | INTEGER | — | nao | comissao.id_contrato | permitido | nao | — | CHECK ck_auditoria_arco_exclusivo, ck_auditoria_id_comissao_contrato_id_comissao_corretor |
| auditoria | id_comissao_corretor | Referencia a comissao | INTEGER | — | nao | comissao.id_corretor | permitido | nao | — | CHECK ck_auditoria_id_comissao_contrato_id_comissao_corretor |
| auditoria | id_conta_receber | Referencia a conta_receber | INTEGER | — | nao | conta_receber.id_conta_receber | permitido | nao | — | CHECK ck_auditoria_arco_exclusivo |
| auditoria | id_recebimento_conta | Referencia a recebimento | INTEGER | — | nao | recebimento.id_conta_receber | permitido | nao | — | CHECK ck_auditoria_arco_exclusivo, ck_auditoria_id_recebimento_conta_nr_recebimento |
| auditoria | nr_recebimento | Referencia a recebimento | SMALLINT | — | nao | recebimento.nr_recebimento | permitido | nao | — | CHECK ck_auditoria_id_recebimento_conta_nr_recebimento |
| auditoria | id_conta_pagar | Referencia a conta_pagar | INTEGER | — | nao | conta_pagar.id_conta_pagar | permitido | nao | — | CHECK ck_auditoria_arco_exclusivo |
| auditoria | id_pagamento_conta | Referencia a pagamento | INTEGER | — | nao | pagamento.id_conta_pagar | permitido | nao | — | CHECK ck_auditoria_arco_exclusivo, ck_auditoria_id_pagamento_conta_nr_pagamento |
| auditoria | nr_pagamento | Referencia a pagamento | SMALLINT | — | nao | pagamento.nr_pagamento | permitido | nao | — | CHECK ck_auditoria_id_pagamento_conta_nr_pagamento |

## auditoria_campo

*Entidade AUDITORIA_CAMPO (fraca). 1FN: um registro por campo alterado.* · 208 linhas na massa de dados.

| Tabela | Atributo | Descricao | Tipo | Tamanho | PK | FK | NULL | UNIQUE | DEFAULT | Regra/Restricao |
|---|---|---|---|---|---|---|---|---|---|---|
| auditoria_campo | id_auditoria | Referencia a auditoria | INTEGER | — | sim | auditoria.id_auditoria | nao permitido | nao | — | — |
| auditoria_campo | nm_campo | Nome do campo alterado | VARCHAR | 60 | sim | nao | nao permitido | nao | — | Identificador parcial dentro do registro de auditoria |
| auditoria_campo | ds_valor_anterior | Valor do campo antes da acao | TEXT | — | nao | nao | permitido | nao | — | Vazio na criacao |
| auditoria_campo | ds_valor_novo | Valor do campo depois da acao | TEXT | — | nao | nao | permitido | nao | — | Vazio quando o valor e apagado |

# CRMoveis — Dicionário de dados lógico

Modelo lógico normalizado até a 3FN. Cada tabela indica a origem no modelo conceitual (seção 15 do README), as colunas com tipo, chave e obrigatoriedade, e as restrições de integridade.

**Legenda.** PK = chave primária · FK = chave estrangeira · UK = valor único · Nulo: *Não* = obrigatória (NOT NULL), *Sim* = aceita nulo.

**Totais.** 34 tabelas · 224 colunas · 57 chaves estrangeiras (a de automacao_log é composta por duas colunas).

## Índice

[usuario](#usuario) · [usuario_papel](#usuario_papel) · [telefone](#telefone) · [cidade](#cidade) · [cep](#cep) · [perfil_interesse](#perfil_interesse) · [imovel](#imovel) · [foto](#foto) · [caracteristica](#caracteristica) · [imovel_caracteristica](#imovel_caracteristica) · [funil_estagio](#funil_estagio) · [conversa](#conversa) · [conversa_imovel](#conversa_imovel) · [mensagem](#mensagem) · [historico_estagio](#historico_estagio) · [tarefa](#tarefa) · [tag](#tag) · [conversa_tag](#conversa_tag) · [visita](#visita) · [proposta](#proposta) · [contrato](#contrato) · [documento](#documento) · [comissao](#comissao) · [financiamento](#financiamento) · [categoria_financeira](#categoria_financeira) · [conta_bancaria](#conta_bancaria) · [conta_receber](#conta_receber) · [recebimento](#recebimento) · [conta_pagar](#conta_pagar) · [pagamento](#pagamento) · [automacao_execucao](#automacao_execucao) · [automacao_log](#automacao_log) · [auditoria](#auditoria) · [auditoria_campo](#auditoria_campo)

## usuario

*Origem: Entidade USUARIO (forte).*

| Coluna | Tipo | Chave | Nulo | Referência | Descrição | Regra / observação |
|---|---|---|---|---|---|---|
| id_usuario | INTEGER | PK | Não | — | Identificador do usuário | Identificação única |
| nm_usuario | VARCHAR(150) | — | Não | — | Nome completo ou razão social | — |
| nr_cpf_cnpj | VARCHAR(14) | UK | Sim | — | CPF ou CNPJ | Não pode se repetir; obrigatório para proprietário, instituição financeira e quem assina contrato (RN04); apagado na anonimização (PO07) |
| ds_email | VARCHAR(150) | UK | Sim | — | E-mail de contato e de acesso | Não pode se repetir; obrigatório para quem acessa o sistema |
| ds_senha_hash | VARCHAR(255) | — | Sim | — | Senha de acesso, guardada como hash | Só para quem acessa o sistema; nunca em texto (RNF02) |
| nr_creci | VARCHAR(20) | — | Sim | — | Registro do corretor no CRECI | Obrigatório para quem tem o papel corretor |
| tp_origem | VARCHAR(20) | — | Sim | — | Canal pelo qual a pessoa chegou | Site, indicação, portal, Instagram, WhatsApp ou interno |
| fl_ativo | BOOLEAN | — | Não | — | Indica se o cadastro está ativo | Cadastro inativo não acessa o sistema |
| dt_cadastro | TIMESTAMP | — | Não | — | Data do cadastro | Preenchida automaticamente |
| dt_anonimizacao | TIMESTAMP | — | Sim | — | Data em que os dados pessoais foram anonimizados | Preenchida quando o titular pede a exclusão e há obrigação de guarda (PO07) |

**Restrições:** tp_origem IN ('site','indicacao','portal','instagram','whatsapp','interno')

## usuario_papel

*Origem: Atributo multivalorado USUARIO.tp_papel.* 1FN: o atributo multivalorado tp_papel virou tabela própria, uma linha por papel.

| Coluna | Tipo | Chave | Nulo | Referência | Descrição | Regra / observação |
|---|---|---|---|---|---|---|
| id_usuario | INTEGER | PK FK | Não | usuario.id_usuario (multivalorado tp_papel) | Referência a usuario | — |
| tp_papel | VARCHAR(25) | PK | Não | — | Papel exercido pelo usuário (uma linha por papel) | — |

**Restrições:** Chave primária composta (id_usuario, tp_papel) · tp_papel IN ('cliente','proprietario','inquilino','corretor','financeiro','fornecedor','administrador','instituicao_financeira')

## telefone

*Origem: Entidade TELEFONE (forte).*

| Coluna | Tipo | Chave | Nulo | Referência | Descrição | Regra / observação |
|---|---|---|---|---|---|---|
| id_telefone | INTEGER | PK | Não | — | Identificador do telefone | Identificação única |
| id_usuario | INTEGER | FK | Não | usuario.id_usuario (POSSUI) | Referência a usuario | — |
| nr_telefone | VARCHAR(20) | — | Não | — | Número com DDD | Quando o tipo é WhatsApp, não pode se repetir no sistema (RN03) |
| tp_telefone | VARCHAR(10) | — | Não | — | Tipo da linha | Celular, WhatsApp ou fixo |
| fl_principal | BOOLEAN | — | Não | — | Indica o telefone preferencial | Apenas um principal por usuário |

**Restrições:** tp_telefone IN ('celular','whatsapp','fixo') · nr_telefone único quando tp_telefone = 'whatsapp' (índice único parcial, RN03)

## cidade

*Origem: Entidade CIDADE (forte).* 3FN: cidade e UF saíram do imóvel e do perfil (dependiam do CEP, não da chave).

| Coluna | Tipo | Chave | Nulo | Referência | Descrição | Regra / observação |
|---|---|---|---|---|---|---|
| id_cidade | INTEGER | PK | Não | — | Identificador da cidade | Identificação única |
| nm_cidade | VARCHAR(100) | — | Não | — | Nome da cidade | Junto com a UF, não pode se repetir |
| sg_uf | CHAR(2) | — | Não | — | Sigla do estado | Duas letras (ex.: SP) |

**Restrições:** UNIQUE (nm_cidade, sg_uf)

## cep

*Origem: Entidade CEP (forte).* 3FN: CEP → cidade e UF; o imóvel guarda só o CEP.

| Coluna | Tipo | Chave | Nulo | Referência | Descrição | Regra / observação |
|---|---|---|---|---|---|---|
| nr_cep | CHAR(8) | PK | Não | — | CEP com 8 dígitos | Identificação única; determina a cidade (RN41) |
| id_cidade | INTEGER | FK | Não | cidade.id_cidade (AGRUPA) | Referência a cidade | — |
| tp_cep | VARCHAR(15) | — | Não | — | Abrangência do CEP | Geral (a cidade inteira) ou de logradouro; como um CEP geral não indica rua nem bairro, esses dados continuam no imóvel |

**Restrições:** tp_cep IN ('logradouro','geral','especial')

## perfil_interesse

*Origem: Entidade PERFIL_INTERESSE (fraca).*

| Coluna | Tipo | Chave | Nulo | Referência | Descrição | Regra / observação |
|---|---|---|---|---|---|---|
| id_usuario | INTEGER | PK FK | Não | usuario.id_usuario (BUSCA) | Referência a usuario | — |
| nr_perfil | SMALLINT | PK | Não | — | Número do perfil dentro do usuário | Identificador parcial |
| id_cidade | INTEGER | FK | Sim | cidade.id_cidade (PREFERE) | Referência a cidade | — |
| tp_finalidade | VARCHAR(10) | — | Não | — | Venda ou locação | Mesmo vocabulário de IMOVEL |
| tp_imovel | VARCHAR(20) | — | Sim | — | Tipo de imóvel procurado | Ex.: apartamento, casa, comercial |
| nm_bairro | VARCHAR(100) | — | Sim | — | Bairro desejado | Pode ficar em branco |
| vl_minimo | NUMERIC(12,2) | — | Sim | — | Valor mínimo aceito | Não pode ser maior que o valor máximo |
| vl_maximo | NUMERIC(12,2) | — | Sim | — | Valor máximo aceito | Maior ou igual ao mínimo |
| qt_quartos_min | SMALLINT | — | Sim | — | Quantidade mínima de quartos | — |

**Restrições:** Chave primária composta (id_usuario, nr_perfil) · tp_finalidade IN ('venda','locacao') · vl_minimo <= vl_maximo

## imovel

*Origem: Entidade IMOVEL (forte).* 1FN: o endereço composto virou colunas atômicas. 3FN: cidade e UF não ficam aqui; vêm de nr_cep → cep → cidade.

| Coluna | Tipo | Chave | Nulo | Referência | Descrição | Regra / observação |
|---|---|---|---|---|---|---|
| id_imovel | INTEGER | PK | Não | — | Identificador do imóvel | Identificação única |
| cd_imobizi | VARCHAR(30) | UK | Sim | — | Código do imóvel no IMOBIZI | Não pode se repetir; obrigatório nos imóveis importados (RF14) |
| id_proprietario | INTEGER | FK | Não | usuario.id_usuario (ANUNCIA) | Referência a usuario | — |
| id_corretor_responsavel | INTEGER | FK | Sim | usuario.id_usuario (RESPONSAVEL) | Referência a usuario | — |
| nr_cep | CHAR(8) | FK | Não | cep.nr_cep (LOCALIZA) | Referência a cep | — |
| tp_imovel | VARCHAR(20) | — | Não | — | Tipo do imóvel | Apartamento, casa, terreno, comercial ou rural |
| tp_finalidade | VARCHAR(15) | — | Não | — | Venda, locação ou ambas | Define quais valores são obrigatórios (17.24) |
| nm_logradouro | VARCHAR(150) | — | Não | — | Logradouro (rua, avenida etc.) | — |
| nr_endereco | VARCHAR(10) | — | Não | — | Número do endereço | — |
| ds_complemento | VARCHAR(60) | — | Sim | — | Complemento (apartamento, bloco, sala) | — |
| nm_bairro | VARCHAR(100) | — | Não | — | Bairro | — |
| vl_area_util | NUMERIC(10,2) | — | Sim | — | Área útil em m² | — |
| vl_area_total | NUMERIC(10,2) | — | Sim | — | Área total em m² | Maior ou igual à área útil |
| qt_quartos | SMALLINT | — | Sim | — | Quantidade de quartos | — |
| qt_banheiros | SMALLINT | — | Sim | — | Quantidade de banheiros | — |
| qt_vagas_garagem | SMALLINT | — | Sim | — | Quantidade de vagas de garagem | — |
| vl_venda | NUMERIC(12,2) | — | Sim | — | Preço de venda | Obrigatório quando a finalidade é venda ou ambas |
| vl_aluguel | NUMERIC(12,2) | — | Sim | — | Aluguel mensal pedido | Obrigatório quando a finalidade é locação ou ambas |
| st_imovel | VARCHAR(15) | — | Não | — | Situação do imóvel | Disponível, reservado, vendido, alugado ou inativo; vendido, alugado ou inativo não recebe visita nem proposta (RN10) |
| ds_anuncio | TEXT | — | Sim | — | Texto do anúncio | — |
| dt_cadastro | TIMESTAMP | — | Não | — | Data do cadastro | Preenchida automaticamente |

**Restrições:** tp_finalidade IN ('venda','locacao','venda_locacao') · st_imovel IN ('disponivel','reservado','vendido','alugado','inativo') · vl_venda obrigatório se a finalidade inclui venda; vl_aluguel obrigatório se inclui locação

## foto

*Origem: Entidade FOTO (fraca).*

| Coluna | Tipo | Chave | Nulo | Referência | Descrição | Regra / observação |
|---|---|---|---|---|---|---|
| id_imovel | INTEGER | PK FK | Não | imovel.id_imovel (TEM) | Referência a imovel | — |
| nr_foto | SMALLINT | PK | Não | — | Número da foto dentro do imóvel | Identificador parcial; não muda quando a galeria é reordenada |
| nr_ordem | SMALLINT | — | Não | — | Posição da foto na galeria | Pode ser alterada |
| ds_url | VARCHAR(500) | — | Não | — | Endereço do arquivo da foto | — |

**Restrições:** Chave primária composta (id_imovel, nr_foto)

## caracteristica

*Origem: Entidade CARACTERISTICA (forte).*

| Coluna | Tipo | Chave | Nulo | Referência | Descrição | Regra / observação |
|---|---|---|---|---|---|---|
| id_caracteristica | INTEGER | PK | Não | — | Identificador da característica | Identificação única |
| nm_caracteristica | VARCHAR(60) | UK | Não | — | Nome (piscina, elevador, aceita pet…) | Não pode se repetir |

## imovel_caracteristica

*Origem: Relacionamento N:N APRESENTA.* Relacionamento N:N APRESENTA.

| Coluna | Tipo | Chave | Nulo | Referência | Descrição | Regra / observação |
|---|---|---|---|---|---|---|
| id_caracteristica | INTEGER | PK FK | Não | caracteristica.id_caracteristica (APRESENTA) | Referência a caracteristica | — |
| id_imovel | INTEGER | PK FK | Não | imovel.id_imovel (APRESENTA) | Referência a imovel | — |

**Restrições:** Chave primária composta (id_caracteristica, id_imovel)

## funil_estagio

*Origem: Entidade FUNIL_ESTAGIO (forte).*

| Coluna | Tipo | Chave | Nulo | Referência | Descrição | Regra / observação |
|---|---|---|---|---|---|---|
| id_estagio | INTEGER | PK | Não | — | Identificador do estágio | Identificação única |
| nm_estagio | VARCHAR(40) | UK | Não | — | Nome do estágio | Não pode se repetir |
| nr_ordem | SMALLINT | UK | Não | — | Posição do estágio no funil | — |
| ds_cor | CHAR(7) | — | Sim | — | Cor usada no quadro do funil | — |

## conversa

*Origem: Entidade CONVERSA (forte).* dt_atualizacao é derivada (data da última mensagem) e não é armazenada.

| Coluna | Tipo | Chave | Nulo | Referência | Descrição | Regra / observação |
|---|---|---|---|---|---|---|
| id_conversa | INTEGER | PK | Não | — | Identificador da conversa | Identificação única |
| id_cliente | INTEGER | FK | Não | usuario.id_usuario (INICIA) | Referência a usuario | — |
| id_corretor | INTEGER | FK | Sim | usuario.id_usuario (ATENDE) | Referência a usuario | — |
| id_estagio | INTEGER | FK | Não | funil_estagio.id_estagio (PERTENCE A) | Referência a funil_estagio | — |
| st_conversa | VARCHAR(10) | — | Não | — | Situação da conversa | Aberta ou encerrada (RN34) |
| ds_notas | TEXT | — | Sim | — | Anotações do corretor sobre o atendimento | — |
| dt_inicio | TIMESTAMP | — | Não | — | Data de abertura da conversa | Preenchida automaticamente |

**Restrições:** st_conversa IN ('aberta','encerrada')

## conversa_imovel

*Origem: Entidade CONVERSA_IMOVEL (associativa).* Entidade associativa CONVERSA_IMOVEL (INTERESSA).

| Coluna | Tipo | Chave | Nulo | Referência | Descrição | Regra / observação |
|---|---|---|---|---|---|---|
| id_imovel | INTEGER | PK FK | Não | imovel.id_imovel (INTERESSA) | Referência a imovel | — |
| id_conversa | INTEGER | PK FK | Não | conversa.id_conversa (INTERESSA) | Referência a conversa | — |
| dt_interesse | TIMESTAMP | — | Não | — | Quando o imóvel passou a interessar na conversa | Atributo do relacionamento |

**Restrições:** Chave primária composta (id_imovel, id_conversa)

## mensagem

*Origem: Entidade MENSAGEM (fraca).*

| Coluna | Tipo | Chave | Nulo | Referência | Descrição | Regra / observação |
|---|---|---|---|---|---|---|
| id_conversa | INTEGER | PK FK | Não | conversa.id_conversa (CONTEM) | Referência a conversa | — |
| nr_mensagem | INTEGER | PK | Não | — | Número da mensagem dentro da conversa | Identificador parcial |
| cd_externo | VARCHAR(64) | — | Sim | — | Código da mensagem no WhatsApp | Não se repete na mesma conversa, o que impede registrar a mesma mensagem duas vezes (RN31); vazio nas notas internas |
| tp_direcao | VARCHAR(10) | — | Sim | — | Entrada (cliente) ou saída (imobiliária) | Em branco quando for nota interna |
| tp_canal | VARCHAR(15) | — | Não | — | Meio da mensagem | WhatsApp, e-mail ou nota interna |
| ds_corpo | TEXT | — | Não | — | Conteúdo da mensagem | — |
| dt_mensagem | TIMESTAMP | — | Não | — | Data e hora da mensagem | — |

**Restrições:** Chave primária composta (id_conversa, nr_mensagem) · UNIQUE (id_conversa, cd_externo) · tp_direcao IN ('entrada','saida') · tp_canal IN ('whatsapp','nota_interna')

## historico_estagio

*Origem: Entidade HISTORICO_ESTAGIO (associativa).* Entidade associativa HISTORICO_ESTAGIO (MOVE).

| Coluna | Tipo | Chave | Nulo | Referência | Descrição | Regra / observação |
|---|---|---|---|---|---|---|
| id_conversa | INTEGER | PK FK | Não | conversa.id_conversa (MOVE) | Referência a conversa | — |
| dt_alteracao | TIMESTAMP | PK | Não | — | Data e hora da mudança de estágio | Identificador parcial; toda mudança gera um registro e o mais recente é o estágio atual (RN14) |
| id_estagio | INTEGER | FK | Não | funil_estagio.id_estagio (MOVE) | Referência a funil_estagio | — |
| id_usuario | INTEGER | FK | Sim | usuario.id_usuario (REGISTRA) | Referência a usuario | — |

**Restrições:** Chave primária composta (id_conversa, dt_alteracao)

## tarefa

*Origem: Entidade TAREFA (forte).*

| Coluna | Tipo | Chave | Nulo | Referência | Descrição | Regra / observação |
|---|---|---|---|---|---|---|
| id_tarefa | INTEGER | PK | Não | — | Identificador da tarefa | Identificação única |
| id_conversa | INTEGER | FK | Sim | conversa.id_conversa (GERA TAREFA) | Referência a conversa | — |
| id_corretor | INTEGER | FK | Não | usuario.id_usuario (EXECUTA) | Referência a usuario | — |
| ds_titulo | VARCHAR(120) | — | Não | — | Resumo da tarefa | — |
| ds_tarefa | TEXT | — | Sim | — | Detalhes | — |
| dt_vencimento | TIMESTAMP | — | Não | — | Prazo da tarefa | A situação “atrasada” é calculada a partir do prazo e não é armazenada |
| st_tarefa | VARCHAR(15) | — | Não | — | Situação | Pendente, concluída ou cancelada |

**Restrições:** st_tarefa IN ('pendente','concluida','cancelada')

## tag

*Origem: Entidade TAG (forte).*

| Coluna | Tipo | Chave | Nulo | Referência | Descrição | Regra / observação |
|---|---|---|---|---|---|---|
| id_tag | INTEGER | PK | Não | — | Identificador da tag | Identificação única |
| nm_tag | VARCHAR(40) | UK | Não | — | Texto da etiqueta | Não pode se repetir |

## conversa_tag

*Origem: Relacionamento N:N MARCA.* Relacionamento N:N MARCA.

| Coluna | Tipo | Chave | Nulo | Referência | Descrição | Regra / observação |
|---|---|---|---|---|---|---|
| id_conversa | INTEGER | PK FK | Não | conversa.id_conversa (MARCA) | Referência a conversa | — |
| id_tag | INTEGER | PK FK | Não | tag.id_tag (MARCA) | Referência a tag | — |

**Restrições:** Chave primária composta (id_conversa, id_tag)

## visita

*Origem: Entidade VISITA (associativa).* Entidade associativa VISITA (cliente × imóvel), com o corretor de ACOMPANHA.

| Coluna | Tipo | Chave | Nulo | Referência | Descrição | Regra / observação |
|---|---|---|---|---|---|---|
| id_visita | INTEGER | PK | Não | — | Identificador da visita | Identificação única |
| id_imovel | INTEGER | FK | Não | imovel.id_imovel (VISITA) | Referência a imovel | — |
| id_cliente | INTEGER | FK | Não | usuario.id_usuario (VISITA) | Referência a usuario | — |
| id_corretor | INTEGER | FK | Não | usuario.id_usuario (ACOMPANHA) | Referência a usuario | — |
| dt_visita | TIMESTAMP | — | Não | — | Data e hora da visita | O mesmo cliente não visita o mesmo imóvel duas vezes no mesmo horário (RN16) |
| st_visita | VARCHAR(15) | — | Não | — | Situação | Agendada, realizada ou cancelada |
| ds_feedback | TEXT | — | Sim | — | Impressão do cliente após a visita | Preenchido quando a visita é realizada |

**Restrições:** UNIQUE (id_imovel, id_cliente, dt_visita) · st_visita IN ('agendada','realizada','cancelada')

## proposta

*Origem: Entidade PROPOSTA (associativa).* Entidade associativa PROPOSTA (cliente × imóvel). vl_anunciado é o valor congelado no momento da proposta, e não uma cópia de imovel.vl_venda.

| Coluna | Tipo | Chave | Nulo | Referência | Descrição | Regra / observação |
|---|---|---|---|---|---|---|
| id_proposta | INTEGER | PK | Não | — | Identificador da proposta | Identificação única |
| id_imovel | INTEGER | FK | Não | imovel.id_imovel (PROPOE) | Referência a imovel | — |
| id_cliente | INTEGER | FK | Não | usuario.id_usuario (PROPOE) | Referência a usuario | — |
| id_corretor | INTEGER | FK | Não | usuario.id_usuario (NEGOCIA) | Referência a usuario | — |
| id_autorizador | INTEGER | FK | Sim | usuario.id_usuario (AUTORIZA) | Referência a usuario | — |
| id_proposta_respondida | INTEGER | FK UK | Sim | proposta.id_proposta (RESPONDE) | Referência a proposta | — |
| id_visita | INTEGER | FK | Sim | visita.id_visita (ORIGINA) | Referência a visita | — |
| vl_proposto | NUMERIC(12,2) | — | Não | — | Valor oferecido | Desconto acima de 10% sobre o valor anunciado exige aprovação (PO03) |
| vl_anunciado | NUMERIC(12,2) | — | Não | — | Valor anunciado do imóvel no momento da proposta | Base para calcular o desconto (PO03, 17.19) |
| ds_condicoes | TEXT | — | Sim | — | Forma de pagamento, prazos e financiamento | — |
| st_proposta | VARCHAR(15) | — | Não | — | Situação | Pendente, aceita, recusada ou substituída (respondida por contraproposta, RN35) |
| dt_proposta | TIMESTAMP | — | Não | — | Data da proposta | — |
| dt_autorizacao | TIMESTAMP | — | Sim | — | Data da autorização do administrador | Obrigatória quando o desconto passa de 10% (PO03); atributo do relacionamento AUTORIZA |

**Restrições:** st_proposta IN ('aberta','aceita','recusada','substituida') · id_autorizador e dt_autorizacao obrigatórios quando vl_proposto < 0,9 × vl_anunciado (PO03)

## contrato

*Origem: Entidade CONTRATO (forte).* vl_corretagem = vl_final × pc_corretagem é derivado e não é armazenado (evita dependência entre colunas não chave).

| Coluna | Tipo | Chave | Nulo | Referência | Descrição | Regra / observação |
|---|---|---|---|---|---|---|
| id_contrato | INTEGER | PK | Não | — | Identificador do contrato | Identificação única |
| id_proposta | INTEGER | FK UK | Não | proposta.id_proposta (FECHA) | Referência a proposta | — |
| tp_contrato | VARCHAR(10) | — | Não | — | Venda ou locação | RN19 |
| tp_forma_pagamento | VARCHAR(15) | — | Não | — | Como o comprador paga | À vista, financiado ou parcelado direto; “financiado” se, e somente se, houver financiamento (RN22) |
| vl_final | NUMERIC(12,2) | — | Não | — | Valor fechado; na locação, o aluguel mensal | — |
| pc_corretagem | NUMERIC(5,2) | — | Não | — | Percentual de corretagem sobre o valor final | Na locação, incide sobre o aluguel mensal (taxa de intermediação); base da conta a receber da corretagem (RF24) |
| pc_administracao | NUMERIC(5,2) | — | Sim | — | Percentual retido do aluguel pela imobiliária | Obrigatório na locação; define o repasse ao proprietário (RN30) |
| nr_dia_vencimento | SMALLINT | — | Sim | — | Dia do mês em que vence o aluguel | Obrigatório na locação (RF27) |
| dt_assinatura | DATE | — | Sim | — | Data da assinatura | Vazia enquanto o contrato é rascunho (RN36) |
| dt_inicio | DATE | — | Sim | — | Início da vigência | Obrigatória na locação (RN19) |
| dt_fim | DATE | — | Sim | — | Data de término | Obrigatória na locação (RN19) |
| st_contrato | VARCHAR(15) | — | Não | — | Situação | Rascunho, vigente, encerrado ou cancelado; contrato assinado não é excluído, só cancelado (PO04) |
| dt_cancelamento | DATE | — | Sim | — | Data do cancelamento | Obrigatória quando cancelado (PO04, RN37) |
| ds_motivo_cancelamento | TEXT | — | Sim | — | Motivo do cancelamento | Obrigatório quando cancelado (PO04, RN37) |

**Restrições:** tp_contrato IN ('venda','locacao') · tp_forma_pagamento IN ('a_vista','financiado','mensal') · st_contrato IN ('rascunho','assinado','encerrado','cancelado') · locação exige dt_inicio, dt_fim, pc_administracao e nr_dia_vencimento (RN19)

## documento

*Origem: Entidade DOCUMENTO (fraca).*

| Coluna | Tipo | Chave | Nulo | Referência | Descrição | Regra / observação |
|---|---|---|---|---|---|---|
| id_contrato | INTEGER | PK FK | Não | contrato.id_contrato (ANEXA) | Referência a contrato | — |
| nr_documento | SMALLINT | PK | Não | — | Número do documento dentro do contrato | Identificador parcial |
| nm_documento | VARCHAR(120) | — | Não | — | Nome do documento | — |
| ds_url | VARCHAR(500) | — | Não | — | Endereço do arquivo | — |

**Restrições:** Chave primária composta (id_contrato, nr_documento)

## comissao

*Origem: Entidade COMISSAO (associativa).* Entidade associativa COMISSAO (RECEBE). vl_comissao é derivado de pc_comissao e da corretagem do contrato e não é armazenado.

| Coluna | Tipo | Chave | Nulo | Referência | Descrição | Regra / observação |
|---|---|---|---|---|---|---|
| id_contrato | INTEGER | PK FK | Não | contrato.id_contrato (RECEBE) | Referência a contrato | — |
| id_corretor | INTEGER | PK FK | Não | usuario.id_usuario (RECEBE) | Referência a usuario | — |
| pc_comissao | NUMERIC(5,2) | — | Não | — | Percentual do corretor sobre a corretagem do contrato | A soma no contrato não passa de 100% (RN20) |
| tp_regra_pagamento | VARCHAR(20) | — | Não | — | Quando a comissão pode ser paga | Na assinatura, na liberação do crédito ou no recebimento (RN24) |
| st_comissao | VARCHAR(15) | — | Não | — | Situação | Pendente, liberada ou cancelada; “paga” não é armazenada, pois deriva da conta a pagar ligada por LANCA (17.20) |
| id_aprovador | INTEGER | FK | Sim | usuario.id_usuario (APROVA) | Referência a usuario | — |
| dt_aprovacao | TIMESTAMP | — | Sim | — | Data da aprovação do administrador | Obrigatória antes do pagamento (PO01); atributo do relacionamento APROVA |
| id_conta_pagar | INTEGER | FK UK | Sim | conta_pagar.id_conta_pagar (LANCA) | Referência a conta_pagar | — |

**Restrições:** Chave primária composta (id_contrato, id_corretor) · tp_regra_pagamento IN ('assinatura','liberacao_credito','recebimento') · st_comissao IN ('prevista','liberada','aprovada','paga','cancelada')

## financiamento

*Origem: Entidade FINANCIAMENTO (fraca).* Identificado pelo próprio contrato (1:1). 3FN: o antigo LIBERA foi removido, porque a referência da conta a receber ao financiamento repetia o contrato da conta.

| Coluna | Tipo | Chave | Nulo | Referência | Descrição | Regra / observação |
|---|---|---|---|---|---|---|
| id_contrato | INTEGER | PK FK | Não | contrato.id_contrato (FINANCIA) | Referência a contrato | — |
| id_instituicao | INTEGER | FK | Não | usuario.id_usuario (CONCEDE) | Referência a usuario | — |
| vl_financiado | NUMERIC(12,2) | — | Não | — | Valor financiado | — |
| vl_entrada | NUMERIC(12,2) | — | Sim | — | Valor de entrada | — |
| nr_parcelas | SMALLINT | — | Sim | — | Quantidade de parcelas | — |
| pc_juros_aa | NUMERIC(5,2) | — | Sim | — | Taxa de juros ao ano | — |
| st_financiamento | VARCHAR(15) | — | Não | — | Situação | Em análise, aprovado, reprovado, liberado ou cancelado |
| dt_aprovacao | DATE | — | Sim | — | Data da aprovação do crédito | — |
| dt_liberacao | DATE | — | Sim | — | Data em que o banco libera o crédito | Condiciona o recebimento da corretagem (RN23) |

**Restrições:** st_financiamento IN ('em_analise','aprovado','liberado','recusado')

## categoria_financeira

*Origem: Entidade CATEGORIA_FINANCEIRA (forte).*

| Coluna | Tipo | Chave | Nulo | Referência | Descrição | Regra / observação |
|---|---|---|---|---|---|---|
| id_categoria | INTEGER | PK | Não | — | Identificador da categoria | Identificação única |
| nm_categoria | VARCHAR(60) | UK | Não | — | Nome da categoria | Não pode se repetir |
| tp_categoria | VARCHAR(10) | — | Não | — | Receita ou despesa | Deve ser compatível com a conta classificada (RN26) |

**Restrições:** tp_categoria IN ('receita','despesa')

## conta_bancaria

*Origem: Entidade CONTA_BANCARIA (forte).*

| Coluna | Tipo | Chave | Nulo | Referência | Descrição | Regra / observação |
|---|---|---|---|---|---|---|
| id_conta | INTEGER | PK | Não | — | Identificador da conta | Identificação única |
| nm_apelido | VARCHAR(60) | UK | Não | — | Nome de referência da conta | Não pode se repetir |
| nm_instituicao | VARCHAR(100) | — | Sim | — | Banco | — |
| tp_conta_bancaria | VARCHAR(15) | — | Não | — | Tipo | Corrente, poupança ou caixa |
| fl_ativa | BOOLEAN | — | Não | — | Indica se a conta está em uso | — |

**Restrições:** tp_conta_bancaria IN ('corrente','poupanca','caixa')

## conta_receber

*Origem: Entidade CONTA_RECEBER (forte).* st_conta é derivada das baixas e do vencimento e não é armazenada (RN38).

| Coluna | Tipo | Chave | Nulo | Referência | Descrição | Regra / observação |
|---|---|---|---|---|---|---|
| id_conta_receber | INTEGER | PK | Não | — | Identificador da conta a receber | Identificação única |
| id_contrato | INTEGER | FK | Sim | contrato.id_contrato (GERA RECEITA) | Referência a contrato | — |
| id_categoria | INTEGER | FK | Não | categoria_financeira.id_categoria (CLASSIFICA) | Referência a categoria_financeira | — |
| id_pagador | INTEGER | FK | Não | usuario.id_usuario (PAGA) | Referência a usuario | — |
| tp_papel_pagador | VARCHAR(15) | — | Não | — | Papel exercido por quem paga | Cliente, inquilino, proprietário ou banco (RN27) |
| tp_origem_receita | VARCHAR(20) | — | Não | — | Natureza da receita | Corretagem, intermediação, administração, aluguel ou serviço |
| ds_conta | VARCHAR(200) | — | Sim | — | Descrição | — |
| dt_competencia | DATE | — | Sim | — | Mês de referência | Obrigatório na locação |
| vl_receber | NUMERIC(12,2) | — | Não | — | Valor a receber | — |
| dt_vencimento | DATE | — | Não | — | Data de vencimento | — |
| fl_cancelada | BOOLEAN | — | Não | — | Indica conta cancelada | Único estado armazenado (RN37, RN38) |

**Restrições:** tp_papel_pagador IN ('cliente','inquilino','proprietario','banco') · tp_origem_receita IN ('corretagem','aluguel','taxa','outra')

## recebimento

*Origem: Entidade RECEBIMENTO (fraca).*

| Coluna | Tipo | Chave | Nulo | Referência | Descrição | Regra / observação |
|---|---|---|---|---|---|---|
| id_conta_receber | INTEGER | PK FK | Não | conta_receber.id_conta_receber (QUITA) | Referência a conta_receber | — |
| nr_recebimento | SMALLINT | PK | Não | — | Número do recebimento dentro da conta | Identificador parcial |
| id_conta | INTEGER | FK | Não | conta_bancaria.id_conta (CREDITA) | Referência a conta_bancaria | — |
| dt_recebimento | DATE | — | Não | — | Data do recebimento | — |
| vl_recebido | NUMERIC(12,2) | — | Não | — | Valor recebido | A soma não passa do valor da conta (RN29) |
| tp_forma_pagamento | VARCHAR(15) | — | Não | — | Forma de pagamento | Pix, TED, boleto, dinheiro ou cartão |

**Restrições:** Chave primária composta (id_conta_receber, nr_recebimento) · vl_recebido > 0 · soma das baixas ≤ vl_receber (RN29)

## conta_pagar

*Origem: Entidade CONTA_PAGAR (forte).* st_conta é derivada e não é armazenada (RN38).

| Coluna | Tipo | Chave | Nulo | Referência | Descrição | Regra / observação |
|---|---|---|---|---|---|---|
| id_conta_pagar | INTEGER | PK | Não | — | Identificador da conta a pagar | Identificação única |
| id_contrato | INTEGER | FK | Sim | contrato.id_contrato (GERA DESPESA) | Referência a contrato | — |
| id_categoria | INTEGER | FK | Não | categoria_financeira.id_categoria (CATEGORIZA) | Referência a categoria_financeira | — |
| id_favorecido | INTEGER | FK | Sim | usuario.id_usuario (FAVORECE) | Referência a usuario | — |
| id_custeador | INTEGER | FK | Sim | usuario.id_usuario (CUSTEIA) | Referência a usuario | — |
| tp_papel_custeio | VARCHAR(15) | — | Não | — | Papel de quem arca com o custo final | Imobiliária, proprietário ou inquilino (RN28) |
| tp_despesa | VARCHAR(20) | — | Não | — | Natureza da despesa | Comissão, repasse ao proprietário, despesa ou imposto |
| ds_conta | VARCHAR(200) | — | Sim | — | Descrição | — |
| dt_competencia | DATE | — | Sim | — | Mês de referência | Obrigatório no repasse de aluguel |
| vl_pagar | NUMERIC(12,2) | — | Não | — | Valor a pagar | — |
| dt_vencimento | DATE | — | Não | — | Data de vencimento | No repasse, até 5 dias úteis após o recebimento do aluguel (PO05) |
| fl_cancelada | BOOLEAN | — | Não | — | Indica conta cancelada | Único estado armazenado (RN37, RN38) |

**Restrições:** tp_papel_custeio IN ('imobiliaria','proprietario','inquilino') · id_custeador obrigatório quando tp_papel_custeio ≠ 'imobiliaria' (RN28)

## pagamento

*Origem: Entidade PAGAMENTO (fraca).*

| Coluna | Tipo | Chave | Nulo | Referência | Descrição | Regra / observação |
|---|---|---|---|---|---|---|
| id_conta_pagar | INTEGER | PK FK | Não | conta_pagar.id_conta_pagar (LIQUIDA) | Referência a conta_pagar | — |
| nr_pagamento | SMALLINT | PK | Não | — | Número do pagamento dentro da conta | Identificador parcial |
| id_conta | INTEGER | FK | Não | conta_bancaria.id_conta (DEBITA) | Referência a conta_bancaria | — |
| id_usuario | INTEGER | FK | Não | usuario.id_usuario (EFETIVA) | Referência a usuario | — |
| dt_pagamento | DATE | — | Não | — | Data do pagamento | — |
| vl_pago | NUMERIC(12,2) | — | Não | — | Valor pago | A soma não passa do valor da conta (RN29) |
| tp_forma_pagamento | VARCHAR(15) | — | Não | — | Forma de pagamento | Pix, TED, boleto, dinheiro ou cartão |

**Restrições:** Chave primária composta (id_conta_pagar, nr_pagamento) · vl_pago > 0 · soma das baixas ≤ vl_pagar (RN29)

## automacao_execucao

*Origem: Entidade AUTOMACAO_EXECUCAO (fraca).*

| Coluna | Tipo | Chave | Nulo | Referência | Descrição | Regra / observação |
|---|---|---|---|---|---|---|
| id_conversa | INTEGER | PK FK | Não | conversa.id_conversa (DISPARA) | Referência a conversa | — |
| nr_execucao | INTEGER | PK | Não | — | Número da execução dentro da conversa | Identificador parcial |
| cd_demanda | VARCHAR(64) | — | Não | — | Resumo que identifica a demanda | Não se repete na mesma conversa (RN31) |
| st_execucao | VARCHAR(15) | — | Não | — | Situação da execução | — |
| ds_demanda | TEXT | — | Sim | — | O que o cliente pediu, extraído da mensagem | — |
| ds_criterios | TEXT | — | Sim | — | Critérios usados para escolher os imóveis | — |
| ds_conteudo_enviado | TEXT | — | Sim | — | Conteúdo enviado ao cliente | — |
| ds_resumo | TEXT | — | Sim | — | Resumo da execução | — |
| ds_erro | TEXT | — | Sim | — | Erro ocorrido | Preenchido apenas quando há erro |
| dt_execucao | TIMESTAMP | — | Não | — | Data e hora da execução | — |
| dt_envio | TIMESTAMP | — | Sim | — | Data e hora do envio ao cliente | Preenchida quando há envio |

**Restrições:** Chave primária composta (id_conversa, nr_execucao) · UNIQUE (id_conversa, cd_demanda) · st_execucao IN ('recebida','processada','enviada','erro')

## automacao_log

*Origem: Entidade AUTOMACAO_LOG (fraca).* FK composta (id_conversa, nr_execucao) → automacao_execucao.

| Coluna | Tipo | Chave | Nulo | Referência | Descrição | Regra / observação |
|---|---|---|---|---|---|---|
| id_conversa | INTEGER | PK FK | Não | automacao_execucao.id_conversa (GRAVA) | Referência a automacao_execucao | — |
| nr_execucao | INTEGER | PK FK | Não | automacao_execucao.nr_execucao (GRAVA) | Referência a automacao_execucao | — |
| nr_log | INTEGER | PK | Não | — | Número do evento dentro da execução | Identificador parcial |
| nm_evento | VARCHAR(60) | — | Não | — | Nome do evento | — |
| ds_evento | TEXT | — | Sim | — | Descrição do evento | — |
| ds_dados | TEXT | — | Sim | — | Dados técnicos do evento | — |
| dt_log | TIMESTAMP | — | Não | — | Data e hora do evento | — |

**Restrições:** Chave primária composta (id_conversa, nr_execucao, nr_log)

## auditoria

*Origem: Entidade AUDITORIA (forte).* Registro imutável (RN40).

| Coluna | Tipo | Chave | Nulo | Referência | Descrição | Regra / observação |
|---|---|---|---|---|---|---|
| id_auditoria | INTEGER | PK | Não | — | Identificador do registro de auditoria | Identificação única |
| id_usuario | INTEGER | FK | Não | usuario.id_usuario (PRATICA) | Referência a usuario | — |
| nm_entidade | VARCHAR(40) | — | Não | — | Entidade afetada | Contrato, proposta, comissão, conta a receber, conta a pagar, recebimento ou pagamento |
| cd_registro | VARCHAR(60) | — | Não | — | Identificação do registro afetado | Referência genérica, sem relacionamento com cada entidade (17.22) |
| tp_acao | VARCHAR(15) | — | Não | — | Ação praticada | Criação, alteração ou cancelamento (RN40) |
| dt_acao | TIMESTAMP | — | Não | — | Data e hora da ação | Preenchida automaticamente; o registro nunca é alterado (RNF04) |

**Restrições:** tp_acao IN ('criacao','alteracao','cancelamento')

## auditoria_campo

*Origem: Entidade AUDITORIA_CAMPO (fraca).* 1FN: o antigo ds_valores (vários campos num texto) virou uma linha por campo alterado.

| Coluna | Tipo | Chave | Nulo | Referência | Descrição | Regra / observação |
|---|---|---|---|---|---|---|
| id_auditoria | INTEGER | PK FK | Não | auditoria.id_auditoria (DETALHA) | Referência a auditoria | — |
| nm_campo | VARCHAR(60) | PK | Não | — | Nome do campo alterado | Identificador parcial dentro do registro de auditoria |
| ds_valor_anterior | TEXT | — | Sim | — | Valor do campo antes da ação | Vazio na criação |
| ds_valor_novo | TEXT | — | Sim | — | Valor do campo depois da ação | Vazio quando o valor é apagado |

**Restrições:** Chave primária composta (id_auditoria, nm_campo)

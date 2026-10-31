# CRMoveis — Normalizacao (Etapas 8 a 11)

Projeto Integrador — Modelagem de Dados · Prof. Clovis · Grupo 4

O manual pede para nao escrever so “o banco foi normalizado ate a 3FN”, e sim mostrar o processo: **estrutura analisada → dependencia funcional → problema identificado → correcao realizada**. E avisa: *“Nao inventem erros apenas para mostrar uma normalizacao.”*

Por isso todos os casos abaixo aconteceram de verdade, em um de dois lugares:

- **No app original SP Imoveis CRM** (Flask + SQLite), que o nosso amigo usava e que deu origem ao projeto. As estruturas “ANTES” marcadas assim sao as tabelas reais do `app.py` dele (`conversations`, `stages`, `messages`, `automation_runs`, `automation_logs`).
- **Na nossa primeira entrega e nas revisoes seguintes** (normalizacao da aula 8, devolutiva do professor e revisao final antes da apresentacao).

Os dados dos exemplos sao os da nossa massa de dados ficticia (`sql/dados/10_massa_de_dados.sql`). No “ANTES”, mostramos como esses mesmos dados ficariam na estrutura antiga; no “DEPOIS”, as linhas foram lidas do banco instalado.

## Como analisamos

| Forma normal | Pergunta pratica do manual | O que fizemos em cada tabela |
|---|---|---|
| 1FN (Etapa 8) | “Cada campo armazena adequadamente um unico valor?” — UM CAMPO → UM VALOR | Procuramos listas dentro de campos, grupos repetitivos, colunas numeradas (telefone1, telefone2…) e atributos guardando varias ocorrencias. |
| 2FN (Etapa 9) | “Cada atributo nao chave depende da CHAVE TODA?” | Nas 18 tabelas de chave composta, perguntamos de qual parte da chave cada atributo depende. |
| 3FN (Etapa 10) | “O atributo depende diretamente da chave ou depende de outro atributo?” | Listamos as dependencias funcionais de cada tabela e procuramos atributo nao chave determinado por outro atributo nao chave. |

As formas normais sao cumulativas: uma tabela na 3FN tambem esta na 1FN e na 2FN.

## Etapa 8 — Primeira forma normal (1FN)

| Pergunta do manual | O que encontramos | Caso |
|---|---|---|
| Existem listas dentro de campos? | Sim, no app original: varios codigos de imovel no mesmo campo. | 1.1 |
| Um atributo esta tentando armazenar varias ocorrencias? | Sim: os papeis da pessoa (1a entrega), os campos alterados da auditoria (1a entrega) e os tipos de imovel e os bairros aceitos pelo perfil (revisao final). | 1.2, 1.3, 1.5 e 1.6 |
| Existem grupos repetitivos? | Sim: o endereco do imovel era um atributo composto no DER. | 1.4 |
| Existem colunas como telefone1, telefone2, telefone3? | Nao. O telefone sempre ficou numa tabela propria, uma linha por telefone; na revisao final ele virou entidade fraca da pessoa (caso 2.1). | — |

### Caso 1.1 — Varios imoveis dentro de um campo (property_codes)

*Onde aconteceu:* app original SP Imoveis CRM, tabela `conversations`.

**ANTES**

conversations(id, name, phone, stage, kind, source, owner, last_message, notes, **property_codes**, color, created_at, updated_at)

| id | name | property_codes |
|---|---|---|
| 1 | Bruno Lima | IMB-3501, IMB-3525 |
| 2 | Camila Rocha | IMB-3502, IMB-3520 |
| 3 | Diego Alves | IMB-3503, IMB-3516, IMB-3522 |

**DEPENDENCIAS**

id → property_codes, mas property_codes nao e **um** valor: e uma lista de codigos separados por virgula. Cada codigo, isoladamente, identifica um imovel (cd_imobizi → imovel).

**PROBLEMA**

Viola a 1FN (lista dentro de um campo). Na pratica: para saber quem se interessou pelo IMB-3525 e preciso recortar texto em todas as conversas; nada impede um codigo que nao existe ou escrito com espaco; nao ha onde guardar **quando** o interesse surgiu; e retirar um imovel da lista exige reescrever o campo inteiro.

**DEPOIS**

conversa(**id_conversa**, …) · imovel(**id_imovel**, cd_imobizi, …) · conversa_imovel(**_id_imovel_, _id_conversa_**, dt_interesse)

| id_conversa | id_imovel | (cd_imobizi) | dt_interesse |
|---|---|---|---|
| 1 | 101 | IMB-3501 | 2025-08-18 |
| 1 | 125 | IMB-3525 | 2025-08-18 |
| 2 | 102 | IMB-3502 | 2026-01-12 |
| 2 | 120 | IMB-3520 | 2026-01-12 |
| 3 | 103 | IMB-3503 | 2026-01-21 |
| 3 | 116 | IMB-3516 | 2026-01-21 |
| 3 | 122 | IMB-3522 | 2026-01-21 |

Uma linha por imovel de interesse. A FK garante que o imovel existe, a chave composta impede repetir o mesmo imovel na conversa, e dt_interesse, que depende do par, ganhou lugar. O relacionamento e o INTERESSA do DER.

### Caso 1.2 — Varios papeis da mesma pessoa

*Onde aconteceu:* app original (`conversations.kind`) e nossa 1a entrega (atributo multivalorado tp_papel em USUARIO).

**ANTES**

App original: conversations(…, **kind**, …), com um papel por conversa (‘Cliente’, ‘Corretor’, ‘Proprietario’), e colunas “Corretores” e “Proprietarios” no proprio funil (`stages`).

1a entrega: USUARIO(id_usuario, nm_usuario, …, **tp_papel** {multivalorado})

| id_usuario | nm_usuario | tp_papel |
|---|---|---|
| 15 | Ana Souza | cliente, proprietario |
| 19 | Beatriz Antunes | cliente, proprietario |
| 25 | Camila Rocha | cliente, inquilino |

**DEPENDENCIAS**

id_usuario →→ tp_papel (dependencia multivalorada: uma pessoa tem varios papeis ao mesmo tempo). Cada papel tem os proprios fatos: id_usuario, papel → dt_inicio, dt_fim (e nr_creci, no corretor).

**PROBLEMA**

Viola a 1FN (varias ocorrencias num atributo). O papel guardado na conversa (`kind`) ainda obrigava a escolher **um** papel por pessoa, e misturar papel com etapa do funil fazia o corretor aparecer como se fosse um negocio. Tambem nao havia onde guardar desde quando e ate quando a pessoa tem o papel (RN02).

**DEPOIS**

usuario(**id_usuario**, nm_usuario, …) + um subtipo por papel: cliente(**_id_usuario_**, dt_inicio, dt_fim), proprietario(**_id_usuario_**, dt_inicio, dt_fim), corretor(**_id_usuario_**, nr_creci, dt_inicio, dt_fim), …

| tabela | id_usuario | pessoa |
|---|---|---|
| cliente | 15 | Ana Souza |
| proprietario | 15 | Ana Souza |
| cliente | 19 | Beatriz Antunes |
| proprietario | 19 | Beatriz Antunes |
| cliente | 25 | Camila Rocha |
| inquilino | 25 | Camila Rocha |

Uma linha por papel. Depois da normalizacao da aula 8, a correcao foi uma tabela usuario_papel(id_usuario, tp_papel); depois da devolutiva (ponto 1), cada papel virou subtipo, com tabela propria: continua um valor por campo e, alem disso, as FKs passam a exigir o papel certo (imovel.id_proprietario → proprietario, por exemplo).

### Caso 1.3 — Campos alterados da auditoria num unico texto

*Onde aconteceu:* nossa 1a entrega (atributo ds_valores em AUDITORIA).

**ANTES**

auditoria(id_auditoria, id_usuario, nm_entidade, cd_registro, tp_acao, **ds_valores**, dt_acao)

| id_auditoria | tp_acao | ds_valores |
|---|---|---|
| 27 | alteracao | dt_assinatura: (vazio) → 2026-02-20; st_contrato: rascunho → vigente |

**DEPENDENCIAS**

id_auditoria → ds_valores, mas o campo junta varias ocorrencias de (campo alterado, valor anterior, valor novo). Para cada campo: (id_auditoria, nm_campo) → ds_valor_anterior, ds_valor_novo.

**PROBLEMA**

Viola a 1FN. Para responder “quem mudou a data de assinatura?” seria preciso recortar o texto; o formato depende de quem escreveu.

**DEPOIS**

auditoria(**id_auditoria**, …) · auditoria_campo(**_id_auditoria_, nm_campo**, ds_valor_anterior, ds_valor_novo)

| id_auditoria | nm_campo | ds_valor_anterior | ds_valor_novo |
|---|---|---|---|
| 27 | dt_assinatura | (vazio) | 2026-02-20 |
| 27 | st_contrato | rascunho | vigente |

Um registro por campo alterado (RN40), gravado automaticamente pelo gatilho de auditoria. Na devolutiva (ponto 6), nm_entidade + cd_registro tambem foram trocados por sete FKs (AUDITA), com CHECK de exatamente uma preenchida.

### Caso 1.4 — Endereco do imovel como atributo composto

*Onde aconteceu:* nosso DER (atributo composto endereco em IMOVEL).

**ANTES**

IMOVEL(id_imovel, …, **endereco** {logradouro, numero, complemento, bairro, CEP, cidade, UF})

| id_imovel | endereco (um texto) |
|---|---|
| 101 | Rua Tuiuti, 450 — Tatuape — 03310-000 — Sao Paulo/SP |
| 119 | Rua Tuiuti, 620 — Tatuape — 03310-000 — Sao Paulo/SP |

**DEPENDENCIAS**

id_imovel → logradouro, numero, complemento, bairro, CEP (cada parte e um fato separado).

**PROBLEMA**

Guardado num campo so, o valor nao e atomico: buscar imoveis por bairro (G07, G09, seletor por perfil) exigiria recortar texto.

**DEPOIS**

imovel(**id_imovel**, …, nm_logradouro, nr_endereco, ds_complemento, _id_bairro_, _nr_cep_)

| id_imovel | nm_logradouro | nr_endereco | id_bairro | (nm_bairro) | nr_cep |
|---|---|---|---|---|---|
| 101 | Rua Tuiuti | 450 | 1 | Tatuape | 03310000 |
| 119 | Rua Tuiuti | 620 | 1 | Tatuape | 03310000 |

Uma coluna por parte. O bairro, que comecou como coluna de texto, virou referencia a tabela bairro na revisao final (caso 1.6); CEP, cidade e UF seguem para o caso 3.2 (3FN).

### Caso 1.5 — Varios tipos de imovel no mesmo perfil

*Onde aconteceu:* revisao final: o professor pediu que o perfil do cliente aceite mais de um tipo de imovel.

**ANTES**

perfil_interesse(**id_usuario, nr_perfil**, tp_finalidade, **tp_imovel**, nm_bairro, vl_minimo, vl_maximo, qt_quartos_min)

Com um tipo so por perfil, o cliente que aceita apartamento ou cobertura teria de virar dois perfis iguais, ou o tipo teria de guardar uma lista:

| id_usuario | cliente | nr_perfil | tp_finalidade | tp_imovel |
|---|---|---|---|---|
| 24 | Bruno Lima | 1 | locacao | apartamento, kitnet |
| 24 | Bruno Lima | 2 | venda | apartamento, cobertura |

**DEPENDENCIAS**

(id_usuario, nr_perfil) →→ tipo (dependencia multivalorada: um perfil aceita varios tipos). Os outros atributos do perfil (finalidade, faixa, quartos) nao dependem do tipo.

**PROBLEMA**

Com a lista no campo, viola a 1FN; com dois perfis repetidos, a faixa de valor e os quartos ficam duplicados e podem ficar diferentes. Alem disso, o tipo era um texto conferido por CHECK, repetido em imovel e em perfil_interesse.

**DEPOIS**

tipo_imovel(**id_tipo_imovel**, nm_tipo_imovel) · perfil_interesse(**_id_usuario_, nr_perfil**, tp_finalidade, …) · perfil_interesse_tipo(**_id_usuario_, _nr_perfil_, _id_tipo_imovel_**)

| perfil_interesse_tipo: id_usuario | nr_perfil | id_tipo_imovel | (nm_tipo_imovel) |
|---|---|---|---|
| 24 | 1 | 1 | Apartamento |
| 24 | 1 | 5 | Kitnet |
| 24 | 2 | 1 | Apartamento |
| 24 | 2 | 4 | Cobertura |

Uma linha por tipo aceito (relacionamento N:N DESEJA, RN47). Perfil sem nenhuma linha aceita qualquer tipo. O imovel aponta para a mesma tabela tipo_imovel (TIPIFICA, RN48), entao perfil e imovel usam o mesmo vocabulario.

### Caso 1.6 — Varios bairros no mesmo perfil (e o bairro digitado em duas tabelas)

*Onde aconteceu:* revisao final: revisando todos os atributos de texto do banco com os criterios da literatura (lista que muda com o tempo, o mesmo dado em mais de um lugar, atributo multivalorado).

**ANTES**

perfil_interesse(**id_usuario, nr_perfil**, _id_cidade_, tp_finalidade, **nm_bairro**, …) e imovel(**id_imovel**, …, **nm_bairro**, _nr_cep_)

Com um bairro so por perfil, o cliente que aceita Tatuape ou Mooca teria de virar dois perfis iguais, ou o campo teria de guardar uma lista; e o bairro era digitado tanto no perfil quanto no imovel:

| id_usuario | cliente | nr_perfil | cidade | nm_bairro |
|---|---|---|---|---|
| 24 | Bruno Lima | 1 | Sao Paulo | Mooca, Tatuape |
| 24 | Bruno Lima | 2 | Sao Paulo | Mooca, Tatuape |

**DEPENDENCIAS**

(id_usuario, nr_perfil) →→ bairro (dependencia multivalorada: um perfil aceita varios bairros). E o bairro, em texto, aparecia em duas tabelas, sem nada que garantisse a mesma grafia.

**PROBLEMA**

Com a lista no campo, viola a 1FN; com perfis repetidos, a faixa de valor e os quartos ficam duplicados. O texto digitado em dois lugares fazia "Vila Galvao" e "V. Galvao" serem bairros diferentes: o perfil deixava de casar com o imovel no seletor e na consulta de demanda por regiao (G09). E nada impedia um imovel de CEP de Guarulhos com um bairro de Sao Paulo.

**DEPOIS**

bairro(**id_bairro**, _id_cidade_, nm_bairro) · imovel(**id_imovel**, …, _id_bairro_, _nr_cep_) · perfil_interesse_bairro(**_id_usuario_, _nr_perfil_, _id_bairro_**)

| perfil_interesse_bairro: id_usuario | nr_perfil | id_bairro | (nm_bairro) |
|---|---|---|---|
| 24 | 1 | 2 | Mooca |
| 24 | 1 | 1 | Tatuape |
| 24 | 2 | 2 | Mooca |
| 24 | 2 | 1 | Tatuape |

O bairro existe uma vez, ligado a sua cidade (o nome so nao se repete dentro da mesma cidade: o Centro existe em Guarulhos e em Aruja). O imovel aponta para ele (SITUA), e o perfil aceita um, varios ou nenhum bairro (N:N ABRANGE; nenhum = qualquer bairro da cidade). Os gatilhos conferem que o bairro do imovel e da cidade do CEP (RN51) e que os bairros do perfil sao da cidade do perfil (RN52).

### O que parece violar a 1FN, mas nao viola

| Coluna | Por que fica como esta |
|---|---|
| automacao_execucao.ds_demanda, ds_criterios, ds_conteudo_enviado · automacao_log.ds_dados | Guardam o documento que o N8N enviou ou recebeu, do jeito que chegou, para rastrear a automacao (heranca dos campos *_json do app original). Nenhuma regra, consulta ou FK usa partes desse texto: o que o sistema usa de verdade foi para tabelas proprias (imoveis de interesse em conversa_imovel, mensagens em mensagem, situacao em st_execucao). Para o banco, e um valor so. |
| conversa.ds_notas · imovel.ds_anuncio · mensagem.ds_corpo | Texto livre escrito por pessoas: um valor so, que nunca e recortado. |
| imovel.qt_quartos, qt_banheiros, qt_vagas_garagem, vl_area_util, vl_area_total, ao lado de caracteristica e imovel_caracteristica | Nao e a mesma informacao em dois lugares. Quartos, banheiros, vagas e areas sao um numero so por imovel, todo imovel tem e as buscas comparam por faixa (perfil com quartos minimos): ficam como colunas. As caracteristicas (piscina, elevador, aceita pet) sao opcionais, variam de imovel para imovel e a lista cresce: cada imovel tem nenhuma ou varias, por isso ficam no catalogo caracteristica e na ligacao N:N imovel_caracteristica (APRESENTA). Colunas fl_piscina, fl_elevador… seriam um grupo repetitivo, como telefone1, telefone2. |
| conversa.id_estagio + historico_estagio | Nao e grupo repetitivo: o historico tem uma linha por mudanca de etapa, e a conversa guarda so a etapa atual (redundancia controlada, explicada no fim). |

## Etapa 9 — Segunda forma normal (2FN)

A 2FN so se aplica a chaves compostas. Conferimos as 18 tabelas com chave composta, perguntando de qual parte da chave cada atributo depende:

| Tabela | Chave primaria | Os atributos nao chave dependem da chave toda? |
|---|---|---|
| telefone | (id_usuario, nr_sequencia) | Numero, principal e titular descrevem aquele telefone daquela pessoa: o mesmo numero pode ser o principal de uma pessoa e nao da outra, e so uma delas e a titular. Se e celular ou fixo se deduz do numero e nao e guardado (seria dependencia de parte da chave candidata id_usuario + nr_telefone). |
| perfil_interesse | (id_usuario, nr_perfil) | Finalidade, bairro, cidade, faixa de valor e quartos descrevem aquele perfil, e nao o usuario: o mesmo cliente pode ter um perfil de compra e outro de locacao. |
| perfil_interesse_tipo | (id_usuario, nr_perfil, id_tipo_imovel) | Nao ha atributo nao chave: cada linha so diz que aquele perfil aceita aquele tipo. |
| perfil_interesse_bairro | (id_usuario, nr_perfil, id_bairro) | Nao ha atributo nao chave: cada linha so diz que aquele perfil aceita aquele bairro. |
| foto | (id_imovel, nr_foto) | Ordem e endereco do arquivo descrevem aquela foto; nao dependem so do imovel. |
| imovel_caracteristica | (id_caracteristica, id_imovel) | Nao ha atributo nao chave. |
| conversa_imovel | (id_imovel, id_conversa) | dt_interesse e o momento em que aquela conversa mostrou interesse naquele imovel: depende do par. |
| mensagem | (id_conversa, nr_mensagem) | Codigo externo, direcao, canal, texto e data descrevem aquela mensagem da conversa. |
| historico_estagio | (id_conversa, dt_alteracao) | O estagio e quem fez a mudanca dependem daquela mudanca (conversa + data e hora). |
| conversa_tag | (id_conversa, id_tag) | Nao ha atributo nao chave. |
| documento | (id_contrato, nr_documento) | Nome e arquivo descrevem aquele documento do contrato. |
| comissao | (id_contrato, id_corretor) | Percentual, regra de pagamento, situacao, aprovacao e conta a pagar valem para aquele corretor naquele contrato. Contraexemplo: nm_corretor dependeria so de id_corretor e pc_corretagem so de id_contrato (metade da chave), por isso ficam em usuario e contrato. |
| movimento_bancario | (id_conta, nr_movimento) | Codigo da transacao, data, valor, tipo e historico descrevem aquele lancamento do extrato da conta, e nao a conta bancaria inteira. |
| recebimento | (id_conta_receber, nr_recebimento) | Conta bancaria, data, valor, forma de pagamento, movimento do extrato e data da conciliacao descrevem aquela baixa, e nao a conta a receber inteira (a conta pode ter varias baixas). |
| pagamento | (id_conta_pagar, nr_pagamento) | Conta bancaria, quem efetivou, data, valor, forma, movimento do extrato e data da conciliacao descrevem aquela baixa da conta a pagar. |
| automacao_execucao | (id_conversa, nr_execucao) | Demanda, situacao, criterios, conteudo, resumo, erro e datas descrevem aquela execucao da automacao na conversa. |
| automacao_log | (id_conversa, nr_execucao, nr_log) | Evento, descricao, dados e data descrevem aquele registro do log da execucao. |
| auditoria_campo | (id_auditoria, nm_campo) | Valor anterior e valor novo dependem do campo dentro daquele registro de auditoria. |

Nenhuma dependencia parcial ficou no modelo. O caso abaixo e a situacao real em que a 2FN precisou ser pensada: primeiro na devolutiva (um numero de varias pessoas) e depois na revisao final (o telefone deixou de ter chave propria).

### Caso 2.1 — Telefone: da devolutiva a revisao final

*Onde aconteceu:* devolutiva do professor (ponto 2: um numero pode pertencer a mais de uma pessoa) e revisao final (o professor nao aprovou o telefone como entidade com chave propria).

**ANTES**

Depois da devolutiva: telefone(**id_telefone**, nr_telefone, tp_telefone) · usuario_telefone(**_id_usuario_, _id_telefone_**, fl_principal, fl_titular). O telefone era uma entidade com chave propria, embora nao identifique nada no negocio.

Juntando tudo numa tabela so, com o numero na chave, ela ficaria assim:

telefone(**id_usuario, nr_telefone**, tp_telefone, fl_principal, fl_titular)

| id_usuario | pessoa | nr_telefone | tp_telefone | fl_principal | fl_titular |
|---|---|---|---|---|---|
| 25 | Camila Rocha | 1130000061 | fixo | nao | sim |
| 26 | Diego Alves | 1130000061 | fixo | nao | nao |

**DEPENDENCIAS**

(id_usuario, nr_telefone) → fl_principal, fl_titular (chave toda)

nr_telefone → tp_telefone (parte da chave)

**PROBLEMA**

tp_telefone dependeria so de **parte** da chave: dependencia parcial (viola a 2FN), e o casal poderia ficar com o mesmo numero marcado como celular para um e fixo para o outro. E com o numero na chave, corrigir um digito mudaria a chave.

**DEPOIS**

telefone(**_id_usuario_, nr_sequencia**, nr_telefone, fl_principal, fl_titular), com UNIQUE (id_usuario, nr_telefone)

| telefone: id_usuario | nr_sequencia | nr_telefone | fl_principal | fl_titular |
|---|---|---|---|---|
| 25 | 2 | 1130000061 | nao | sim |
| 26 | 2 | 1130000061 | nao | nao |
| 20 | 2 | 11900000059 | nao | sim |
| 23 | 2 | 11900000059 | nao | nao |

O telefone virou entidade fraca da pessoa: a chave e a pessoa + a sequencia (1, 2, 3...), como a foto do imovel, e o numero nao e chave nem parte dela. Se e celular ou fixo se deduz do numero (celular tem 9 digitos depois do DDD), entao nao e guardado. Todos os atributos dependem da chave toda. O numero se repete para o casal, mas nada depende so dele: a regra “exatamente um titular por numero” (RN03) e uma restricao entre linhas, garantida pelo indice unico parcial ux_telefone_titular e pelo gatilho ct_telefone_titular, conferido no fim da transacao.

## Etapa 10 — Terceira forma normal (3FN)

### Caso 3.1 — Dados da pessoa e do corretor dentro da conversa

*Onde aconteceu:* app original SP Imoveis CRM, tabela `conversations`.

**ANTES**

conversations(**id**, name, phone, stage, kind, source, owner, last_message, notes, property_codes, color, created_at, updated_at)

O mesmo cliente voltou meses depois e abriu outro atendimento (RN11):

| id | name | phone | owner | stage |
|---|---|---|---|---|
| 1 | Bruno Lima | 11900000024 | Rui Almeida | Ganho |
| 44 | Bruno Lima | 11900000024 | Rui Almeida | Qualificacao |

**DEPENDENCIAS**

id → phone · phone → name (no WhatsApp, o numero identifica a pessoa) · id → owner, e o nome do corretor determina quem ele e.

Logo id → phone → name: dependencia transitiva.

**PROBLEMA**

name depende de phone, que nao e chave da conversa (viola a 3FN). Nome e telefone se repetem a cada novo atendimento: se o cliente corrigir o nome numa conversa, a outra continua com o nome antigo (anomalia de atualizacao); nao da para cadastrar uma pessoa sem abrir uma conversa (insercao); e apagar a ultima conversa apaga a pessoa (exclusao). O corretor era um nome digitado (`owner`), sem garantia de que existe nem de que e corretor.

**DEPOIS**

usuario(**id_usuario**, nm_usuario, …) · telefone (caso 2.1) · corretor(**_id_usuario_**, nr_creci, …) · conversa(**id_conversa**, _id_cliente_, _id_corretor_, _id_estagio_, st_conversa, ds_notas, dt_inicio)

| id_conversa | id_cliente | id_corretor | id_estagio | dt_inicio |
|---|---|---|---|---|
| 1 | 24 | 4 | 6 | 2025-08-18 |
| 44 | 24 | 4 | 2 | 2026-09-21 |

A conversa guarda so chaves estrangeiras: o nome do cliente e o do corretor existem uma vez, em usuario. O mesmo raciocinio trocou `stage` (texto) por id_estagio → funil_estagio, com o historico em historico_estagio (RN13, RN14).

### Caso 3.2 — Cidade e UF dependentes do CEP

*Onde aconteceu:* nossa 1a entrega (IMOVEL com nr_cep, nm_cidade e sg_uf; PERFIL_INTERESSE com a cidade digitada).

**ANTES**

imovel(**id_imovel**, nm_logradouro, nr_endereco, nm_bairro, nr_cep, **nm_cidade**, **sg_uf**, …)

| id_imovel | nm_logradouro | nr_endereco | nm_bairro | nr_cep | nm_cidade | sg_uf |
|---|---|---|---|---|---|---|
| 101 | Rua Tuiuti | 450 | Tatuape | 03310000 | Sao Paulo | SP |
| 119 | Rua Tuiuti | 620 | Tatuape | 03310000 | Sao Paulo | SP |
| 107 | Rua Serra de Japi | 88 | Tatuape | 03320010 | Sao Paulo | SP |
| 125 | Rua Serra de Japi | 200 | Tatuape | 03320010 | Sao Paulo | SP |

**DEPENDENCIAS**

id_imovel → nr_cep · nr_cep → nm_cidade, sg_uf

Logo id_imovel → nr_cep → nm_cidade, sg_uf: dependencia transitiva.

**PROBLEMA**

nm_cidade e sg_uf sao “campos carona”: dependem do CEP, e nao do imovel (viola a 3FN). A cidade se repete em cada imovel; corrigir a grafia exige alterar todos os imoveis daquele CEP (basta esquecer um para “Sao Paulo” e “Sao Paulo” conviverem e a busca por cidade falhar); nao da para registrar a cidade de um CEP sem imovel nele; e o perfil de interesse, com a cidade digitada, deixa de casar com o imovel quando a grafia difere.

**DEPOIS**

uf(**sg_uf**, nm_uf) · cidade(**id_cidade**, nm_cidade, _sg_uf_) · cep(**nr_cep**, _id_cidade_, tp_cep) · imovel(**id_imovel**, …, _id_bairro_, _nr_cep_) · perfil_interesse(…, _id_cidade_, …)

| cidade: id_cidade | nm_cidade | sg_uf |
|---|---|---|
| 1 | Sao Paulo | SP |
| 2 | Guarulhos | SP |
| 3 | Aruja | SP |

| cep: nr_cep | id_cidade | tp_cep |
|---|---|---|
| 03310000 | 1 | logradouro |
| 03320010 | 1 | logradouro |

| imovel: id_imovel | nm_logradouro | nr_endereco | (bairro) | nr_cep |
|---|---|---|---|---|
| 101 | Rua Tuiuti | 450 | Tatuape | 03310000 |
| 119 | Rua Tuiuti | 620 | Tatuape | 03310000 |
| 107 | Rua Serra de Japi | 88 | Tatuape | 03320010 |
| 125 | Rua Serra de Japi | 200 | Tatuape | 03320010 |

A juncao imovel → cep → cidade devolve a cidade e a UF de cada imovel sem perda, porque nr_cep e a chave de cep e id_cidade e a chave de cidade. O logradouro continua no imovel porque um CEP geral cobre a cidade inteira e nao determina a rua: a dependencia nr_cep → logradouro nao vale para todos os CEPs, entao nao e violacao de 3FN. O bairro, que o CEP tambem nao determina, virou a tabela bairro (caso 1.6), e a UF passou a ser escolhida da tabela uf, com as 27 siglas (revisao final). RN41 e RN42; relacionamentos AGRUPA, COMPREENDE, LOCALIZA e PREFERE.

### Caso 3.3 — Conta a receber ligada ao contrato e ao financiamento do mesmo contrato

*Onde aconteceu:* nossa 1a entrega (relacionamentos GERA RECEITA e LIBERA).

**ANTES**

conta_receber(**id_conta_receber**, _id_contrato_, **_id_contrato_financiamento_**, vl_receber, …)

| id_conta_receber | id_contrato | id_contrato_financiamento | vl_receber |
|---|---|---|---|
| 7 | 7 | 7 | 37500.00 |

**DEPENDENCIAS**

id_conta_receber → id_contrato · id_contrato → financiamento (a chave do financiamento e o proprio contrato, RN22)

Logo id_conta_receber → id_contrato → id_contrato_financiamento: transitiva.

**PROBLEMA**

A FK de LIBERA repetia um dado determinado por id_contrato, que nao e chave da conta (viola a 3FN). Pior: as duas colunas podiam se contradizer (a conta do contrato 7 apontando para o financiamento do contrato 8).

**DEPOIS**

conta_receber(**id_conta_receber**, _id_contrato_, vl_receber, …) · financiamento(**_id_contrato_**, _id_instituicao_, vl_financiado, …)

| financiamento: id_contrato | id_instituicao | vl_financiado | st_financiamento |
|---|---|---|---|
| 7 | 12 | 600000.00 | liberado |
| 8 | 13 | 416000.00 | reprovado |

LIBERA foi removido sem perder informacao: o financiamento de uma conta e encontrado pelo contrato da conta (financiamento.id_contrato = conta_receber.id_contrato). RN23 e RN27 foram reescritas.

### Caso 3.4 — Atributos derivados

*Onde aconteceu:* nosso DER (atributos derivados vl_corretagem, vl_comissao, st_conta, st_conciliacao e dt_atualizacao).

**ANTES**

contrato(**id_contrato**, …, vl_final, pc_corretagem, **vl_corretagem**)

| id_contrato | vl_final | pc_corretagem | vl_corretagem |
|---|---|---|---|
| 6 | 620000.00 | 6.00 | 37200.00 |
| 7 | 750000.00 | 5.00 | 37500.00 |

**DEPENDENCIAS**

id_contrato → vl_final, pc_corretagem · (vl_final, pc_corretagem) → vl_corretagem

vl_corretagem e determinado por outros atributos nao chave.

**PROBLEMA**

Guardado, vl_corretagem dependeria de atributos nao chave (viola a 3FN) e ficaria errado se alguem corrigisse o valor final sem recalcular. O mesmo vale para vl_comissao (do percentual da comissao e da corretagem), st_conta (das baixas) e st_conciliacao (da conferencia das baixas).

**DEPOIS**

contrato(**id_contrato**, …, vl_final, pc_corretagem) e a visao vw_contrato, que calcula vl_corretagem na hora da consulta; idem vw_comissao, vw_conta_receber, vw_conta_pagar, vw_movimento_bancario e vw_conversa.

| vw_contrato: id_contrato | vl_final | pc_corretagem | vl_corretagem (calculado) |
|---|---|---|---|
| 6 | 620000.00 | 6.00 | 37200.00 |
| 7 | 750000.00 | 5.00 | 37500.00 |

Nenhum atributo derivado e armazenado (script `sql/ddl/05_visoes.sql`).

### Caso 3.5 — Natureza do lancamento dependente da categoria

*Onde aconteceu:* revisao final: conferindo o modelo para a apresentacao.

**ANTES**

conta_pagar(**id_conta_pagar**, …, _id_categoria_, **tp_despesa**, …) e conta_receber(**id_conta_receber**, …, _id_categoria_, **tp_origem_receita**, …)

| id_conta_pagar | id_categoria | (nm_categoria) | tp_despesa |
|---|---|---|---|
| 1 | 7 | Comissao de corretor | comissao |
| 9 | 9 | Despesa operacional | despesa |
| 14 | 10 | Imposto | imposto |
| 16 | 8 | Repasse de aluguel | repasse |

**DEPENDENCIAS**

id_conta_pagar → id_categoria · id_categoria → tp_despesa (cada categoria e de uma natureza so)

Logo id_conta_pagar → id_categoria → tp_despesa: dependencia transitiva.

**PROBLEMA**

tp_despesa dependia da categoria, e nao da conta (viola a 3FN). Nada impedia a contradicao (categoria Imposto com tipo repasse), e as regras dos gatilhos olhavam o tipo enquanto os relatorios olhavam a categoria. A mesma coisa acontecia com tp_origem_receita na conta a receber. E a RN26 (conta a receber usa categoria de receita) estava escrita, mas nao era garantida pelo banco.

**DEPOIS**

conta_pagar(**id_conta_pagar**, …, _id_categoria_, …) · conta_receber(**id_conta_receber**, …, _id_categoria_, …) · categoria_financeira(**id_categoria**, cd_categoria, nm_categoria, tp_categoria)

| categoria_financeira: id_categoria | cd_categoria | nm_categoria | tp_categoria |
|---|---|---|---|
| 1 | corretagem_venda | Corretagem de venda | receita |
| 2 | intermediacao_locacao | Intermediacao de locacao | receita |
| 3 | aluguel | Aluguel | receita |
| 4 | taxa_administracao | Taxa de administracao | receita |
| 5 | multa_rescisoria | Multa rescisoria | receita |
| 6 | servico | Servicos | receita |
| 7 | comissao | Comissao de corretor | despesa |
| 8 | repasse | Repasse de aluguel | despesa |
| 9 | despesa_operacional | Despesa operacional | despesa |
| 10 | imposto | Imposto | despesa |

A natureza do lancamento fica so na categoria. O codigo (cd_categoria) e fixo e e por ele que os gatilhos encontram a categoria do aluguel, do repasse e da multa; o nome pode ser editado sem quebrar nada. A RN26 passou a ser conferida por gatilho (tg_conta_receber_categoria e tg_conta_pagar_categoria), e o codigo nao muda depois de criado (tg_categoria_financeira_estavel).

## O que parece redundancia, mas nao e

| Situacao | Por que fica |
|---|---|
| proposta.vl_anunciado e contrato.vl_final | Valores congelados no momento da proposta e do contrato. Dependem da proposta e do contrato, e nao do preco atual do imovel, que pode mudar depois (PO03). |
| conta_receber.tp_papel_pagador e conta_pagar.tp_papel_custeio | Dizem em que papel a pessoa paga ou arca com aquela conta. Uma pessoa pode ser cliente e proprietaria ao mesmo tempo, entao o papel nao e determinado pelo usuario (RN27, RN28). |
| O bairro no imovel (id_bairro) e nos perfis (perfil_interesse_bairro) | No imovel e o bairro onde ele fica; no perfil, os bairros que o cliente aceita. Sao fatos diferentes, e os dois apontam para a mesma tabela bairro: o nome existe uma vez so. |
| O imovel chega a cidade por dois caminhos (bairro → cidade e CEP → cidade) | A cidade nao e coluna do imovel, entao nao ha fato repetido nele. O que poderia acontecer e os dois caminhos levarem a cidades diferentes; o gatilho da RN51 impede isso. |
| O mesmo nr_telefone em duas pessoas (casal) | Cada linha e o telefone de uma pessoa. Nenhum atributo depende so do numero (o tipo nao e guardado), entao nao ha fato repetido; a unica regra do numero, um titular, e garantida entre as linhas (RN03). |
| conversa.id_estagio e historico_estagio | Redundancia controlada: o estagio atual e sempre o do registro mais recente do historico (RN14). Fica na conversa para o kanban nao precisar procurar o ultimo registro de cada conversa; as duas gravacoes acontecem na mesma transacao, e a consulta de auditoria A11 confere se batem. |
| conta_pagar.vl_pagar e dt_vencimento do repasse | Calculados quando o repasse e gerado (valor recebido menos a taxa de administracao; 5 dias uteis depois do recebimento) e congelados: se a taxa do contrato mudar, o repasse ja gerado nao muda (RN30). |
| recebimento.id_conta e movimento_bancario.id_conta | Nao e repeticao: a FK composta (id_conta, nr_movimento) usa a propria conta da baixa, e e isso que garante que o movimento conciliado e da mesma conta bancaria (RN45). |

## Resultado

| Caso | Forma normal | Origem | Tabelas criadas ou alteradas |
|---|---|---|---|
| 1.1 | 1FN | app original | conversa_imovel |
| 1.2 | 1FN | app original e 1a entrega | 8 subtipos de usuario |
| 1.3 | 1FN | 1a entrega | auditoria_campo |
| 1.4 | 1FN | DER | imovel (colunas do endereco) |
| 1.5 | 1FN | revisao final | tipo_imovel, perfil_interesse_tipo |
| 1.6 | 1FN | revisao final | bairro, perfil_interesse_bairro, imovel (id_bairro) |
| 2.1 | 2FN | devolutiva e revisao final | telefone (entidade fraca de usuario; usuario_telefone removida) |
| 3.1 | 3FN | app original | usuario, conversa, funil_estagio, historico_estagio |
| 3.2 | 3FN | 1a entrega (uf na revisao final) | uf, cidade, cep, imovel, perfil_interesse |
| 3.3 | 3FN | 1a entrega | conta_receber (LIBERA removido) |
| 3.4 | 3FN | DER | 6 visoes |
| 3.5 | 3FN | revisao final | conta_receber e conta_pagar (tipos removidos), categoria_financeira (cd_categoria) |

As 50 tabelas do modelo final estao na 3FN. A conferencia foi feita tabela por tabela (quadro da 2FN acima e dependencias no dicionario de dados), e o modelo normalizado e exatamente o que foi instalado e testado no PostgreSQL.

**Por que criar tabelas nao basta?** Uma tabela aceita dados mesmo guardando o mesmo fato em varios lugares: o `conversations` do app original funcionava, mas o nome do cliente dependia do telefone, e nao do atendimento. Essa dependencia escondida gera redundancia, e a redundancia abre espaco para anomalias. A normalizacao decide onde cada fato deve ficar a partir das dependencias entre os atributos; as restricoes e os gatilhos (Etapa 12) completam a garantia para as regras que envolvem mais de uma linha.
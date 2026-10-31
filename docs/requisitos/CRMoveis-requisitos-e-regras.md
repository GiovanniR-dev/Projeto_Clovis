# CRMoveis — Requisitos e regras de negocio

Projeto Integrador — Modelagem de Dados · Prof. Clovis

**Equipe:** Giovanni Correa Rodrigues · Julio Cesar Ferreira do Nascimento · Anderson da Silva · Fellipe da Eira Aguiar · Leonardo Vinicius de Farias · Guilherme Lucas Correa · Joao Vitor Candido Cassiano · Kayky Fernandes de Andrade · Gabriel Rocha da Silva · Davi Costa Ferraz

**Como ler.** Cada requisito funcional indica o fluxograma em que aparece e as entidades do DER que o atendem. Cada regra de negocio indica onde aparece no modelo: uma cardinalidade, um atributo ou uma restricao.

**Fluxogramas:** F1 Atendimento de um novo contato pelo WhatsApp · F2 Captacao de imovel · F3 Visita e proposta · F4 Venda: contrato, financiamento e comissao · F5 Locacao: ciclo mensal do aluguel · F6 Conciliacao bancaria

**Revisao final (antes da apresentacao):** RF01, RF03, RF04, RF13 e RF26 foram atualizados e o RF37 (busca de imoveis) entrou; RN03, RN22 e RN26 foram reescritas e entraram RN47 (tipos do perfil), RN48 (tipo do imovel), RN49 (origem do contato) e RN50 (forma de pagamento).

## 1. Requisitos funcionais

O que o sistema deve fazer. A coluna *Fluxo* indica em qual fluxograma o requisito aparece; o traco (—) marca requisito transversal ou de consulta, que nao e etapa de nenhum fluxo.

### Pessoas

| Codigo | Requisito | Fluxo | Entidades |
|---|---|---|---|
| RF01 | O sistema devera cadastrar usuarios com nome, documento (CPF/CNPJ), e-mail e origem do contato, escolhida do cadastro de origens. | F1, F2 | USUARIO, ORIGEM_CONTATO |
| RF02 | O sistema devera permitir que um mesmo usuario exerca mais de um papel (cliente, proprietario, inquilino, corretor, financeiro, fornecedor, administrador ou instituicao financeira) e so aceitar a pessoa, em cada operacao, no papel que ela exerce. | F1, F2 | USUARIO e os subtipos CLIENTE, PROPRIETARIO, INQUILINO, CORRETOR, FINANCEIRO, FORNECEDOR, ADMINISTRADOR e INSTITUICAO_FINANCEIRA |
| RF03 | O sistema devera registrar os telefones de cada usuario, permitir que o mesmo numero esteja no cadastro de mais de uma pessoa e identificar quem escreveu pelo titular do numero de WhatsApp. | F1 | TELEFONE |
| RF04 | O sistema devera registrar os perfis de interesse do cliente: finalidade, um ou mais tipos de imovel, cidade, um ou mais bairros, faixa de valor e quartos. | F1 | PERFIL_INTERESSE, TIPO_IMOVEL, CIDADE, BAIRRO, CLIENTE |

### Atendimento e funil

| Codigo | Requisito | Fluxo | Entidades |
|---|---|---|---|
| RF05 | O sistema devera receber as mensagens do WhatsApp, por meio do N8N, e registra-las na conversa do cliente. | F1 | CONVERSA, MENSAGEM |
| RF06 | O sistema devera abrir uma nova conversa ou retomar a conversa existente do cliente. | F1 | CONVERSA |
| RF07 | O sistema devera posicionar cada conversa em um estagio do funil de vendas e permitir move-la entre estagios. | F1 | FUNIL_ESTAGIO |
| RF08 | O sistema devera registrar cada mudanca de estagio, com data, hora e usuario responsavel. | F1 | HISTORICO_ESTAGIO |
| RF09 | O sistema devera permitir classificar conversas com etiquetas (tags). | — | TAG |
| RF10 | O sistema devera criar tarefas para os corretores, com prazo e situacao, ligadas ou nao a uma conversa. | F1, F2, F4 | TAREFA |
| RF11 | O sistema devera interpretar a demanda do cliente e sugerir automaticamente imoveis compativeis com o perfil de interesse. | F1 | AUTOMACAO_EXECUCAO, CONVERSA_IMOVEL |
| RF12 | O sistema devera registrar cada execucao da automacao e os eventos tecnicos de cada execucao. | F1 | AUTOMACAO_EXECUCAO, AUTOMACAO_LOG |

### Imoveis

| Codigo | Requisito | Fluxo | Entidades |
|---|---|---|---|
| RF13 | O sistema devera cadastrar imoveis com tipo (escolhido do cadastro de tipos), endereco com o bairro escolhido do cadastro de bairros, caracteristicas, finalidade (venda, locacao ou ambas), valores de venda e/ou de aluguel e situacao. | F2 | IMOVEL, TIPO_IMOVEL, BAIRRO, CARACTERISTICA, CEP, CIDADE |
| RF14 | O sistema devera importar e atualizar os imoveis a partir do IMOBIZI. | F2 | IMOVEL, CEP |
| RF15 | O sistema devera anexar fotos aos imoveis, na ordem de exibicao. | F2 | FOTO |
| RF16 | O sistema devera registrar o proprietario e o corretor responsavel de cada imovel. | F2 | IMOVEL, PROPRIETARIO, CORRETOR |
| RF17 | O sistema devera registrar os imoveis de interesse de cada conversa. | F1 | CONVERSA_IMOVEL |
| RF37 | O sistema devera buscar os imoveis cadastrados por tipo, finalidade, cidade, bairro, situacao, numero minimo de quartos e por texto (codigo, bairro, rua ou proprietario). | F2 | IMOVEL, TIPO_IMOVEL, BAIRRO, CEP, CIDADE |

### Negociacao

| Codigo | Requisito | Fluxo | Entidades |
|---|---|---|---|
| RF18 | O sistema devera agendar, registrar a realizacao e cancelar visitas, guardando o feedback do cliente. | F3 | VISITA |
| RF19 | O sistema devera registrar propostas e contrapropostas, ligadas ou nao a uma visita, guardando o valor anunciado do imovel no momento da proposta e ligando cada contraproposta a proposta que ela responde. | F3 | PROPOSTA |
| RF20 | O sistema devera gerar o contrato de venda ou de locacao a partir de uma proposta aceita, com percentual de corretagem ou taxa de administracao. | F3, F4 | CONTRATO |
| RF21 | O sistema devera anexar documentos ao contrato, cada um classificado por um tipo do cadastro de tipos de documento. | F4 | DOCUMENTO, TIPO_DOCUMENTO |
| RF22 | O sistema devera registrar a comissao de cada corretor no contrato, com percentual sobre a corretagem, regra de pagamento e aprovacao do administrador. | F4 | COMISSAO, CORRETOR, ADMINISTRADOR |
| RF33 | O sistema devera cancelar, rescindir e encerrar contratos, registrando a data, o motivo e, na rescisao, quem pediu, e aplicar os efeitos de cada caso sobre o imovel, as comissoes e os lancamentos. | F4, F5 | CONTRATO, IMOVEL, COMISSAO, CONTA_RECEBER, CONTA_PAGAR |

### Financeiro

| Codigo | Requisito | Fluxo | Entidades |
|---|---|---|---|
| RF23 | O sistema devera registrar o financiamento do contrato: instituicao financeira, valor financiado, entrada, parcelas, taxa, aprovacao e liberacao do credito. | F4 | FINANCIAMENTO, INSTITUICAO_FINANCEIRA |
| RF24 | O sistema devera gerar contas a receber (corretagem, intermediacao, taxa de administracao, aluguel e servicos), indicando quem paga. | F4, F5 | CONTA_RECEBER |
| RF25 | O sistema devera gerar contas a pagar (comissao, repasse ao proprietario, despesas e impostos), indicando quem paga e quem recebe. | F4, F5 | CONTA_PAGAR |
| RF26 | O sistema devera registrar recebimentos e pagamentos, inclusive parciais, indicando a forma de pagamento, a conta bancaria movimentada e, nos pagamentos, o usuario que os efetivou. | F4, F5 | RECEBIMENTO, PAGAMENTO, FORMA_PAGAMENTO, CONTA_BANCARIA |
| RF27 | O sistema devera gerar todo mes, nos contratos de locacao, a conta a receber do aluguel e, a cada recebimento do aluguel, inclusive parcial, a conta a pagar do repasse do valor recebido ao proprietario, descontada a taxa de administracao, com vencimento em ate 5 dias uteis. | F5 | CONTA_RECEBER, RECEBIMENTO, CONTA_PAGAR |
| RF28 | O sistema devera liberar a comissao para pagamento somente quando a condicao da regra de pagamento for atendida. | F4 | COMISSAO, CONTA_PAGAR |
| RF29 | O sistema devera classificar cada conta a receber e a pagar em uma categoria financeira. | F4, F5 | CATEGORIA_FINANCEIRA |
| RF36 | O sistema devera importar o extrato de cada conta bancaria e conciliar cada movimento com os recebimentos e pagamentos registrados, apontando o que ficou pendente ou divergente. | F6 | MOVIMENTO_BANCARIO, RECEBIMENTO, PAGAMENTO, CONTA_BANCARIA |

### Consultas e relatorios

| Codigo | Requisito | Fluxo | Entidades |
|---|---|---|---|
| RF30 | O sistema devera emitir relatorio de conversao do funil por estagio e por periodo. | — | HISTORICO_ESTAGIO |
| RF31 | O sistema devera emitir relatorio financeiro com valores a receber, recebidos, a pagar e pagos por periodo. | — | CONTA_RECEBER, CONTA_PAGAR |
| RF32 | O sistema devera permitir consultar o historico de atendimentos, visitas, propostas e contratos de um cliente. | — | CONVERSA, VISITA, PROPOSTA, CONTRATO |

### Auditoria e privacidade

| Codigo | Requisito | Fluxo | Entidades |
|---|---|---|---|
| RF34 | O sistema devera registrar quem criou, alterou ou cancelou contratos, propostas, comissoes e lancamentos financeiros, e quando, ligando cada registro ao contrato, proposta, comissao, conta, recebimento ou pagamento afetado e guardando os campos alterados. | — | AUDITORIA, AUDITORIA_CAMPO |
| RF35 | O sistema devera anonimizar os dados pessoais de um usuario a pedido do titular quando houver obrigacao de guarda dos registros (contratos e lancamentos financeiros), e excluir o cadastro quando nao houver. | — | USUARIO, TELEFONE, MENSAGEM |

## 2. Requisitos nao funcionais

Como o sistema deve funcionar. Os valores de tempo e disponibilidade sao metas propostas pela equipe.

| Codigo | Categoria | Requisito |
|---|---|---|
| RNF01 | Controle de acesso | O sistema devera controlar o acesso por perfil (administrador, corretor e financeiro), liberando a cada perfil apenas as funcoes e os dados de que ele precisa. |
| RNF02 | Seguranca | O sistema devera armazenar as senhas somente na forma de hash, nunca em texto. |
| RNF03 | Privacidade (LGPD) | O sistema devera tratar os dados pessoais (CPF/CNPJ, telefone e e-mail) conforme a LGPD, permitindo ao titular consultar, corrigir e solicitar a exclusao ou anonimizacao de seus dados (RF35, PO07). |
| RNF04 | Auditoria | Os registros de auditoria (RF34) deverao ser somente de inclusao: nenhum perfil podera altera-los ou exclui-los. |
| RNF05 | Tempo de resposta | O sistema devera enviar a resposta automatica ao cliente no WhatsApp em ate 10 segundos apos o recebimento da mensagem, em condicoes normais de uso. |
| RNF06 | Desempenho | As consultas de cadastro, funil e contas deverao ser apresentadas em ate 3 segundos, para uso no atendimento. |
| RNF07 | Disponibilidade | O sistema devera funcionar 24 horas por dia, com meta de 99% de disponibilidade mensal, porque o atendimento pelo WhatsApp acontece tambem fora do horario comercial. |
| RNF08 | Confiabilidade | O sistema nao devera processar a mesma demanda da automacao mais de uma vez. |
| RNF09 | Copia de seguranca | O banco de dados devera ter copia de seguranca diaria, guardada por pelo menos 30 dias. |
| RNF10 | Usabilidade | O sistema devera ser web e responsivo, utilizavel no celular pelos corretores durante visitas. |
| RNF11 | Integracao | A integracao com o WhatsApp e com o IMOBIZI devera ocorrer por meio do N8N, sem redigitacao manual dos dados. |
| RNF12 | Precisao financeira | Os valores financeiros deverao ser armazenados com duas casas decimais, sem arredondamentos intermediarios nos calculos de comissao e repasse. |
| RNF13 | Integridade transacional | As regras que envolvem mais de um registro (papel exigido em cada operacao, soma das comissoes, repasse a cada recebimento, termino do contrato, conciliacao e referencia da auditoria) deverao ser garantidas pelo proprio banco de dados, com chaves, restricoes, gatilhos (triggers) e transacoes, e nao so pela tela. |

## 3. Regras de negocio

O que pode ou nao pode acontecer. A ultima coluna mostra onde a regra aparece no DER. Nas cardinalidades, o par (min,max) escrito junto de uma entidade indica quantas vezes uma ocorrencia dela participa do relacionamento, isto e, com quantas ocorrencias da outra entidade ela se relaciona (convencao detalhada na secao 14 do README da primeira entrega).

### Pessoas

| Codigo | Regra | Onde aparece no modelo |
|---|---|---|
| RN01 | Toda pessoa registrada no CRM e um usuario e deve exercer pelo menos um papel. | Especializacao total (t) de USUARIO |
| RN02 | A mesma pessoa pode exercer varios papeis ao mesmo tempo, por exemplo ser cliente e proprietaria. Cada papel guarda a data em que a pessoa passou a exerce-lo e, se deixar de exercer, a data de fim; o papel nunca e apagado, para nao perder os registros ligados a ele. | Especializacao compartilhada (c) de USUARIO em CLIENTE, PROPRIETARIO, INQUILINO, CORRETOR, FINANCEIRO, FORNECEDOR, ADMINISTRADOR e INSTITUICAO_FINANCEIRA · dt_inicio, dt_fim |
| RN03 | Um usuario pode ter varios telefones, e o mesmo numero pode estar no cadastro de mais de uma pessoa (por exemplo, um casal ou os socios de uma empresa). Entre as pessoas que usam o mesmo numero, exatamente uma e a titular: e pelo titular do numero de WhatsApp que a automacao identifica quem enviou a mensagem. Cada pessoa tem no maximo um telefone principal. O numero nao identifica o telefone: quem o identifica e a pessoa + a sequencia. | USUARIO (0,n) — POSSUI — (1,1) TELEFONE (entidade fraca) · um titular por numero · um principal por pessoa |
| RN04 | O documento (CPF/CNPJ) nao pode se repetir e e obrigatorio para proprietarios, para instituicoes financeiras e para quem assina contrato. | USUARIO.nr_cpf_cnpj unico |
| RN05 | Um cliente pode ter nenhum ou varios perfis de interesse. | CLIENTE (0,n) — BUSCA — (1,1) PERFIL_INTERESSE |
| RN32 | Cada relacionamento que exige um papel liga-se ao subtipo correspondente, e nao a USUARIO: PROPRIETARIO em ANUNCIA; CORRETOR em RESPONSAVEL, ATENDE, EXECUTA, ACOMPANHA, NEGOCIA e RECEBE; CLIENTE em BUSCA, INICIA, VISITA e PROPOE; ADMINISTRADOR em AUTORIZA e APROVA; INSTITUICAO_FINANCEIRA em CONCEDE. Assim, a ligacao so e aceita se a pessoa exercer aquele papel. Nos relacionamentos que aceitam mais de um papel (PAGA, CUSTEIA e EFETIVA), o papel fica num atributo e a pessoa precisa exerce-lo. Novos registros so aceitam papeis sem data de fim. | Relacionamentos com os subtipos de USUARIO · tp_papel_pagador, tp_papel_custeio |
| RN33 | O cliente passa a ser tambem INQUILINO quando o contrato de locacao e assinado e recebe a data de fim desse papel quando o contrato e encerrado ou rescindido; o banco passa a ser INSTITUICAO_FINANCEIRA quando concede um financiamento. | INQUILINO.dt_inicio, dt_fim · INSTITUICAO_FINANCEIRA |
| RN42 | O perfil de interesse pode indicar no maximo uma cidade, escolhida do cadastro de cidades, para que a comparacao com a cidade do imovel seja exata. | CIDADE (0,n) — PREFERE — (0,1) PERFIL_INTERESSE |
| RN47 | Um perfil de interesse pode aceitar nenhum, um ou varios tipos de imovel, escolhidos do cadastro de tipos. O perfil sem nenhum tipo aceita qualquer tipo. | PERFIL_INTERESSE (0,n) — DESEJA — (0,n) TIPO_IMOVEL |
| RN49 | A origem do contato, quando informada, e escolhida do cadastro de origens (site, indicacao, portal, Instagram, WhatsApp...), para que os relatorios de captacao agrupem sem erro de digitacao. | ORIGEM_CONTATO (0,n) — CAPTA — (0,1) USUARIO |
| RN52 | Um perfil de interesse pode aceitar nenhum, um ou varios bairros, escolhidos do cadastro de bairros e todos da cidade do perfil. O perfil sem bairro aceita qualquer bairro da cidade. | PERFIL_INTERESSE (0,n) — ABRANGE — (0,n) BAIRRO · bairro da cidade do perfil |

### Imoveis

| Codigo | Regra | Onde aparece no modelo |
|---|---|---|
| RN06 | Todo imovel tem exatamente um proprietario, e um proprietario pode ter varios imoveis. Imoveis com mais de um proprietario (copropriedade) ficam fora do escopo desta entrega. | PROPRIETARIO (0,n) — ANUNCIA — (1,1) IMOVEL |
| RN07 | Um imovel pode ter nenhum ou um corretor responsavel, e um corretor pode ser responsavel por varios imoveis. | CORRETOR (0,n) — RESPONSAVEL — (0,1) IMOVEL |
| RN08 | Um imovel pode ter varias caracteristicas, e uma caracteristica pode estar em varios imoveis. | IMOVEL (0,n) — APRESENTA — (0,n) CARACTERISTICA |
| RN09 | Uma foto so existe vinculada a um imovel. | FOTO · entidade fraca |
| RN10 | Imovel vendido, alugado ou inativo nao pode receber novas visitas nem propostas. | IMOVEL.st_imovel |
| RN41 | Todo imovel esta em exatamente um CEP, todo CEP pertence a exatamente uma cidade, e toda cidade, a exatamente uma UF, escolhida do cadastro das 27 unidades federativas. A cidade e a UF do imovel nao sao digitadas no imovel: sao obtidas pelo CEP. | CEP (0,n) — LOCALIZA — (1,1) IMOVEL · CIDADE (0,n) — AGRUPA — (1,1) CEP · UF (0,n) — COMPREENDE — (1,1) CIDADE |
| RN48 | Todo imovel e de exatamente um tipo, escolhido do cadastro de tipos de imovel mantido pela imobiliaria. Um tipo que ja classifica imoveis ou perfis nao pode ser excluido. | TIPO_IMOVEL (0,n) — TIPIFICA — (1,1) IMOVEL |
| RN51 | Todo imovel fica em exatamente um bairro, escolhido do cadastro de bairros, e o bairro tem de ser da cidade do CEP do imovel. O nome do bairro nao se repete dentro da mesma cidade, mas pode existir em cidades diferentes (Centro de Guarulhos e Centro de Aruja). | CIDADE (0,n) — DIVIDE — (1,1) BAIRRO (0,n) — SITUA — (1,1) IMOVEL · bairro da cidade do CEP |

### Atendimento e funil

| Codigo | Regra | Onde aparece no modelo |
|---|---|---|
| RN11 | Toda conversa pertence a exatamente um cliente, e um cliente pode ter varias conversas. | CLIENTE (0,n) — INICIA — (1,1) CONVERSA |
| RN12 | A conversa pode ficar sem corretor no inicio do atendimento, mas nunca tera mais de um corretor responsavel. | CORRETOR (0,n) — ATENDE — (0,1) CONVERSA |
| RN13 | Toda conversa esta em exatamente um estagio do funil por vez. | CONVERSA (1,1) — PERTENCE A — (0,n) FUNIL_ESTAGIO |
| RN14 | Toda mudanca de estagio, inclusive o estagio inicial na abertura da conversa, deve gerar um registro no historico, com data e hora; o estagio atual da conversa e sempre o do registro mais recente. | HISTORICO_ESTAGIO · PERTENCE A = ultimo registro |
| RN15 | Toda tarefa tem um corretor responsavel e pode ou nao estar ligada a uma conversa. | CORRETOR (0,n) — EXECUTA — (1,1) TAREFA · CONVERSA (0,n) — GERA TAREFA — (0,1) TAREFA |
| RN34 | Uma conversa fica aberta ate ser encerrada pelo corretor ou por inatividade (prazo definido pela imobiliaria). A mensagem de um cliente que tem conversa aberta retoma essa conversa; se nao houver conversa aberta, o sistema abre uma nova. | CONVERSA.st_conversa |

### Negociacao

| Codigo | Regra | Onde aparece no modelo |
|---|---|---|
| RN16 | Uma visita envolve exatamente um cliente, um imovel e um corretor; o mesmo cliente pode visitar o mesmo imovel mais de uma vez, em datas diferentes. | VISITA · associativa entre CLIENTE e IMOVEL, com CORRETOR (ACOMPANHA) · unico (imovel, cliente, data e hora) |
| RN17 | Uma proposta pode ou nao ter origem em uma visita; quando tem, o cliente e o imovel da proposta sao os mesmos da visita. | VISITA (0,n) — ORIGINA — (0,1) PROPOSTA |
| RN18 | Uma proposta aceita gera no maximo um contrato, e todo contrato nasce de exatamente uma proposta. | PROPOSTA (0,1) — FECHA — (1,1) CONTRATO |
| RN19 | Todo contrato e de venda ou de locacao, e o contrato de locacao deve ter data de inicio, data de termino, taxa de administracao e dia de vencimento do aluguel. | CONTRATO.tp_contrato, dt_inicio, dt_fim, pc_administracao, nr_dia_vencimento |
| RN20 | A comissao de um contrato pode ser dividida entre varios corretores, e a soma dos percentuais nao pode passar de 100% da corretagem do contrato. As comissoes canceladas nao entram na soma. A soma e conferida pelo banco a cada gravacao, com o contrato bloqueado, e a gravacao que passar de 100% e recusada. | CONTRATO (0,n) — RECEBE (COMISSAO) — (0,n) CORRETOR · gatilho de soma (17.30, secao 19) |
| RN21 | O valor da comissao e o percentual do corretor aplicado sobre a corretagem do contrato (valor final × percentual de corretagem), e nao sobre o valor do imovel. | COMISSAO.vl_comissao · derivado de CONTRATO.vl_corretagem |
| RN35 | Uma contraproposta e uma nova proposta ligada a proposta que ela responde. Cada proposta recebe no maximo uma contraproposta, e a proposta respondida passa a situacao “substituida”. | PROPOSTA (0,1) — RESPONDE — (0,1) PROPOSTA · recursivo |
| RN36 | O contrato nasce como rascunho e so e considerado assinado quando a data de assinatura e registrada. Somente contratos assinados geram comissoes, contas a receber e contas a pagar. | CONTRATO.st_contrato, dt_assinatura |
| RN37 | Cancelar e desfazer o contrato antes de ele produzir efeitos (por exemplo, um rascunho de que se desistiu ou uma venda cujo financiamento foi negado). Registram-se a data e o motivo; as contas a receber e a pagar sem nenhuma baixa e as comissoes ainda nao pagas sao canceladas; os valores ja recebidos ou pagos sao mantidos, e qualquer devolucao e feita por um novo lancamento; o imovel volta a situacao “disponivel”. | CONTRATO.st_contrato = cancelado, dt_termino, ds_motivo_termino · CONTA_*.fl_cancelada · COMISSAO.st_comissao |
| RN43 | Rescindir e terminar antes do prazo um contrato vigente, por pedido de uma das partes ou de comum acordo (por exemplo, o inquilino que sai antes do fim da locacao). Registram-se a data, o motivo e quem pediu; o sistema deixa de gerar alugueis a partir da data da rescisao e cancela as contas de periodos futuros; as contas ja vencidas continuam devidas; os repasses de valores ja recebidos continuam devidos; se o contrato preve multa rescisoria, ela e lancada como conta a receber; as comissoes ja liberadas sao mantidas e as pendentes sao canceladas; o imovel volta a “disponivel” e o papel de inquilino recebe a data de fim. | CONTRATO.st_contrato = rescindido, dt_termino, ds_motivo_termino, tp_iniciativa_rescisao |
| RN44 | Encerrar e o termino normal do contrato: na locacao, ao chegar a data de termino sem renovacao; na venda, quando todas as contas do contrato estao quitadas. Nenhum lancamento e cancelado; na locacao, o imovel volta a “disponivel” e o papel de inquilino recebe a data de fim; na venda, o imovel fica “vendido”. | CONTRATO.st_contrato = encerrado, dt_termino |
| RN53 | Todo documento anexado ao contrato e de exatamente um tipo, escolhido do cadastro de tipos de documento (contrato assinado, documento do cliente, matricula do imovel, laudo de vistoria...). | TIPO_DOCUMENTO (0,n) — QUALIFICA — (1,1) DOCUMENTO |

### Financeiro

| Codigo | Regra | Onde aparece no modelo |
|---|---|---|
| RN22 | Um contrato pode ter no maximo um financiamento. O financiamento so existe quando a condicao de pagamento do contrato e “financiado”, e todo contrato “financiado” tem financiamento. | CONTRATO (0,1) — FINANCIA — (1,1) FINANCIAMENTO · CONTRATO.tp_condicao_pagamento |
| RN23 | Na venda financiada, a corretagem so e considerada recebida depois que o banco libera o credito: nenhum recebimento da corretagem pode ter data anterior a liberacao do financiamento do mesmo contrato. | FINANCIAMENTO.dt_liberacao · RECEBIMENTO.dt_recebimento · CONTRATO (0,1) — FINANCIA — (1,1) FINANCIAMENTO |
| RN24 | A comissao so e liberada para pagamento quando a condicao da regra de pagamento e atendida: na assinatura, na liberacao do credito ou no recebimento. | COMISSAO.tp_regra_pagamento |
| RN25 | Cada comissao liberada gera no maximo uma conta a pagar ao corretor. | COMISSAO (0,1) — LANCA — (0,1) CONTA_PAGAR |
| RN26 | Toda conta a receber usa uma categoria de receita, e toda conta a pagar, uma categoria de despesa. A categoria define a natureza do lancamento (aluguel, corretagem, repasse, comissao, imposto...), e as regras automaticas encontram as categorias pelo codigo, que nao muda quando o nome e editado. A conta a pagar gerada por um recebimento usa a categoria de repasse. | CATEGORIA_FINANCEIRA (0,n) — CLASSIFICA e CATEGORIZA — (1,1) CONTA_RECEBER e CONTA_PAGAR · CATEGORIA_FINANCEIRA.cd_categoria e tp_categoria |
| RN27 | Toda conta a receber tem um pagador, que e um usuario: cliente, inquilino, proprietario ou banco. Quando o pagador e o banco, a conta deve pertencer a um contrato financiado, e o banco deve ser a instituicao financeira que concedeu esse financiamento; o financiamento e encontrado pelo proprio contrato. O pagador precisa exercer o papel indicado na conta (RN32). | USUARIO (0,n) — PAGA — (1,1) CONTA_RECEBER · CONTA_RECEBER.tp_papel_pagador · INSTITUICAO_FINANCEIRA (0,n) — CONCEDE — (1,1) FINANCIAMENTO |
| RN28 | Toda conta a pagar e paga pela imobiliaria ao favorecido; o atributo de custeio indica quem arca com o valor final: a imobiliaria, o proprietario (descontado do repasse) ou o inquilino (cobrado no aluguel). Quando nao for a imobiliaria, a pessoa que arca com o custo deve ser informada e precisa exercer o papel indicado (RN32). | CONTA_PAGAR.tp_papel_custeio · USUARIO (0,n) — CUSTEIA — (0,1) CONTA_PAGAR |
| RN29 | Uma conta pode ser quitada em varios recebimentos ou pagamentos parciais, sem que a soma passe do valor da conta, e cada baixa deve indicar a conta bancaria movimentada. | CONTA (0,n) — QUITA e LIQUIDA — (1,1) baixa · CONTA_BANCARIA (0,n) — CREDITA e DEBITA — (1,1) baixa |
| RN30 | Na locacao, cada recebimento do aluguel, inclusive parcial, gera uma conta a pagar de repasse ao proprietario com o valor recebido menos a taxa de administracao proporcional. Enquanto nada e recebido, nao ha repasse; o saldo continua na conta a receber do inquilino, e cada novo recebimento gera um novo repasse. O prazo de pagamento de cada repasse e o da PO05, contado do recebimento que o originou. | RECEBIMENTO (0,1) — REPASSA — (0,1) CONTA_PAGAR · CONTRATO.pc_administracao |
| RN38 | A situacao de uma conta (prevista, parcial, quitada ou atrasada) e calculada a partir do valor, das baixas e do vencimento; somente o cancelamento e registrado. | CONTA_RECEBER.st_conta e CONTA_PAGAR.st_conta · derivados · fl_cancelada |
| RN39 | Todo pagamento registra o usuario que o efetivou, que precisa exercer o papel de administrador ou de financeiro; o pagamento de comissoes so pode ser efetivado pelo administrador (PO01). | USUARIO (0,n) — EFETIVA — (1,1) PAGAMENTO · ADMINISTRADOR ou FINANCEIRO |
| RN45 | Cada recebimento e cada pagamento e conferido com um movimento do extrato da mesma conta bancaria e na mesma direcao (credito para recebimento, debito para pagamento). Um movimento pode comprovar varias baixas, e a soma das baixas ligadas a ele nao pode passar do valor do movimento. Movimento sem baixa, ou com baixas que somam menos que o seu valor, fica pendente para analise do financeiro. | MOVIMENTO_BANCARIO (0,n) — CONCILIA — (0,1) RECEBIMENTO · MOVIMENTO_BANCARIO (0,n) — CONFERE — (0,1) PAGAMENTO · st_conciliacao |
| RN46 | O mesmo movimento do extrato nao pode ser importado duas vezes: o codigo da transacao informado pelo banco nao se repete na mesma conta. | CONTA_BANCARIA (0,n) — LISTA — (1,1) MOVIMENTO_BANCARIO · unico (conta, cd_transacao_banco) |
| RN50 | Todo recebimento e todo pagamento tem exatamente uma forma de pagamento, escolhida do mesmo cadastro de formas (Pix, TED, boleto, dinheiro, cartao...). | FORMA_PAGAMENTO (0,n) — RECEBIDO VIA e PAGO VIA — (1,1) RECEBIMENTO e PAGAMENTO |

### Automacao e auditoria

| Codigo | Regra | Onde aparece no modelo |
|---|---|---|
| RN31 | A mesma demanda de uma conversa nao pode ser processada duas vezes pela automacao, e a mesma mensagem do WhatsApp nao pode ser registrada duas vezes na conversa. | AUTOMACAO_EXECUCAO · unico (conversa, cd_demanda) · MENSAGEM.cd_externo |
| RN40 | Toda criacao, alteracao ou cancelamento de contrato, proposta, comissao e lancamento financeiro (conta, recebimento e pagamento) gera um registro de auditoria com o usuario e a data e hora da acao, ligado ao registro afetado por exatamente um dos relacionamentos AUDITA; cada campo alterado e registrado a parte, com o valor anterior e o novo. O registro de auditoria nunca e alterado, e os registros auditados nunca sao excluidos, so cancelados, para que a referencia nao se perca. | USUARIO (0,n) — PRATICA — (1,1) AUDITORIA · AUDITA (sete relacionamentos, exatamente um por registro) · AUDITORIA (0,n) — DETALHA — (1,1) AUDITORIA_CAMPO |

## 4. Restricoes e politicas organizacionais

Decisoes da imobiliaria que o sistema precisa respeitar. Os limites (10% e 5 dias uteis) sao propostas da equipe.

| Codigo | Tipo | Descricao | Area |
|---|---|---|---|
| PO01 | Politica | Somente o administrador pode aprovar e pagar comissoes (relacionamentos APROVA e EFETIVA). | Financeiro |
| PO02 | Politica | O corretor so pode alterar as conversas, visitas e propostas sob sua responsabilidade. | Atendimento e negociacao |
| PO03 | Restricao | Proposta com desconto acima de 10% do valor anunciado no momento da proposta (vl_anunciado) exige autorizacao do administrador (relacionamento AUTORIZA). | Negociacao |
| PO04 | Restricao | Contrato assinado nao pode ser excluido; ele so termina por cancelamento, rescisao ou encerramento, com a data registrada (RN37, RN43, RN44). | Negociacao |
| PO05 | Restricao | O repasse ao proprietario deve ser pago em ate 5 dias uteis apos o recebimento do aluguel. | Financeiro |
| PO06 | Politica | Dados financeiros e documentos pessoais so podem ser consultados pelos perfis administrador e financeiro; o corretor consulta apenas as proprias comissoes. | Acesso a informacao |
| PO07 | Politica | A pedido do titular, os dados pessoais de quem tem contrato, lancamento financeiro ou outra obrigacao legal de guarda sao anonimizados e o registro e mantido; os demais cadastros podem ser excluidos. | Privacidade (LGPD) |

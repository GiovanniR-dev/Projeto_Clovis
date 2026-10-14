# CRMoveis — Requisitos e regras de negócio

Projeto Integrador — Modelagem de Dados · Prof. Clóvis

**Equipe:** Gustavo Amorim · Giovanni Corrêa Rodrigues · Julio Cesar Ferreira do Nascimento · Anderson da Silva · Fellipe da Eira Aguiar · Leonardo Vinicius de Farias · Guilherme Lucas Correa · João Vitor Candido Cassiano · Kayky Fernandes de Andrade · Gabriel Rocha da Silva · Davi Costa Ferraz

**Como ler.** Cada requisito funcional indica o fluxograma em que aparece e as entidades do DER que o atendem. Cada regra de negócio indica onde aparece no modelo: uma cardinalidade, um atributo ou uma restrição.

**Fluxogramas:** F1 Atendimento de um novo contato pelo WhatsApp · F2 Captação de imóvel · F3 Visita e proposta · F4 Venda: contrato, financiamento e comissão · F5 Locação: ciclo mensal do aluguel

## 1. Requisitos funcionais

O que o sistema deve fazer. A coluna *Fluxo* indica em qual fluxograma o requisito aparece; o traço (—) marca requisito transversal ou de consulta, que não é etapa de nenhum fluxo.

### Pessoas

| Código | Requisito | Fluxo | Entidades |
|---|---|---|---|
| RF01 | O sistema deverá cadastrar usuários com nome, documento (CPF/CNPJ), e-mail e origem do contato. | F1, F2 | USUARIO |
| RF02 | O sistema deverá permitir que um mesmo usuário exerça mais de um papel: cliente, proprietário, inquilino, corretor, financeiro, fornecedor, administrador ou instituição financeira. | F1, F2 | USUARIO (papel) |
| RF03 | O sistema deverá registrar um ou mais telefones por usuário e identificar o usuário pelo número do WhatsApp. | F1 | TELEFONE |
| RF04 | O sistema deverá registrar os perfis de interesse do cliente: finalidade, tipo de imóvel, cidade, bairro, faixa de valor e quartos. | F1 | PERFIL_INTERESSE, CIDADE |

### Atendimento e funil

| Código | Requisito | Fluxo | Entidades |
|---|---|---|---|
| RF05 | O sistema deverá receber as mensagens do WhatsApp, por meio do N8N, e registrá-las na conversa do cliente. | F1 | CONVERSA, MENSAGEM |
| RF06 | O sistema deverá abrir uma nova conversa ou retomar a conversa existente do cliente. | F1 | CONVERSA |
| RF07 | O sistema deverá posicionar cada conversa em um estágio do funil de vendas e permitir movê-la entre estágios. | F1 | FUNIL_ESTAGIO |
| RF08 | O sistema deverá registrar cada mudança de estágio, com data, hora e usuário responsável. | F1 | HISTORICO_ESTAGIO |
| RF09 | O sistema deverá permitir classificar conversas com etiquetas (tags). | — | TAG |
| RF10 | O sistema deverá criar tarefas para os corretores, com prazo e situação, ligadas ou não a uma conversa. | F1, F2, F4 | TAREFA |
| RF11 | O sistema deverá interpretar a demanda do cliente e sugerir automaticamente imóveis compatíveis com o perfil de interesse. | F1 | AUTOMACAO_EXECUCAO, CONVERSA_IMOVEL |
| RF12 | O sistema deverá registrar cada execução da automação e os eventos técnicos de cada execução. | F1 | AUTOMACAO_EXECUCAO, AUTOMACAO_LOG |

### Imóveis

| Código | Requisito | Fluxo | Entidades |
|---|---|---|---|
| RF13 | O sistema deverá cadastrar imóveis com endereço, características, finalidade (venda, locação ou ambas), valores de venda e/ou de aluguel e situação. | F2 | IMOVEL, CARACTERISTICA, CEP, CIDADE |
| RF14 | O sistema deverá importar e atualizar os imóveis a partir do IMOBIZI. | F2 | IMOVEL, CEP |
| RF15 | O sistema deverá anexar fotos aos imóveis, na ordem de exibição. | F2 | FOTO |
| RF16 | O sistema deverá registrar o proprietário e o corretor responsável de cada imóvel. | F2 | IMOVEL, USUARIO |
| RF17 | O sistema deverá registrar os imóveis de interesse de cada conversa. | F1 | CONVERSA_IMOVEL |

### Negociação

| Código | Requisito | Fluxo | Entidades |
|---|---|---|---|
| RF18 | O sistema deverá agendar, registrar a realização e cancelar visitas, guardando o feedback do cliente. | F3 | VISITA |
| RF19 | O sistema deverá registrar propostas e contrapropostas, ligadas ou não a uma visita, guardando o valor anunciado do imóvel no momento da proposta e ligando cada contraproposta à proposta que ela responde. | F3 | PROPOSTA |
| RF20 | O sistema deverá gerar o contrato de venda ou de locação a partir de uma proposta aceita, com percentual de corretagem ou taxa de administração. | F3, F4 | CONTRATO |
| RF21 | O sistema deverá anexar documentos ao contrato. | F4 | DOCUMENTO |
| RF22 | O sistema deverá registrar a comissão de cada corretor no contrato, com percentual sobre a corretagem, regra de pagamento e aprovação do administrador. | F4 | COMISSAO |
| RF33 | O sistema deverá cancelar contratos, registrando data e motivo, e cancelar as contas e comissões pendentes ligadas a eles. | F4 | CONTRATO, CONTA_RECEBER, CONTA_PAGAR, COMISSAO |

### Financeiro

| Código | Requisito | Fluxo | Entidades |
|---|---|---|---|
| RF23 | O sistema deverá registrar o financiamento do contrato: instituição financeira, valor financiado, entrada, parcelas, taxa, aprovação e liberação do crédito. | F4 | FINANCIAMENTO, USUARIO (instituição financeira) |
| RF24 | O sistema deverá gerar contas a receber (corretagem, intermediação, taxa de administração, aluguel e serviços), indicando quem paga. | F4, F5 | CONTA_RECEBER |
| RF25 | O sistema deverá gerar contas a pagar (comissão, repasse ao proprietário, despesas e impostos), indicando quem paga e quem recebe. | F4, F5 | CONTA_PAGAR |
| RF26 | O sistema deverá registrar recebimentos e pagamentos, inclusive parciais, indicando a conta bancária movimentada e, nos pagamentos, o usuário que os efetivou. | F4, F5 | RECEBIMENTO, PAGAMENTO, CONTA_BANCARIA |
| RF27 | O sistema deverá gerar todo mês, nos contratos de locação, a conta a receber do aluguel e, após o recebimento, a conta a pagar do repasse ao proprietário, com vencimento em até 5 dias úteis. | F5 | CONTA_RECEBER, CONTA_PAGAR |
| RF28 | O sistema deverá liberar a comissão para pagamento somente quando a condição da regra de pagamento for atendida. | F4 | COMISSAO, CONTA_PAGAR |
| RF29 | O sistema deverá classificar cada conta a receber e a pagar em uma categoria financeira. | F4, F5 | CATEGORIA_FINANCEIRA |

### Consultas e relatórios

| Código | Requisito | Fluxo | Entidades |
|---|---|---|---|
| RF30 | O sistema deverá emitir relatório de conversão do funil por estágio e por período. | — | HISTORICO_ESTAGIO |
| RF31 | O sistema deverá emitir relatório financeiro com valores a receber, recebidos, a pagar e pagos por período. | — | CONTA_RECEBER, CONTA_PAGAR |
| RF32 | O sistema deverá permitir consultar o histórico de atendimentos, visitas, propostas e contratos de um cliente. | — | CONVERSA, VISITA, PROPOSTA, CONTRATO |

### Auditoria e privacidade

| Código | Requisito | Fluxo | Entidades |
|---|---|---|---|
| RF34 | O sistema deverá registrar quem criou, alterou ou cancelou contratos, propostas, comissões e lançamentos financeiros, e quando, com os campos alterados. | — | AUDITORIA, AUDITORIA_CAMPO |
| RF35 | O sistema deverá anonimizar os dados pessoais de um usuário a pedido do titular quando houver obrigação de guarda dos registros (contratos e lançamentos financeiros), e excluir o cadastro quando não houver. | — | USUARIO, TELEFONE, MENSAGEM |

## 2. Requisitos não funcionais

Como o sistema deve funcionar. Os valores de tempo e disponibilidade são metas propostas pela equipe.

| Código | Categoria | Requisito |
|---|---|---|
| RNF01 | Controle de acesso | O sistema deverá controlar o acesso por perfil (administrador, corretor e financeiro), liberando a cada perfil apenas as funções e os dados de que ele precisa. |
| RNF02 | Segurança | O sistema deverá armazenar as senhas somente na forma de hash, nunca em texto. |
| RNF03 | Privacidade (LGPD) | O sistema deverá tratar os dados pessoais (CPF/CNPJ, telefone e e-mail) conforme a LGPD, permitindo ao titular consultar, corrigir e solicitar a exclusão ou anonimização de seus dados (RF35, PO07). |
| RNF04 | Auditoria | Os registros de auditoria (RF34) deverão ser somente de inclusão: nenhum perfil poderá alterá-los ou excluí-los. |
| RNF05 | Tempo de resposta | O sistema deverá enviar a resposta automática ao cliente no WhatsApp em até 10 segundos após o recebimento da mensagem, em condições normais de uso. |
| RNF06 | Desempenho | As consultas de cadastro, funil e contas deverão ser apresentadas em até 3 segundos, para uso no atendimento. |
| RNF07 | Disponibilidade | O sistema deverá funcionar 24 horas por dia, com meta de 99% de disponibilidade mensal, porque o atendimento pelo WhatsApp acontece também fora do horário comercial. |
| RNF08 | Confiabilidade | O sistema não deverá processar a mesma demanda da automação mais de uma vez. |
| RNF09 | Cópia de segurança | O banco de dados deverá ter cópia de segurança diária, guardada por pelo menos 30 dias. |
| RNF10 | Usabilidade | O sistema deverá ser web e responsivo, utilizável no celular pelos corretores durante visitas. |
| RNF11 | Integração | A integração com o WhatsApp e com o IMOBIZI deverá ocorrer por meio do N8N, sem redigitação manual dos dados. |
| RNF12 | Precisão financeira | Os valores financeiros deverão ser armazenados com duas casas decimais, sem arredondamentos intermediários nos cálculos de comissão e repasse. |

## 3. Regras de negócio

O que pode ou não pode acontecer. A última coluna mostra onde a regra aparece no DER. Nas cardinalidades, o par (mín,máx) escrito junto de uma entidade indica quantas vezes uma ocorrência dela participa do relacionamento, isto é, com quantas ocorrências da outra entidade ela se relaciona (convenção detalhada na seção 14 do README).

### Pessoas

| Código | Regra | Onde aparece no modelo |
|---|---|---|
| RN01 | Toda pessoa registrada no CRM é um usuário e deve ter pelo menos um papel. | USUARIO · papel obrigatório |
| RN02 | A mesma pessoa pode exercer vários papéis ao mesmo tempo, por exemplo ser cliente e proprietária. | papel multivalorado |
| RN03 | Um telefone pertence a um único usuário. O número de WhatsApp não pode se repetir no sistema, pois é por ele que a automação identifica o cliente; os demais telefones podem ser compartilhados (por exemplo, por um casal ou por uma empresa). | USUARIO (0,n) — POSSUI — (1,1) TELEFONE · WhatsApp único |
| RN04 | O documento (CPF/CNPJ) não pode se repetir e é obrigatório para proprietários, para instituições financeiras e para quem assina contrato. | USUARIO.nr_cpf_cnpj único |
| RN05 | Um cliente pode ter nenhum ou vários perfis de interesse. | USUARIO (0,n) — BUSCA — (1,1) PERFIL_INTERESSE |
| RN32 | O papel exigido em cada relacionamento deve constar entre os papéis do usuário: proprietário em ANUNCIA; corretor em RESPONSAVEL, ATENDE, EXECUTA, ACOMPANHA, NEGOCIA e RECEBE; cliente em INICIA, VISITA e PROPOE; administrador em AUTORIZA e APROVA; instituição financeira em CONCEDE; administrador ou financeiro em EFETIVA. | Restrição sobre USUARIO.tp_papel nos relacionamentos indicados |
| RN33 | O papel de inquilino é atribuído ao cliente quando o contrato de locação é assinado, e o de instituição financeira é atribuído ao banco que concede um financiamento. | USUARIO.tp_papel (inquilino, instituição financeira) |
| RN42 | O perfil de interesse pode indicar no máximo uma cidade, escolhida do cadastro de cidades, para que a comparação com a cidade do imóvel seja exata. | CIDADE (0,n) — PREFERE — (0,1) PERFIL_INTERESSE |

### Imóveis

| Código | Regra | Onde aparece no modelo |
|---|---|---|
| RN06 | Todo imóvel tem exatamente um proprietário, e um proprietário pode ter vários imóveis. Imóveis com mais de um proprietário (copropriedade) ficam fora do escopo desta entrega. | USUARIO (0,n) — ANUNCIA — (1,1) IMOVEL |
| RN07 | Um imóvel pode ter nenhum ou um corretor responsável, e um corretor pode ser responsável por vários imóveis. | USUARIO (0,n) — RESPONSAVEL — (0,1) IMOVEL |
| RN08 | Um imóvel pode ter várias características, e uma característica pode estar em vários imóveis. | IMOVEL (0,n) — APRESENTA — (0,n) CARACTERISTICA |
| RN09 | Uma foto só existe vinculada a um imóvel. | FOTO · entidade fraca |
| RN10 | Imóvel vendido, alugado ou inativo não pode receber novas visitas nem propostas. | IMOVEL.st_imovel |
| RN41 | Todo imóvel está em exatamente um CEP, e todo CEP pertence a exatamente uma cidade. A cidade e a UF do imóvel não são digitadas no imóvel: são obtidas pelo CEP. | CEP (0,n) — LOCALIZA — (1,1) IMOVEL · CIDADE (0,n) — AGRUPA — (1,1) CEP |

### Atendimento e funil

| Código | Regra | Onde aparece no modelo |
|---|---|---|
| RN11 | Toda conversa pertence a exatamente um cliente, e um cliente pode ter várias conversas. | USUARIO (0,n) — INICIA — (1,1) CONVERSA |
| RN12 | A conversa pode ficar sem corretor no início do atendimento, mas nunca terá mais de um corretor responsável. | USUARIO (0,n) — ATENDE — (0,1) CONVERSA |
| RN13 | Toda conversa está em exatamente um estágio do funil por vez. | CONVERSA (1,1) — PERTENCE A — (0,n) FUNIL_ESTAGIO |
| RN14 | Toda mudança de estágio, inclusive o estágio inicial na abertura da conversa, deve gerar um registro no histórico, com data e hora; o estágio atual da conversa é sempre o do registro mais recente. | HISTORICO_ESTAGIO · PERTENCE A = último registro |
| RN15 | Toda tarefa tem um corretor responsável e pode ou não estar ligada a uma conversa. | USUARIO (0,n) — EXECUTA — (1,1) TAREFA · CONVERSA (0,n) — GERA TAREFA — (0,1) TAREFA |
| RN34 | Uma conversa fica aberta até ser encerrada pelo corretor ou por inatividade (prazo definido pela imobiliária). A mensagem de um cliente que tem conversa aberta retoma essa conversa; se não houver conversa aberta, o sistema abre uma nova. | CONVERSA.st_conversa |

### Negociação

| Código | Regra | Onde aparece no modelo |
|---|---|---|
| RN16 | Uma visita envolve exatamente um cliente, um imóvel e um corretor; o mesmo cliente pode visitar o mesmo imóvel mais de uma vez, em datas diferentes. | VISITA · associativa · único (imóvel, cliente, data e hora) |
| RN17 | Uma proposta pode ou não ter origem em uma visita; quando tem, o cliente e o imóvel da proposta são os mesmos da visita. | VISITA (0,n) — ORIGINA — (0,1) PROPOSTA |
| RN18 | Uma proposta aceita gera no máximo um contrato, e todo contrato nasce de exatamente uma proposta. | PROPOSTA (0,1) — FECHA — (1,1) CONTRATO |
| RN19 | Todo contrato é de venda ou de locação, e o contrato de locação deve ter data de início, data de término, taxa de administração e dia de vencimento do aluguel. | CONTRATO.tp_contrato, dt_inicio, dt_fim, pc_administracao, nr_dia_vencimento |
| RN20 | A comissão de um contrato pode ser dividida entre vários corretores, e a soma dos percentuais não pode passar de 100% da corretagem do contrato. | CONTRATO (0,n) — RECEBE (COMISSAO) — (0,n) USUARIO |
| RN21 | O valor da comissão é o percentual do corretor aplicado sobre a corretagem do contrato (valor final × percentual de corretagem), e não sobre o valor do imóvel. | COMISSAO.vl_comissao · derivado de CONTRATO.vl_corretagem |
| RN35 | Uma contraproposta é uma nova proposta ligada à proposta que ela responde. Cada proposta recebe no máximo uma contraproposta, e a proposta respondida passa à situação “substituída”. | PROPOSTA (0,1) — RESPONDE — (0,1) PROPOSTA · recursivo |
| RN36 | O contrato nasce como rascunho e só é considerado assinado quando a data de assinatura é registrada. Somente contratos assinados geram comissões, contas a receber e contas a pagar. | CONTRATO.st_contrato, dt_assinatura |
| RN37 | Ao cancelar um contrato, registram-se a data e o motivo; as contas a receber e a pagar sem nenhuma baixa e as comissões ainda não pagas são canceladas; os valores já recebidos ou pagos são mantidos, e qualquer devolução é feita por um novo lançamento; o imóvel volta à situação “disponível”. | CONTRATO.st_contrato, dt_cancelamento, ds_motivo_cancelamento · CONTA_*.fl_cancelada · COMISSAO.st_comissao |

### Financeiro

| Código | Regra | Onde aparece no modelo |
|---|---|---|
| RN22 | Um contrato pode ter no máximo um financiamento. O financiamento só existe quando a forma de pagamento do contrato é “financiado”, e todo contrato “financiado” tem financiamento. | CONTRATO (0,1) — FINANCIA — (1,1) FINANCIAMENTO · CONTRATO.tp_forma_pagamento |
| RN23 | Na venda financiada, a corretagem só é considerada recebida depois que o banco libera o crédito: nenhum recebimento da corretagem pode ter data anterior à liberação do financiamento do mesmo contrato. | FINANCIAMENTO.dt_liberacao · RECEBIMENTO.dt_recebimento · CONTRATO (0,1) — FINANCIA — (1,1) FINANCIAMENTO |
| RN24 | A comissão só é liberada para pagamento quando a condição da regra de pagamento é atendida: na assinatura, na liberação do crédito ou no recebimento. | COMISSAO.tp_regra_pagamento |
| RN25 | Cada comissão liberada gera no máximo uma conta a pagar ao corretor. | COMISSAO (0,1) — LANCA — (0,1) CONTA_PAGAR |
| RN26 | Toda conta a receber e toda conta a pagar deve ter uma categoria financeira do tipo compatível (receita para a conta a receber, despesa para a conta a pagar). | CATEGORIA_FINANCEIRA (0,n) — CLASSIFICA e CATEGORIZA — (1,1) CONTA_RECEBER e CONTA_PAGAR |
| RN27 | Toda conta a receber tem um pagador, que é um usuário: cliente, inquilino, proprietário ou banco. Quando o pagador é o banco, a conta deve pertencer a um contrato financiado, e o banco deve ser a instituição financeira que concedeu esse financiamento; o financiamento é encontrado pelo próprio contrato. | USUARIO (0,n) — PAGA — (1,1) CONTA_RECEBER · CONTA_RECEBER.tp_papel_pagador · USUARIO (0,n) — CONCEDE — (1,1) FINANCIAMENTO |
| RN28 | Toda conta a pagar é paga pela imobiliária ao favorecido; o atributo de custeio indica quem arca com o valor final: a imobiliária, o proprietário (descontado do repasse) ou o inquilino (cobrado no aluguel). Quando não for a imobiliária, a pessoa que arca com o custo deve ser informada. | CONTA_PAGAR.tp_papel_custeio · USUARIO (0,n) — CUSTEIA — (0,1) CONTA_PAGAR |
| RN29 | Uma conta pode ser quitada em vários recebimentos ou pagamentos parciais, sem que a soma passe do valor da conta, e cada baixa deve indicar a conta bancária movimentada. | CONTA (0,n) — QUITA e LIQUIDA — (1,1) baixa · CONTA_BANCARIA (0,n) — CREDITA e DEBITA — (1,1) baixa |
| RN30 | Na locação, o aluguel recebido do inquilino gera o repasse ao proprietário, descontada a taxa de administração; enquanto o aluguel não for recebido, o repasse não é gerado. O prazo de pagamento do repasse é o da PO05. | CONTRATO.pc_administracao · CONTA_RECEBER → CONTA_PAGAR |
| RN38 | A situação de uma conta (prevista, parcial, quitada ou atrasada) é calculada a partir do valor, das baixas e do vencimento; somente o cancelamento é registrado. | CONTA_RECEBER.st_conta e CONTA_PAGAR.st_conta · derivados · fl_cancelada |
| RN39 | Todo pagamento registra o usuário que o efetivou; o pagamento de comissões só pode ser efetivado pelo administrador (PO01). | USUARIO (0,n) — EFETIVA — (1,1) PAGAMENTO |

### Automação e auditoria

| Código | Regra | Onde aparece no modelo |
|---|---|---|
| RN31 | A mesma demanda de uma conversa não pode ser processada duas vezes pela automação, e a mesma mensagem do WhatsApp não pode ser registrada duas vezes na conversa. | AUTOMACAO_EXECUCAO · único (conversa, cd_demanda) · MENSAGEM.cd_externo |
| RN40 | Toda criação, alteração ou cancelamento de contrato, proposta, comissão e lançamento financeiro (conta, recebimento e pagamento) gera um registro de auditoria com o usuário e a data e hora da ação; cada campo alterado é registrado à parte, com o valor anterior e o novo; esse registro nunca é alterado. | USUARIO (0,n) — PRATICA — (1,1) AUDITORIA · AUDITORIA (0,n) — DETALHA — (1,1) AUDITORIA_CAMPO |

## 4. Restrições e políticas organizacionais

Decisões da imobiliária que o sistema precisa respeitar. Os limites (10% e 5 dias úteis) são propostas da equipe.

| Código | Tipo | Descrição | Área |
|---|---|---|---|
| PO01 | Política | Somente o administrador pode aprovar e pagar comissões (relacionamentos APROVA e EFETIVA). | Financeiro |
| PO02 | Política | O corretor só pode alterar as conversas, visitas e propostas sob sua responsabilidade. | Atendimento e negociação |
| PO03 | Restrição | Proposta com desconto acima de 10% do valor anunciado no momento da proposta (vl_anunciado) exige autorização do administrador (relacionamento AUTORIZA). | Negociação |
| PO04 | Restrição | Contrato assinado não pode ser excluído; apenas cancelado, com data e motivo do cancelamento. | Negociação |
| PO05 | Restrição | O repasse ao proprietário deve ser pago em até 5 dias úteis após o recebimento do aluguel. | Financeiro |
| PO06 | Política | Dados financeiros e documentos pessoais só podem ser consultados pelos perfis administrador e financeiro; o corretor consulta apenas as próprias comissões. | Acesso à informação |
| PO07 | Política | A pedido do titular, os dados pessoais de quem tem contrato, lançamento financeiro ou outra obrigação legal de guarda são anonimizados e o registro é mantido; os demais cadastros podem ser excluídos. | Privacidade (LGPD) |

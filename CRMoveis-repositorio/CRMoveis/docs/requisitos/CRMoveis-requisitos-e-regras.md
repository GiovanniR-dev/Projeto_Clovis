# CRMoveis — Requisitos e regras de negócio

Projeto Integrador — Modelagem de Dados. CRM para imobiliária de venda e locação de imóveis, integrado a WhatsApp e N8N.

**Equipe:** Gustavo Amorim · Giovanni Corrêa Rodrigues · Julio Cesar Ferreira do Nascimento · Anderson da Silva · Fellipe da Eira Aguiar · Leonardo Vinicius de Farias · Guilherme Lucas Correa · João Vitor Candido Cassiano · Kayky Fernandes de Andrade · Gabriel Rocha da Silva · Davi Costa Ferraz

**Como ler.** Cada requisito funcional indica o fluxograma em que aparece e as entidades do DER que o atendem. Cada regra de negócio indica o que ela sustenta no modelo: uma cardinalidade, um atributo ou uma restrição.

**Fluxogramas:** F1 Atendimento pelo WhatsApp · F2 Captação de imóvel · F3 Visita e proposta · F4 Venda com financiamento e comissão · F5 Locação mensal.

## 1. Requisitos funcionais

O que o sistema deve fazer.

### Pessoas

| Código | Requisito | Fluxo | Entidades |
|---|---|---|---|
| RF01 | O sistema deverá cadastrar usuários com nome, documento (CPF/CNPJ), e-mail e origem do contato. | F1, F2 | USUARIO |
| RF02 | O sistema deverá permitir que um mesmo usuário exerça mais de um papel: cliente, proprietário, corretor, financeiro, fornecedor ou administrador. | F1, F2 | USUARIO (papel) |
| RF03 | O sistema deverá registrar um ou mais telefones por usuário e identificar o usuário pelo número do WhatsApp. | F1 | TELEFONE |
| RF04 | O sistema deverá registrar os perfis de interesse do cliente: finalidade, tipo de imóvel, cidade, bairro, faixa de valor e quartos. | F1 | PERFIL_INTERESSE |

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
| RF13 | O sistema deverá cadastrar imóveis com endereço, características, valor, finalidade (venda ou locação) e situação. | F2 | IMOVEL, CARACTERISTICA |
| RF14 | O sistema deverá importar e atualizar os imóveis a partir do IMOBIZI. | F2 | IMOVEL |
| RF15 | O sistema deverá anexar fotos aos imóveis, na ordem de exibição. | F2 | FOTO |
| RF16 | O sistema deverá registrar o proprietário e o corretor responsável de cada imóvel. | F2 | IMOVEL, USUARIO |
| RF17 | O sistema deverá registrar os imóveis de interesse de cada conversa. | F1 | CONVERSA_IMOVEL |

### Negociação

| Código | Requisito | Fluxo | Entidades |
|---|---|---|---|
| RF18 | O sistema deverá agendar, registrar a realização e cancelar visitas, guardando o feedback do cliente. | F3 | VISITA |
| RF19 | O sistema deverá registrar propostas e contrapropostas, ligadas ou não a uma visita. | F3 | PROPOSTA |
| RF20 | O sistema deverá gerar o contrato de venda ou de locação a partir de uma proposta aceita, com percentual de corretagem ou taxa de administração. | F3, F4 | CONTRATO |
| RF21 | O sistema deverá anexar documentos ao contrato. | F4 | DOCUMENTO |
| RF22 | O sistema deverá registrar a comissão de cada corretor no contrato, com percentual, regra de pagamento e aprovação do administrador. | F4 | COMISSAO |

### Financeiro

| Código | Requisito | Fluxo | Entidades |
|---|---|---|---|
| RF23 | O sistema deverá registrar o financiamento do contrato: instituição, valor financiado, entrada, parcelas, taxa, aprovação e liberação do crédito. | F4 | FINANCIAMENTO |
| RF24 | O sistema deverá gerar contas a receber (corretagem, intermediação, taxa de administração, aluguel e serviços), indicando quem paga. | F4, F5 | CONTA_RECEBER |
| RF25 | O sistema deverá gerar contas a pagar (comissão, repasse ao proprietário, despesas e impostos), indicando quem paga e quem recebe. | F4, F5 | CONTA_PAGAR |
| RF26 | O sistema deverá registrar recebimentos e pagamentos, inclusive parciais, indicando a conta bancária movimentada. | F4, F5 | RECEBIMENTO, PAGAMENTO, CONTA_BANCARIA |
| RF27 | O sistema deverá gerar todo mês, nos contratos de locação, a conta a receber do aluguel e a conta a pagar do repasse ao proprietário. | F5 | CONTA_RECEBER, CONTA_PAGAR |
| RF28 | O sistema deverá liberar a comissão para pagamento somente quando a condição da regra de pagamento for atendida. | F4 | COMISSAO, CONTA_PAGAR |
| RF29 | O sistema deverá classificar cada conta a receber e a pagar em uma categoria financeira. | F4, F5 | CATEGORIA_FINANCEIRA |

### Consultas e relatórios

| Código | Requisito | Fluxo | Entidades |
|---|---|---|---|
| RF30 | O sistema deverá emitir relatório de conversão do funil por estágio e por período. | — | HISTORICO_ESTAGIO |
| RF31 | O sistema deverá emitir relatório financeiro com valores a receber, recebidos, a pagar e pagos por período. | — | CONTA_RECEBER, CONTA_PAGAR |
| RF32 | O sistema deverá permitir consultar o histórico de atendimentos, visitas, propostas e contratos de um cliente. | — | CONVERSA, VISITA, PROPOSTA, CONTRATO |

## 2. Requisitos não funcionais

Como o sistema deve funcionar: condições, restrições e qualidade.

| Código | Categoria | Requisito |
|---|---|---|
| RNF01 | Controle de acesso | O sistema deverá controlar o acesso por perfil (administrador, corretor e financeiro), liberando a cada perfil apenas as funções e os dados de que ele precisa. |
| RNF02 | Segurança | O sistema deverá armazenar as senhas somente na forma de hash, nunca em texto. |
| RNF03 | Privacidade (LGPD) | O sistema deverá tratar os dados pessoais (CPF/CNPJ, telefone e e-mail) conforme a LGPD, permitindo consultar e excluir os dados do titular quando ele solicitar. |
| RNF04 | Auditoria | O sistema deverá registrar quem criou ou alterou contratos, propostas, comissões e lançamentos financeiros, e quando. |
| RNF05 | Tempo de resposta | O sistema deverá enviar a resposta automática ao cliente no WhatsApp em até 10 segundos após o recebimento da mensagem, em condições normais de uso. |
| RNF06 | Desempenho | As consultas de cadastro, funil e contas deverão ser apresentadas em até 3 segundos, para uso no atendimento. |
| RNF07 | Disponibilidade | O sistema deverá funcionar 24 horas por dia, com meta de 99% de disponibilidade mensal, porque o atendimento pelo WhatsApp acontece também fora do horário comercial. |
| RNF08 | Confiabilidade | O sistema não deverá processar a mesma demanda da automação mais de uma vez. |
| RNF09 | Cópia de segurança | O banco de dados deverá ter cópia de segurança diária, guardada por pelo menos 30 dias. |
| RNF10 | Usabilidade | O sistema deverá ser web e responsivo, utilizável no celular pelos corretores durante visitas. |
| RNF11 | Integração | A integração com o WhatsApp e com o IMOBIZI deverá ocorrer por meio do N8N, sem redigitação manual dos dados. |
| RNF12 | Precisão financeira | Os valores financeiros deverão ser armazenados com duas casas decimais, sem arredondamentos intermediários nos cálculos de comissão e repasse. |

## 3. Regras de negócio

O que pode ou não pode acontecer no negócio, e onde cada regra aparece no modelo.

### Pessoas

| Código | Regra | O que sustenta no modelo |
|---|---|---|
| RN01 | Toda pessoa registrada no CRM é um usuário e deve ter pelo menos um papel. | USUARIO · papel obrigatório |
| RN02 | A mesma pessoa pode exercer vários papéis ao mesmo tempo, por exemplo ser cliente e proprietária. | papel multivalorado |
| RN03 | Um telefone pertence a um único usuário, e o mesmo número não pode se repetir no sistema. | USUARIO (1,1) — TELEFONE (0,n) · número único |
| RN04 | O documento (CPF/CNPJ) não pode se repetir e é obrigatório para proprietários e para quem assina contrato. | USUARIO.documento único |
| RN05 | Um cliente pode ter nenhum ou vários perfis de interesse. | USUARIO (1,1) — PERFIL_INTERESSE (0,n) |

### Imóveis

| Código | Regra | O que sustenta no modelo |
|---|---|---|
| RN06 | Todo imóvel tem exatamente um proprietário, e um proprietário pode ter vários imóveis. | USUARIO (1,1) — ANUNCIA — IMOVEL (0,n) |
| RN07 | Um imóvel pode ter nenhum ou um corretor responsável, e um corretor pode ser responsável por vários imóveis. | USUARIO (0,1) — RESPONSÁVEL — IMOVEL (0,n) |
| RN08 | Um imóvel pode ter várias características, e uma característica pode estar em vários imóveis. | IMOVEL (0,n) — APRESENTA — CARACTERISTICA (0,n) |
| RN09 | Uma foto só existe vinculada a um imóvel. | FOTO · entidade fraca |
| RN10 | Imóvel vendido, alugado ou inativo não pode receber novas visitas nem propostas. | IMOVEL.st_imovel |

### Atendimento e funil

| Código | Regra | O que sustenta no modelo |
|---|---|---|
| RN11 | Toda conversa pertence a exatamente um cliente, e um cliente pode ter várias conversas. | USUARIO (1,1) — INICIA — CONVERSA (0,n) |
| RN12 | A conversa pode ficar sem corretor no início do atendimento, mas nunca terá mais de um corretor responsável. | USUARIO (0,1) — ATENDE — CONVERSA (0,n) |
| RN13 | Toda conversa está em exatamente um estágio do funil por vez. | CONVERSA (0,n) — ESTÁ EM — FUNIL_ESTAGIO (1,1) |
| RN14 | Toda mudança de estágio deve gerar um registro no histórico, com data e hora. | HISTORICO_ESTAGIO |
| RN15 | Toda tarefa tem um corretor responsável e pode ou não estar ligada a uma conversa. | EXECUTA (1,1) · GERA TAREFA (0,1) |

### Negociação

| Código | Regra | O que sustenta no modelo |
|---|---|---|
| RN16 | Uma visita envolve exatamente um cliente, um imóvel e um corretor; o mesmo cliente pode visitar o mesmo imóvel mais de uma vez, em datas diferentes. | VISITA · associativa · único (imóvel, cliente, data e hora) |
| RN17 | Uma proposta pode ou não ter origem em uma visita. | VISITA (0,1) — ORIGINA — PROPOSTA (0,n) |
| RN18 | Uma proposta aceita gera no máximo um contrato, e todo contrato nasce de exatamente uma proposta. | PROPOSTA (1,1) — FECHA — CONTRATO (0,1) |
| RN19 | Todo contrato é de venda ou de locação, e o contrato de locação deve ter data de término, taxa de administração e dia de vencimento do aluguel. | CONTRATO.tipo_contrato, dt_fim, taxa_administracao, dia_vencimento |
| RN20 | A comissão de um contrato pode ser dividida entre vários corretores, e a soma dos percentuais não pode passar de 100%. | CONTRATO (0,n) — COMISSAO — USUARIO (0,n) |
| RN21 | O valor da comissão é o percentual aplicado sobre o valor final do contrato. | COMISSAO.valor · derivado |

### Financeiro

| Código | Regra | O que sustenta no modelo |
|---|---|---|
| RN22 | Um contrato pode ter no máximo um financiamento. | CONTRATO (1,1) — FINANCIA — FINANCIAMENTO (0,1) |
| RN23 | Na venda financiada, a corretagem só é considerada recebida depois que o banco libera o crédito. | FINANCIAMENTO (0,1) — LIBERA — CONTA_RECEBER (0,n) |
| RN24 | A comissão só é liberada para pagamento quando a condição da regra de pagamento é atendida: na assinatura, na liberação do crédito ou no recebimento. | COMISSAO.regra_pagamento |
| RN25 | Cada comissão liberada gera no máximo uma conta a pagar ao corretor. | COMISSAO (0,1) — LANÇA — CONTA_PAGAR (0,1) |
| RN26 | Toda conta a receber e toda conta a pagar deve ter uma categoria financeira e um responsável pelo pagamento. | CLASSIFICA e CATEGORIZA (1,1) · responsavel obrigatório |
| RN27 | Na conta a receber, quem paga pode ser o cliente, o inquilino, o proprietário ou o banco; quando for o banco, a conta deve estar ligada a um financiamento. | CONTA_RECEBER.responsavel |
| RN28 | Na conta a pagar, quem paga pode ser a imobiliária, o proprietário ou o inquilino; quando não for a imobiliária, o pagador deve ser informado. | CONTA_PAGAR.responsavel · USUARIO (0,1) — CUSTEIA |
| RN29 | Uma conta pode ser quitada em vários recebimentos ou pagamentos parciais, e cada um deve indicar a conta bancária movimentada. | QUITA e LIQUIDA (1,1)–(0,n) · CREDITA e DEBITA (1,1) |
| RN30 | Na locação, o aluguel recebido do inquilino gera, no mesmo mês, o repasse ao proprietário, descontada a taxa de administração. | CONTRATO.taxa_administracao · CONTA_RECEBER → CONTA_PAGAR |

### Automação

| Código | Regra | O que sustenta no modelo |
|---|---|---|
| RN31 | A mesma demanda de uma conversa não pode ser processada duas vezes pela automação. | AUTOMACAO_EXECUCAO · único (conversa, chave_demanda) |

## 4. Restrições e políticas organizacionais

Decisões da imobiliária que o sistema precisa respeitar. Os limites (10%, 5 dias úteis) são propostas da equipe e devem ser confirmados com a imobiliária.

| Código | Política | Área |
|---|---|---|
| PO01 | Somente o administrador pode aprovar e pagar comissões (relacionamento APROVA). | Financeiro |
| PO02 | O corretor só pode alterar as conversas, visitas e propostas sob sua responsabilidade. | Atendimento e negociação |
| PO03 | Proposta com desconto acima de 10% do valor anunciado exige autorização do administrador (relacionamento AUTORIZA). | Negociação |
| PO04 | Contrato assinado não pode ser excluído; apenas cancelado, com data e motivo do cancelamento. | Negociação |
| PO05 | O repasse ao proprietário deve ser pago em até 5 dias úteis após o recebimento do aluguel. | Financeiro |
| PO06 | Dados financeiros e documentos pessoais só podem ser consultados pelos perfis administrador e financeiro. | Acesso à informação |

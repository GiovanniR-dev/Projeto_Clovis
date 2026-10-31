# Massa de dados (Etapa 16)

Cerca de **oito meses de operacao** de uma imobiliaria pequena de Sao Paulo, Guarulhos e Aruja (marco a outubro de 2026, com alguns contratos de 2025). A data de referencia e **20/10/2026**: o que vence depois dela esta “previsto”, o que venceu e nao foi pago esta “atrasado”. Executando depois dessa data, o banco passa a mostrar como atrasado o que venceu nesse meio-tempo, e as colunas de dias aumentam: os dados nao mudam, muda o dia de hoje.

**Todos os nomes, CPFs, CNPJs, telefones, e-mails e enderecos sao ficticios.** Os CPFs e CNPJs tem digito verificador valido, mas foram gerados a partir de numeros sequenciais; os celulares seguem o padrao 11 9000-0xxx e os fixos, 11 3000-0xxx.

| Arquivo | O que faz |
|---|---|
| `07_dados_de_referencia.sql` | Categorias financeiras e etapas do funil (sem elas o sistema nao funciona). |
| `10_massa_de_dados.sql` | A massa de dados, numa transacao: se qualquer linha violar uma regra, nada e gravado. |
| `11_contagem_por_tabela.sql` | Conta as linhas de cada tabela, para conferir o volume. |
| `gerador/gerar_massa_de_dados.py` | O programa que gerou o arquivo 10 (Python, sem bibliotecas externas, semente fixa: gera sempre o mesmo resultado). |

## Volume

**2553 linhas** em 50 tabelas; nenhuma tabela vazia.

| Area | Linhas por tabela | Total |
|---|---|---|
| **Pessoas e papeis** | usuario 55 · cliente 34 · proprietario 10 · inquilino 5 · corretor 5 · financeiro 2 · fornecedor 3 · administrador 1 · instituicao_financeira 2 · origem_contato 7 · telefone 62 | 186 |
| **Localizacao e perfil** | uf 27 · cidade 3 · cep 15 · bairro 15 · perfil_interesse 30 · perfil_interesse_tipo 42 · perfil_interesse_bairro 40 | 172 |
| **Imoveis** | tipo_imovel 10 · imovel 30 · foto 168 · caracteristica 15 · imovel_caracteristica 121 | 344 |
| **Funil / CRM** | funil_estagio 7 · conversa 45 · conversa_imovel 86 · mensagem 353 · historico_estagio 139 · tarefa 104 · tag 8 · conversa_tag 46 | 788 |
| **Negociacao** | visita 31 · proposta 16 · contrato 9 · documento 24 · tipo_documento 6 · comissao 10 · financiamento 2 | 98 |
| **Financeiro** | categoria_financeira 10 · conta_bancaria 3 · movimento_bancario 84 · conta_receber 45 · recebimento 42 · conta_pagar 49 · pagamento 45 · forma_pagamento 5 | 283 |
| **N8N e auditoria** | automacao_execucao 34 · automacao_log 128 · auditoria 312 · auditoria_campo 208 | 682 |

## Situacoes que a massa permite testar

O manual pede dados que testem diferentes situacoes, relacionamentos, restricoes, consultas e regras de negocio, e que sejam coerentes entre si. Cada situacao abaixo existe na massa de proposito:

| Situacao | Na massa | Onde e usada |
|---|---|---|
| Pessoa com varios papeis | Ana Souza e Beatriz Antunes sao clientes e proprietarias; Camila Rocha e Diego Alves sao clientes e inquilinos. | consulta 20 (item 4), RN02 |
| Telefone compartilhado | O fixo do casal Camila (titular) e Diego; o celular da Construtora Vale Verde (titular) usado pelo socio Eduardo. O mesmo numero aparece no cadastro de cada pessoa, com um titular. | A09, RN03, caso 2.1 da normalizacao |
| Perfis com varios tipos de imovel | 30 perfis: sem tipo (aceita qualquer): 1, um tipo: 16, 2 tipos: 13. | G15, consulta 20 (item 3a), RN47 |
| Tipos de imovel | Imoveis por tipo: Apartamento: 15, Casa: 8, Casa em condominio: 1, Cobertura: 1, Galpao: 1, Kitnet: 1, Loja: 1, Sala comercial: 1, Terreno: 1; a lista tem tambem tipos ainda sem imovel (Chacara). | G07, G15, RN48 |
| Corretor que saiu da empresa | Sergio Dias tem papel encerrado em 30/06/2026; as conversas abertas dele foram transferidas para Bianca. | G03, A10, RN32 |
| Cliente que pediu exclusao (PO07) | Um cliente anonimizado: nome trocado, sem CPF e sem e-mail, historico preservado; a conversa que estava aberta foi encerrada no dia do pedido. | PO07 |
| Cliente que voltou | 11 clientes com duas conversas em epocas diferentes. | RN11, caso 3.1 da normalizacao |
| Funil completo | Conversas em todas as etapas: Novo contato: 7, Qualificacao: 8, Visita: 8, Proposta: 2, Contrato: 1, Ganho: 7, Perdido: 12. | G01, G02, G13, A11 |
| Imoveis em todas as situacoes | disponivel: 24, alugado: 3, inativo: 1, reservado: 1, vendido: 1; venda, locacao e ambas; tres cidades. | consulta 20 (item 1), G07, G08, A08 |
| Visitas e propostas | Visitas realizada: 25, agendada: 4, cancelada: 2. Propostas aceita: 9, substituida: 3, recusada: 2, pendente: 2; contrapropostas encadeadas (RESPONDE) e desconto acima de 10% autorizado pelo administrador (PO03). | G11, RN35, PO03 |
| Contratos em todas as situacoes | cancelado (venda): 1, encerrado (locacao): 1, encerrado (venda): 1, rascunho (locacao): 1, rescindido (locacao): 1, vigente (locacao): 3, vigente (venda): 1. | G04, G10, G12, RN36, RN37, RN43, RN44 |
| Venda financiada | Um financiamento liberado e um reprovado (o reprovado levou ao cancelamento do contrato). | RN22, RN23, RN37 |
| Rescisao com multa | Uma locacao rescindida pelo inquilino, com multa rescisoria cobrada e paga. | RN43 |
| Comissoes | Contratos com um e com dois corretores, comissoes liberadas, pendentes e canceladas; soma por contrato ate 100%. | RN20, RN24, RN25, PO01 |
| Aluguel pago em dia, atrasado, parcial e em aberto | Contas a receber: quitada: 40, atrasada: 3, cancelada: 2; pagamento parcial em duas baixas; inquilino com dois meses em aberto. | G05, RN29 |
| Repasse ao proprietario | 34 repasses gerados automaticamente, um para cada recebimento de aluguel (inclusive parcial); um deles ja atrasado na data de referencia. | G06, A03, RN30, PO05 |
| Despesas e quem arca com elas | Fotografia (imobiliaria), manutencao (proprietario), vistoria (inquilino) e imposto. | RN28 |
| Conciliacao bancaria | Extrato de marco a 15/10 com conciliado: 73, pendente: 11 movimentos: tarifas sem lancamento, um credito nao identificado, um PIX que nao bate com nenhuma baixa e uma baixa parcial ainda nao conciliada. | A01, A02, RN45, RN46 |
| Automacao N8N | Execucoes enviada: 30, recebida: 2, erro: 1, processada: 1, com log de cada passo (a mesma ideia do app original). | G14, RN31 |
| Conversas paradas | As conversas abertas tem contato recente, exceto duas deixadas sem contato de proposito (16 e 23), tres novos contatos ainda sem corretor e tres novos contatos esfriando. | A06 |
| Tarefas | Tarefas concluida: 87, pendente: 12, cancelada: 5, algumas vencidas. | A07 |
| Auditoria | 312 registros e 208 campos alterados, gravados pelos gatilhos durante a propria carga. | A12, RN40 |

## Como a coerencia foi garantida

- **Datas em ordem:** a conversa comeca antes da visita, a visita antes da proposta, a proposta antes do contrato, o contrato antes das contas, e o pagamento depois do vencimento ou no dia (exceto os atrasos de proposito).
- **Valores que batem:** a corretagem e o percentual do contrato sobre o valor final; a comissao e a fracao da corretagem; o repasse e o valor recebido menos a taxa de administracao; as baixas nunca passam do valor da conta.
- **Papeis certos:** quem anuncia e proprietario, quem paga o aluguel e inquilino, quem paga a comissao e o administrador (PO01), e ninguem atua num papel encerrado.
- **O banco confere tudo:** a carga passa pelas mesmas chaves, restricoes e gatilhos que valem para o sistema. Se uma linha violar qualquer regra, a transacao inteira e desfeita.
- **Consultas de auditoria:** as 13 consultas de `sql/auditoria/30_consultas_auditoria.sql` encontram so as situacoes colocadas de proposito (listadas acima), e nenhuma inconsistencia acidental.
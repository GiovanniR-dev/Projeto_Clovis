# Potencial para BI e IA (Etapa 21)

O manual nao pede uma solucao de BI ou IA implementada, e sim mostrar que o grupo percebe o potencial dos dados que estruturou, sempre no caminho **PROBLEMA → DADOS → ANALISE → POSSIVEL BENEFICIO**. Todos os dados citados ja existem no modelo logico.

## Informacoes estrategicas e indicadores

| Indicador | Como calcular | Tabelas | Consulta |
|---|---|---|---|
| Taxa de conversao do funil | conversas que chegaram a Contrato ÷ conversas criadas | conversa, historico_estagio, funil_estagio | G01 |
| Conversao por origem do contato | contratos assinados ÷ clientes, por origem | usuario, origem_contato, conversa, proposta, contrato | G02 |
| Produtividade do corretor | conversas, visitas, propostas, contratos e comissao liberada por corretor | corretor, conversa, visita, proposta, comissao | G03 |
| Receita por mes e por tipo | soma das baixas por competencia e categoria | recebimento, conta_receber, categoria_financeira | G04 |
| Inadimplencia | valor vencido e nao baixado ÷ valor vencido | vw_conta_receber, recebimento | G05 |
| Prazo de repasse | dias entre o recebimento e o pagamento do repasse | conta_pagar, pagamento, recebimento | G06, A03 |
| Demanda × oferta por regiao | perfis ativos ÷ imoveis disponiveis, por cidade, bairro e finalidade | perfil_interesse, imovel, cep, cidade | G09 |
| Demanda × oferta por tipo | perfis que aceitam o tipo ÷ imoveis disponiveis do tipo, por finalidade | perfil_interesse_tipo, perfil_interesse, tipo_imovel, imovel | G15 |
| Tempo ate o contrato | dias entre o inicio da conversa e a assinatura | conversa, proposta, contrato | G10 |
| Desconto medio concedido | (vl_anunciado − vl_proposto) ÷ vl_anunciado das propostas aceitas | proposta | G11 |
| Receita recorrente prevista | alugueis e taxas de administracao dos contratos vigentes nos proximos meses | contrato, conta_receber | G12 |
| Tempo de primeira resposta | minutos entre a primeira mensagem recebida e a primeira enviada | mensagem | G13 |
| Eficiencia da automacao | execucoes enviadas, com erro e reprocessadas | automacao_execucao, automacao_log | G14 |

## Business Intelligence

### Painel comercial

- **Problema:** O dono nao sabe em que etapa perde clientes nem qual canal e qual corretor trazem negocio.
- **Dados:** conversa, historico_estagio (data de cada mudanca), funil_estagio, origem_contato, corretor, visita, proposta, contrato.
- **Analise:** Funil por mes, conversao por origem e por corretor, tempo medio em cada etapa (diferenca entre as datas do historico).
- **Possivel beneficio:** Redistribuir leads entre corretores, investir nos canais que fecham e atacar a etapa com maior perda.

### Painel financeiro e de caixa

- **Problema:** Hoje o financeiro descobre atrasos e divergencias tarde, olhando planilhas.
- **Dados:** conta_receber, recebimento, conta_pagar, pagamento, movimento_bancario, vw_conta_receber, vw_movimento_bancario.
- **Analise:** Fluxo de caixa realizado × previsto, inadimplencia por mes, repasses no prazo, percentual do extrato conciliado.
- **Possivel beneficio:** Cobranca antes do atraso virar problema, repasses sempre no prazo (PO05) e fechamento do mes mais rapido.

### Mapa de demanda × oferta

- **Problema:** A imobiliaria capta imoveis sem saber o que os clientes estao procurando.
- **Dados:** perfil_interesse (finalidade, bairro, cidade, faixa de valor, quartos), perfil_interesse_tipo e tipo_imovel (tipos aceitos), imovel, cep, cidade, conversa_imovel.
- **Analise:** Por bairro, tipo de imovel e faixa de preco: quantos clientes procuram × quantos imoveis existem (G09 e G15); imoveis com muitos interesses e nenhuma visita.
- **Possivel beneficio:** Direcionar a captacao para os bairros e faixas com falta de oferta e rever preco ou anuncio dos imoveis parados (G08).

## Inteligencia Artificial

### Pontuacao de leads

- **Problema:** Os corretores atendem as conversas por ordem de chegada, e nao pela chance de virar negocio.
- **Dados:** Conversas antigas com o resultado conhecido (chegou a contrato ou nao): origem, tempo de primeira resposta, numero de mensagens, imoveis de interesse, visitas, perfil de interesse e etapa.
- **Analise:** Modelo de classificacao treinado com o historico (conversas ganhas × perdidas), que da a cada conversa nova a probabilidade de fechar.
- **Possivel beneficio:** O corretor prioriza quem tem mais chance e o gestor percebe cedo conversas boas sem atendimento (complementa a A06).

### Recomendacao de imoveis

- **Problema:** Hoje o seletor do N8N escolhe imoveis por regras fixas (cidade, faixa de valor, quartos).
- **Dados:** perfil_interesse, imovel, imovel_caracteristica, e o comportamento real: conversa_imovel (interesses), visita e proposta.
- **Analise:** Recomendacao por similaridade: imoveis parecidos com os que clientes de perfil parecido visitaram e propuseram.
- **Possivel beneficio:** Mensagens de disparo mais certeiras, menos visitas perdidas e mais propostas por visita.

### Previsao de inadimplencia

- **Problema:** O atraso do aluguel so e percebido depois do vencimento.
- **Dados:** Historico de cada inquilino: recebimentos (datas e valores, pagamentos parciais), vencimentos, valor do aluguel × perfil, rescisoes.
- **Analise:** Modelo que estima, a cada mes, a chance de atraso de cada contrato vigente.
- **Possivel beneficio:** Contato preventivo antes do vencimento e previsao de caixa mais realista; menos repasses afetados por atraso.

### Atendimento automatico no WhatsApp

- **Problema:** Muitas perguntas repetidas (preco, disponibilidade, visita) chegam fora do horario.
- **Dados:** mensagem (texto, direcao, data), conversa, imovel, automacao_execucao e automacao_log (o que ja foi enviado e o resultado).
- **Analise:** Assistente que responde perguntas sobre imoveis com os dados do banco e registra tudo como mensagem e execucao da automacao.
- **Possivel beneficio:** Primeira resposta imediata (G13) sem perder o historico; o corretor assume quando a conversa avanca.

## Cuidados com os dados

- **LGPD:** o cliente pode pedir a exclusao; o modelo ja anonimiza (PO07) sem apagar o historico dos negocios, o que permite usar os dados em analises sem identificar a pessoa.
- **Qualidade:** BI e IA so valem o que valem os dados. As consultas de auditoria (A01 a A13) sao o filtro antes de qualquer painel ou treino de modelo.
- **Vies:** um modelo de pontuacao de leads treinado so com o passado pode repetir preferencias antigas (por bairro ou origem); os resultados devem ser acompanhados pelo gestor, e nao decidir sozinhos.
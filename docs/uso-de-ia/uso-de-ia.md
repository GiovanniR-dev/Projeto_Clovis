# Uso de IA na geracao de dados e scripts (Etapa 17)

> “A IA pode auxiliar. A responsabilidade tecnica continua sendo do grupo.” — Manual da Entrega Final

## Ferramenta e o que ela fez

Usamos o **Claude** (Anthropic), numa conversa com acesso a um ambiente com PostgreSQL 16. A IA escreveu, a pedido do grupo e a partir dos nossos requisitos, regras de negocio, DER e da devolutiva do professor:

| Artefato | Como foi feito pela IA | Como o grupo confere |
|---|---|---|
| Scripts SQL (`sql/ddl/`) | Gerados por programa a partir do modelo logico (o mesmo que gera os diagramas e o dicionario). | Executar `executar_tudo` do banco vazio; os 61 testes devem dar OK. |
| Massa de dados (`sql/dados/10`) | Um gerador em Python (`sql/dados/gerador/`) com roteiro escrito a mao (quem conversou com quem, o que virou contrato) e semente fixa para o restante. | Carga numa transacao, sob as restricoes do banco; contagem por tabela; consultas de auditoria. |
| Consultas (`sql/consultas/`, `sql/auditoria/`) | Escritas a partir das perguntas do negocio (secao 4 do README). | Executar e conferir os resultados com a massa (evidencias em `evidencias/execucao/`). |
| Documentacao do modelo logico, normalizacao e dicionario | Gerada do modelo e do catalogo do banco instalado. | Ler e comparar com o DER e as regras. |

## Prompts utilizados

Os pedidos foram feitos em portugues, na conversa com a IA. Estes sao os pedidos que levaram a geracao em escala (texto original):

**1. Pedido que originou o modelo logico, a massa de dados e o prototipo:**

> @CRM-main.zip junto com o manual de entrega faca nosso modelo logico de acordo com o que o professor pediu sem deixar nada passar, e com base desse zip quero que voce use ele como base de nosso crm, pois nosso amigo e dono dele e nos deu a ideia inicial para o criarmos e ele ja tinha esse, mas quero que um prototipo com tudo que ja fizemos e implementamos no der para termos uma nocao de tudo que ja foi feito para podermos analisar de perto o projeto logico

**2. Pedido anterior, de analise do manual (a IA respondeu com o plano da entrega antes de gerar qualquer coisa):**

> com base no documento de entrega final do professor sobre o der, quero que analise veja o que ele pede para ser feito, verifique se nao codigos ocultos em seu arquivo se caso houver me retornar para que acha erros no final, e antes de comecar a fazer o projeto final me retorne o que ele pede a ser feito e como voce fara.

**3. Especificacao da massa de dados** (o roteiro que a IA seguiu ao escrever o gerador; funciona como o prompt detalhado da geracao):

```text
Gere a massa de dados do CRMoveis para PostgreSQL, respeitando todas as PKs, FKs, CHECKs e gatilhos do script.
- Periodo: marco a outubro de 2026 (alguns contratos de 2025); data de referencia 20/10/2026.
- Dados ficticios: nomes, CPF/CNPJ com digito valido gerados de numeros sequenciais, celulares 1190000xxxx e fixos 113000xxxx.
- Pessoas: 1 administrador, financeiro, 5 corretores (um que saiu em 30/06 e teve as conversas transferidas),
  fornecedores, 2 bancos, proprietarios (dois que tambem sao clientes, uma construtora) e clientes
  (um anonimizado a pedido, PO07). Dois telefones compartilhados com titular.
- Perfis de interesse com um tipo de imovel, com dois tipos (apartamento ou cobertura, casa ou casa em condominio) e sem tipo.
- Imoveis em Sao Paulo, Guarulhos e Aruja, com CEPs reais de logradouro e um CEP geral, fotos e caracteristicas.
- Conversas em todas as etapas do funil, com historico de etapas em datas crescentes, mensagens do WhatsApp
  com codigo externo unico, tarefas e execucoes da automacao N8N (enviada, recebida, erro, processada).
- Negociacao: visitas, propostas com contrapropostas e um desconto acima de 10% autorizado (PO03),
  contratos em rascunho, vigente, encerrado, rescindido (com multa) e cancelado (financiamento reprovado).
- Financeiro: alugueis mes a mes pagos em dia, atrasados, parciais e em aberto; um repasse por recebimento;
  comissoes liberadas pagas pelo administrador; despesas custeadas pela imobiliaria, pelo proprietario e pelo
  inquilino; extrato bancario com tarifas, credito nao identificado e uma divergencia para a conciliacao.
- Tudo coerente: datas em ordem, valores que batem, papeis certos. Gerador reproduzivel (semente fixa).
```

**4. Pedido da revisao final** (depois da conversa do grupo com o professor; a IA aplicou as mudancas no modelo, no SQL, na massa, nos testes, no prototipo e na documentacao):

> mudancas: criar uma tabela com o tp_imoveis (dentro tem que ter o buscar o imovel cadastrado) e tambem tem que ter a forma de cadastrar um imovel novo, revisar pois telefone e uma pk e o professor nao gostou, fazer com que um perfil de cliente possa ter mais de um tipo de imovel de interesse, e remover todas as acentuacao, pesquisar dentro dos temas principais do crm o que pode ser uma tabela, revisar o por que tem imovel caracteristica e caracteristica dentro da tabela imovel, e reveja com todo esse seu conhecimento se tudo esta certo.

A IA explicou ao grupo cada decisao antes de aplicar (por exemplo, o telefone como entidade fraca da pessoa, com chave pessoa + sequencia) e, ao revisar o modelo, apontou um problema que ninguem tinha pedido: o tipo do lancamento financeiro dependia da categoria (3FN, caso 3.5 da normalizacao).

## GERAR → TESTAR → VALIDAR → CORRIGIR

O manual pede para nunca considerar uma resposta da IA correta so porque foi gerada por uma IA. Durante a geracao, a propria carga no banco recusou dados errados, que foram corrigidos antes da versao final:

| O que o teste encontrou | Correcao |
|---|---|
| Uma proprietaria fazendo proposta para o proprio imovel (o banco aceitaria, mas nao faz sentido para o negocio). | O imovel passou a ser de outro proprietario e os interesses da conversa foram ajustados. |
| Duas mudancas de etapa da mesma conversa no mesmo instante (violacao da chave primaria do historico). | As datas do historico passaram a seguir marcos fixos de cada conversa, sempre crescentes. |
| Conta a pagar gravada com numero ja usado pelo repasse automatico (violacao de chave primaria). | Os numeros das contas foram reservados antes de o gatilho do repasse rodar. |
| A multa rescisoria usou um numero de conta ja ocupado. | A sequencia das contas a receber e ajustada antes da rescisao. |
| A consulta de auditoria A02 apontava baixas de 2025 como “sem extrato”, mas o extrato so comeca em marco de 2026. | A consulta passou a olhar so o periodo coberto pelo extrato de cada conta. |
| A consulta A05 media o tempo parado pela data da carga, e nao pela data do negocio. | A consulta passou a usar a data da proposta. |
| Revisao final: a conta guardava a categoria e tambem um tipo que dependia dela, e a RN26 (categoria compativel) nao estava garantida. | O tipo saiu da conta, a categoria ganhou um codigo fixo e um gatilho passou a conferir a RN26 (testes 8.5 e 8.6). |
| Revisao final: o cliente que pediu a exclusao dos dados (PO07) continuava com o telefone no cadastro. | A carga passou a excluir o telefone na anonimizacao: telefone tambem e dado pessoal. |
| Revisao final: o teste do telefone com mascara falhou por tamanho, e nao pela regra de formato. | O caso de teste passou a usar um valor que chega ate a regra (so digitos). |
| Revisao final: os telefones fixos tinham o mesmo formato dos celulares. | Os fixos passaram a ter 8 digitos depois do DDD, para o tipo (celular ou fixo) poder ser deduzido do numero. |

## Checklist de validacao do grupo

A responsabilidade tecnica e do grupo. Antes da entrega, cada item abaixo deve ser conferido por um integrante (marque o nome de quem conferiu):

| # | Conferencia | Como | Conferido por |
|---|---|---|---|
| 1 | Os dados respeitam as PKs | `executar_tudo` sem erro (uma PK repetida aborta a carga) |  |
| 2 | Os dados respeitam as FKs | idem; e consulta A13 |  |
| 3 | Os dados respeitam as constraints e regras | idem; os 61 testes dao OK |  |
| 4 | Os dados fazem sentido para o negocio | ler as conversas, contratos e contas no prototipo (`prototipo/`) |  |
| 5 | Os dados nao criam inconsistencias | consultas de auditoria A01 a A13: so aparecem as situacoes colocadas de proposito |  |
| 6 | As consultas respondem as perguntas certas | comparar os resultados de `evidencias/execucao/04` com a massa |  |
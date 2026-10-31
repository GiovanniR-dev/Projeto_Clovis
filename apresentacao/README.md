# Apresentacao e defesa final

Seguimos o Manual da Apresentacao: 20 minutos na sequencia **EXPLICAR → MOSTRAR → DEFENDER → DEMONSTRAR → PROPOR**, seguidos de 20 minutos de arguicao. Os slides servem de apoio visual, com pouco texto: quem apresenta explica, sem ler.

## Quem apresenta o que

| # | Integrante | Etapa | O que apresenta | Tempo |
|---|---|---|---|---|
| 1 | Julio Cesar Ferreira do Nascimento | Explicar | A empresa, o problema e a necessidade | 2:00 |
| 2 | Joao Vitor Candido Cassiano | Mostrar | A solucao: modulos e problema → requisitos → solucao | 3:00 |
| 3 | Anderson da Silva | Defender | Decisao 1: uma pessoa, varios papeis | 2:00 |
| 4 | Fellipe da Eira Aguiar | Defender | Decisao 2: telefone e tipo de imovel (revisao final) | 2:00 |
| 5 | Guilherme Lucas Correa | Defender | Decisao 3: a soma das comissoes garantida pelo banco | 2:00 |
| 6 | Leonardo Vinicius de Farias | Demonstrar | O banco recusa comissoes acima de 100% (ao vivo) | 2:00 |
| 7 | Gabriel Rocha da Silva | Demonstrar | Um recebimento parcial gera o repasse e a auditoria (ao vivo) | 3:00 |
| 8 | Kayky Fernandes de Andrade | Propor | O que a imobiliaria ganha | 1:30 |
| 9 | Davi Costa Ferraz | Propor | Evolucao: pontuacao de leads | 2:30 |

## As tres decisoes tecnicas defendidas

| Decisao | Problema | Por que decidimos assim | Se fosse diferente |
|---|---|---|---|
| USUARIO com 8 subtipos (especializacao total e compartilhada, PK = FK) | No app original o papel era texto: quem tinha dois papeis virava dois cadastros | Uma pessoa, varios papeis com datas; cada FK exige o papel certo (RN01, RN02, RN32) | Com um campo “tipo”, cadastro duplicado e nenhuma FK garantindo o papel |
| TELEFONE como entidade fraca da pessoa (chave id_usuario + nr_sequencia), com um titular por numero; TIPO_IMOVEL como tabela, com o perfil aceitando varios tipos (N:N) | O professor nao aprovou o telefone com chave propria; casais e socios usam o mesmo numero (devolutiva, ponto 2); o tipo de imovel era texto fixo e o perfil aceitava um tipo so | O numero nao identifica nada: muda de dono e pode estar em duas pessoas; o tipo do telefone se deduz do numero (2FN). O tipo de imovel e uma lista que cresce e e usada por imovel e perfil (RN03, RN47, RN48) | Com o numero na chave, o tipo dependeria de parte dela (2FN); com o tipo em texto, cada tipo novo exigiria alterar o banco, e varios tipos num campo violariam a 1FN |
| Soma das comissoes conferida por gatilho, com o contrato bloqueado | Comissao dividida entre corretores, calculada a mao (devolutiva, ponto 7) | O CHECK so ve uma linha; o gatilho le as outras e impede gravacoes simultaneas acima de 100% (RN20) | Na tela, o pgAdmin e o N8N passariam por cima; com o valor gravado, a comissao ficaria desatualizada |

## As duas demonstracoes

Os passos estao no [roteiro do prototipo](../prototipo/README.md#roteiro-de-demonstracao-5-minutos) (passos 3, 5 e 7).

| Demonstracao | O que mostra | Por que escolhemos | Que informacao produz |
|---|---|---|---|
| Comissao de 95% para o Paulo Nunes no contrato 5, que ja tem 40% | Uma regra de integridade: o banco recusa (RN20) e nada e gravado | Pagar mais do que a corretagem recebida e o erro mais caro | A regra violada e o valor que a soma teria (135%) |
| Recebimento parcial de R$ 1.000 no aluguel de R$ 1.800 do contrato 3 | Quatro tabelas juntas: `conta_receber` → `recebimento` → `conta_pagar` (repasse de R$ 900) → `auditoria` | Era o controle mais manual da imobiliaria e foi uma correcao da devolutiva (RN29, RN30, RN40) | Quanto repassar, a quem e ate quando (G06 e A03), e quem registrou |

## O que mudou na revisao final (para a arguicao)

Depois da conversa com o professor, antes da apresentacao, o modelo mudou nestes pontos (detalhes na [tabela de alteracoes](../docs/modelo-logico/README.md#11-principais-alteracoes-de-modelagem-etapa-2)):

| Mudanca | Onde ver |
|---|---|
| Tipo de imovel virou a tabela `tipo_imovel`; o prototipo busca imoveis por tipo e cadastra imovel novo | Prototipo, Imoveis → Buscar e cadastrar; consulta 20 (itens 1, 1a e 1b) |
| O perfil do cliente aceita varios tipos (`perfil_interesse_tipo`, N:N DESEJA) | Normalizacao, caso 1.5; consulta 20 (item 3a); G15 |
| O telefone virou entidade fraca da pessoa: o numero nao e chave | Normalizacao, caso 2.1; testes 2.1 a 2.7 |
| Origem do contato e forma de pagamento viraram tabelas; os status ficaram como CHECK | [Modelo logico, secao 8](../docs/modelo-logico/README.md#8-listas-de-dominio-check-ou-tabela-revisao-final) |
| 3FN: a conta guardava a categoria e um tipo que dependia dela; agora so a categoria, com codigo fixo | Normalizacao, caso 3.5; testes 8.5 e 8.6 |
| Por que existem `caracteristica` e `imovel_caracteristica`, e quartos, banheiros e vagas ficam no imovel | Modelo logico, secao 8; normalizacao, “O que parece violar a 1FN” |
| Todo o projeto sem acento | Scripts, dados, documentos e prototipo |

## A evolucao proposta

**Pontuacao de leads.** Os corretores atendem por ordem de chegada, e nao pela chance de fechar. Com dados que o banco ja guarda (origem, tempo de resposta, mensagens, imoveis de interesse, visitas e o resultado das conversas antigas), um modelo daria a cada conversa nova a chance de virar contrato e ordenaria a fila de cada corretor. O painel comercial (G01, G03 e G13) mede se a conversao subiu. Cuidados: LGPD (o cliente anonimizado fica fora) e poucos meses de historico. Detalhes em [`docs/bi-ia/bi-e-ia.md`](../docs/bi-ia/bi-e-ia.md).

## Antes de apresentar

1. Rodar o `executar_tudo` para voltar aos dados originais. Cada ensaio grava um recebimento de verdade.
2. Ligar o prototipo e deixar “Agindo como” em Carla Mendes (administradora).
3. Ter copias locais dos slides e do projeto. Se o prototipo falhar, as telas de cada passo estao nos slides de reserva e em [`evidencias/prototipo/`](../evidencias/prototipo/).

Os resultados que dependem da data (dias de atraso, recebido no mes) mudam conforme o dia em que se executa: a massa de dados vai ate 20/10/2026.

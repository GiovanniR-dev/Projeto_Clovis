# Evidencias

## O que ha nesta pasta

| Arquivo | O que mostra |
|---|---|
| `execucao/01_criacao.txt` | Criacao do banco vazio, das tabelas, chaves, indices, gatilhos, visoes e comentarios (sem erros) |
| `execucao/02_massa_de_dados.txt` | Carga da massa de dados e a contagem exata de linhas de cada tabela |
| `execucao/03_select_join_update_delete.txt` | SELECT, JOIN, UPDATE e DELETE, inclusive as operacoes que o banco recusa (avisos “Recusado pelo banco”) |
| `execucao/04_consultas_gerenciais.txt` | Resultado das 15 consultas gerenciais |
| `execucao/05_consultas_auditoria.txt` | Resultado das 13 consultas de auditoria |
| `execucao/06_testes_regras.txt` | Os 61 cenarios de teste das regras, num banco separado, todos “OK” |
| `prototipo/*.png` | Telas do prototipo, inclusive o banco recusando gravacoes (RN20, PO01, CHECK do imovel), o repasse gerado pelo gatilho (RN30), a busca de imoveis por tipo e por bairro, o cadastro de imovel novo com o bairro da cidade do CEP, o perfil com varios tipos e varios bairros e a **busca de imovel na aba Dados do modelo logico** (`39-...` e `40-...`, com o SQL executado) |
| `prototipo/testes_api.txt` | Teste automatico do prototipo: todas as telas (167 enderecos) e 97 gravacoes e conferencias, aceitas e recusadas: 264 de 264 OK |

Os arquivos de `execucao/` sao gerados de novo sempre que se roda `executar_tudo` na pasta do repositorio.

## Teste de consistencia da entrega final (secao 29 do manual)

| Pergunta | Resposta | Onde conferir |
|---|---|---|
| **Requisitos** — as necessidades da empresa continuam representadas? | Sim: cada problema da empresa aponta para os requisitos que o resolvem | README, secao 3; `docs/requisitos/` |
| **Regras de negocio** — estao claras e atualizadas? | Sim: as regras alteradas na devolutiva e na revisao final foram reescritas, e cada uma aponta para o que a garante no banco | `docs/requisitos/`; `docs/modelo-logico/README.md`, secao 7 |
| **DER** — representa corretamente as regras? | Sim: as cardinalidades foram conferidas regra a regra | `docs/diagramas/der/`; historico, secao 14 |
| **Modelo logico** — representa corretamente o DER? | Sim, conferido por script: todo relacionamento tem a FK certa, minimo 1 → NOT NULL, 1:1 → UNIQUE, nenhum atributo faltando | `docs/modelo-logico/README.md` (conferencia automatica no inicio) |
| **Normalizacao** — tabelas ate a 3FN? | Sim: 12 casos reais documentados e o quadro da 2FN para as 18 chaves compostas | `docs/normalizacao/normalizacao.md` |
| **Dicionario** — representa o modelo implementado? | Sim: e gerado do catalogo do banco instalado | `docs/dicionario-dados/dicionario-de-dados.md` |
| **SQL** — implementa o modelo logico? | Sim, conferido por script: mesmas tabelas, colunas, chaves, nulos e CHECKs | `docs/modelo-logico/README.md`; `execucao/01_criacao.txt` |
| **Massa de dados** — permite testar regras e relacionamentos? | Sim: cobre de proposito cada situacao das regras, e nenhuma tabela esta vazia | `sql/dados/README.md`; `execucao/02_massa_de_dados.txt` |
| **Consultas** — respondem a perguntas relevantes? | Sim: cada uma parte de uma pergunta do gestor ou de uma verificacao explicada | `sql/consultas/README.md`; `sql/auditoria/README.md` |
| **BI/IA** — os dados tem potencial analitico identificado? | Sim: indicadores, paineis e quatro aplicacoes de IA com os dados necessarios | `docs/bi-ia/bi-e-ia.md` |
| **GitHub** — outra pessoa consegue compreender e executar o projeto? | Sim: `executar_tudo` recria tudo do zero, e o README explica cada parte | README da raiz |

## Checklist final da equipe (secao 30 do manual)

| Grupo | Item | Situacao |
|---|---|---|
| Primeira entrega revisada | Requisitos, regras, DER, cardinalidades revisados; alteracoes justificadas | Feito — tabela de alteracoes em `docs/modelo-logico/README.md`, secao 1.1 |
| Modelo logico | Tabelas, atributos, PKs, FKs, chaves compostas, N:N, associativas, fracas, restricoes | Feito — secoes 2 a 7 de `docs/modelo-logico/README.md` |
| Normalizacao | 1FN, 2FN, 3FN, dependencias funcionais e justificativas | Feito — `docs/normalizacao/normalizacao.md` |
| Dicionario de dados | Tabelas, atributos, tipos, PKs, FKs, restricoes; coerente com o SQL | Feito — gerado do banco |
| SQL | CREATE DATABASE, CREATE TABLE, PK, FK, NOT NULL, UNIQUE, CHECK, DEFAULT, INSERT, SELECT, JOIN, UPDATE, DELETE; executado e testado | Feito — `sql/` e `execucao/` |
| Massa de dados | Quantidade, coerencia, relacionamentos e restricoes testados; prompts de IA documentados | Feito — `sql/dados/README.md` e `docs/uso-de-ia/uso-de-ia.md` |
| Consultas | Gerenciais e de auditoria, com a pergunta e a finalidade | Feito — `sql/consultas/` e `sql/auditoria/` |
| BI e IA | Informacoes estrategicas, indicadores, BI, IA, dados necessarios, beneficio | Feito — `docs/bi-ia/bi-e-ia.md` |
| GitHub e documentacao | README, DER, modelo logico, dicionario, normalizacao, scripts e consultas organizados | Feito |
| GitHub e documentacao | Historico de commits preservado; evidencias colaborativas; todos os integrantes contribuiram | Historico de commits preservado (primeira entrega e entrega final no mesmo repositorio). A participacao de cada integrante fica registrada no diario de bordo e na avaliacao 360 |
| Uso de IA | Validacao dos dados gerados com IA | **A cargo da equipe:** preencher o checklist de `docs/uso-de-ia/uso-de-ia.md` |

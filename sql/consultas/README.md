# Consultas

| Arquivo | Conteudo |
|---|---|
| `20_select_join_update_delete.sql` | SELECT, JOIN, LEFT JOIN, UPDATE e DELETE com sentido de negocio, incluindo exclusoes em cascata, SET NULL e operacoes que o banco recusa. As alteracoes ficam dentro de BEGIN … ROLLBACK, para nao mudar a massa de dados. |
| `21_consultas_gerenciais.sql` | 15 consultas gerenciais (abaixo). |
| `../auditoria/30_consultas_auditoria.sql` | 13 consultas de auditoria (veja `sql/auditoria/README.md`). |

## Consultas gerenciais (Etapas 18 e 20)

O manual pede para comecar pela pergunta do gestor, e nao pelo JOIN: **CONSULTA GERENCIAL = PERGUNTA DO NEGOCIO + SQL + INFORMACAO PARA DECISAO**, e depois pensar em **DADO → INFORMACAO → DECISAO**. Cada consulta abaixo segue esse caminho.

**Sobre os resultados mostrados:** foram obtidos executando as consultas em 31/10/2026. Varias consultas comparam datas com `CURRENT_DATE` (o dia de hoje), entao as colunas de dias e a situacao prevista/atrasada mudam conforme o dia em que forem executadas: os dados nao mudam, muda a data de comparacao.

| # | Pergunta do negocio |
|---|---|
| [G01](#g01--funil-comercial) | Quantas conversas chegaram a cada etapa do funil e quanto se perde de uma etapa para a outra? |
| [G02](#g02--origem-dos-clientes) | De onde vem os clientes que fecham negocio? |
| [G03](#g03--desempenho-dos-corretores) | Quanto cada corretor atende, visita, propoe e fecha, e quanto ja tem de comissao liberada? |
| [G04](#g04--receita-por-mes) | Quanto a imobiliaria faturou por mes, separando corretagem, taxa de administracao e multas? |
| [G05](#g05--inadimplencia) | Quais alugueis estao em atraso, de quem e ha quantos dias? |
| [G06](#g06--repasses-aos-proprietarios) | Quais repasses estao para vencer ou atrasados? |
| [G07](#g07--imoveis-mais-procurados) | Quais imoveis despertam mais interesse, visitas e propostas? |
| [G08](#g08--imoveis-parados) | Quais imoveis disponiveis nao recebem visita ha mais de 60 dias? |
| [G09](#g09--demanda--oferta-por-regiao) | Onde ha mais clientes procurando do que imoveis disponiveis? |
| [G10](#g10--tempo-ate-o-contrato) | Quanto tempo leva, em media, do primeiro contato ate a assinatura? |
| [G11](#g11--descontos-nas-propostas) | Qual e o desconto medio pedido e quantas propostas precisaram de autorizacao? |
| [G12](#g12--receita-recorrente-prevista) | Quanto de aluguel e de taxa de administracao esta previsto para os proximos tres meses? |
| [G13](#g13--tempo-de-primeira-resposta) | Quanto tempo cada corretor leva para responder o primeiro contato no WhatsApp? |
| [G14](#g14--automacao-n8n) | Quantas demandas a automacao recebeu, enviou e em quantas falhou? |
| [G15](#g15--demanda--oferta-por-tipo-de-imovel) | Quais tipos de imovel os clientes procuram, comparados com os imoveis disponiveis de cada tipo? |

### G01 — Funil comercial

**Pergunta do negocio:** Quantas conversas chegaram a cada etapa do funil e quanto se perde de uma etapa para a outra?

**Dado:** conversa, funil_estagio, historico_estagio.

**Informacao** (resultado na massa de dados):

| ordem | etapa | conversas_que_chegaram | pct_do_total |
|---|---|---|---|
| 1 | Novo contato | 45 | 100,00 |
| 2 | Qualificacao | 34 | 75,60 |
| 3 | Visita | 20 | 44,40 |
| 4 | Proposta | 12 | 26,70 |
| 5 | Contrato | 9 | 20,00 |
| 6 | Ganho | 7 | 15,60 |
| 7 | Perdido | 12 | 26,70 |

**Decisao:** Mostra em que etapa os clientes desistem. Se a queda maior esta entre visita e proposta, o problema e a selecao dos imoveis visitados; se esta no comeco, e o tempo de resposta.

<details><summary>SQL</summary>

```sql
SELECT fe.nr_ordem AS ordem, fe.nm_estagio AS etapa,
       count(DISTINCT h.id_conversa) AS conversas_que_chegaram,
       round(100.0 * count(DISTINCT h.id_conversa) / (SELECT count(*) FROM conversa), 1) AS pct_do_total
  FROM funil_estagio fe
  LEFT JOIN historico_estagio h ON h.id_estagio = fe.id_estagio
 GROUP BY fe.id_estagio, fe.nr_ordem, fe.nm_estagio
 ORDER BY fe.nr_ordem;
```

</details>

### G02 — Origem dos clientes

**Pergunta do negocio:** De onde vem os clientes que fecham negocio?

**Dado:** cliente, contrato, conversa, origem_contato, proposta, usuario.

**Informacao** (resultado na massa de dados):

| origem | clientes | conversas | contratos_assinados | conversao_pct |
|---|---|---|---|---|
| WhatsApp | 15 | 19 | 4 | 26,70 |
| Site | 6 | 7 | 1 | 16,70 |
| Instagram | 5 | 7 | 1 | 20,00 |
| Indicacao | 4 | 5 | 1 | 25,00 |
| Portal imobiliario | 4 | 7 | 1 | 25,00 |

**Decisao:** Indica onde investir a divulgacao: o canal com mais contratos por cliente merece mais verba; o que so traz contatos precisa de outra abordagem.

<details><summary>SQL</summary>

```sql
SELECT coalesce(oc.nm_origem, '(nao informada)') AS origem,
       count(DISTINCT cl.id_usuario) AS clientes,
       count(DISTINCT cv.id_conversa) AS conversas,
       count(DISTINCT ct.id_contrato) FILTER (WHERE ct.dt_assinatura IS NOT NULL) AS contratos_assinados,
       round(100.0 * count(DISTINCT ct.id_contrato) FILTER (WHERE ct.dt_assinatura IS NOT NULL)
             / NULLIF(count(DISTINCT cl.id_usuario), 0), 1) AS conversao_pct
  FROM cliente cl
  JOIN usuario u ON u.id_usuario = cl.id_usuario
  LEFT JOIN origem_contato oc ON oc.id_origem = u.id_origem
  LEFT JOIN conversa cv ON cv.id_cliente = cl.id_usuario
  LEFT JOIN proposta p ON p.id_cliente = cl.id_usuario
  LEFT JOIN contrato ct ON ct.id_proposta = p.id_proposta
 GROUP BY oc.nm_origem
 ORDER BY contratos_assinados DESC, clientes DESC;
```

</details>

### G03 — Desempenho dos corretores

**Pergunta do negocio:** Quanto cada corretor atende, visita, propoe e fecha, e quanto ja tem de comissao liberada?

**Dado:** contrato, conversa, corretor, proposta, usuario, visita, vw_comissao.

**Informacao** (resultado na massa de dados):

| corretor | situacao | conversas | visitas | propostas | contratos | comissao_liberada |
|---|---|---|---|---|---|---|
| Rui Almeida | ativo | 9 | 7 | 4 | 2 | 12.280,00 |
| Paulo Nunes | ativo | 10 | 7 | 5 | 2 | 19.470,00 |
| Bianca Freitas | ativo | 8 | 4 | 3 | 2 | 1.350,00 |
| Lia Martins | ativo | 11 | 6 | 3 | 1 | 8.320,00 |
| Sergio Dias | saiu em 30/06/2026 | 4 | 1 | 1 | 1 | 1.000,00 |

**Decisao:** Apoia a distribuicao de novos contatos e o acompanhamento individual: quem visita muito e fecha pouco precisa de apoio na negociacao.

<details><summary>SQL</summary>

```sql
SELECT u.nm_usuario AS corretor,
       CASE WHEN co.dt_fim IS NULL THEN 'ativo' ELSE 'saiu em ' || to_char(co.dt_fim, 'DD/MM/YYYY') END AS situacao,
       (SELECT count(*) FROM conversa c WHERE c.id_corretor = co.id_usuario) AS conversas,
       (SELECT count(*) FROM visita v WHERE v.id_corretor = co.id_usuario AND v.st_visita = 'realizada') AS visitas,
       (SELECT count(*) FROM proposta p WHERE p.id_corretor = co.id_usuario) AS propostas,
       (SELECT count(*) FROM proposta p JOIN contrato ct ON ct.id_proposta = p.id_proposta
         WHERE p.id_corretor = co.id_usuario AND ct.dt_assinatura IS NOT NULL) AS contratos,
       (SELECT coalesce(sum(vc.vl_comissao), 0) FROM vw_comissao vc
         WHERE vc.id_corretor = co.id_usuario AND vc.st_comissao = 'liberada') AS comissao_liberada
  FROM corretor co
  JOIN usuario u ON u.id_usuario = co.id_usuario
 ORDER BY contratos DESC, visitas DESC;
```

</details>

### G04 — Receita por mes

**Pergunta do negocio:** Quanto a imobiliaria faturou por mes, separando corretagem, taxa de administracao e multas?

**Dado:** categoria_financeira, conta_pagar, conta_receber, recebimento.

**Informacao** (resultado na massa de dados):

| mes | corretagem_e_intermediacao | taxa_de_administracao | multas | receita_total |
|---|---|---|---|---|
| 01/2026 | 0,00 | 280,00 | 0,00 | 280,00 |
| 02/2026 | 0,00 | 280,00 | 0,00 | 280,00 |
| 03/2026 | 4.700,00 | 456,00 | 0,00 | 5.156,00 |
| 04/2026 | 1.800,00 | 886,00 | 0,00 | 2.686,00 |
| 05/2026 | 0,00 | 886,00 | 0,00 | 886,00 |
| 06/2026 | 37.200,00 | 886,00 | 0,00 | 38.086,00 |
| 07/2026 | 4.500,00 | 1.246,00 | 0,00 | 5.746,00 |
| 08/2026 | 0,00 | 996,00 | 5.000,00 | 5.996,00 |

*… e mais 2 linhas.*

**Decisao:** Mostra a dependencia das vendas (receita irregular) e das locacoes (receita recorrente) e ajuda a planejar o caixa e as metas.

<details><summary>SQL</summary>

```sql
WITH receitas AS (
    SELECT date_trunc('month', r.dt_recebimento)::date AS mes,
           CASE WHEN cf.cd_categoria IN ('corretagem_venda', 'intermediacao_locacao') THEN r.vl_recebido ELSE 0 END AS corretagem,
           CASE WHEN cf.cd_categoria = 'aluguel' THEN r.vl_recebido - cp.vl_pagar ELSE 0 END AS taxa_administracao,
           CASE WHEN cf.cd_categoria = 'multa_rescisoria' THEN r.vl_recebido ELSE 0 END AS multa
      FROM recebimento r
      JOIN conta_receber cr ON cr.id_conta_receber = r.id_conta_receber
      JOIN categoria_financeira cf ON cf.id_categoria = cr.id_categoria
      LEFT JOIN conta_pagar cp ON cp.id_conta_receber_origem = r.id_conta_receber
                              AND cp.nr_recebimento_origem = r.nr_recebimento)
SELECT to_char(mes, 'MM/YYYY') AS mes,
       sum(corretagem) AS corretagem_e_intermediacao,
       sum(taxa_administracao) AS taxa_de_administracao,
       sum(multa) AS multas,
       sum(corretagem + taxa_administracao + multa) AS receita_total
  FROM receitas
 WHERE mes >= DATE '2026-01-01'
 GROUP BY mes
 ORDER BY mes;
```

</details>

### G05 — Inadimplencia

**Pergunta do negocio:** Quais alugueis estao em atraso, de quem e ha quantos dias?

**Dado:** usuario, vw_conta_receber.

**Informacao** (resultado na massa de dados):

| inquilino | contrato | conta | vencimento | valor | recebido | saldo | dias_de_atraso |
|---|---|---|---|---|---|---|---|
| Diego Alves | 3 | Aluguel 09/2026 - contrato 3 | 10/09/2026 | 1.800,00 | 0,00 | 1.800,00 | 51 |
| Camila Rocha | 2 | Aluguel 10/2026 - contrato 2 | 05/10/2026 | 2.200,00 | 1.200,00 | 1.000,00 | 26 |
| Diego Alves | 3 | Aluguel 10/2026 - contrato 3 | 10/10/2026 | 1.800,00 | 0,00 | 1.800,00 | 21 |

**Decisao:** Define a ordem da cobranca e quando acionar a garantia do contrato; tambem mostra se um inquilino atrasa com frequencia.

<details><summary>SQL</summary>

```sql
SELECT u.nm_usuario AS inquilino, cr.id_contrato AS contrato, cr.ds_conta AS conta,
       to_char(cr.dt_vencimento, 'DD/MM/YYYY') AS vencimento,
       cr.vl_receber AS valor, cr.vl_baixado AS recebido, cr.vl_receber - cr.vl_baixado AS saldo,
       CURRENT_DATE - cr.dt_vencimento AS dias_de_atraso
  FROM vw_conta_receber cr
  JOIN usuario u ON u.id_usuario = cr.id_pagador
 WHERE cr.st_conta = 'atrasada'
 ORDER BY dias_de_atraso DESC;
```

</details>

### G06 — Repasses aos proprietarios

**Pergunta do negocio:** Quais repasses estao para vencer ou atrasados?

**Dado:** categoria_financeira, usuario, vw_conta_pagar.

**Informacao** (resultado na massa de dados):

| proprietario | conta | vencimento | valor | situacao |
|---|---|---|---|---|
| Ricardo Pires | Repasse do recebimento 43/1 | 11/09/2026 | 4.140,00 | atrasada |
| Ricardo Pires | Repasse do recebimento 44/1 | 23/10/2026 | 4.140,00 | atrasada |

**Decisao:** O repasse tem prazo de 5 dias uteis (PO05): a lista organiza os pagamentos do financeiro e evita multa e desgaste com o proprietario.

<details><summary>SQL</summary>

```sql
SELECT u.nm_usuario AS proprietario, cp.ds_conta AS conta,
       to_char(cp.dt_vencimento, 'DD/MM/YYYY') AS vencimento, cp.vl_pagar AS valor, cp.st_conta AS situacao
  FROM vw_conta_pagar cp
  JOIN categoria_financeira cf ON cf.id_categoria = cp.id_categoria
  JOIN usuario u ON u.id_usuario = cp.id_favorecido
 WHERE cf.cd_categoria = 'repasse' AND cp.st_conta IN ('prevista', 'parcial', 'atrasada')
 ORDER BY cp.dt_vencimento;
```

</details>

### G07 — Imoveis mais procurados

**Pergunta do negocio:** Quais imoveis despertam mais interesse, visitas e propostas?

**Dado:** bairro, cep, cidade, conversa_imovel, imovel, proposta, tipo_imovel, visita.

**Informacao** (resultado na massa de dados):

| codigo | tipo | bairro | cidade | situacao | interesses | visitas | propostas |
|---|---|---|---|---|---|---|---|
| IMB-3516 | Apartamento | Gopouva | Guarulhos | disponivel | 9 | 2 | 0 |
| IMB-3514 | Casa | Penha | Sao Paulo | disponivel | 8 | 2 | 0 |
| IMB-3519 | Apartamento | Tatuape | Sao Paulo | disponivel | 8 | 1 | 0 |
| IMB-3521 | Cobertura | Pinheiros | Sao Paulo | disponivel | 7 | 1 | 0 |
| IMB-3511 | Apartamento | Macedo | Guarulhos | disponivel | 6 | 2 | 1 |
| IMB-3515 | Kitnet | Vila Mariana | Sao Paulo | disponivel | 4 | 1 | 0 |
| IMB-3526 | Apartamento | Picanco | Guarulhos | disponivel | 4 | 1 | 0 |
| IMB-3528 | Casa | Gopouva | Guarulhos | disponivel | 4 | 0 | 0 |

*… e mais 2 linhas.*

**Decisao:** Mostra o perfil de imovel que o mercado procura: orienta a captacao de imoveis parecidos e o destaque nos anuncios.

<details><summary>SQL</summary>

```sql
SELECT i.cd_imobizi AS codigo, t.nm_tipo_imovel AS tipo, b.nm_bairro AS bairro, ci.nm_cidade AS cidade, i.st_imovel AS situacao,
       count(DISTINCT x.id_conversa) AS interesses, count(DISTINCT v.id_visita) AS visitas, count(DISTINCT p.id_proposta) AS propostas
  FROM imovel i
  JOIN tipo_imovel t ON t.id_tipo_imovel = i.id_tipo_imovel
  JOIN bairro b ON b.id_bairro = i.id_bairro
  JOIN cep ON cep.nr_cep = i.nr_cep
  JOIN cidade ci ON ci.id_cidade = cep.id_cidade
  LEFT JOIN conversa_imovel x ON x.id_imovel = i.id_imovel
  LEFT JOIN visita v ON v.id_imovel = i.id_imovel
  LEFT JOIN proposta p ON p.id_imovel = i.id_imovel
 GROUP BY i.id_imovel, t.nm_tipo_imovel, b.nm_bairro, ci.nm_cidade
 ORDER BY interesses DESC, visitas DESC, propostas DESC
 LIMIT 10;
```

</details>

### G08 — Imoveis parados

**Pergunta do negocio:** Quais imoveis disponiveis nao recebem visita ha mais de 60 dias?

**Dado:** bairro, imovel, tipo_imovel, visita.

**Informacao** (resultado na massa de dados):

| codigo | tipo | bairro | finalidade | valor | ultima_visita | dias_na_carteira |
|---|---|---|---|---|---|---|
| IMB-3520 | Casa | Vila Galvao | locacao | 2.600,00 | — | 419 |
| IMB-3529 | Apartamento | Vila Mariana | venda | 830.000,00 | — | 409 |
| IMB-3522 | Apartamento | Bosque Maia | locacao | 1.900,00 | — | 379 |
| IMB-3528 | Casa | Gopouva | venda | 480.000,00 | — | 378 |
| IMB-3518 | Loja | Centro | ambas | 720.000,00 | — | 300 |
| IMB-3530 | Casa | Macedo | locacao | 2.100,00 | — | 270 |
| IMB-3517 | Terreno | Parque Rodrigo Barreto | venda | 230.000,00 | — | 269 |
| IMB-3501 | Apartamento | Tatuape | locacao | 2.800,00 | 06/09/2025 | 430 |

*… e mais 15 linhas.*

**Decisao:** Candidatos a rever preco, fotos ou anuncio, ou a conversar com o proprietario sobre a exclusividade.

<details><summary>SQL</summary>

```sql
SELECT i.cd_imobizi AS codigo, t.nm_tipo_imovel AS tipo, b.nm_bairro AS bairro, i.tp_finalidade AS finalidade,
       coalesce(i.vl_venda, i.vl_aluguel) AS valor, to_char(max(v.dt_visita), 'DD/MM/YYYY') AS ultima_visita,
       CURRENT_DATE - i.dt_cadastro::date AS dias_na_carteira
  FROM imovel i
  JOIN tipo_imovel t ON t.id_tipo_imovel = i.id_tipo_imovel
  JOIN bairro b ON b.id_bairro = i.id_bairro
  LEFT JOIN visita v ON v.id_imovel = i.id_imovel AND v.st_visita = 'realizada'
 WHERE i.st_imovel = 'disponivel'
 GROUP BY i.id_imovel, t.nm_tipo_imovel, b.nm_bairro
HAVING max(v.dt_visita) IS NULL OR max(v.dt_visita) < CURRENT_DATE - 60
 ORDER BY max(v.dt_visita) NULLS FIRST, dias_na_carteira DESC;
```

</details>

### G09 — Demanda × oferta por regiao

**Pergunta do negocio:** Onde ha mais clientes procurando do que imoveis disponiveis?

**Dado:** bairro, cep, cidade, imovel, perfil_interesse, perfil_interesse_bairro.

**Informacao** (resultado na massa de dados):

| cidade | bairro | finalidade | perfis | imoveis_disponiveis |
|---|---|---|---|---|
| Sao Paulo | Tatuape | venda | 4 | 2 |
| Sao Paulo | Mooca | locacao | 3 | 1 |
| Sao Paulo | Tatuape | locacao | 3 | 2 |
| Guarulhos | Centro | venda | 2 | 1 |
| Guarulhos | Centro | locacao | 2 | 1 |
| Guarulhos | Gopouva | locacao | 2 | 1 |
| Guarulhos | Gopouva | venda | 2 | 1 |
| Guarulhos | Macedo | locacao | 2 | 1 |

*… e mais 16 linhas.*

**Decisao:** Indica onde captar novos imoveis: regiao com muitos perfis e pouca oferta e oportunidade perdida.

<details><summary>SQL</summary>

```sql
WITH demanda AS (   -- cada bairro aceito conta o perfil (ABRANGE); perfil sem bairro aceita qualquer bairro da cidade
    SELECT p.id_cidade, pb.id_bairro, p.tp_finalidade, count(*) AS perfis
      FROM perfil_interesse p
      LEFT JOIN perfil_interesse_bairro pb ON pb.id_usuario = p.id_usuario AND pb.nr_perfil = p.nr_perfil
     GROUP BY p.id_cidade, pb.id_bairro, p.tp_finalidade)
SELECT ci.nm_cidade AS cidade, coalesce(b.nm_bairro, '(qualquer bairro)') AS bairro, d.tp_finalidade AS finalidade, d.perfis,
       (SELECT count(*) FROM imovel i JOIN cep ce ON ce.nr_cep = i.nr_cep
         WHERE i.st_imovel = 'disponivel' AND ce.id_cidade = d.id_cidade
           AND (d.id_bairro IS NULL OR i.id_bairro = d.id_bairro)
           AND i.tp_finalidade IN (d.tp_finalidade, 'ambas')) AS imoveis_disponiveis
  FROM demanda d
  JOIN cidade ci ON ci.id_cidade = d.id_cidade
  LEFT JOIN bairro b ON b.id_bairro = d.id_bairro
 ORDER BY d.perfis DESC, imoveis_disponiveis, cidade, bairro;
```

</details>

### G10 — Tempo ate o contrato

**Pergunta do negocio:** Quanto tempo leva, em media, do primeiro contato ate a assinatura?

**Dado:** contrato, conversa, conversa_imovel, proposta.

**Informacao** (resultado na massa de dados):

| tipo | contratos | dias_em_media | menor | maior |
|---|---|---|---|---|
| locacao | 5 | 43,00 | 35 | 68 |
| venda | 3 | 64,00 | 57 | 72 |

**Decisao:** Ajuda a prever o fechamento das negociacoes em andamento e a medir se as melhorias no atendimento encurtam o ciclo.

<details><summary>SQL</summary>

```sql
SELECT ct.tp_contrato AS tipo, count(*) AS contratos,
       round(avg(ct.dt_assinatura - x.primeiro_contato)) AS dias_em_media,
       min(ct.dt_assinatura - x.primeiro_contato) AS menor, max(ct.dt_assinatura - x.primeiro_contato) AS maior
  FROM contrato ct
  JOIN proposta p ON p.id_proposta = ct.id_proposta
  JOIN LATERAL (SELECT min(cv.dt_inicio)::date AS primeiro_contato
                  FROM conversa cv JOIN conversa_imovel ci ON ci.id_conversa = cv.id_conversa
                 WHERE cv.id_cliente = p.id_cliente AND ci.id_imovel = p.id_imovel) x ON TRUE
 WHERE ct.dt_assinatura IS NOT NULL
 GROUP BY ct.tp_contrato;
```

</details>

### G11 — Descontos nas propostas

**Pergunta do negocio:** Qual e o desconto medio pedido e quantas propostas precisaram de autorizacao?

**Dado:** proposta.

**Informacao** (resultado na massa de dados):

| situacao | propostas | desconto_medio_pct | com_autorizacao |
|---|---|---|---|
| aceita | 9 | 0,90 | 0 |
| substituida | 3 | 6,90 | 0 |
| recusada | 2 | 13,10 | 2 |
| pendente | 2 | 9,30 | 1 |

**Decisao:** Calibra o preco anunciado: descontos altos e frequentes indicam imoveis acima do mercado; autorizacoes frequentes indicam a regra de 10% muito apertada.

<details><summary>SQL</summary>

```sql
SELECT st_proposta AS situacao, count(*) AS propostas,
       round(avg(100 * (1 - vl_proposto / vl_anunciado)), 1) AS desconto_medio_pct,
       count(*) FILTER (WHERE id_autorizador IS NOT NULL) AS com_autorizacao
  FROM proposta
 GROUP BY st_proposta
 ORDER BY propostas DESC;
```

</details>

### G12 — Receita recorrente prevista

**Pergunta do negocio:** Quanto de aluguel e de taxa de administracao esta previsto para os proximos tres meses?

**Dado:** contrato.

**Informacao** (resultado na massa de dados):

| mes | locacoes_vigentes | aluguel_previsto | taxa_prevista |
|---|---|---|---|
| 11/2026 | 3 | 8.500,00 | 716,00 |
| 12/2026 | 3 | 8.500,00 | 716,00 |
| 01/2027 | 3 | 8.500,00 | 716,00 |

**Decisao:** Base do planejamento de caixa: a receita recorrente das locacoes cobre os custos fixos?

<details><summary>SQL</summary>

```sql
SELECT to_char(m, 'MM/YYYY') AS mes, count(*) AS locacoes_vigentes,
       sum(ct.vl_final) AS aluguel_previsto,
       round(sum(ct.vl_final * ct.pc_administracao / 100), 2) AS taxa_prevista
  FROM contrato ct
 CROSS JOIN generate_series(date_trunc('month', CURRENT_DATE) + INTERVAL '1 month',
                            date_trunc('month', CURRENT_DATE) + INTERVAL '3 month', INTERVAL '1 month') AS m
 WHERE ct.tp_contrato = 'locacao' AND ct.st_contrato = 'vigente' AND m::date <= ct.dt_fim
 GROUP BY m
 ORDER BY m;
```

</details>

### G13 — Tempo de primeira resposta

**Pergunta do negocio:** Quanto tempo cada corretor leva para responder o primeiro contato no WhatsApp?

**Dado:** conversa, mensagem, usuario.

**Informacao** (resultado na massa de dados):

| corretor | conversas | minutos_em_media |
|---|---|---|
| Lia Martins | 11 | 102,00 |
| Paulo Nunes | 10 | 117,00 |
| (sem corretor) | 3 | 121,00 |
| Bianca Freitas | 8 | 125,00 |
| Sergio Dias | 4 | 131,00 |
| Rui Almeida | 9 | 153,00 |

**Decisao:** Mede o atendimento contra a meta do RNF05; corretor com resposta lenta perde clientes no comeco do funil.

<details><summary>SQL</summary>

```sql
WITH t AS (
    SELECT cv.id_conversa, cv.id_corretor,
           min(m.dt_mensagem) FILTER (WHERE m.tp_direcao = 'entrada') AS primeira_entrada,
           min(m.dt_mensagem) FILTER (WHERE m.tp_direcao = 'saida') AS primeira_saida
      FROM conversa cv JOIN mensagem m ON m.id_conversa = cv.id_conversa
     GROUP BY cv.id_conversa, cv.id_corretor)
SELECT coalesce(u.nm_usuario, '(sem corretor)') AS corretor, count(*) AS conversas,
       round(avg(extract(epoch FROM primeira_saida - primeira_entrada) / 60)) AS minutos_em_media
  FROM t LEFT JOIN usuario u ON u.id_usuario = t.id_corretor
 WHERE primeira_saida > primeira_entrada
 GROUP BY u.nm_usuario
 ORDER BY minutos_em_media;
```

</details>

### G14 — Automacao N8N

**Pergunta do negocio:** Quantas demandas a automacao recebeu, enviou e em quantas falhou?

**Dado:** automacao_execucao.

**Informacao** (resultado na massa de dados):

| situacao | execucoes | pct | minutos_ate_enviar |
|---|---|---|---|
| enviada | 30 | 88,20 | 2,00 |
| recebida | 2 | 5,90 | — |
| erro | 1 | 2,90 | — |
| processada | 1 | 2,90 | — |

**Decisao:** Mostra se a automacao esta cumprindo o papel de responder sozinha e quando e preciso revisar o fluxo do N8N ou o seletor de imoveis.

<details><summary>SQL</summary>

```sql
SELECT st_execucao AS situacao, count(*) AS execucoes,
       round(100.0 * count(*) / sum(count(*)) OVER (), 1) AS pct,
       round(avg(extract(epoch FROM dt_envio - dt_execucao) / 60), 1) AS minutos_ate_enviar
  FROM automacao_execucao
 GROUP BY st_execucao
 ORDER BY execucoes DESC;
```

</details>

### G15 — Demanda × oferta por tipo de imovel

**Pergunta do negocio:** Quais tipos de imovel os clientes procuram, comparados com os imoveis disponiveis de cada tipo?

**Dado:** imovel, perfil_interesse, perfil_interesse_tipo, tipo_imovel.

**Informacao** (resultado na massa de dados):

| tipo | finalidade | perfis_que_aceitam | imoveis_disponiveis |
|---|---|---|---|
| Apartamento | locacao | 8 | 7 |
| Casa | venda | 7 | 4 |
| Apartamento | venda | 7 | 8 |
| Kitnet | locacao | 6 | 1 |
| Cobertura | venda | 4 | 1 |
| Casa | locacao | 4 | 3 |
| Casa em condominio | locacao | 2 | 0 |
| Casa em condominio | venda | 2 | 1 |

*… e mais 4 linhas.*

**Decisao:** Orienta a captacao: tipo com muitos perfis e pouca oferta e o primeiro a captar; tipo com oferta e sem procura pede revisao de preco ou de anuncio. Perfis sem tipo aceitam qualquer tipo e nao entram na contagem.

<details><summary>SQL</summary>

```sql
WITH demanda AS (
    SELECT pt.id_tipo_imovel, p.tp_finalidade, count(*) AS perfis
      FROM perfil_interesse_tipo pt
      JOIN perfil_interesse p ON p.id_usuario = pt.id_usuario AND p.nr_perfil = pt.nr_perfil
     GROUP BY pt.id_tipo_imovel, p.tp_finalidade),
oferta AS (
    SELECT i.id_tipo_imovel, f.fin AS tp_finalidade, count(*) AS imoveis
      FROM imovel i
     CROSS JOIN (VALUES ('venda'), ('locacao')) AS f(fin)
     WHERE i.st_imovel = 'disponivel' AND i.tp_finalidade IN (f.fin, 'ambas')
     GROUP BY i.id_tipo_imovel, f.fin)
SELECT t.nm_tipo_imovel AS tipo, x.fin AS finalidade,
       coalesce(d.perfis, 0) AS perfis_que_aceitam, coalesce(o.imoveis, 0) AS imoveis_disponiveis
  FROM tipo_imovel t
 CROSS JOIN (VALUES ('venda'), ('locacao')) AS x(fin)
  LEFT JOIN demanda d ON d.id_tipo_imovel = t.id_tipo_imovel AND d.tp_finalidade = x.fin
  LEFT JOIN oferta o ON o.id_tipo_imovel = t.id_tipo_imovel AND o.tp_finalidade = x.fin
 WHERE d.perfis IS NOT NULL OR o.imoveis IS NOT NULL
 ORDER BY perfis_que_aceitam DESC, imoveis_disponiveis, tipo;
```

</details>

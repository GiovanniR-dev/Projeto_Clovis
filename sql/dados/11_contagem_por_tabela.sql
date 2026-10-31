-- =====================================================================
-- CRMoveis - Conferencia do volume da massa de dados (Etapa 16)
-- psql -d crmoveis -f sql/dados/11_contagem_por_tabela.sql
-- Conta as linhas de cada tabela (contagem exata, nao a estimativa das estatisticas).
-- =====================================================================
SELECT t.table_name AS tabela,
       (xpath('/row/c/text()', query_to_xml(format('SELECT count(*) AS c FROM %I', t.table_name), FALSE, TRUE, '')))[1]::text::integer AS linhas
  FROM information_schema.tables t
 WHERE t.table_schema = 'public' AND t.table_type = 'BASE TABLE'
 ORDER BY t.table_name;

#!/usr/bin/env bash
# =====================================================================
# CRMoveis · executa o projeto inteiro a partir de um banco vazio (Etapa 15 do manual)
#   BANCO VAZIO → TABELAS → RESTRICOES → DADOS → CONSULTAS → TESTES → RESULTADOS
# Uso (na pasta do repositorio):   ./executar_tudo.sh
# Conexao: as variaveis padrao do PostgreSQL (PGHOST, PGPORT, PGUSER, PGPASSWORD).
#   Ex.: PGHOST=localhost PGUSER=postgres PGPASSWORD=suasenha ./executar_tudo.sh
# Saidas: evidencias/execucao/*.txt
# =====================================================================
set -euo pipefail
cd "$(dirname "$0")"
export PGCLIENTENCODING=UTF8
OUT=evidencias/execucao
mkdir -p "$OUT"
PSQL="psql -X -v ON_ERROR_STOP=1 -q"
DDL="sql/ddl/01_tabelas.sql sql/ddl/02_chaves_estrangeiras.sql sql/ddl/03_indices.sql sql/ddl/04_regras_gatilhos_procedimentos.sql sql/ddl/05_visoes.sql sql/ddl/06_comentarios.sql sql/dados/07_dados_de_referencia.sql"

echo "1/5  Criando o banco crmoveis (vazio)"
$PSQL -d postgres -f sql/00_criar_banco.sql > "$OUT/01_criacao.txt" 2>&1

echo "2/5  Tabelas, chaves, restricoes, gatilhos, visoes, comentarios e dados de referencia"
for f in $DDL; do $PSQL -d crmoveis -f "$f"; done >> "$OUT/01_criacao.txt" 2>&1

echo "3/5  Massa de dados"
$PSQL -d crmoveis -f sql/dados/10_massa_de_dados.sql > "$OUT/02_massa_de_dados.txt" 2>&1
$PSQL -d crmoveis -f sql/dados/11_contagem_por_tabela.sql >> "$OUT/02_massa_de_dados.txt" 2>&1

echo "4/5  Consultas (SELECT/JOIN/UPDATE/DELETE, gerenciais e auditoria)"
$PSQL -d crmoveis -f sql/consultas/20_select_join_update_delete.sql > "$OUT/03_select_join_update_delete.txt" 2>&1
$PSQL -d crmoveis -f sql/consultas/21_consultas_gerenciais.sql      > "$OUT/04_consultas_gerenciais.txt" 2>&1
$PSQL -d crmoveis -f sql/auditoria/30_consultas_auditoria.sql       > "$OUT/05_consultas_auditoria.txt" 2>&1

echo "5/5  Testes das regras num banco separado (crmoveis_testes)"
$PSQL -d postgres -c "DROP DATABASE IF EXISTS crmoveis_testes" -c "CREATE DATABASE crmoveis_testes WITH ENCODING 'UTF8' TEMPLATE template0" > /dev/null 2>&1
for f in $DDL; do $PSQL -d crmoveis_testes -f "$f"; done > /dev/null 2>&1
$PSQL -d crmoveis_testes -f sql/testes/40_testes_regras.sql > "$OUT/06_testes_regras.txt" 2>&1

OK=$(grep -c "| OK$" "$OUT/06_testes_regras.txt" || true)
FALHOU=$(grep -c "| FALHOU$" "$OUT/06_testes_regras.txt" || true)
echo
echo "Pronto. Testes: $OK OK, $FALHOU falharam. Resultados em $OUT/"
[ "$FALHOU" = "0" ]

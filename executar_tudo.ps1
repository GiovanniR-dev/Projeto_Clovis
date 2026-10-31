# =====================================================================
# CRMoveis · executa o projeto inteiro a partir de um banco vazio (Etapa 15 do manual)
#   BANCO VAZIO → TABELAS → RESTRICOES → DADOS → CONSULTAS → TESTES → RESULTADOS
# Uso: clique duas vezes em executar_tudo.bat, ou no PowerShell:  .\executar_tudo.ps1
# Parametros opcionais: -Servidor localhost -Porta 5432 -Usuario postgres
# Saidas: evidencias\execucao\*.txt
# =====================================================================
param([string]$Servidor = "localhost", [int]$Porta = 5432, [string]$Usuario = "postgres")
$ErrorActionPreference = "Stop"
Set-Location -Path $PSScriptRoot

# 1. Encontrar o psql (no PATH ou na instalacao padrao do PostgreSQL para Windows)
$psql = (Get-Command psql -ErrorAction SilentlyContinue).Source
if (-not $psql) {
    $psql = Get-ChildItem "C:\Program Files\PostgreSQL\*\bin\psql.exe" -ErrorAction SilentlyContinue |
            Sort-Object { [int]($_.FullName -replace '.*PostgreSQL\\(\d+)\\.*', '$1') } -Descending |
            Select-Object -First 1 -ExpandProperty FullName
}
if (-not $psql) { Write-Host "psql nao encontrado. Instale o PostgreSQL 13 ou superior (https://www.postgresql.org/download/windows/)." -ForegroundColor Red; exit 1 }
Write-Host "Usando $psql"

# 2. Conexao: a senha e pedida uma vez so
$env:PGHOST = $Servidor; $env:PGPORT = "$Porta"; $env:PGUSER = $Usuario; $env:PGCLIENTENCODING = "UTF8"
if (-not $env:PGPASSWORD) {
    $s = Read-Host "Senha do usuario $Usuario no PostgreSQL" -AsSecureString
    $env:PGPASSWORD = [Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR($s))
}
$out = "evidencias\execucao"
New-Item -ItemType Directory -Force -Path $out | Out-Null

[Console]::OutputEncoding = [Text.Encoding]::UTF8   # o psql escreve em UTF-8 (PGCLIENTENCODING)
function Rodar([string]$banco, [string]$arquivo, [string]$saida, [switch]$Acrescentar) {
    $ErrorActionPreference = "Continue"   # avisos (NOTICE) do psql saem pela saida de erro e nao devem interromper
    & $psql -X -v ON_ERROR_STOP=1 -q -d $banco -f $arquivo 2>&1 | ForEach-Object { "$_" } |
        Out-File -FilePath $saida -Encoding utf8 -Append:$Acrescentar
    if ($LASTEXITCODE -ne 0) { Write-Host "Erro ao executar $arquivo (veja $saida)" -ForegroundColor Red; exit 1 }
}
$ddl = "sql\ddl\01_tabelas.sql", "sql\ddl\02_chaves_estrangeiras.sql", "sql\ddl\03_indices.sql", "sql\ddl\04_regras_gatilhos_procedimentos.sql",
       "sql\ddl\05_visoes.sql", "sql\ddl\06_comentarios.sql", "sql\dados\07_dados_de_referencia.sql"

Write-Host "1/5  Criando o banco crmoveis (vazio)"
Rodar postgres "sql\00_criar_banco.sql" "$out\01_criacao.txt"
Write-Host "2/5  Tabelas, chaves, restricoes, gatilhos, visoes, comentarios e dados de referencia"
foreach ($f in $ddl) { Rodar crmoveis $f "$out\01_criacao.txt" -Acrescentar }
Write-Host "3/5  Massa de dados"
Rodar crmoveis "sql\dados\10_massa_de_dados.sql" "$out\02_massa_de_dados.txt"
Rodar crmoveis "sql\dados\11_contagem_por_tabela.sql" "$out\02_massa_de_dados.txt" -Acrescentar
Write-Host "4/5  Consultas (SELECT/JOIN/UPDATE/DELETE, gerenciais e auditoria)"
Rodar crmoveis "sql\consultas\20_select_join_update_delete.sql" "$out\03_select_join_update_delete.txt"
Rodar crmoveis "sql\consultas\21_consultas_gerenciais.sql" "$out\04_consultas_gerenciais.txt"
Rodar crmoveis "sql\auditoria\30_consultas_auditoria.sql" "$out\05_consultas_auditoria.txt"
Write-Host "5/5  Testes das regras num banco separado (crmoveis_testes)"
$ErrorActionPreference = "Continue"
& $psql -X -q -d postgres -c "DROP DATABASE IF EXISTS crmoveis_testes" -c "CREATE DATABASE crmoveis_testes WITH ENCODING 'UTF8' TEMPLATE template0" *> $null
$ErrorActionPreference = "Stop"
foreach ($f in $ddl) { Rodar crmoveis_testes $f "$out\06_testes_regras.txt" }
Rodar crmoveis_testes "sql\testes\40_testes_regras.sql" "$out\06_testes_regras.txt"

$txt = Get-Content "$out\06_testes_regras.txt" -Encoding UTF8
$ok = ($txt | Select-String -Pattern "\| OK$").Count
$falhou = ($txt | Select-String -Pattern "\| FALHOU$").Count
Write-Host ""
Write-Host "Pronto. Testes: $ok OK, $falhou falharam. Resultados em $out\" -ForegroundColor Green

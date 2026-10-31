# =====================================================================
# CRMoveis · inicia o prototipo (Windows)
# Mesmo jeito do INICIAR_APP do SP Imoveis CRM: encontra o Python, instala o que falta e abre o navegador.
# Antes, crie o banco com executar_tudo.bat (na pasta do repositorio).
# =====================================================================
param([switch]$SemNavegador, [int]$Porta = 5003)
# "Continue", e nao "Stop": no Windows PowerShell 5.1, qualquer texto que um programa externo (python, pip)
# escreve na saida de erro vira erro fatal com "Stop", mesmo quando e so um aviso. Os erros reais sao
# conferidos pelo codigo de saida ($LASTEXITCODE).
$ErrorActionPreference = "Continue"
Set-Location -LiteralPath $PSScriptRoot

function Sair([string]$msg) { Write-Host $msg -ForegroundColor Red; exit 1 }

# ja esta rodando (por exemplo, pelo inicio automatico com o Windows)? entao so abre o navegador
try {
    Invoke-WebRequest "http://127.0.0.1:$Porta/api/health" -UseBasicParsing -TimeoutSec 2 -ErrorAction Stop | Out-Null
    Write-Host "O prototipo ja esta rodando. Abrindo o navegador..." -ForegroundColor Green
    Start-Process "http://127.0.0.1:$Porta"
    exit 0
} catch { }

function Find-Python {
    foreach ($c in @(@{ F = "py"; A = @("-3") }, @{ F = "python"; A = @() })) {
        try {
            & $c.F @($c.A) --version 2>$null | Out-Null
            if ($LASTEXITCODE -eq 0) { return $c }
        } catch { }
    }
    return $null
}

$py = Find-Python
if (-not $py) { Sair "Python 3 nao encontrado. Instale o Python 3 (python.org) marcando 'Add python.exe to PATH' e abra este arquivo de novo." }

$venv = Join-Path $PSScriptRoot ".venv"
$vpy = Join-Path $venv "Scripts\python.exe"
if (-not (Test-Path -LiteralPath $vpy)) {
    Write-Host "Criando ambiente virtual (.venv)..." -ForegroundColor Cyan
    & $py.F @($py.A) -m venv $venv
    if ($LASTEXITCODE -ne 0 -or -not (Test-Path -LiteralPath $vpy)) { Sair "Nao foi possivel criar o ambiente virtual (.venv)." }
}

& $vpy -c "import flask, psycopg" 2>$null | Out-Null
if ($LASTEXITCODE -ne 0) {
    Write-Host "Instalando dependencias (flask, psycopg)... pode levar um ou dois minutos." -ForegroundColor Cyan
    & $vpy -m pip install --disable-pip-version-check -q -r requirements.txt
    if ($LASTEXITCODE -ne 0) { Sair "A instalacao das dependencias falhou. Confira a internet e tente de novo." }
    & $vpy -c "import flask, psycopg" 2>$null | Out-Null
    if ($LASTEXITCODE -ne 0) { Sair "As dependencias foram instaladas, mas o Python nao conseguiu carrega-las." }
}

$envFile = Join-Path $PSScriptRoot ".env"
if (-not (Test-Path -LiteralPath $envFile)) {
    Write-Host "Primeira execucao: vamos configurar a conexao com o PostgreSQL." -ForegroundColor Yellow
    $usuario = Read-Host "Usuario do PostgreSQL [postgres]"; if (-not $usuario) { $usuario = "postgres" }
    $s = Read-Host "Senha do usuario $usuario" -AsSecureString
    $senha = [Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR($s))
    $senha = [Uri]::EscapeDataString($senha)
    $conteudo = (Get-Content -LiteralPath (Join-Path $PSScriptRoot ".env.example") -Encoding UTF8) -replace "postgresql://postgres:SUA_SENHA@", "postgresql://${usuario}:${senha}@"
    [IO.File]::WriteAllLines($envFile, $conteudo, (New-Object Text.UTF8Encoding($false)))
    Write-Host "Arquivo .env criado (para trocar a senha, apague o .env e abra este arquivo de novo)." -ForegroundColor Green
}

$env:CRM_PORTA = "$Porta"
if (-not $SemNavegador) { Start-Job -ScriptBlock { param($p) Start-Sleep 3; Start-Process "http://127.0.0.1:$p" } -ArgumentList $Porta | Out-Null }
Write-Host "Prototipo em http://127.0.0.1:$Porta  (deixe esta janela aberta; feche-a para parar)" -ForegroundColor Green
& $vpy app.py

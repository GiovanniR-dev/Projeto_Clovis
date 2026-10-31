# =====================================================================
# CRMoveis · faz o prototipo iniciar sozinho com o Windows, sem janela (como no app SP Imoveis CRM).
# Depois disso, e so abrir o Chrome em http://127.0.0.1:5003 (ou o atalho "CRMoveis" da area de trabalho).
# Pre-requisito: ter rodado o INICIAR_PROTOTIPO.bat pelo menos uma vez (ele instala o Python do prototipo e cria o .env).
# Para desfazer: REMOVER_INICIAR_COM_WINDOWS.bat
# =====================================================================
$ErrorActionPreference = "Continue"
Set-Location -LiteralPath $PSScriptRoot

$pyw = Join-Path $PSScriptRoot ".venv\Scripts\pythonw.exe"
$app = Join-Path $PSScriptRoot "app.py"
$envFile = Join-Path $PSScriptRoot ".env"
if (-not (Test-Path -LiteralPath $pyw) -or -not (Test-Path -LiteralPath $envFile)) {
    Write-Host "Rode primeiro o INICIAR_PROTOTIPO.bat uma vez: ele instala o que falta e grava a senha do banco (.env)." -ForegroundColor Red
    exit 1
}

# porta configurada no .env (padrao 5003)
$porta = 5003
foreach ($linha in Get-Content -LiteralPath $envFile -Encoding UTF8) {
    if ($linha -match '^\s*CRM_PORTA\s*=\s*(\d+)') { $porta = [int]$Matches[1] }
}
$url = "http://127.0.0.1:$porta"

# 1. Inicializacao automatica: um .vbs na pasta Inicializar do Windows abre o prototipo sem janela (pythonw)
$startup = [Environment]::GetFolderPath("Startup")
$vbsPath = Join-Path $startup "CRMoveis prototipo.vbs"
# No VBScript, aspas dentro de um texto sao escritas dobradas: Run """programa"" ""arquivo""", 0, False
$q = '"'
$linhas = @(
    'Set WshShell = CreateObject("WScript.Shell")',
    ('WshShell.CurrentDirectory = ' + $q + $PSScriptRoot + $q),
    ('WshShell.Run ' + $q + $q + $q + $pyw + $q + $q + ' ' + $q + $q + $app + $q + $q + $q + ', 0, False')
)
# Unicode: o Windows Script Host le .vbs em UTF-16, o que preserva caminhos com acento
Set-Content -LiteralPath $vbsPath -Value ($linhas -join "`r`n") -Encoding Unicode

# 2. Atalho "CRMoveis" na area de trabalho, que abre o prototipo no navegador
$desk = [Environment]::GetFolderPath("Desktop")
Set-Content -LiteralPath (Join-Path $desk "CRMoveis.url") -Value "[InternetShortcut]`r`nURL=$url/`r`n" -Encoding ASCII

# 3. Inicia agora, se ainda nao estiver rodando
$rodando = Get-CimInstance Win32_Process -Filter "Name = 'pythonw.exe'" -ErrorAction SilentlyContinue |
           Where-Object { $_.CommandLine -and $_.CommandLine.Contains($app) }
if (-not $rodando) { Start-Process "wscript.exe" -ArgumentList ('"' + $vbsPath + '"') }

Write-Host ""
Write-Host "Pronto: o prototipo vai iniciar sozinho sempre que o Windows ligar." -ForegroundColor Green
Write-Host "Para abrir: Chrome em $url  ou o atalho CRMoveis na area de trabalho." -ForegroundColor Green
for ($i = 0; $i -lt 40; $i++) {
    try { Invoke-WebRequest -Uri "$url/" -TimeoutSec 1 -UseBasicParsing | Out-Null; Start-Process "$url/"; exit 0 }
    catch { Start-Sleep -Seconds 1 }
}
Write-Host "O prototipo ainda nao respondeu. Veja o arquivo prototipo.log ou rode o INICIAR_PROTOTIPO.bat para ver a mensagem de erro." -ForegroundColor Yellow

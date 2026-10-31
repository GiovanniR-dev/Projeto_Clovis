# =====================================================================
# CRMoveis · desfaz o INSTALAR_INICIAR_COM_WINDOWS: tira a inicializacao automatica, o atalho e para o prototipo.
# =====================================================================
$ErrorActionPreference = "Continue"
$app = Join-Path $PSScriptRoot "app.py"
$vbsPath = Join-Path ([Environment]::GetFolderPath("Startup")) "CRMoveis prototipo.vbs"
$atalho = Join-Path ([Environment]::GetFolderPath("Desktop")) "CRMoveis.url"
foreach ($f in @($vbsPath, $atalho)) { if (Test-Path -LiteralPath $f) { Remove-Item -LiteralPath $f -Force } }
Get-CimInstance Win32_Process -Filter "Name = 'pythonw.exe'" -ErrorAction SilentlyContinue |
    Where-Object { $_.CommandLine -and $_.CommandLine.Contains($app) } |
    ForEach-Object { Stop-Process -Id $_.ProcessId -Force }
Write-Host "Inicializacao automatica removida e prototipo parado. Para usar de novo: INICIAR_PROTOTIPO.bat." -ForegroundColor Green

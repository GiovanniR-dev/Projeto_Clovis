@echo off
cd /d "%~dp0"
if not exist "%~dp0INICIAR_PROTOTIPO.ps1" (
  echo.
  echo ERRO: arquivos do prototipo nao encontrados. Extraia o ZIP antes de abrir este arquivo.
  echo.
  pause
  exit /b 1
)
chcp 65001 > nul
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0INICIAR_PROTOTIPO.ps1" %*
pause

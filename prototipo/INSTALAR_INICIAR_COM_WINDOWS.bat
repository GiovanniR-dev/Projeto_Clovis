@echo off
cd /d "%~dp0"
chcp 65001 > nul
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0INSTALAR_INICIAR_COM_WINDOWS.ps1"
pause

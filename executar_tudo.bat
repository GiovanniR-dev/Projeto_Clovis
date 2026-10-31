@echo off
rem CRMoveis - executa o projeto inteiro a partir de um banco vazio (Etapa 15)
chcp 65001 > nul
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0executar_tudo.ps1" %*
pause

@echo off
REM ============================================================
REM  WEP Dashboard - abre o painel no navegador padrao.
REM  Se o servidor local nao estiver rodando, inicia ele antes.
REM ============================================================

set "PROJETO=C:\Users\Admin\Desktop\Claude\WEP - DASHBOARD"
set "URL=http://localhost:5184"

REM Ja tem servidor escutando na porta 5184?
netstat -ano | findstr ":5184" | findstr "LISTENING" >nul
if errorlevel 1 (
    echo Iniciando o servidor do WEP Dashboard...
    start "WEP Dashboard - servidor" /min cmd /c "cd /d "%PROJETO%" && npm run dev"
    REM Da uns segundos pro Vite subir antes de abrir o navegador
    "%SystemRoot%\System32\timeout.exe" /t 5 /nobreak >nul
)

start "" "%URL%"

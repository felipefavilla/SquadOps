@echo off
REM Carrega variáveis do .env (formato KEY=VALUE, ignora linhas em branco e #).
REM Uso interno por outros scripts batch.

set "ENV_FILE=%~dp0..\.env"
if not exist "%ENV_FILE%" (
    echo [ERRO] Arquivo .env nao encontrado em %ENV_FILE%
    echo Copie .env.example para .env e ajuste, ou rode build_release.ps1 novamente.
    exit /b 1
)

for /f "usebackq tokens=1,* delims==" %%a in ("%ENV_FILE%") do (
    set "_key=%%a"
    if not "!_key:~0,1!"=="#" if not "%%a"=="" set "%%a=%%b"
)
exit /b 0

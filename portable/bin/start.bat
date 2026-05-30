@echo off
setlocal

set "PORTABLE_ROOT=%~dp0.."
set "PGSQL=%PORTABLE_ROOT%\pgsql"
set "PGDATA=%PORTABLE_ROOT%\pgdata"
set "APP=%PORTABLE_ROOT%\app"

call "%~dp0_load_env.bat"
if errorlevel 1 exit /b 1

REM Inicia Postgres se nao estiver rodando
"%PGSQL%\bin\pg_isready.exe" -h localhost -p 5433 -U squadops >nul 2>&1
if errorlevel 1 (
    echo [INFO] Iniciando Postgres...
    "%PGSQL%\bin\pg_ctl.exe" -D "%PGDATA%" -l "%PORTABLE_ROOT%\pg.log" -w start
    if errorlevel 1 (
        echo [ERRO] Falha ao iniciar Postgres. Veja pg.log
        exit /b 1
    )
) else (
    echo [INFO] Postgres ja esta rodando.
)

echo.
echo === SquadOps iniciando em http://localhost:%PORT% ===
echo Ctrl+C para parar. Postgres continua rodando (use stop.bat para parar tudo).
echo.

"%APP%\bin\squad_ops.bat" start

endlocal

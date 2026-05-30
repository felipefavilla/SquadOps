@echo off
setlocal

REM Primeira execução: inicializa o cluster Postgres, cria DB, migra e cria admin.

set "PORTABLE_ROOT=%~dp0.."
set "PGSQL=%PORTABLE_ROOT%\pgsql"
set "PGDATA=%PORTABLE_ROOT%\pgdata"
set "APP=%PORTABLE_ROOT%\app"
set "PWFILE=%PORTABLE_ROOT%\.pgpass.tmp"

echo === SquadOps Setup ===

REM 0. Verificar caracteres especiais no caminho (acentos, OneDrive)
echo %PORTABLE_ROOT% | findstr /R /C:"[^\x20-\x7E]" >nul
if not errorlevel 1 (
    echo [ERRO] O caminho da instalacao contem caracteres nao-ASCII: %PORTABLE_ROOT%
    echo PostgreSQL falha quando o path tem acentos ^(ex: "Area de Trabalho"^).
    echo Mova a pasta para um caminho simples como C:\SquadOps\ ou C:\Users\seu_usuario\SquadOps\
    exit /b 1
)
echo %PORTABLE_ROOT% | findstr /I "OneDrive" >nul
if not errorlevel 1 (
    echo [ERRO] A pasta esta dentro do OneDrive: %PORTABLE_ROOT%
    echo OneDrive sincroniza arquivos durante a execucao e corrompe o banco.
    echo Mova para fora do OneDrive ^(ex: C:\SquadOps\^).
    exit /b 1
)

REM 1. Validações
if not exist "%PGSQL%\bin\initdb.exe" (
    echo [ERRO] PostgreSQL portatil nao encontrado em %PGSQL%
    echo Baixe o ZIP em https://www.enterprisedb.com/download-postgresql-binaries
    echo Descompacte o conteudo de pgsql\ do ZIP dentro de portable\pgsql\
    exit /b 1
)
if not exist "%APP%\bin\squad_ops.bat" (
    echo [ERRO] Release nao encontrado em %APP%
    echo Rode scripts\build_release.ps1 no PC de desenvolvimento.
    exit /b 1
)

call "%~dp0_load_env.bat"
if errorlevel 1 exit /b 1

REM 2. Inicializa cluster (se ainda nao foi)
if exist "%PGDATA%\PG_VERSION" (
    echo [INFO] Cluster Postgres ja inicializado em %PGDATA%
    goto :start_pg
)

echo [INFO] Inicializando cluster Postgres em %PGDATA%...

REM Cria arquivo temporario com a senha
> "%PWFILE%" echo squadops

"%PGSQL%\bin\initdb.exe" -D "%PGDATA%" -U squadops --pwfile="%PWFILE%" -E UTF8 --locale=C --auth=md5
set "INITDB_EXIT=%ERRORLEVEL%"

REM Remove o arquivo temporario com a senha
if exist "%PWFILE%" del "%PWFILE%"

if not "%INITDB_EXIT%"=="0" (
    echo [ERRO] initdb falhou com codigo %INITDB_EXIT%
    exit /b 1
)

REM Configura porta 5433
echo. >> "%PGDATA%\postgresql.conf"
echo port = 5433 >> "%PGDATA%\postgresql.conf"
echo listen_addresses = 'localhost' >> "%PGDATA%\postgresql.conf"

:start_pg
REM 3. Inicia Postgres
echo [INFO] Iniciando Postgres (porta 5433)...
"%PGSQL%\bin\pg_ctl.exe" -D "%PGDATA%" -l "%PORTABLE_ROOT%\pg.log" -w start
if errorlevel 1 (
    echo [ERRO] Falha ao iniciar Postgres. Veja %PORTABLE_ROOT%\pg.log
    exit /b 1
)

REM 4. Cria database (se nao existe)
set "PGPASSWORD=squadops"
"%PGSQL%\bin\psql.exe" -U squadops -h localhost -p 5433 -d postgres -tAc "SELECT 1 FROM pg_database WHERE datname='squad_ops_prod'" | findstr /C:"1" >nul 2>&1
if errorlevel 1 (
    echo [INFO] Criando database squad_ops_prod...
    "%PGSQL%\bin\createdb.exe" -U squadops -h localhost -p 5433 squad_ops_prod
    if errorlevel 1 (
        echo [ERRO] Falha ao criar database.
        exit /b 1
    )
) else (
    echo [INFO] Database squad_ops_prod ja existe.
)
set "PGPASSWORD="

REM 5. Migra
echo [INFO] Rodando migrations...
call "%APP%\bin\squad_ops.bat" eval "SquadOps.Release.migrate()"
if errorlevel 1 (
    echo [ERRO] Falha na migracao.
    exit /b 1
)

REM 6. Cria admin
echo [INFO] Criando usuario admin...
call "%APP%\bin\squad_ops.bat" eval "SquadOps.Release.seed_admin()"
if errorlevel 1 (
    echo [ERRO] Falha ao criar admin.
    exit /b 1
)

echo.
echo === Setup concluido ===
echo Agora rode bin\start.bat para iniciar o servidor.

endlocal

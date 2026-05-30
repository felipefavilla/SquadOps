@echo off
setlocal

set "PORTABLE_ROOT=%~dp0.."
set "PGSQL=%PORTABLE_ROOT%\pgsql"
set "PGDATA=%PORTABLE_ROOT%\pgdata"

echo [INFO] Parando Postgres...
"%PGSQL%\bin\pg_ctl.exe" -D "%PGDATA%" stop -m fast

endlocal

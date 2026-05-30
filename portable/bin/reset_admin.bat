@echo off
setlocal
set "APP=%~dp0..\app"
call "%~dp0_load_env.bat"
if errorlevel 1 exit /b 1
echo Recriando admin (email=%ADMIN_EMAIL%, senha vinda do .env)...
"%APP%\bin\squad_ops.bat" eval "SquadOps.Release.seed_admin()"
endlocal

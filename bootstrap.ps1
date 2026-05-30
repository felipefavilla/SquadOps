# bootstrap.ps1
# Executa UMA VEZ para gerar o scaffold do projeto Phoenix via Docker.
# Após rodar este script, use apenas docker compose up para desenvolver.

Write-Host "=== SquadOps Bootstrap ===" -ForegroundColor Cyan
Write-Host "Gerando projeto Phoenix com LiveView..."

# Gera o projeto Phoenix dentro do container, na pasta atual
docker run --rm -v "${PWD}:/app" -w /app elixir:1.18-otp-27-alpine sh -c "
  apk add --no-cache git nodejs npm &&
  mix local.hex --force &&
  mix local.rebar --force &&
  mix archive.install hex phx_new --force &&
  echo y | mix phx.new . --app squad_ops --module SquadOps --live --no-install
"

Write-Host ""
Write-Host "Projeto gerado! Agora iniciando o ambiente Docker..." -ForegroundColor Green
Write-Host ""
Write-Host "Executando: docker compose up --build" -ForegroundColor Yellow
docker compose up --build

# build_release.ps1
# Gera o release Phoenix de produção e prepara a pasta portable/app/.
#
# Pré-requisitos no PC de build (Windows):
#   - Elixir 1.18+ e Erlang OTP 27+ instalados (winget install Elixir.Elixir)
#   - Pasta do projeto SquadOps (este script roda da raiz)
#
# Uso: .\scripts\build_release.ps1

$ErrorActionPreference = "Stop"
$projectRoot = Split-Path -Parent $PSScriptRoot
Set-Location $projectRoot

Write-Host "=== SquadOps Release Builder ===" -ForegroundColor Cyan

$env:MIX_ENV = "prod"

Write-Host "`n[1/5] Buscando dependências..." -ForegroundColor Yellow
mix deps.get --only prod
if ($LASTEXITCODE -ne 0) { throw "mix deps.get falhou" }

Write-Host "`n[2/5] Compilando..." -ForegroundColor Yellow
mix compile
if ($LASTEXITCODE -ne 0) { throw "mix compile falhou" }

Write-Host "`n[3/5] Compilando assets (esbuild + tailwind)..." -ForegroundColor Yellow
mix assets.deploy
if ($LASTEXITCODE -ne 0) { throw "mix assets.deploy falhou" }

Write-Host "`n[4/5] Gerando release..." -ForegroundColor Yellow
mix release squad_ops --overwrite
if ($LASTEXITCODE -ne 0) { throw "mix release falhou" }

Write-Host "`n[5/5] Copiando release para portable/app/..." -ForegroundColor Yellow
$source = Join-Path $projectRoot "_build\prod\rel\squad_ops"
$dest = Join-Path $projectRoot "portable\app"

if (Test-Path $dest) { Remove-Item -Recurse -Force $dest }
Copy-Item -Recurse -Path $source -Destination $dest

# Gera SECRET_KEY_BASE se ainda não existe
$envFile = Join-Path $projectRoot "portable\.env"
if (-not (Test-Path $envFile)) {
    Write-Host "`nGerando .env com SECRET_KEY_BASE..." -ForegroundColor Yellow
    $secret = mix phx.gen.secret
    $template = Get-Content (Join-Path $projectRoot "portable\.env.example") -Raw
    $template = $template.Replace("__GENERATE_ME__", $secret.Trim())
    $template | Set-Content -Path $envFile -Encoding UTF8
}

Write-Host "`n=== Release pronto em portable\app\ ===" -ForegroundColor Green
Write-Host "Próximo passo: baixe PostgreSQL portable em portable\pgsql\"
Write-Host "Depois copie a pasta portable\ inteira para o pendrive."

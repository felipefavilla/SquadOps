# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project

**SquadOps** — Elixir/Phoenix application for managing development Squads via Azure DevOps.
Connects to Azure DevOps REST API to manage Features, User Stories, Tasks, and Sprints.
Suporta um **modo mock** completo para desenvolvimento sem PAT real.

Stack: Elixir 1.18 + Phoenix 1.7 + LiveView + PostgreSQL 16 + Docker + DaisyUI/Tailwind + Bcrypt.

### Contexto & ambiente

- **Primeiro projeto Elixir do usuário** (Felipe Barth — desenvolvedor experiente, novo no ecossistema Elixir/Phoenix). Prefira explicações um pouco mais detalhadas sobre idiomas/convenções Elixir quando relevante.
- **Máquina de desenvolvimento (esta):** tem **Elixir 1.18, Erlang OTP 27 e Docker** instalados. O dev do dia a dia é via Docker, mas comandos `mix` locais e o `scripts\build_release.ps1` rodam **direto** aqui, sem container.
- **Notebook corporativo:** **não permite instalar nada** (sem Elixir/Erlang/Docker). Lá só roda a **versão portátil** (ver seção "Versão Portátil"). Todo deploy de correção para o notebook passa por regerar o release aqui e copiar `portable\app\`.

### Histórico de correções relevantes

- **Bug de sync em modo real (`AZURE_MODE=real`), corrigido:** `SquadOps.Azure.Client.new/1` montava `params` com tupla de chave string (`[{"api-version", ...}]`), que **não é uma keyword list válida**. Só estourava `ArgumentError` em `Azure.WorkItems.fetch/2` — a única chamada que passa `params:` extras, forçando o `Keyword.merge` do Req. Correção: usar chave atom → `params: ["api-version": @api_version]`. Não houve mudança de schema/migration.

---

## Commands

All development is Docker-based. Run from the project root.

```bash
# First-time setup
docker compose up --build

# Start development environment
docker compose up

# Run a Mix command inside the container
docker compose exec app mix <command>

# Create the database and run migrations + seeds (cria 3 squads, sprints, work items e o admin)
docker compose exec app mix ecto.setup

# Recriar apenas o admin sem rodar todos os seeds
docker compose exec app mix run priv/repo/create_admin.exs

# Run tests
docker compose exec app mix test
docker compose exec app mix test test/squad_ops/azure_test.exs

# Linter
docker compose exec app mix credo --strict

# Formatter
docker compose exec app mix format

# Open IEx console
docker compose exec app iex -S mix
```

### Local development (optional, requires Elixir 1.18 + Erlang OTP 27)

```bash
mix deps.get
mix ecto.setup
mix phx.server
# or: iex -S mix phx.server
```

---

## Versão Portátil (notebook corporativo)

O notebook corporativo **não permite instalar nada** — sem Elixir, sem Erlang, sem Docker.
Para esse cenário existe um pacote **portátil autocontido** em `portable/`, que roda em qualquer
Windows 10/11 x64 sem instalação. Ele empacota um **release Phoenix de produção já compilado**
(`portable/app/`) + **PostgreSQL portátil** (`portable/pgsql/`).

> ⚠️ **`portable/app/` é um release Mix compilado (`.beam`), não código-fonte.** Editar arquivos
> `.ex` e copiá-los para o notebook **não tem efeito** — o runtime usa os artefatos compilados.
> Qualquer mudança de código só chega ao portátil **regerando o release**.

### Estrutura

```
portable/
├── app/          ← release Phoenix compilado (gerado por scripts\build_release.ps1)
├── pgsql/        ← PostgreSQL portátil (baixado do EnterpriseDB, não versionado)
├── pgdata/       ← dados do banco (criado na 1ª execução pelo setup.bat)
├── bin/
│   ├── setup.bat        ← 1ª execução: initdb + cria DB + migrate + admin (porta 5433)
│   ├── start.bat        ← inicia Postgres + servidor (http://localhost:4000)
│   ├── stop.bat         ← para o Postgres
│   ├── migrate.bat      ← roda migrations
│   └── reset_admin.bat  ← recria admin com senha do .env
├── .env          ← gerado pelo build_release.ps1 (contém SECRET_KEY_BASE)
└── README.md
```

Banco de prod: `squad_ops_prod`, usuário/senha `squadops`/`squadops`, **porta 5433** (não 5432).
Migrations e seed do admin rodam via `SquadOps.Release.migrate()` / `SquadOps.Release.seed_admin()`.

### Gerar/atualizar o pacote (no PC de desenvolvimento, com Elixir)

```powershell
.\scripts\build_release.ps1
```
Faz `deps.get --only prod` → `compile` → `assets.deploy` → `mix release squad_ops` →
copia `_build\prod\rel\squad_ops` para `portable\app\` e gera `portable\.env` (se não existir).

### Como o usuário roda no notebook

1. Copia a pasta `portable\` para um caminho **simples e ASCII, fora do OneDrive**
   (o `setup.bat` aborta se detectar acentos ou OneDrive — corrompe o Postgres).
2. **1ª vez:** `bin\setup.bat`  → inicializa banco, migra, cria admin.
3. **Rodar:** `bin\start.bat` → abre em `http://localhost:4000`
   (login `admin@squadops.local` / `Admin@123`, configuráveis no `.env`).

### Aplicar uma correção de código no notebook

Como `portable/app/` é compilado, o ciclo é:

1. **PC de dev:** rode `.\scripts\build_release.ps1` (recompila com o fix, sobrescreve `portable\app\`).
2. Copie **apenas a pasta `portable\app\`** para o notebook, substituindo a antiga
   (preserva `.env`, `pgdata\` e `pgsql\`).
3. **Notebook:** rode `bin\start.bat`. Só rode `bin\migrate.bat` se houve **migration nova**;
   correções de código puro (ex.: o fix do `Azure.Client`) não exigem migrate.

---

## Architecture

### Fluxo de dados

```
+--------------+     assigns/events     +-----------------+     {:ok, _}      +------------------+
|  LiveView    |  <------------------>  |  Context        |  -------------->  |  Azure / Repo    |
|  (web/live)  |                        |  (squad_ops/*)  |  <--------------  |  (HTTP / Ecto)   |
+--------------+                        +-----------------+                   +------------------+
       |                                        |                                       |
       | render HEEx                            | Ecto.Query / Changeset                | Azure.mode()
       v                                        v                                       v
   Layouts.app                              PostgreSQL                            Real (Req) | Mock
```

LiveViews só conversam com **contextos**. Os contextos é que decidem entre Repo (Postgres) e `SquadOps.Azure` (fachada). O `SquadOps.Azure.Sync` é a ponte que traz dados do Azure para o banco local aplicando regras (`Rules`).

### Contextos (`lib/squad_ops/`)

| Contexto | Módulo principal | Responsabilidade |
|---|---|---|
| Accounts | `SquadOps.Accounts` + `Accounts.User` | Usuários locais, autenticação bcrypt, roles (`admin`/`user`) |
| Auth | `SquadOps.Auth` + `Auth.Token` | Armazenamento e upsert de PAT do Azure DevOps por squad, marca `validated_at` |
| Squads | `SquadOps.Squads` + `Squads.{Squad,Sprint,WorkItem}` | Domínio principal — CRUD de squads, sprints, work items e agregações (`work_item_stats`, `list_all_work_items`) |
| Rules | `SquadOps.Rules` + `Rules.SquadRule` | Regras de negócio por squad em 4 seções JSONB: `workflow`, `validations`, `field_mapping`, `sync_policy`. Faz merge com defaults |
| SyncLogs | `SquadOps.SyncLogs` + `SyncLogs.SyncLog` | Log persistido das sincronizações (tabela `sync_logs`). Cada run tem `run_id`; helpers `info/warning/error/4`, `list_logs/1`, `clear_logs/1`. Lido pela tela `/logs` |
| Azure | `SquadOps.Azure` | Fachada — despacha cada chamada entre `Real` (HTTP) e `Mock` conforme `AZURE_MODE` |
| Azure.Client | `SquadOps.Azure.Client` | Cliente HTTP (Req) com Basic Auth (`":" <> PAT`), API version `7.1`, tratamento de status 401/404/429 |
| Azure.Projects | `SquadOps.Azure.Projects` | `GET /_apis/projects` |
| Azure.Sprints | `SquadOps.Azure.Sprints` | Iterations do team — converte `timeFrame` em `active`/`past`/`future` |
| Azure.WorkItems | `SquadOps.Azure.WorkItems` | WIQL query + fetch em chunks de 200; normaliza campos `System.*` e `Microsoft.VSTS.*` |
| Azure.Boards | `SquadOps.Azure.Boards` | Colunas do board (default `"Stories"`) — usadas como workflow visual do Kanban |
| Azure.Mock | `SquadOps.Azure.Mock` | Dados falsos no mesmo shape dos módulos reais, para dev sem PAT |
| Azure.Sync | `SquadOps.Azure.Sync` | Orquestra a sincronização: token → sprints → WIQL → work items → board columns → `Auth.mark_validated/1`. **Resiliente**: grava cada item individualmente (`Repo.insert/update`, sem bang); linha inválida é logada em `SyncLogs` e pulada — não aborta o run. Retorna `work_item_errors` no resumo |

Observação: **não existe `Azure.Batch`** (a versão antiga do CLAUDE.md mencionava). A criação em massa hoje é local (LiveView → `Squads.create_work_item/1`).

### Web (`lib/squad_ops_web/`)

| Arquivo | Função |
|---|---|
| `router.ex` | Pipelines `:browser` (com `fetch_current_user`) e `:require_authenticated`; rotas públicas e protegidas |
| `user_auth.ex` | Plug `fetch_current_user`/`require_authenticated_user`, helpers `log_in_user`/`log_out_user`, hook LiveView `on_mount :require_authenticated_user` |
| `components/layouts.ex` | Layout `app` com Drawer DaisyUI (sidebar + topbar mobile), `nav_item`, `theme_toggle`, `flash_group` |
| `controllers/user_session_controller.ex` | `POST /users/session` (login) e `DELETE /users/session` (logout) |
| `live/*_live.ex` | 8 LiveViews (ver tabela de rotas) |

### Rotas

| Pipeline | Método | Path | Módulo |
|---|---|---|---|
| pública | live | `/login` | `LoginLive` (`layout: false`) |
| pública | POST | `/users/session` | `UserSessionController.create/2` |
| pública | DELETE | `/users/session` | `UserSessionController.delete/2` |
| autenticada | live | `/` | `DashboardLive` — cards de squads com stats |
| autenticada | live | `/squads/:id` | `SquadLive` — Kanban do sprint ativo |
| autenticada | live | `/squads/:id/settings` | `SquadSettingsLive` — PAT, URL, project, test/sync |
| autenticada | live | `/squads/:id/rules` | `SquadRulesLive` — abas de workflow/validations/mapping/sync |
| autenticada | live | `/backlog` | `BacklogLive` — filtros por squad/sprint/type/status |
| autenticada | live | `/bulk-create` | `BulkCreateLive` — criação local de N work items via textarea |
| autenticada | live | `/logs` | `SyncLogsLive` — tabela de logs de sync com filtros squad/nível, limpar/atualizar |
| dev | live | `/dev/dashboard` | `Phoenix.LiveDashboard` (compile_env `:dev_routes`) |
| dev | forward | `/dev/mailbox` | `Plug.Swoosh.MailboxPreview` |

---

## Schemas

Migrations em `priv/repo/migrations/` — todas têm a data `20260528000001..06`.

### `squads`
| Campo | Tipo | Notas |
|---|---|---|
| `name` | string NOT NULL | unique index |
| `description` | text | |
| `color` | string | default `"#6366f1"` |
| `azure_project` | string | nome do projeto no Azure DevOps |
| `inserted_at`/`updated_at` | timestamps | |

Relações: `has_many :sprints`, `has_many :work_items`, `has_one :auth_token`.

### `sprints`
| Campo | Tipo | Notas |
|---|---|---|
| `squad_id` | FK squads ON DELETE CASCADE | index |
| `name` | string NOT NULL | |
| `azure_id` | string | id do iteration do Azure |
| `start_date`/`end_date` | date | |
| `status` | string | `future` (default) / `active` / `past`, index |

### `work_items`
| Campo | Tipo | Notas |
|---|---|---|
| `squad_id` | FK squads ON DELETE CASCADE | index |
| `sprint_id` | FK sprints ON DELETE NILIFY | index |
| `azure_id` | integer | unique index parcial (`WHERE azure_id IS NOT NULL`) |
| `title` | string NOT NULL | |
| `description` | text | |
| `type` | string NOT NULL default `story` | `feature` / `story` / `task` / `bug`, index |
| `status` | string NOT NULL default `new` | `new` / `active` / `resolved` / `closed` / `removed`, index |
| `assigned_to` | string | display name |
| `story_points` | float | >= 0 — Azure manda double (ex.: `0.5`, `13.0`); preservamos fracionário |
| `priority` | integer default 2 | 1..4 |

### `auth_tokens`
| Campo | Tipo | Notas |
|---|---|---|
| `squad_id` | FK squads ON DELETE CASCADE | unique (um token por squad) |
| `pat_token` | string NOT NULL | armazenado em texto plano |
| `azure_org_url` | string NOT NULL | regex `^https://dev\.azure\.com/` |
| `validated_at` | naive_datetime | setado por `Auth.mark_validated/1` após sync bem-sucedido |

### `users`
| Campo | Tipo | Notas |
|---|---|---|
| `email` | string NOT NULL | unique index, validado por regex |
| `name` | string NOT NULL | |
| `hashed_password` | string NOT NULL | bcrypt |
| `role` | string NOT NULL default `user` | `admin` / `user` |

### `squad_rules`
| Campo | Tipo | Notas |
|---|---|---|
| `squad_id` | FK squads ON DELETE CASCADE | unique (uma regra por squad) |
| `workflow` | map (JSONB) | transitions, labels, columns (preenchidas pelo sync de boards) |
| `validations` | map (JSONB) | flags `story_requires_points`, `bug_requires_assignee`, `max_sprint_points`, `block_invalid_transitions` |
| `field_mapping` | map (JSONB) | mapeia tipos/status do Azure para enums locais |
| `sync_policy` | map (JSONB) | `mode`, `frequency_minutes`, `scope`, `conflict_resolution` |

Defaults vivem em `SquadOps.Rules` e são *mesclados* com o que está salvo (`merge_defaults/1`).

### `sync_logs`
| Campo | Tipo | Notas |
|---|---|---|
| `squad_id` | FK squads ON DELETE CASCADE | index, nullable |
| `run_id` | string | UUID que agrupa todas as entradas de um mesmo run, index |
| `level` | string NOT NULL default `info` | `info` / `warning` / `error`, index |
| `message` | string NOT NULL | texto curto do evento |
| `context` | map (JSONB) NOT NULL default `{}` | detalhes (azure_id, title, errors do changeset…) — normalizado para JSON em `SyncLogs.normalize_context/1` |
| `inserted_at` | timestamp | só inserted_at (`timestamps(updated_at: false)`), index |

Migrations novas: `20260529000001` (story_points integer→float) e `20260529000002` (cria `sync_logs`). **Deploy que inclua essas mudanças exige rodar migrations** (no portátil: `bin\migrate.bat`).

---

## Modo Mock vs Real

Toda chamada Azure passa por `SquadOps.Azure`, que lê `System.get_env("AZURE_MODE", "mock")` em runtime:

```elixir
def list_projects(token) do
  case mode() do
    :real -> Projects.list(token)
    :mock -> Mock.list_projects(token)
  end
end
```

- `AZURE_MODE=mock` (default) → `SquadOps.Azure.Mock` retorna 3 projetos, 3 sprints e work items gerados aleatoriamente. Nenhum HTTP é feito; o PAT pode ser fake.
- `AZURE_MODE=real` → `SquadOps.Azure.Client` faz HTTP via Req com Basic Auth. Erros mapeados: `401 → :unauthorized`, `404 → :not_found`, `429 → :rate_limited`, transport → `{:transport, msg}`.

O `Azure.test_connection/1` é o que `SquadSettingsLive` chama no botão "Testar conexão" — em mock sempre retorna `{:ok, :mock_mode}`.

---

## Sidebar e navegação contextual

`SquadOpsWeb.Layouts.app/1` recebe `current_path` (cada LiveView passa via `assign`) e usa `extract_squad_id/1` (regex `^/squads/(\d+)`) para detectar quando o usuário está dentro de um squad. Quando detecta:

- Mostra o bloco **"Squad ativo"** abaixo do menu fixo
- Inclui links contextuais: **Kanban**, **Configurações**, **Regras de Negócio** (todos com o `:id` resolvido)

Os LiveViews que aparecem em `/squads/:id/*` **devem** setar `current_path` no `mount/3` (ex.: `current_path: "/squads/#{id}/rules"`), caso contrário o submenu não aparece.

O rodapé do sidebar tem o `theme_toggle` (system/light/dark via `phx:set-theme`), avatar do `current_user` e formulário de logout (`DELETE /users/session`).

---

## Autenticação

Stack: bcrypt + cookie session do Phoenix + hook LiveView.

1. **Login** — `LoginLive` renderiza um form que faz `POST /users/session` (controller, não LiveView). `Accounts.authenticate_user/2` usa `Bcrypt.verify_pass/2` (e `Bcrypt.no_user_verify/0` para mitigar timing attacks).
2. **Sessão** — `UserAuth.log_in_user/2` faz `renew_session` (limpa CSRF, regenera ID) e grava `:user_id` na session.
3. **Plug** — `fetch_current_user` carrega o `User` na assign `:current_user`; `require_authenticated_user` redireciona para `/login` se não houver usuário.
4. **LiveView** — todos os `*_live.ex` autenticados começam com `on_mount {SquadOpsWeb.UserAuth, :require_authenticated_user}`, que rehidrata o user via session.
5. **Logout** — `DELETE /users/session` chama `log_out_user/1` que faz `renew_session` e redireciona para `/login`.

### Admin seed

`mix ecto.setup` (e `priv/repo/create_admin.exs` standalone) criam:

```
email:    admin@squadops.local
password: Admin@123
role:     admin
```

Idempotente — só cria se ainda não existir.

---

## Environment Variables

Copy `.env.example` to `.env` and fill in:

```
# Database
DATABASE_URL=ecto://postgres:postgres@db/squad_ops_dev
DB_HOST=db

# Azure DevOps — mode controla mock vs real
AZURE_MODE=mock                   # mock (default) | real
AZURE_ORG_URL=https://dev.azure.com/your-org
AZURE_PAT=your-personal-access-token

# Phoenix
SECRET_KEY_BASE=<mix phx.gen.secret>
PHX_HOST=localhost
PORT=4000
```

Em mock o `AZURE_ORG_URL`/`AZURE_PAT` não são usados, mas as variáveis precisam existir para o boot do container.

---

## Agents

Três agentes Claude Code configurados em `agents/`:

- **`/architect`** — revisa `lib/` e propõe melhorias estruturais (boundaries entre contextos, design de módulos, dependências).
- **`/tester`** — gera e executa testes ExUnit (unit, LiveView integration, mocks de Azure).
- **`/security`** — audita vulnerabilidades (exposição de PAT, query injection, CSRF, validação de input, auth).

Briefings completos estão nos respectivos `.md`.

---

## Git Conventions

- **Repositório:** <https://github.com/felipefavilla/SquadOps> (remote `origin`, HTTPS). Branch publicada: **`master`**. Auth via Git Credential Manager (já em cache nesta máquina) — push direto com `git push`.
- Branches: `feat/`, `fix/`, `chore/`
- Commits: English, imperative mood (`Add sprint board LiveView`)
- PRs must pass `mix test` and `mix credo --strict`

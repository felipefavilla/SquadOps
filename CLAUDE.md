# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project

**SquadOps** — Elixir/Phoenix application for managing development Squads via Azure DevOps.
Connects to Azure DevOps REST API to manage Features, User Stories, Tasks, and Sprints.

Stack: Elixir 1.18 + Phoenix 1.7 + LiveView + PostgreSQL 16 + Docker

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

# Create the database and run migrations
docker compose exec app mix ecto.setup

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

## Architecture

Phoenix contexts (under `lib/squad_ops/`):

| Context | Responsibility |
|---|---|
| `Azure` | Azure DevOps REST API client (PAT auth, HTTP via Req) |
| `Azure.WorkItems` | CRUD for Features, User Stories, Tasks |
| `Azure.Sprints` | Sprint listing and management |
| `Azure.Batch` | Bulk creation via Azure `$batch` endpoint |
| `Squads` | Local squad domain, caching, aggregations |
| `Auth` | PAT token storage and validation |

Frontend: `lib/squad_ops_web/live/` — all pages are Phoenix LiveView.

| Route | Page |
|---|---|
| `/` | Dashboard with squad metrics |
| `/squads/:id` | Kanban sprint board (drag-and-drop) |
| `/backlog` | Filtered backlog (by squad/sprint/type) |
| `/bulk-create` | Mass creation form for work items |

---

## Environment Variables

Copy `.env.example` to `.env` and fill in:

```
DATABASE_URL=ecto://postgres:postgres@db/squad_ops_dev
AZURE_ORG_URL=https://dev.azure.com/your-org
AZURE_PAT=your-personal-access-token
SECRET_KEY_BASE=<generate with: mix phx.gen.secret>
PHX_HOST=localhost
PORT=4000
```

---

## Agents

Three Claude Code agents are configured in `agents/`:

- **`/architect`** — reviews `lib/` and proposes structural improvements (context boundaries, module design, dependencies)
- **`/tester`** — generates and runs ExUnit tests for specified modules (unit tests, LiveView integration tests, Azure API mocks)
- **`/security`** — audits for vulnerabilities (PAT exposure, query injection, CSRF, input validation, auth issues)

---

## Git Conventions

- Branches: `feat/`, `fix/`, `chore/`
- Commits: English, imperative mood (`Add sprint board LiveView`)
- PRs must pass `mix test` and `mix credo --strict`

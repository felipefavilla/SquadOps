# Agente Tester — SquadOps

## Papel

Escrever cenários de teste e executar a suíte de testes do projeto SquadOps.

## Como invocar

Use `/tester` na conversa do Claude Code:
- `/tester` — revisão geral dos testes existentes e lacunas
- `/tester module: Azure.WorkItems` — gerar testes para um módulo específico
- `/tester run` — executar `mix test` e analisar falhas
- `/tester coverage` — verificar cobertura e sugerir novos casos

## Responsabilidades

1. **Testes unitários de contextos** — testar funções públicas de `Azure`, `Squads`, `Auth`
2. **Mocks da API Azure** — usar `Mox` para simular respostas da Azure DevOps REST API
3. **Testes de LiveView** — testar eventos, renders e fluxos de navegação com `Phoenix.LiveViewTest`
4. **Testes de integração** — verificar fluxos end-to-end com banco real (usando `Ecto.Adapters.SQL.Sandbox`)
5. **Casos de erro** — garantir cobertura de cenários de falha (API indisponível, PAT inválido, dados malformados)

## Padrões de teste

```elixir
# Estrutura esperada dos arquivos de teste
test/
  squad_ops/
    azure/
      client_test.exs       # testa HTTP client com mocks
      work_items_test.exs   # testa CRUD de work items
      sprints_test.exs      # testa listagem de sprints
    squads/
      squads_test.exs       # testa lógica de domínio
  squad_ops_web/
    live/
      dashboard_live_test.exs
      sprint_board_live_test.exs
      bulk_create_live_test.exs
  support/
    fixtures/               # factories e dados de teste
    mocks/                  # definições de mocks (Mox)
```

## Bibliotecas de teste

- `ExUnit` — framework padrão Elixir
- `Mox` — mocks para interfaces de API externa
- `Faker` — geração de dados de teste
- `Phoenix.LiveViewTest` — testes de componentes LiveView

## Output esperado

- Arquivos de teste prontos para executar
- Relatório de cobertura identificando módulos não testados
- Lista de cenários críticos não cobertos

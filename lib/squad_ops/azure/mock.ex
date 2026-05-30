defmodule SquadOps.Azure.Mock do
  @moduledoc """
  Fake Azure DevOps data for development without a real PAT.
  Returns the same shape as the real Azure.* modules.
  """

  def list_projects(_token) do
    {:ok,
     [
       %{
         id: "mock-pag",
         name: "Pagamentos",
         description: "Plataforma de pagamentos",
         state: "wellFormed"
       },
       %{id: "mock-ide", name: "Identidade", description: "Auth e SSO", state: "wellFormed"},
       %{id: "mock-mkt", name: "Marketplace", description: "Catálogo", state: "wellFormed"}
     ]}
  end

  def list_sprints(_token, _project, _team \\ nil) do
    today = Date.utc_today()

    {:ok,
     [
       %{
         azure_id: "mock-s11",
         name: "Sprint 11",
         path: "MockProject\\Sprint 11",
         start_date: Date.add(today, -28),
         end_date: Date.add(today, -15),
         status: "past",
         kind: "sprint"
       },
       %{
         azure_id: "mock-s12",
         name: "Sprint 12",
         path: "MockProject\\Sprint 12",
         start_date: Date.add(today, -14),
         end_date: today,
         status: "active",
         kind: "sprint"
       },
       %{
         azure_id: "mock-s13",
         name: "Sprint 13",
         path: "MockProject\\Sprint 13",
         start_date: Date.add(today, 1),
         end_date: Date.add(today, 14),
         status: "future",
         kind: "sprint"
       },
       %{
         azure_id: "mock-backlog",
         name: "Backlog",
         path: "MockProject\\Backlog",
         start_date: nil,
         end_date: nil,
         status: "future",
         kind: "backlog"
       },
       %{
         azure_id: "mock-analise",
         name: "Análise de Esforço",
         path: "MockProject\\Análise de Esforço",
         start_date: nil,
         end_date: nil,
         status: "future",
         kind: "backlog"
       }
     ]}
  end

  def query_ids(_token, _project, _wiql), do: {:ok, Enum.map(mock_items(), & &1.azure_id)}

  def fetch(_token, ids) do
    by_id = Map.new(mock_items(), &{&1.azure_id, &1})
    {:ok, ids |> Enum.map(&Map.get(by_id, &1)) |> Enum.reject(&is_nil/1)}
  end

  # Árvore determinística Feature → User Story → Task, em 2 áreas e 2 iterations,
  # com datas e alguns story points fracionários — exercita relacionamentos e KPIs.
  defp mock_items do
    now = DateTime.utc_now() |> DateTime.truncate(:second)
    ago = fn days -> DateTime.add(now, -days * 86_400, :second) end

    [
      item(
        9001,
        "Feature: Carteira digital",
        "feature",
        "active",
        "Ana Lima",
        nil,
        nil,
        "Pagamentos",
        "Sprint 12",
        ago.(20),
        now,
        nil
      ),
      item(
        9002,
        "US: Cadastro de cartão",
        "story",
        "active",
        "Carlos Melo",
        5.0,
        9001,
        "Pagamentos\\PIX",
        "Sprint 12",
        ago.(18),
        now,
        nil
      ),
      item(
        9003,
        "Task: Tela de cartão",
        "task",
        "resolved",
        "Carlos Melo",
        2.0,
        9002,
        "Pagamentos\\PIX",
        "Sprint 12",
        ago.(17),
        ago.(2),
        ago.(2)
      ),
      item(
        9004,
        "Task: Validação de bandeira",
        "task",
        "active",
        "Ana Lima",
        0.5,
        9002,
        "Pagamentos\\PIX",
        "Sprint 12",
        ago.(16),
        now,
        nil
      ),
      item(
        9005,
        "US: Limite de gastos",
        "story",
        "new",
        nil,
        3.0,
        9001,
        "Pagamentos",
        "Backlog",
        ago.(10),
        ago.(10),
        nil
      ),
      item(
        9006,
        "Feature: Cobrança recorrente",
        "feature",
        "new",
        "Bruno Sá",
        nil,
        nil,
        "Cobrança",
        "Backlog",
        ago.(9),
        ago.(9),
        nil
      ),
      item(
        9007,
        "US: Agendar cobrança",
        "story",
        "active",
        "Bruno Sá",
        8.0,
        9006,
        "Cobrança",
        "Sprint 12",
        ago.(8),
        now,
        nil
      ),
      item(
        9008,
        "Task: Job de cobrança",
        "task",
        "new",
        nil,
        2.5,
        9007,
        "Cobrança",
        "Sprint 12",
        ago.(7),
        ago.(7),
        nil
      ),
      item(
        9009,
        "Bug: Cobrança duplicada",
        "bug",
        "active",
        "Ana Lima",
        nil,
        9006,
        "Cobrança",
        "Sprint 12",
        ago.(5),
        now,
        nil
      )
    ]
  end

  defp item(
         id,
         title,
         type,
         status,
         assignee,
         points,
         parent,
         area,
         iter,
         created,
         changed,
         closed
       ) do
    %{
      azure_id: id,
      title: title,
      type: type,
      status: status,
      assigned_to: assignee,
      story_points: points,
      priority: Enum.random([1, 2, 3]),
      iteration_path: "MockProject\\" <> iter,
      area_path: "MockProject\\" <> area,
      parent_azure_id: parent,
      azure_created_at: created,
      azure_changed_at: changed,
      closed_at: closed,
      description: "Mock: #{title}"
    }
  end

  def test_connection(_token), do: {:ok, :mock_mode}

  def get_board_columns(_token, _project, _team \\ nil, _board \\ "Stories") do
    {:ok,
     [
       %{name: "New", column_type: "incoming", states: ["New"], item_limit: nil},
       %{name: "Approved", column_type: "inProgress", states: ["Active"], item_limit: 5},
       %{name: "Committed", column_type: "inProgress", states: ["Active"], item_limit: 5},
       %{name: "Done", column_type: "outgoing", states: ["Resolved", "Closed"], item_limit: nil}
     ]}
  end
end

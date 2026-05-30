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
         start_date: Date.add(today, -28),
         end_date: Date.add(today, -15),
         status: "past"
       },
       %{
         azure_id: "mock-s12",
         name: "Sprint 12",
         start_date: Date.add(today, -14),
         end_date: today,
         status: "active"
       },
       %{
         azure_id: "mock-s13",
         name: "Sprint 13",
         start_date: Date.add(today, 1),
         end_date: Date.add(today, 14),
         status: "future"
       }
     ]}
  end

  def query_ids(_token, _project, _wiql), do: {:ok, [9001, 9002, 9003]}

  def fetch(_token, ids) do
    items =
      Enum.map(ids, fn id ->
        %{
          azure_id: id,
          title: "Mock work item ##{id}",
          type: Enum.random(~w(feature story task bug)),
          status: Enum.random(~w(new active resolved)),
          assigned_to: Enum.random(["Ana Lima", "Carlos Melo", nil]),
          story_points: Enum.random([nil, 1, 2, 3, 5, 8]),
          priority: Enum.random([1, 2, 3]),
          iteration_path: "MockProject\\Sprint 12",
          description: "Mock description for item #{id}."
        }
      end)

    {:ok, items}
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

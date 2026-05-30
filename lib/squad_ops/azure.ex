defmodule SquadOps.Azure do
  @moduledoc """
  Public facade for Azure DevOps integration.

  Dispatches between real HTTP calls and mock data based on the env var AZURE_MODE
  (`"real"` or `"mock"`, defaults to `"mock"`).
  """

  alias SquadOps.Azure.{Boards, Mock, Projects, Sprints, WorkItems}

  def mode do
    case System.get_env("AZURE_MODE", "mock") |> String.downcase() do
      "real" -> :real
      _ -> :mock
    end
  end

  def list_projects(token) do
    case mode() do
      :real -> Projects.list(token)
      :mock -> Mock.list_projects(token)
    end
  end

  def list_sprints(token, project, team \\ nil) do
    case mode() do
      :real -> Sprints.list(token, project, team)
      :mock -> Mock.list_sprints(token, project, team)
    end
  end

  def query_work_items(token, project, wiql) do
    case mode() do
      :real -> WorkItems.query_ids(token, project, wiql)
      :mock -> Mock.query_ids(token, project, wiql)
    end
  end

  def fetch_work_items(token, ids) do
    case mode() do
      :real -> WorkItems.fetch(token, ids)
      :mock -> Mock.fetch(token, ids)
    end
  end

  def get_board_columns(token, project, team \\ nil, board \\ "Stories") do
    case mode() do
      :real -> Boards.get_columns(token, project, team, board)
      :mock -> Mock.get_board_columns(token, project, team, board)
    end
  end

  @doc """
  Tests connectivity. Returns `{:ok, :real}`, `{:ok, :mock_mode}` or `{:error, reason}`.
  """
  def test_connection(token) do
    case mode() do
      :real ->
        case Projects.list(token) do
          {:ok, _} -> {:ok, :real}
          err -> err
        end

      :mock ->
        Mock.test_connection(token)
    end
  end
end

defmodule SquadOps.Azure.Boards do
  @moduledoc """
  Reads board columns from Azure DevOps.

  In Azure, each team has boards (Stories, Features, Epics). Each board has
  columns, and each column maps to one or more work item *states*.

  This module returns columns as a list of maps:

      [
        %{name: "New", states: ["New"], column_type: "incoming"},
        %{name: "Approved", states: ["Approved"], column_type: "inProgress"},
        %{name: "Committed", states: ["Committed"], column_type: "inProgress"},
        %{name: "Done", states: ["Done"], column_type: "outgoing"}
      ]
  """

  alias SquadOps.Azure.Client

  @doc """
  Returns columns of a given board for a given team.

  - `board` defaults to "Stories" (Agile process).
  - `team` defaults to `<project> Team` (Azure convention).
  """
  def get_columns(token, project, team \\ nil, board \\ "Stories") do
    team = team || "#{project} Team"
    path = "/#{URI.encode(project)}/#{URI.encode(team)}/_apis/work/boards/#{URI.encode(board)}"

    token
    |> Client.new()
    |> Client.get(path)
    |> Client.handle()
    |> case do
      {:ok, %{"columns" => cols}} -> {:ok, Enum.map(cols, &normalize/1)}
      other -> other
    end
  end

  defp normalize(col) do
    state_mappings = col["stateMappings"] || %{}

    %{
      name: col["name"],
      column_type: col["columnType"] || "inProgress",
      states: state_mappings |> Map.values() |> Enum.uniq(),
      item_limit: col["itemLimit"]
    }
  end
end

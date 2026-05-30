defmodule SquadOps.Azure.Sprints do
  @moduledoc """
  Iterations do projeto.

  Usamos os **classification nodes** (`/_apis/wit/classificationnodes/iterations`),
  que devolvem a árvore COMPLETA de iterations do projeto — independente de time.
  O endpoint `teamsettings/iterations` só traz as iterations associadas ao time
  default, o que deixava iterations de fora. Se os classification nodes falharem,
  cai no comportamento antigo (por time) como fallback.
  """

  alias SquadOps.Azure.Client

  def list(token, project, team \\ nil) do
    case list_from_nodes(token, project) do
      {:ok, iterations} when iterations != [] -> {:ok, iterations}
      {:ok, []} -> list_from_team(token, project, team)
      {:error, _} -> list_from_team(token, project, team)
    end
  end

  # --- Fonte primária: árvore completa de classification nodes ---

  defp list_from_nodes(token, project) do
    path = "/#{URI.encode(project)}/_apis/wit/classificationnodes/iterations"

    token
    |> Client.new()
    |> Client.get(path, params: ["$depth": 10])
    |> Client.handle()
    |> case do
      {:ok, root} -> {:ok, flatten(root)}
      other -> other
    end
  end

  # Achata a árvore: pega todos os descendentes (a raiz é o nó do projeto, ignorada).
  defp flatten(%{"children" => children}) when is_list(children) do
    Enum.flat_map(children, &collect/1)
  end

  defp flatten(_), do: []

  defp collect(node) do
    [normalize_node(node) | Enum.flat_map(node["children"] || [], &collect/1)]
  end

  defp normalize_node(node) do
    attrs = node["attributes"] || %{}
    start_date = parse_date(attrs["startDate"])
    end_date = parse_date(attrs["finishDate"])

    %{
      azure_id: node["identifier"],
      name: node["name"],
      path: node["path"],
      start_date: start_date,
      end_date: end_date,
      status: status_from_dates(start_date, end_date),
      kind: if(start_date && end_date, do: "sprint", else: "backlog")
    }
  end

  # Classification nodes não trazem timeFrame; derivamos do intervalo de datas.
  defp status_from_dates(nil, _), do: "future"
  defp status_from_dates(_, nil), do: "future"

  defp status_from_dates(start_date, end_date) do
    today = Date.utc_today()

    cond do
      Date.compare(today, start_date) == :lt -> "future"
      Date.compare(today, end_date) == :gt -> "past"
      true -> "active"
    end
  end

  # --- Fallback: iterations do time default ---

  defp list_from_team(token, project, team) do
    team = team || project <> " Team"
    path = "/#{URI.encode(project)}/#{URI.encode(team)}/_apis/work/teamsettings/iterations"

    token
    |> Client.new()
    |> Client.get(path)
    |> Client.handle()
    |> case do
      {:ok, %{"value" => iterations}} -> {:ok, Enum.map(iterations, &normalize_team/1)}
      other -> other
    end
  end

  defp normalize_team(it) do
    attrs = it["attributes"] || %{}
    start_date = parse_date(attrs["startDate"])
    end_date = parse_date(attrs["finishDate"])

    %{
      azure_id: it["id"],
      name: it["name"],
      path: it["path"],
      start_date: start_date,
      end_date: end_date,
      status: map_status(attrs["timeFrame"]),
      kind: if(start_date && end_date, do: "sprint", else: "backlog")
    }
  end

  defp parse_date(nil), do: nil

  defp parse_date(str) do
    case Date.from_iso8601(String.slice(str, 0, 10)) do
      {:ok, d} -> d
      _ -> nil
    end
  end

  defp map_status("current"), do: "active"
  defp map_status("past"), do: "past"
  defp map_status("future"), do: "future"
  defp map_status(_), do: "future"
end

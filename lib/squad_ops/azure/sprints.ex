defmodule SquadOps.Azure.Sprints do
  alias SquadOps.Azure.Client

  def list(token, project, team \\ nil) do
    team = team || project <> " Team"
    path = "/#{URI.encode(project)}/#{URI.encode(team)}/_apis/work/teamsettings/iterations"

    token
    |> Client.new()
    |> Client.get(path)
    |> Client.handle()
    |> case do
      {:ok, %{"value" => iterations}} -> {:ok, Enum.map(iterations, &normalize/1)}
      other -> other
    end
  end

  defp normalize(it) do
    attrs = it["attributes"] || %{}

    %{
      azure_id: it["id"],
      name: it["name"],
      start_date: parse_date(attrs["startDate"]),
      end_date: parse_date(attrs["finishDate"]),
      status: map_status(attrs["timeFrame"])
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

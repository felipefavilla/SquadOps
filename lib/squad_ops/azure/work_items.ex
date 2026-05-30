defmodule SquadOps.Azure.WorkItems do
  alias SquadOps.Azure.Client

  @fields ~w(System.Id System.Title System.WorkItemType System.State System.AssignedTo
             Microsoft.VSTS.Scheduling.StoryPoints Microsoft.VSTS.Common.Priority
             System.IterationPath System.AreaPath System.Parent System.Description
             System.CreatedDate System.ChangedDate Microsoft.VSTS.Common.ClosedDate)

  @doc "Run a WIQL query and return matching IDs"
  def query_ids(token, project, wiql) do
    path = "/#{URI.encode(project)}/_apis/wit/wiql"

    token
    |> Client.new()
    |> Client.post(path, %{query: wiql})
    |> Client.handle()
    |> case do
      {:ok, %{"workItems" => list}} -> {:ok, Enum.map(list, & &1["id"])}
      other -> other
    end
  end

  @doc "Fetch details for a batch of IDs"
  def fetch(token, ids) when is_list(ids) and ids != [] do
    chunk_ids =
      ids
      |> Enum.chunk_every(200)
      |> Enum.reduce_while({:ok, []}, fn chunk, {:ok, acc} ->
        ids_str = Enum.join(chunk, ",")

        token
        |> Client.new()
        |> Client.get("/_apis/wit/workitems",
          params: [
            ids: ids_str,
            fields: Enum.join(@fields, ","),
            "api-version": "7.1"
          ]
        )
        |> Client.handle()
        |> case do
          {:ok, %{"value" => items}} -> {:cont, {:ok, acc ++ Enum.map(items, &normalize/1)}}
          err -> {:halt, err}
        end
      end)

    chunk_ids
  end

  def fetch(_token, []), do: {:ok, []}

  defp normalize(%{"id" => id, "fields" => f}) do
    %{
      azure_id: id,
      title: f["System.Title"],
      type: map_type(f["System.WorkItemType"]),
      status: map_status(f["System.State"]),
      assigned_to: extract_user(f["System.AssignedTo"]),
      story_points: parse_points(f["Microsoft.VSTS.Scheduling.StoryPoints"]),
      priority: f["Microsoft.VSTS.Common.Priority"] || 2,
      iteration_path: f["System.IterationPath"],
      area_path: f["System.AreaPath"],
      parent_azure_id: f["System.Parent"],
      azure_created_at: parse_datetime(f["System.CreatedDate"]),
      azure_changed_at: parse_datetime(f["System.ChangedDate"]),
      closed_at: parse_datetime(f["Microsoft.VSTS.Common.ClosedDate"]),
      description: strip_html(f["System.Description"])
    }
  end

  defp map_type("Feature"), do: "feature"
  defp map_type("User Story"), do: "story"
  defp map_type("Task"), do: "task"
  defp map_type("Bug"), do: "bug"
  defp map_type(_), do: "task"

  defp map_status("New"), do: "new"
  defp map_status("Active"), do: "active"
  defp map_status("Resolved"), do: "resolved"
  defp map_status("Closed"), do: "closed"
  defp map_status("Removed"), do: "removed"
  defp map_status(_), do: "new"

  # Azure devolve story points como double (ex.: 13.0, 0.5); preservamos como float.
  defp parse_points(nil), do: nil
  defp parse_points(n) when is_float(n), do: n
  defp parse_points(n) when is_integer(n), do: n * 1.0

  defp parse_points(n) when is_binary(n) do
    case Float.parse(n) do
      {f, _} -> f
      :error -> nil
    end
  end

  defp parse_points(_), do: nil

  defp extract_user(nil), do: nil
  defp extract_user(%{"displayName" => name}), do: name
  defp extract_user(_), do: nil

  # Azure manda ISO8601 (ex.: "2026-05-20T12:34:56.78Z"); schema é :utc_datetime (segundos).
  defp parse_datetime(nil), do: nil

  defp parse_datetime(str) when is_binary(str) do
    case DateTime.from_iso8601(str) do
      {:ok, dt, _offset} -> DateTime.truncate(dt, :second)
      _ -> nil
    end
  end

  defp parse_datetime(_), do: nil

  defp strip_html(nil), do: nil
  defp strip_html(html), do: html |> String.replace(~r/<[^>]+>/, "") |> String.trim()
end

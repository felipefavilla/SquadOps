defmodule SquadOps.Azure.Projects do
  alias SquadOps.Azure.Client

  def list(token) do
    token
    |> Client.new()
    |> Client.get("/_apis/projects")
    |> Client.handle()
    |> case do
      {:ok, %{"value" => projects}} ->
        {:ok, Enum.map(projects, &normalize/1)}

      other ->
        other
    end
  end

  defp normalize(p) do
    %{id: p["id"], name: p["name"], description: p["description"], state: p["state"]}
  end
end

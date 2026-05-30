defmodule SquadOps.Squads do
  import Ecto.Query

  alias SquadOps.Repo
  alias SquadOps.Squads.{Squad, Sprint, WorkItem}

  # --- Squads ---

  def list_squads do
    Repo.all(from s in Squad, order_by: s.name)
  end

  def list_squads_with_stats do
    squads = list_squads()

    Enum.map(squads, fn squad ->
      stats = work_item_stats(squad.id)
      Map.put(squad, :stats, stats)
    end)
  end

  def get_squad!(id), do: Repo.get!(Squad, id)

  def get_squad_with_active_sprint!(id) do
    squad = Repo.get!(Squad, id)
    active_sprint = get_active_sprint(squad.id)

    work_items =
      if active_sprint, do: list_work_items(squad.id, sprint_id: active_sprint.id), else: []

    {squad, active_sprint, work_items}
  end

  def create_squad(attrs) do
    %Squad{}
    |> Squad.changeset(attrs)
    |> Repo.insert()
  end

  def update_squad(%Squad{} = squad, attrs) do
    squad
    |> Squad.changeset(attrs)
    |> Repo.update()
  end

  def delete_squad(%Squad{} = squad), do: Repo.delete(squad)

  def change_squad(%Squad{} = squad, attrs \\ %{}), do: Squad.changeset(squad, attrs)

  # --- Sprints ---

  def list_sprints(squad_id) do
    Repo.all(
      from s in Sprint,
        where: s.squad_id == ^squad_id,
        order_by: [desc: s.start_date]
    )
  end

  def get_active_sprint(squad_id) do
    Repo.one(
      from s in Sprint,
        where: s.squad_id == ^squad_id and s.status == "active",
        limit: 1
    )
  end

  def create_sprint(attrs) do
    %Sprint{}
    |> Sprint.changeset(attrs)
    |> Repo.insert()
  end

  def update_sprint(%Sprint{} = sprint, attrs) do
    sprint
    |> Sprint.changeset(attrs)
    |> Repo.update()
  end

  # --- Work Items ---

  def list_work_items(squad_id, filters \\ []) do
    query = from w in WorkItem, where: w.squad_id == ^squad_id

    query
    |> maybe_filter_sprint(filters[:sprint_id])
    |> maybe_filter_type(filters[:type])
    |> maybe_filter_status(filters[:status])
    |> order_by([w], asc: w.priority, asc: w.inserted_at)
    |> Repo.all()
  end

  def get_work_item!(id), do: Repo.get!(WorkItem, id)

  def create_work_item(attrs) do
    %WorkItem{}
    |> WorkItem.changeset(attrs)
    |> Repo.insert()
  end

  def update_work_item(%WorkItem{} = item, attrs) do
    item
    |> WorkItem.changeset(attrs)
    |> Repo.update()
  end

  def delete_work_item(%WorkItem{} = item), do: Repo.delete(item)

  def move_work_item(%WorkItem{} = item, new_status) do
    update_work_item(item, %{status: new_status})
  end

  def work_item_stats(squad_id) do
    Repo.all(
      from w in WorkItem,
        where: w.squad_id == ^squad_id,
        group_by: w.status,
        select: {w.status, count(w.id)}
    )
    |> Map.new()
  end

  def list_all_work_items(filters \\ []) do
    query =
      from w in WorkItem,
        join: s in assoc(w, :squad),
        preload: [squad: s]

    query
    |> maybe_filter_squad(filters[:squad_id])
    |> maybe_filter_sprint(filters[:sprint_id])
    |> maybe_filter_type(filters[:type])
    |> maybe_filter_status(filters[:status])
    |> order_by([w], asc: w.priority, asc: w.inserted_at)
    |> Repo.all()
  end

  # --- Private helpers ---

  defp maybe_filter_sprint(query, nil), do: query
  defp maybe_filter_sprint(query, sprint_id), do: where(query, [w], w.sprint_id == ^sprint_id)

  defp maybe_filter_type(query, nil), do: query
  defp maybe_filter_type(query, type), do: where(query, [w], w.type == ^type)

  defp maybe_filter_status(query, nil), do: query
  defp maybe_filter_status(query, status), do: where(query, [w], w.status == ^status)

  defp maybe_filter_squad(query, nil), do: query
  defp maybe_filter_squad(query, squad_id), do: where(query, [w], w.squad_id == ^squad_id)
end

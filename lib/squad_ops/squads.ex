defmodule SquadOps.Squads do
  import Ecto.Query

  alias SquadOps.{Repo, Rules}
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

  @doc "Lista iterations do squad, opcionalmente filtrando por kind (\"sprint\" | \"backlog\")."
  def list_iterations(squad_id, kind \\ nil) do
    query =
      from s in Sprint,
        where: s.squad_id == ^squad_id,
        order_by: [desc: s.start_date, asc: s.name]

    query = if kind, do: where(query, [s], s.kind == ^kind), else: query
    Repo.all(query)
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
    |> maybe_filter_area(filters[:area_path])
    |> apply_sort(filters[:sort])
    |> Repo.all()
  end

  @doc "Áreas (System.AreaPath) distintas com itens no squad, ordenadas."
  def list_areas(squad_id) do
    Repo.all(
      from w in WorkItem,
        where: w.squad_id == ^squad_id and not is_nil(w.area_path),
        distinct: true,
        order_by: w.area_path,
        select: w.area_path
    )
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
    |> maybe_filter_area(filters[:area_path])
    |> apply_sort(filters[:sort])
    |> Repo.all()
  end

  @doc """
  Monta a árvore de relacionamentos Feature → User Story → Task a partir de
  `parent_azure_id`. Retorna uma lista de nós `%{item: wi, children: [...]}`,
  onde as raízes são itens sem pai (ou cujo pai está fora do conjunto filtrado).
  Aceita os mesmos `filters` de `list_all_work_items/1`.
  """
  def relationship_tree(filters \\ []) do
    items = list_all_work_items(filters)

    # Só agrupa quem tem pai explícito — evita que itens locais (azure_id nil)
    # caiam num mesmo balde nil e virem filhos uns dos outros (recursão infinita).
    by_parent =
      items
      |> Enum.filter(& &1.parent_azure_id)
      |> Enum.group_by(& &1.parent_azure_id)

    present = MapSet.new(items, & &1.azure_id)

    items
    |> Enum.filter(fn i ->
      is_nil(i.parent_azure_id) or not MapSet.member?(present, i.parent_azure_id)
    end)
    |> Enum.map(&build_node(&1, by_parent))
  end

  defp build_node(item, by_parent) do
    children =
      if is_nil(item.azure_id) do
        []
      else
        by_parent
        |> Map.get(item.azure_id, [])
        |> Enum.reject(&(&1.azure_id == item.azure_id))
        |> Enum.map(&build_node(&1, by_parent))
      end

    %{item: item, children: children}
  end

  @doc """
  Colunas do board (filas Kanban) do squad, vindas de `rules.workflow["columns"]`
  (sincronizadas do Azure) ou um fallback padrão. Cada coluna mapeia para os
  status locais correspondentes. Não inclui estilização (fica na view).
  """
  def board_columns(squad_id) do
    rule = Rules.get_or_init(squad_id)
    status_mapping = get_in(rule.field_mapping, ["status"]) || %{}

    case get_in(rule.workflow, ["columns"]) do
      cols when is_list(cols) and cols != [] ->
        Enum.map(cols, fn col ->
          local =
            (Map.get(col, "states") || [])
            |> Enum.map(&Map.get(status_mapping, &1, String.downcase(&1)))
            |> Enum.uniq()

          %{
            name: col["name"] || "—",
            local_statuses: local,
            column_type: col["column_type"] || "inProgress",
            item_limit: col["item_limit"]
          }
        end)

      _ ->
        default_columns()
    end
  end

  @doc "Conta itens por fila do board, aplicando filtros (ex.: area_path)."
  def queue_counts(squad_id, filters \\ []) do
    items = list_work_items(squad_id, filters)

    Enum.map(board_columns(squad_id), fn col ->
      Map.put(col, :count, Enum.count(items, &(&1.status in col.local_statuses)))
    end)
  end

  defp default_columns do
    [
      %{name: "Novo", local_statuses: ["new"], column_type: "incoming", item_limit: nil},
      %{
        name: "Em Andamento",
        local_statuses: ["active"],
        column_type: "inProgress",
        item_limit: nil
      },
      %{
        name: "Resolvido",
        local_statuses: ["resolved"],
        column_type: "outgoing",
        item_limit: nil
      },
      %{name: "Fechado", local_statuses: ["closed"], column_type: "outgoing", item_limit: nil}
    ]
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

  defp maybe_filter_area(query, nil), do: query
  defp maybe_filter_area(query, area), do: where(query, [w], w.area_path == ^area)

  # Ordenação: :created = mais recentes primeiro (data de criação no Azure, fallback local);
  # default = por prioridade e inserção.
  defp apply_sort(query, :created),
    do: order_by(query, [w], desc: coalesce(w.azure_created_at, w.inserted_at))

  defp apply_sort(query, "created"), do: apply_sort(query, :created)
  defp apply_sort(query, _), do: order_by(query, [w], asc: w.priority, asc: w.inserted_at)
end

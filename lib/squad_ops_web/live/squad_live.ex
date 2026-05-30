defmodule SquadOpsWeb.SquadLive do
  use SquadOpsWeb, :live_view

  on_mount {SquadOpsWeb.UserAuth, :require_authenticated_user}

  alias SquadOps.{Rules, Squads}

  # Fallback usado quando o squad ainda não sincronizou colunas do Azure board
  @default_columns [
    %{
      name: "Novo",
      local_statuses: ["new"],
      badge_class: "badge-warning",
      column_type: "incoming",
      item_limit: nil
    },
    %{
      name: "Em Andamento",
      local_statuses: ["active"],
      badge_class: "badge-info",
      column_type: "inProgress",
      item_limit: nil
    },
    %{
      name: "Resolvido",
      local_statuses: ["resolved"],
      badge_class: "badge-success",
      column_type: "outgoing",
      item_limit: nil
    },
    %{
      name: "Fechado",
      local_statuses: ["closed"],
      badge_class: "badge-ghost",
      column_type: "outgoing",
      item_limit: nil
    }
  ]

  @type_colors %{
    "feature" => "badge-primary",
    "story" => "badge-secondary",
    "task" => "badge-accent",
    "bug" => "badge-error"
  }

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    {squad, sprint, work_items} = Squads.get_squad_with_active_sprint!(id)
    all_sprints = Squads.list_sprints(squad.id)
    rule = Rules.get_or_init(squad.id)
    columns = build_columns(rule)

    {:ok,
     assign(socket,
       squad: squad,
       active_sprint: sprint,
       all_sprints: all_sprints,
       work_items: work_items,
       columns: columns,
       columns_source: column_source(rule),
       type_colors: @type_colors,
       page_title: squad.name,
       current_path: "/squads/#{id}"
     )}
  end

  @impl true
  def handle_event("move", %{"item-id" => id, "status" => new_status}, socket) do
    item = Squads.get_work_item!(id)

    case Squads.move_work_item(item, new_status) do
      {:ok, updated} ->
        items =
          Enum.map(socket.assigns.work_items, fn i ->
            if i.id == updated.id, do: updated, else: i
          end)

        {:noreply, assign(socket, work_items: items)}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Não foi possível mover o item.")}
    end
  end

  # --- Column resolution ---

  defp column_source(rule) do
    azure_cols = get_in(rule.workflow, ["columns"])

    if is_list(azure_cols) and azure_cols != [],
      do: :azure,
      else: :default
  end

  defp build_columns(rule) do
    azure_cols = get_in(rule.workflow, ["columns"])
    status_mapping = get_in(rule.field_mapping, ["status"]) || %{}

    case azure_cols do
      cols when is_list(cols) and cols != [] ->
        Enum.map(cols, &translate_column(&1, status_mapping))

      _ ->
        @default_columns
    end
  end

  defp translate_column(col, status_mapping) do
    azure_states = Map.get(col, "states") || []

    local_statuses =
      azure_states
      |> Enum.map(&Map.get(status_mapping, &1, String.downcase(&1)))
      |> Enum.uniq()

    %{
      name: col["name"] || "—",
      local_statuses: local_statuses,
      badge_class: badge_for_column_type(col["column_type"]),
      column_type: col["column_type"] || "inProgress",
      item_limit: col["item_limit"]
    }
  end

  defp badge_for_column_type("incoming"), do: "badge-warning"
  defp badge_for_column_type("outgoing"), do: "badge-success"
  defp badge_for_column_type(_), do: "badge-info"

  defp items_in_column(items, column),
    do: Enum.filter(items, &(&1.status in column.local_statuses))

  defp next_local_status(columns, current_status) do
    statuses = Enum.flat_map(columns, & &1.local_statuses)
    idx = Enum.find_index(statuses, &(&1 == current_status))

    if idx && idx < length(statuses) - 1,
      do: Enum.at(statuses, idx + 1),
      else: nil
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="max-w-full mx-auto space-y-4">
      <div class="flex items-center gap-3 flex-wrap">
        <a href={~p"/"} class="btn btn-ghost btn-sm">← Dashboard</a>
        <div class="flex items-center gap-2">
          <div class="w-3 h-3 rounded-full" style={"background-color: #{@squad.color}"}></div>
          <h1 class="text-xl font-bold">{@squad.name}</h1>
        </div>
        <div :if={@active_sprint} class="badge badge-outline">
          {@active_sprint.name}
          <span :if={@active_sprint.end_date} class="ml-1 opacity-60">
            · até {Calendar.strftime(@active_sprint.end_date, "%d/%m")}
          </span>
        </div>
        <div :if={!@active_sprint} class="badge badge-warning badge-outline">Sem sprint ativo</div>

        <div :if={@columns_source == :azure} class="badge badge-success badge-sm gap-1">
          <.icon name="hero-cloud" class="size-3" /> Colunas do Azure
        </div>
        <div :if={@columns_source == :default} class="badge badge-ghost badge-sm gap-1">
          <.icon name="hero-cog-6-tooth" class="size-3" /> Colunas padrão
        </div>
      </div>

      <div
        class="grid gap-3 overflow-x-auto"
        style={"grid-template-columns: repeat(#{length(@columns)}, minmax(12rem, 1fr));"}
      >
        <div :for={col <- @columns} class="flex flex-col gap-2 min-w-48">
          <div class="flex items-center justify-between px-1">
            <span class={"badge #{col.badge_class} badge-sm"}>{col.name}</span>
            <div class="flex items-center gap-1 text-xs">
              <span
                :if={col.item_limit}
                class={[
                  "text-base-content/50",
                  Enum.count(items_in_column(@work_items, col)) > col.item_limit &&
                    "text-error font-bold"
                ]}
              >
                {Enum.count(items_in_column(@work_items, col))}/{col.item_limit}
              </span>
              <span :if={!col.item_limit} class="text-base-content/50">
                {Enum.count(items_in_column(@work_items, col))}
              </span>
            </div>
          </div>

          <div class="flex flex-col gap-2 min-h-24">
            <.work_item_card
              :for={item <- items_in_column(@work_items, col)}
              item={item}
              type_colors={@type_colors}
              next_status={next_local_status(@columns, item.status)}
            />
          </div>
        </div>
      </div>
    </div>
    """
  end

  attr :item, :map, required: true
  attr :type_colors, :map, required: true
  attr :next_status, :string, default: nil

  defp work_item_card(assigns) do
    ~H"""
    <div class="card bg-base-100 shadow-sm border border-base-200 hover:border-base-300 transition-colors">
      <div class="card-body p-3 gap-2">
        <p class="text-sm font-medium leading-snug">{@item.title}</p>
        <div class="flex items-center justify-between gap-1 flex-wrap">
          <div class="flex items-center gap-1">
            <span class={"badge badge-xs #{Map.get(@type_colors, @item.type, "badge-ghost")}"}>
              {@item.type}
            </span>
            <span :if={@item.story_points} class="badge badge-xs badge-ghost">
              {@item.story_points}pts
            </span>
          </div>
          <span :if={@item.assigned_to} class="text-xs text-base-content/50 truncate max-w-24">
            {@item.assigned_to}
          </span>
        </div>
        <div :if={@next_status} class="pt-1 border-t border-base-200">
          <button
            phx-click="move"
            phx-value-item-id={@item.id}
            phx-value-status={@next_status}
            class="btn btn-xs btn-ghost w-full"
          >
            Mover →
          </button>
        </div>
      </div>
    </div>
    """
  end
end

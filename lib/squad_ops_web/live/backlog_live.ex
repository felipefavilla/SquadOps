defmodule SquadOpsWeb.BacklogLive do
  use SquadOpsWeb, :live_view

  on_mount {SquadOpsWeb.UserAuth, :require_authenticated_user}

  alias SquadOps.Squads

  @type_colors %{
    "feature" => "badge-primary",
    "story" => "badge-secondary",
    "task" => "badge-accent",
    "bug" => "badge-error"
  }

  @status_colors %{
    "new" => "badge-warning",
    "active" => "badge-info",
    "resolved" => "badge-success",
    "closed" => "badge-ghost",
    "removed" => "badge-error"
  }

  @impl true
  def mount(params, _session, socket) do
    squad_id = parse_int(params["squad_id"])

    filters = %{
      squad_id: squad_id,
      area_path: nil,
      sprint_id: nil,
      type: nil,
      status: nil,
      sort: "priority"
    }

    {:ok,
     socket
     |> assign(
       squads: Squads.list_squads(),
       type_colors: @type_colors,
       status_colors: @status_colors,
       page_title: "Backlog",
       current_path: "/backlog"
     )
     |> load(filters)}
  end

  @impl true
  def handle_event("filter", params, socket) do
    filters = %{
      squad_id: parse_int(params["squad_id"]),
      area_path: blank_to_nil(params["area_path"]),
      sprint_id: parse_int(params["sprint_id"]),
      type: blank_to_nil(params["type"]),
      status: blank_to_nil(params["status"]),
      sort: params["sort"] || "priority"
    }

    {:noreply, load(socket, filters)}
  end

  defp load(socket, filters) do
    tree = Squads.relationship_tree(Map.to_list(filters))

    # Áreas e iterations só fazem sentido com um squad escolhido.
    {areas, iterations} =
      if filters.squad_id do
        {Squads.list_areas(filters.squad_id), Squads.list_iterations(filters.squad_id)}
      else
        {[], []}
      end

    assign(socket,
      filters: filters,
      tree: tree,
      count: count_nodes(tree),
      areas: areas,
      iterations: iterations
    )
  end

  defp count_nodes(tree),
    do: Enum.reduce(tree, 0, fn n, acc -> acc + 1 + count_nodes(n.children) end)

  defp blank_to_nil(nil), do: nil
  defp blank_to_nil(""), do: nil
  defp blank_to_nil(v), do: v

  defp parse_int(nil), do: nil
  defp parse_int(""), do: nil

  defp parse_int(v) when is_binary(v) do
    case Integer.parse(v) do
      {n, _} -> n
      _ -> nil
    end
  end

  defp parse_int(v) when is_integer(v), do: v

  @impl true
  def render(assigns) do
    ~H"""
    <div class="max-w-5xl mx-auto space-y-4">
      <div class="flex items-center justify-between">
        <h1 class="text-2xl font-bold">Backlog</h1>
        <span class="text-sm text-base-content/50">{@count} itens</span>
      </div>

      <form phx-change="filter" class="card bg-base-100 shadow p-4">
        <div class="flex flex-wrap gap-3">
          <.filter_select name="squad_id" label="Squad" all="Todos">
            <option :for={s <- @squads} value={s.id} selected={@filters.squad_id == s.id}>
              {s.name}
            </option>
          </.filter_select>

          <.filter_select
            name="area_path"
            label="Área"
            all={if @areas == [], do: "—", else: "Todas"}
          >
            <option :for={a <- @areas} value={a} selected={@filters.area_path == a}>
              {a |> String.split("\\") |> List.last()}
            </option>
          </.filter_select>

          <.filter_select
            name="sprint_id"
            label="Iteration"
            all={if @iterations == [], do: "—", else: "Todas"}
          >
            <option :for={it <- @iterations} value={it.id} selected={@filters.sprint_id == it.id}>
              {it.name}
            </option>
          </.filter_select>

          <.filter_select name="type" label="Tipo" all="Todos">
            <option :for={t <- ~w(feature story task bug)} value={t} selected={@filters.type == t}>
              {t}
            </option>
          </.filter_select>

          <.filter_select name="status" label="Status" all="Todos">
            <option
              :for={s <- ~w(new active resolved closed)}
              value={s}
              selected={@filters.status == s}
            >
              {s}
            </option>
          </.filter_select>

          <div class="form-control min-w-40">
            <label class="label py-1"><span class="label-text text-xs">Ordenar</span></label>
            <select name="sort" class="select select-bordered select-sm">
              <option value="priority" selected={@filters.sort == "priority"}>Prioridade</option>
              <option value="created" selected={@filters.sort == "created"}>Data de criação ↓</option>
            </select>
          </div>
        </div>
      </form>

      <div class="card bg-base-100 shadow">
        <div class="card-body gap-1">
          <p :if={@tree == []} class="text-center text-base-content/40 py-8">
            Nenhum item encontrado
          </p>
          <.tree_node
            :for={node <- @tree}
            node={node}
            depth={0}
            type_colors={@type_colors}
            status_colors={@status_colors}
          />
        </div>
      </div>
    </div>
    """
  end

  # Componente recursivo: renderiza o item e seus filhos indentados.
  attr :node, :map, required: true
  attr :depth, :integer, required: true
  attr :type_colors, :map, required: true
  attr :status_colors, :map, required: true

  defp tree_node(assigns) do
    ~H"""
    <div>
      <div
        class="flex items-center gap-2 py-1.5 border-b border-base-200/60 hover:bg-base-200/40 rounded"
        style={"padding-left: #{@depth * 1.5}rem"}
      >
        <.icon
          :if={@node.children != []}
          name="hero-chevron-down"
          class="size-3 text-base-content/30"
        />
        <span :if={@node.children == []} class="w-3"></span>

        <span class={"badge badge-xs #{Map.get(@type_colors, @node.item.type, "badge-ghost")}"}>
          {@node.item.type}
        </span>
        <span class="text-sm font-medium flex-1 truncate">{@node.item.title}</span>

        <span :if={@node.item.area_path} class="text-xs text-base-content/40 hidden md:inline">
          {@node.item.area_path |> String.split("\\") |> List.last()}
        </span>
        <span :if={@node.item.story_points} class="badge badge-xs badge-ghost">
          {@node.item.story_points}pts
        </span>
        <span class={"badge badge-xs #{Map.get(@status_colors, @node.item.status, "badge-ghost")}"}>
          {@node.item.status}
        </span>
        <span class="text-xs text-base-content/40 w-20 text-right hidden sm:inline">
          {created_label(@node.item)}
        </span>
      </div>

      <.tree_node
        :for={child <- @node.children}
        node={child}
        depth={@depth + 1}
        type_colors={@type_colors}
        status_colors={@status_colors}
      />
    </div>
    """
  end

  defp created_label(%{azure_created_at: %DateTime{} = dt}), do: Calendar.strftime(dt, "%d/%m/%y")
  defp created_label(%{inserted_at: %NaiveDateTime{} = dt}), do: Calendar.strftime(dt, "%d/%m/%y")
  defp created_label(_), do: ""

  attr :name, :string, required: true
  attr :label, :string, required: true
  attr :all, :string, required: true
  slot :inner_block, required: true

  defp filter_select(assigns) do
    ~H"""
    <div class="form-control flex-1 min-w-36">
      <label class="label py-1"><span class="label-text text-xs">{@label}</span></label>
      <select name={@name} class="select select-bordered select-sm">
        <option value="">{@all}</option>
        {render_slot(@inner_block)}
      </select>
    </div>
    """
  end
end

defmodule SquadOpsWeb.SquadLive do
  use SquadOpsWeb, :live_view

  on_mount {SquadOpsWeb.UserAuth, :require_authenticated_user}

  alias SquadOps.Squads

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    squad = Squads.get_squad!(id)
    items = Squads.list_work_items(squad.id)
    iterations = Squads.list_iterations(squad.id)
    areas = Squads.list_areas(squad.id)
    columns = Squads.board_columns(squad.id)

    {:ok,
     assign(socket,
       squad: squad,
       items: items,
       iterations: iterations,
       areas: areas,
       columns: columns,
       sprint_lookup: Map.new(iterations, &{&1.id, &1}),
       filters: %{area: nil, iteration_id: nil},
       page_title: squad.name,
       current_path: "/squads/#{id}"
     )}
  end

  @impl true
  def handle_event("filter", %{"area" => area, "iteration_id" => iter}, socket) do
    filters = %{area: blank_to_nil(area), iteration_id: parse_int(iter)}
    {:noreply, assign(socket, filters: filters)}
  end

  defp blank_to_nil(""), do: nil
  defp blank_to_nil(v), do: v

  defp parse_int(nil), do: nil

  defp parse_int(v) do
    case Integer.parse(v) do
      {n, _} -> n
      _ -> nil
    end
  end

  # --- Filtering / aggregation (in-memory) ---

  defp apply_filters(items, filters) do
    items
    |> filter_area(filters.area)
    |> filter_iteration(filters.iteration_id)
  end

  defp filter_area(items, nil), do: items
  defp filter_area(items, area), do: Enum.filter(items, &(&1.area_path == area))

  defp filter_iteration(items, nil), do: items
  defp filter_iteration(items, id), do: Enum.filter(items, &(&1.sprint_id == id))

  defp sum_points(items), do: items |> Enum.map(&(&1.story_points || 0)) |> Enum.sum()

  defp count_in_column(items, col),
    do: Enum.count(items, &(&1.status in col.local_statuses))

  @impl true
  def render(assigns) do
    filtered = apply_filters(assigns.items, assigns.filters)

    by_area =
      assigns.items
      |> filter_iteration(assigns.filters.iteration_id)
      |> Enum.group_by(&(&1.area_path || "— sem área —"))
      |> Enum.map(fn {area, its} -> {area, length(its), sum_points(its)} end)
      |> Enum.sort_by(fn {area, _, _} -> area end)

    by_iteration =
      assigns.items
      |> filter_area(assigns.filters.area)
      |> Enum.group_by(& &1.sprint_id)

    assigns =
      assign(assigns,
        filtered: filtered,
        by_area: by_area,
        by_iteration: by_iteration,
        total: length(filtered),
        total_points: sum_points(filtered)
      )

    ~H"""
    <div class="max-w-6xl mx-auto space-y-5">
      <div class="flex items-center gap-3 flex-wrap">
        <a href={~p"/"} class="btn btn-ghost btn-sm">← Dashboard</a>
        <div class="flex items-center gap-2">
          <div class="w-3 h-3 rounded-full" style={"background-color: #{@squad.color}"}></div>
          <h1 class="text-xl font-bold">{@squad.name}</h1>
        </div>
        <span class="badge badge-ghost badge-sm">{@total} itens</span>
        <span class="badge badge-ghost badge-sm">{@total_points} pts</span>
        <div class="flex-1"></div>
        <a href={~p"/squads/#{@squad.id}/rules"} class="btn btn-ghost btn-sm">
          <.icon name="hero-shield-check" class="size-4" /> Regras
        </a>
        <a href={~p"/backlog?squad_id=#{@squad.id}"} class="btn btn-ghost btn-sm">
          <.icon name="hero-clipboard-document-list" class="size-4" /> Backlog
        </a>
      </div>

      <%!-- Filtros --%>
      <form phx-change="filter" class="card bg-base-100 shadow p-4">
        <div class="flex flex-wrap gap-3">
          <div class="form-control flex-1 min-w-44">
            <label class="label py-1"><span class="label-text text-xs">Área</span></label>
            <select name="area" class="select select-bordered select-sm">
              <option value="">Todas as áreas</option>
              <option :for={a <- @areas} value={a} selected={@filters.area == a}>
                {short_area(a)}
              </option>
            </select>
          </div>
          <div class="form-control flex-1 min-w-44">
            <label class="label py-1"><span class="label-text text-xs">Iteration</span></label>
            <select name="iteration_id" class="select select-bordered select-sm">
              <option value="">Todas as iterations</option>
              <option
                :for={it <- @iterations}
                value={it.id}
                selected={@filters.iteration_id == it.id}
              >
                {it.name} ({it.kind})
              </option>
            </select>
          </div>
        </div>
      </form>

      <%!-- Contagens por fila do Kanban (filtradas pelos filtros acima) --%>
      <div>
        <h2 class="text-sm font-semibold text-base-content/60 mb-2 uppercase tracking-wide">
          Filas do Kanban
        </h2>
        <div
          class="grid gap-3"
          style={"grid-template-columns: repeat(#{length(@columns)}, minmax(8rem, 1fr));"}
        >
          <div :for={col <- @columns} class="card bg-base-100 shadow">
            <div class="card-body p-4 items-center text-center gap-1">
              <span class={"badge badge-sm #{column_badge(col.column_type)}"}>{col.name}</span>
              <div class="text-2xl font-bold">{count_in_column(@filtered, col)}</div>
              <div :if={col.item_limit} class="text-xs text-base-content/40">
                limite {col.item_limit}
              </div>
            </div>
          </div>
        </div>
      </div>

      <div class="grid grid-cols-1 lg:grid-cols-2 gap-5">
        <%!-- Por Área --%>
        <div class="card bg-base-100 shadow">
          <div class="card-body gap-3">
            <h2 class="card-title text-base">
              <.icon name="hero-squares-2x2" class="size-5" /> Itens por Área
            </h2>
            <table class="table table-sm">
              <thead>
                <tr>
                  <th>Área</th>
                  <th class="text-right">Itens</th>
                  <th class="text-right">Pts</th>
                </tr>
              </thead>
              <tbody>
                <tr :if={@by_area == []}>
                  <td colspan="3" class="text-center text-base-content/40 py-4">Sem dados</td>
                </tr>
                <tr :for={{area, count, pts} <- @by_area} class="hover">
                  <td class="text-sm">{short_area(area)}</td>
                  <td class="text-right">{count}</td>
                  <td class="text-right text-base-content/60">{pts}</td>
                </tr>
              </tbody>
            </table>
          </div>
        </div>

        <%!-- Por Iteration --%>
        <div class="card bg-base-100 shadow">
          <div class="card-body gap-3">
            <h2 class="card-title text-base">
              <.icon name="hero-calendar-days" class="size-5" /> Itens por Iteration
            </h2>
            <table class="table table-sm">
              <thead>
                <tr>
                  <th>Iteration</th>
                  <th>Tipo</th>
                  <th class="text-right">Itens</th>
                  <th class="text-right">Pts</th>
                </tr>
              </thead>
              <tbody>
                <tr :for={it <- @iterations} class="hover">
                  <td class="text-sm">{it.name}</td>
                  <td>
                    <span class={"badge badge-xs #{if it.kind == "sprint", do: "badge-primary", else: "badge-ghost"}"}>
                      {it.kind}
                    </span>
                  </td>
                  <td class="text-right">{length(Map.get(@by_iteration, it.id, []))}</td>
                  <td class="text-right text-base-content/60">
                    {sum_points(Map.get(@by_iteration, it.id, []))}
                  </td>
                </tr>
                <tr :if={Map.get(@by_iteration, nil, []) != []} class="hover opacity-70">
                  <td class="text-sm italic">— sem iteration —</td>
                  <td></td>
                  <td class="text-right">{length(Map.get(@by_iteration, nil, []))}</td>
                  <td class="text-right text-base-content/60">
                    {sum_points(Map.get(@by_iteration, nil, []))}
                  </td>
                </tr>
              </tbody>
            </table>
          </div>
        </div>
      </div>
    </div>
    """
  end

  defp column_badge("incoming"), do: "badge-warning"
  defp column_badge("outgoing"), do: "badge-success"
  defp column_badge(_), do: "badge-info"

  # Mostra só o último segmento do Area Path para caber na tela.
  defp short_area(nil), do: "—"
  defp short_area(path), do: path |> String.split("\\") |> List.last()
end

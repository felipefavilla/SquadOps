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
  def mount(_params, _session, socket) do
    squads = Squads.list_squads()
    work_items = Squads.list_all_work_items()

    {:ok,
     assign(socket,
       squads: squads,
       work_items: work_items,
       filters: %{squad_id: nil, type: nil, status: nil},
       type_colors: @type_colors,
       status_colors: @status_colors,
       page_title: "Backlog",
       current_path: "/backlog"
     )}
  end

  @impl true
  def handle_event(
        "filter",
        %{"squad_id" => squad_id, "type" => type, "status" => status},
        socket
      ) do
    filters = %{
      squad_id: blank_to_nil(squad_id),
      type: blank_to_nil(type),
      status: blank_to_nil(status)
    }

    work_items =
      Squads.list_all_work_items(Map.to_list(filters) |> Enum.reject(fn {_, v} -> is_nil(v) end))

    {:noreply, assign(socket, filters: filters, work_items: work_items)}
  end

  defp blank_to_nil(""), do: nil
  defp blank_to_nil(v), do: v

  @impl true
  def render(assigns) do
    ~H"""
    <div class="max-w-5xl mx-auto space-y-4">
      <div class="flex items-center justify-between">
        <h1 class="text-2xl font-bold">Backlog</h1>
        <span class="text-sm text-base-content/50">{length(@work_items)} itens</span>
      </div>

      <form phx-change="filter" class="card bg-base-100 shadow p-4">
        <div class="flex flex-wrap gap-3">
          <div class="form-control flex-1 min-w-36">
            <label class="label py-1"><span class="label-text text-xs">Squad</span></label>
            <select name="squad_id" class="select select-bordered select-sm">
              <option value="">Todos</option>
              <option :for={s <- @squads} value={s.id} selected={@filters.squad_id == to_string(s.id)}>
                {s.name}
              </option>
            </select>
          </div>
          <div class="form-control flex-1 min-w-36">
            <label class="label py-1"><span class="label-text text-xs">Tipo</span></label>
            <select name="type" class="select select-bordered select-sm">
              <option value="">Todos</option>
              <option :for={t <- ~w(feature story task bug)} value={t} selected={@filters.type == t}>
                {t}
              </option>
            </select>
          </div>
          <div class="form-control flex-1 min-w-36">
            <label class="label py-1"><span class="label-text text-xs">Status</span></label>
            <select name="status" class="select select-bordered select-sm">
              <option value="">Todos</option>
              <option
                :for={s <- ~w(new active resolved closed)}
                value={s}
                selected={@filters.status == s}
              >
                {s}
              </option>
            </select>
          </div>
        </div>
      </form>

      <div class="card bg-base-100 shadow overflow-hidden">
        <table class="table table-sm">
          <thead>
            <tr>
              <th>Título</th>
              <th>Squad</th>
              <th>Tipo</th>
              <th>Status</th>
              <th>Responsável</th>
              <th class="text-right">Pts</th>
            </tr>
          </thead>
          <tbody>
            <tr :if={@work_items == []} class="hover">
              <td colspan="6" class="text-center text-base-content/40 py-8">
                Nenhum item encontrado
              </td>
            </tr>
            <tr :for={item <- @work_items} class="hover">
              <td class="max-w-xs">
                <a
                  href={~p"/squads/#{item.squad_id}"}
                  class="hover:text-primary font-medium line-clamp-1"
                >
                  {item.title}
                </a>
              </td>
              <td class="text-sm text-base-content/70">{item.squad.name}</td>
              <td>
                <span class={"badge badge-xs #{Map.get(@type_colors, item.type, "badge-ghost")}"}>
                  {item.type}
                </span>
              </td>
              <td>
                <span class={"badge badge-xs #{Map.get(@status_colors, item.status, "badge-ghost")}"}>
                  {item.status}
                </span>
              </td>
              <td class="text-sm text-base-content/60">{item.assigned_to || "—"}</td>
              <td class="text-right text-sm">{item.story_points || "—"}</td>
            </tr>
          </tbody>
        </table>
      </div>
    </div>
    """
  end
end

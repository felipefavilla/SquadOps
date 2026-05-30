defmodule SquadOpsWeb.SyncLogsLive do
  use SquadOpsWeb, :live_view

  on_mount {SquadOpsWeb.UserAuth, :require_authenticated_user}

  alias SquadOps.{Squads, SyncLogs}

  @level_colors %{
    "info" => "badge-info",
    "warning" => "badge-warning",
    "error" => "badge-error"
  }

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     assign(socket,
       squads: Squads.list_squads(),
       filters: %{squad_id: nil, level: nil},
       logs: SyncLogs.list_logs(),
       level_colors: @level_colors,
       page_title: "Logs de Sincronização",
       current_path: "/logs"
     )}
  end

  @impl true
  def handle_event("filter", %{"squad_id" => squad_id, "level" => level}, socket) do
    filters = %{squad_id: blank_to_nil(squad_id), level: blank_to_nil(level)}
    {:noreply, assign(socket, filters: filters, logs: load(filters))}
  end

  def handle_event("refresh", _params, socket) do
    {:noreply, assign(socket, logs: load(socket.assigns.filters))}
  end

  def handle_event("clear", _params, socket) do
    SyncLogs.clear_logs()

    {:noreply,
     socket
     |> put_flash(:info, "Logs apagados.")
     |> assign(logs: [])}
  end

  defp load(filters) do
    filters
    |> Map.to_list()
    |> Enum.reject(fn {_, v} -> is_nil(v) end)
    |> SyncLogs.list_logs()
  end

  defp blank_to_nil(""), do: nil
  defp blank_to_nil(v), do: v

  @impl true
  def render(assigns) do
    ~H"""
    <div class="max-w-5xl mx-auto space-y-4">
      <div class="flex items-center justify-between">
        <h1 class="text-2xl font-bold">Logs de Sincronização</h1>
        <div class="flex items-center gap-2">
          <span class="text-sm text-base-content/50">{length(@logs)} registros</span>
          <button phx-click="refresh" class="btn btn-ghost btn-sm">
            <.icon name="hero-arrow-path" class="size-4" /> Atualizar
          </button>
          <button
            phx-click="clear"
            data-confirm="Apagar todos os logs de sincronização?"
            class="btn btn-ghost btn-sm text-error"
          >
            <.icon name="hero-trash" class="size-4" /> Limpar
          </button>
        </div>
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
            <label class="label py-1"><span class="label-text text-xs">Nível</span></label>
            <select name="level" class="select select-bordered select-sm">
              <option value="">Todos</option>
              <option :for={l <- ~w(info warning error)} value={l} selected={@filters.level == l}>
                {l}
              </option>
            </select>
          </div>
        </div>
      </form>

      <div class="card bg-base-100 shadow overflow-hidden">
        <table class="table table-sm">
          <thead>
            <tr>
              <th class="w-40">Quando</th>
              <th class="w-20">Nível</th>
              <th>Mensagem</th>
              <th>Squad</th>
            </tr>
          </thead>
          <tbody>
            <tr :if={@logs == []}>
              <td colspan="4" class="text-center text-base-content/40 py-8">
                Nenhum log encontrado
              </td>
            </tr>
            <tr :for={log <- @logs} class="hover align-top">
              <td class="text-xs text-base-content/60 whitespace-nowrap">
                {format_ts(log.inserted_at)}
              </td>
              <td>
                <span class={"badge badge-xs #{Map.get(@level_colors, log.level, "badge-ghost")}"}>
                  {log.level}
                </span>
              </td>
              <td>
                <div class="font-medium">{log.message}</div>
                <pre
                  :if={log.context not in [nil, %{}]}
                  class="mt-1 text-xs bg-base-200 rounded p-2 whitespace-pre-wrap break-all text-base-content/70"
                >{format_context(log.context)}</pre>
              </td>
              <td class="text-sm text-base-content/70 whitespace-nowrap">
                {(log.squad && log.squad.name) || "—"}
              </td>
            </tr>
          </tbody>
        </table>
      </div>
    </div>
    """
  end

  defp format_ts(%NaiveDateTime{} = ts) do
    Calendar.strftime(ts, "%d/%m/%Y %H:%M:%S")
  end

  defp format_ts(_), do: "—"

  defp format_context(context) when is_map(context) do
    context
    |> Enum.map(fn {k, v} -> "#{k}: #{format_value(v)}" end)
    |> Enum.join("\n")
  end

  defp format_context(_), do: ""

  defp format_value(v) when is_map(v) or is_list(v), do: inspect(v)
  defp format_value(v), do: to_string(v)
end

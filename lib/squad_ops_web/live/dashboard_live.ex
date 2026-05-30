defmodule SquadOpsWeb.DashboardLive do
  use SquadOpsWeb, :live_view

  on_mount {SquadOpsWeb.UserAuth, :require_authenticated_user}

  alias SquadOps.{Auth, Azure, Squads, SyncLogs}
  alias SquadOps.Sync.Scheduler

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket), do: Phoenix.PubSub.subscribe(SquadOps.PubSub, Scheduler.topic())

    {:ok, assign_data(socket)}
  end

  defp assign_data(socket) do
    squads = Squads.list_squads_with_stats()
    conns = Map.new(squads, fn s -> {s.id, connection_for(s)} end)

    assign(socket,
      squads: squads,
      conns: conns,
      azure_mode: Azure.mode(),
      auto_sync: Application.get_env(:squad_ops, :auto_sync, true),
      page_title: "Dashboard",
      current_path: "/"
    )
  end

  @impl true
  def handle_info({:sync_status, _squad_id, _result}, socket) do
    # Um sync terminou em background — recarrega stats e status.
    {:noreply, assign_data(socket)}
  end

  @impl true
  def handle_event("sync_now", _params, socket) do
    Scheduler.sync_now()
    {:noreply, put_flash(socket, :info, "Sincronização disparada.")}
  end

  defp connection_for(squad) do
    token = Auth.get_token_for_squad(squad.id)
    last = SyncLogs.list_logs(squad_id: squad.id, limit: 1) |> List.first()

    %{
      configured: token != nil,
      validated_at: token && token.validated_at,
      last_at: last && last.inserted_at,
      last_level: last && last.level
    }
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="max-w-6xl mx-auto space-y-6">
      <div class="flex items-center justify-between">
        <div>
          <h1 class="text-2xl font-bold">Dashboard</h1>
          <p class="text-base-content/60 text-sm mt-1">{length(@squads)} squads</p>
        </div>
        <div class="flex items-center gap-2">
          <button phx-click="sync_now" class="btn btn-ghost btn-sm">
            <.icon name="hero-arrow-path" class="size-4" /> Sincronizar agora
          </button>
          <a href={~p"/connect"} class="btn btn-primary btn-sm">
            <.icon name="hero-link" class="size-4" /> Conectar Azure
          </a>
        </div>
      </div>

      <%!-- Status de conexão / auto-sync --%>
      <div class="card bg-base-100 shadow">
        <div class="card-body py-3 flex-row items-center gap-4 flex-wrap">
          <div class="flex items-center gap-2">
            <span class="text-sm text-base-content/60">Modo Azure:</span>
            <span class={"badge badge-sm #{if @azure_mode == :real, do: "badge-success", else: "badge-warning"}"}>
              {@azure_mode}
            </span>
          </div>
          <div class="flex items-center gap-2">
            <span class="text-sm text-base-content/60">Auto-sync:</span>
            <span class={"badge badge-sm #{if @auto_sync, do: "badge-success", else: "badge-ghost"}"}>
              {if @auto_sync, do: "ativo (5 min)", else: "desligado"}
            </span>
          </div>
          <span class="text-xs text-base-content/40">
            Atualiza automaticamente quando uma sincronização termina.
          </span>
        </div>
      </div>

      <%= if @squads == [] do %>
        <div class="card bg-base-100 shadow">
          <div class="card-body items-center text-center py-12 gap-3">
            <div class="bg-primary/10 p-4 rounded-full">
              <.icon name="hero-cloud" class="size-10 text-primary" />
            </div>
            <h2 class="card-title">Nenhum squad ainda</h2>
            <p class="text-base-content/60 max-w-md">
              Conecte-se ao seu Azure DevOps para importar projetos como squads e sincronizar sprints, work items e áreas.
            </p>
            <a href={~p"/connect"} class="btn btn-primary mt-2">
              <.icon name="hero-link" class="size-5" /> Conectar Azure DevOps
            </a>
          </div>
        </div>
      <% else %>
        <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
          <.squad_card :for={squad <- @squads} squad={squad} conn={@conns[squad.id]} />
        </div>
      <% end %>
    </div>
    """
  end

  attr :squad, :map, required: true
  attr :conn, :map, required: true

  defp squad_card(assigns) do
    stats = assigns.squad.stats
    total = stats |> Map.values() |> Enum.sum()

    assigns =
      assign(assigns,
        total: total,
        active: Map.get(stats, "active", 0),
        resolved: Map.get(stats, "resolved", 0),
        new_items: Map.get(stats, "new", 0)
      )

    ~H"""
    <a
      href={~p"/squads/#{@squad.id}"}
      class="card bg-base-100 shadow hover:shadow-md transition-shadow cursor-pointer"
    >
      <div class="card-body gap-3">
        <div class="flex items-start justify-between">
          <div class="flex items-center gap-2">
            <div
              class="w-3 h-3 rounded-full flex-shrink-0"
              style={"background-color: #{@squad.color}"}
            >
            </div>
            <h2 class="card-title text-base">{@squad.name}</h2>
          </div>
          <span class="badge badge-ghost badge-sm">{@total} itens</span>
        </div>

        <div class="grid grid-cols-3 gap-2 pt-2 border-t border-base-200">
          <div class="text-center">
            <div class="text-lg font-semibold text-warning">{@new_items}</div>
            <div class="text-xs text-base-content/50">Novo</div>
          </div>
          <div class="text-center">
            <div class="text-lg font-semibold text-info">{@active}</div>
            <div class="text-xs text-base-content/50">Ativo</div>
          </div>
          <div class="text-center">
            <div class="text-lg font-semibold text-success">{@resolved}</div>
            <div class="text-xs text-base-content/50">Resolvido</div>
          </div>
        </div>

        <div class="flex items-center gap-2 text-xs pt-1 border-t border-base-200">
          <span class={"w-2 h-2 rounded-full #{status_dot(@conn)}"}></span>
          <span class="text-base-content/50">{status_text(@conn)}</span>
        </div>
      </div>
    </a>
    """
  end

  defp status_dot(%{configured: false}), do: "bg-base-300"
  defp status_dot(%{last_level: "error"}), do: "bg-error"
  defp status_dot(%{last_level: "warning"}), do: "bg-warning"
  defp status_dot(_), do: "bg-success"

  defp status_text(%{configured: false}), do: "Sem token configurado"
  defp status_text(%{last_at: nil}), do: "Nunca sincronizado"
  defp status_text(%{last_at: at}), do: "Última sync: " <> Calendar.strftime(at, "%d/%m %H:%M")
end

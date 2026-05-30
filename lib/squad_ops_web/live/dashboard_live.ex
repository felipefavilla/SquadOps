defmodule SquadOpsWeb.DashboardLive do
  use SquadOpsWeb, :live_view

  on_mount {SquadOpsWeb.UserAuth, :require_authenticated_user}

  alias SquadOps.Squads

  @impl true
  def mount(_params, _session, socket) do
    squads = Squads.list_squads_with_stats()
    {:ok, assign(socket, squads: squads, page_title: "Dashboard", current_path: "/")}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="max-w-6xl mx-auto space-y-6">
      <div class="flex items-center justify-between">
        <div>
          <h1 class="text-2xl font-bold">Dashboard</h1>
          <p class="text-base-content/60 text-sm mt-1">{length(@squads)} squads ativos</p>
        </div>
        <a :if={@squads != []} href={~p"/connect"} class="btn btn-primary btn-sm">
          <.icon name="hero-link" class="size-4" /> Conectar Azure
        </a>
      </div>

      <%= if @squads == [] do %>
        <div class="card bg-base-100 shadow">
          <div class="card-body items-center text-center py-12 gap-3">
            <div class="bg-primary/10 p-4 rounded-full">
              <.icon name="hero-cloud" class="size-10 text-primary" />
            </div>
            <h2 class="card-title">Nenhum squad ainda</h2>
            <p class="text-base-content/60 max-w-md">
              Conecte-se ao seu Azure DevOps para importar projetos como squads e sincronizar sprints, work items e colunas do board.
            </p>
            <a href={~p"/connect"} class="btn btn-primary mt-2">
              <.icon name="hero-link" class="size-5" /> Conectar Azure DevOps
            </a>
          </div>
        </div>
      <% else %>
        <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
          <.squad_card :for={squad <- @squads} squad={squad} />
        </div>
      <% end %>
    </div>
    """
  end

  defp squad_card(assigns) do
    stats = assigns.squad.stats
    total = stats |> Map.values() |> Enum.sum()
    active = Map.get(stats, "active", 0)
    resolved = Map.get(stats, "resolved", 0)
    new_items = Map.get(stats, "new", 0)

    assigns =
      assign(assigns,
        total: total,
        active: active,
        resolved: resolved,
        new_items: new_items
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

        <p :if={@squad.description} class="text-sm text-base-content/60 line-clamp-2">
          {@squad.description}
        </p>

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

        <div :if={@total > 0} class="w-full h-1.5 bg-base-200 rounded-full overflow-hidden">
          <div
            class="h-full bg-success rounded-full transition-all"
            style={"width: #{round(@resolved / @total * 100)}%"}
          >
          </div>
        </div>
      </div>
    </a>
    """
  end
end

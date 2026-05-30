defmodule SquadOpsWeb.ConnectAzureLive do
  use SquadOpsWeb, :live_view

  on_mount {SquadOpsWeb.UserAuth, :require_authenticated_user}

  alias SquadOps.{Auth, Azure, Squads}
  alias SquadOps.Auth.Token
  alias SquadOps.Azure.Sync

  @palette ~w(#6366f1 #10b981 #f59e0b #ef4444 #8b5cf6 #06b6d4 #ec4899 #14b8a6 #f97316 #84cc16)

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     assign(socket,
       step: :credentials,
       org_url: "",
       pat_token: "",
       projects: [],
       selected: MapSet.new(),
       loading: false,
       error: nil,
       import_results: [],
       page_title: "Conectar Azure DevOps",
       current_path: "/connect"
     )}
  end

  # --- Step 1: validar credenciais e listar projetos ---

  @impl true
  def handle_event(
        "connect",
        %{"org_url" => org_url, "pat_token" => pat_token},
        socket
      ) do
    token = %Token{azure_org_url: String.trim(org_url), pat_token: String.trim(pat_token)}

    case Azure.list_projects(token) do
      {:ok, projects} ->
        {:noreply,
         assign(socket,
           step: :projects,
           org_url: org_url,
           pat_token: pat_token,
           projects: projects,
           selected: MapSet.new(Enum.map(projects, & &1.id)),
           error: nil
         )}

      {:error, :unauthorized} ->
        {:noreply, assign(socket, error: "PAT inválido ou sem permissão de leitura de projetos.")}

      {:error, reason} ->
        {:noreply, assign(socket, error: "Falha ao conectar: #{inspect(reason)}")}
    end
  end

  # --- Step 2: seleção de projetos ---

  def handle_event("toggle_project", %{"id" => id}, socket) do
    selected =
      if MapSet.member?(socket.assigns.selected, id),
        do: MapSet.delete(socket.assigns.selected, id),
        else: MapSet.put(socket.assigns.selected, id)

    {:noreply, assign(socket, selected: selected)}
  end

  def handle_event("select_all", _params, socket) do
    {:noreply, assign(socket, selected: MapSet.new(Enum.map(socket.assigns.projects, & &1.id)))}
  end

  def handle_event("select_none", _params, socket) do
    {:noreply, assign(socket, selected: MapSet.new())}
  end

  def handle_event("back", _params, socket) do
    {:noreply, assign(socket, step: :credentials, error: nil)}
  end

  # --- Step 3: importar e sincronizar ---

  def handle_event("import", _params, socket) do
    if MapSet.size(socket.assigns.selected) == 0 do
      {:noreply, assign(socket, error: "Selecione ao menos um projeto.")}
    else
      send(self(), :run_import)
      {:noreply, assign(socket, loading: true, step: :importing, error: nil)}
    end
  end

  @impl true
  def handle_info(:run_import, socket) do
    %{projects: projects, selected: selected, org_url: org_url, pat_token: pat_token} =
      socket.assigns

    results =
      projects
      |> Enum.filter(&MapSet.member?(selected, &1.id))
      |> Enum.with_index()
      |> Enum.map(fn {project, idx} ->
        import_project(project, idx, org_url, pat_token)
      end)

    {:noreply, assign(socket, loading: false, step: :done, import_results: results)}
  end

  defp import_project(project, idx, org_url, pat_token) do
    color = Enum.at(@palette, rem(idx, length(@palette)))

    squad_attrs = %{
      name: project.name,
      description: project.description,
      color: color,
      azure_project: project.name
    }

    squad =
      case Squads.create_squad(squad_attrs) do
        {:ok, s} -> s
        {:error, _} -> dedup_squad_name(project, squad_attrs)
      end

    if squad do
      {:ok, _} =
        Auth.upsert_token(squad.id, %{
          pat_token: pat_token,
          azure_org_url: org_url
        })

      sync_result = Sync.sync_squad(squad)
      %{name: project.name, squad: squad, sync: sync_result}
    else
      %{name: project.name, squad: nil, sync: {:error, :duplicate}}
    end
  end

  defp dedup_squad_name(project, attrs) do
    new_name = "#{project.name} (Azure #{String.slice(project.id, 0, 6)})"

    case Squads.create_squad(%{attrs | name: new_name}) do
      {:ok, s} -> s
      {:error, _} -> nil
    end
  end

  # --- Render ---

  @impl true
  def render(assigns) do
    ~H"""
    <div class="max-w-3xl mx-auto space-y-6">
      <div class="flex items-center gap-3">
        <a href={~p"/"} class="btn btn-ghost btn-sm">
          <.icon name="hero-arrow-left" class="size-4" /> Dashboard
        </a>
        <h1 class="text-2xl font-bold">Conectar ao Azure DevOps</h1>
      </div>

      <%!-- Stepper --%>
      <ul class="steps steps-horizontal w-full">
        <li class={"step #{if @step in [:credentials, :projects, :importing, :done], do: "step-primary"}"}>
          Credenciais
        </li>
        <li class={"step #{if @step in [:projects, :importing, :done], do: "step-primary"}"}>
          Projetos
        </li>
        <li class={"step #{if @step in [:importing, :done], do: "step-primary"}"}>
          Importar
        </li>
      </ul>

      <div class="alert alert-info alert-soft">
        <.icon name="hero-information-circle" class="size-5" />
        <div>
          Modo atual: <span class="badge badge-sm badge-primary">{Azure.mode()}</span>
          <%= if Azure.mode() == :mock do %>
            — você verá projetos fake. Use <code>AZURE_MODE=real</code> para chamar a API real.
          <% end %>
        </div>
      </div>

      <%!-- Step: credentials --%>
      <div :if={@step == :credentials} class="card bg-base-100 shadow">
        <form phx-submit="connect" class="card-body gap-4">
          <h2 class="card-title text-lg">
            <.icon name="hero-key" class="size-5" /> Credenciais
          </h2>

          <div :if={@error} class="alert alert-error py-2">
            <.icon name="hero-exclamation-circle" class="size-4" />
            <span class="text-sm">{@error}</span>
          </div>

          <div class="form-control gap-1">
            <label class="label py-1">
              <span class="label-text text-sm">Organization URL</span>
            </label>
            <input
              type="url"
              name="org_url"
              value={@org_url}
              placeholder="https://dev.azure.com/sua-org"
              required
              autofocus
              class="input input-bordered input-sm"
            />
          </div>

          <div class="form-control gap-1">
            <label class="label py-1">
              <span class="label-text text-sm">Personal Access Token (PAT)</span>
              <span class="label-text-alt text-xs opacity-60">
                escopo: Project & Work Items (read)
              </span>
            </label>
            <input
              type="password"
              name="pat_token"
              value={@pat_token}
              placeholder="Cole o PAT aqui"
              required
              class="input input-bordered input-sm"
            />
          </div>

          <div class="card-actions justify-end">
            <button type="submit" class="btn btn-primary btn-sm">
              <.icon name="hero-arrow-right" class="size-4" /> Conectar e listar projetos
            </button>
          </div>
        </form>
      </div>

      <%!-- Step: projects --%>
      <div :if={@step == :projects} class="card bg-base-100 shadow">
        <div class="card-body gap-4">
          <div class="flex items-center justify-between">
            <h2 class="card-title text-lg">
              <.icon name="hero-folder-open" class="size-5" />
              Projetos disponíveis ({length(@projects)})
            </h2>
            <div class="flex gap-1">
              <button phx-click="select_all" class="btn btn-ghost btn-xs">Marcar todos</button>
              <button phx-click="select_none" class="btn btn-ghost btn-xs">Limpar</button>
            </div>
          </div>

          <div :if={@error} class="alert alert-error py-2">
            <.icon name="hero-exclamation-circle" class="size-4" /> {@error}
          </div>

          <div class="space-y-2 max-h-96 overflow-y-auto">
            <label
              :for={p <- @projects}
              class="flex items-start gap-3 p-3 rounded-lg hover:bg-base-200 cursor-pointer border border-base-200"
            >
              <input
                type="checkbox"
                class="checkbox checkbox-primary mt-0.5"
                checked={MapSet.member?(@selected, p.id)}
                phx-click="toggle_project"
                phx-value-id={p.id}
              />
              <div class="flex-1 min-w-0">
                <div class="font-medium">{p.name}</div>
                <div :if={p.description} class="text-xs text-base-content/60 line-clamp-2">
                  {p.description}
                </div>
              </div>
              <span :if={p.state} class="badge badge-ghost badge-xs">{p.state}</span>
            </label>
          </div>

          <div class="card-actions justify-between">
            <button phx-click="back" class="btn btn-ghost btn-sm">
              <.icon name="hero-arrow-left" class="size-4" /> Voltar
            </button>
            <button phx-click="import" class="btn btn-primary btn-sm">
              Importar {MapSet.size(@selected)} squad(s) e sincronizar
              <.icon name="hero-cloud-arrow-down" class="size-4" />
            </button>
          </div>
        </div>
      </div>

      <%!-- Step: importing --%>
      <div :if={@step == :importing} class="card bg-base-100 shadow">
        <div class="card-body items-center text-center py-12">
          <span class="loading loading-spinner loading-lg text-primary"></span>
          <p class="mt-4 font-medium">Importando e sincronizando...</p>
          <p class="text-sm text-base-content/60">
            Criando squads, baixando sprints, work items e colunas do board.
          </p>
        </div>
      </div>

      <%!-- Step: done --%>
      <div :if={@step == :done} class="card bg-base-100 shadow">
        <div class="card-body gap-4">
          <h2 class="card-title text-lg">
            <.icon name="hero-check-circle" class="size-5 text-success" /> Importação concluída
          </h2>

          <ul class="divide-y divide-base-200">
            <li :for={r <- @import_results} class="py-3">
              <div class="flex items-start justify-between gap-2">
                <div class="font-medium">{r.name}</div>
                <%= case r.sync do %>
                  <% {:ok, %{sprints: s, work_items: w, columns: c} = res} -> %>
                    <div class="text-xs text-right">
                      <div class="text-success">{s} sprints · {w} items · {c} colunas</div>
                      <div :if={Map.get(res, :work_item_errors, 0) > 0} class="text-warning">
                        {res.work_item_errors} item(s) com erro —
                        <.link navigate={~p"/logs"} class="link">logs</.link>
                      </div>
                    </div>
                  <% {:error, reason} -> %>
                    <div class="text-xs text-error">{inspect(reason)}</div>
                <% end %>
              </div>
            </li>
          </ul>

          <div class="card-actions justify-end">
            <a href={~p"/"} class="btn btn-primary btn-sm">
              Ir para o Dashboard <.icon name="hero-arrow-right" class="size-4" />
            </a>
          </div>
        </div>
      </div>
    </div>
    """
  end
end

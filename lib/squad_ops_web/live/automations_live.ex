defmodule SquadOpsWeb.AutomationsLive do
  use SquadOpsWeb, :live_view

  on_mount {SquadOpsWeb.UserAuth, :require_authenticated_user}

  alias SquadOps.{Auth, Azure, Squads}
  alias SquadOps.Azure.Sync
  alias SquadOps.SyncLogs

  @impl true
  def mount(_params, _session, socket) do
    squads = Squads.list_squads()
    squad = List.first(squads)

    {:ok,
     socket
     |> assign(
       squads: squads,
       type: "story",
       area_path: "",
       iteration_path: "",
       parent_id: "",
       titles_text: "",
       loading: false,
       results: nil,
       page_title: "Automações",
       current_path: "/automations"
     )
     |> select_squad(squad && squad.id)}
  end

  defp select_squad(socket, nil) do
    assign(socket, squad: nil, areas: [], iterations: [], features: [])
  end

  defp select_squad(socket, squad_id) do
    squad = Squads.get_squad!(squad_id)

    features =
      Squads.list_work_items(squad_id, type: "feature")
      |> Enum.filter(& &1.azure_id)

    assign(socket,
      squad: squad,
      areas: Squads.list_areas(squad_id),
      iterations: Squads.list_iterations(squad_id),
      features: features
    )
  end

  @impl true
  def handle_event("change", params, socket) do
    squad_id = parse_int(params["squad_id"])
    current_id = socket.assigns.squad && socket.assigns.squad.id

    socket =
      if squad_id != current_id do
        socket
        |> select_squad(squad_id)
        |> assign(area_path: "", iteration_path: "", parent_id: "")
      else
        socket
      end

    {:noreply,
     assign(socket,
       type: params["type"] || socket.assigns.type,
       area_path: params["area_path"] || socket.assigns.area_path,
       iteration_path: params["iteration_path"] || socket.assigns.iteration_path,
       parent_id: params["parent_id"] || socket.assigns.parent_id,
       titles_text: params["titles"] || socket.assigns.titles_text
     )}
  end

  def handle_event("create", _params, socket) do
    titles = parse_titles(socket.assigns.titles_text)
    squad = socket.assigns.squad
    token = squad && Auth.get_token_for_squad(squad.id)

    cond do
      squad == nil ->
        {:noreply, put_flash(socket, :error, "Selecione um squad.")}

      titles == [] ->
        {:noreply, put_flash(socket, :error, "Adicione ao menos um título.")}

      Azure.mode() == :real and is_nil(token) ->
        {:noreply,
         put_flash(socket, :error, "Configure o token do Azure nas Configurações do squad.")}

      true ->
        send(self(), {:run_create, titles, token})
        {:noreply, assign(socket, loading: true, results: nil)}
    end
  end

  @impl true
  def handle_info({:run_create, titles, token}, socket) do
    %{squad: squad, type: type, area_path: area, iteration_path: iter, parent_id: parent} =
      socket.assigns

    run_id = SyncLogs.new_run_id()
    parent_id = parse_int(parent)

    SyncLogs.info(run_id, squad.id, "Automação iniciada", %{
      count: length(titles),
      type: type,
      area: area,
      iteration: iter
    })

    results =
      Enum.map(titles, fn title ->
        fields = %{
          title: title,
          area_path: blank_to_nil(area),
          iteration_path: blank_to_nil(iter),
          parent_azure_id: parent_id
        }

        case Azure.create_work_item(token, squad.azure_project, type, fields) do
          {:ok, %{azure_id: id}} ->
            SyncLogs.info(run_id, squad.id, "Item criado no Azure", %{azure_id: id, title: title})
            {:ok, title, id}

          {:error, reason} ->
            SyncLogs.warning(run_id, squad.id, "Falha ao criar no Azure", %{
              title: title,
              reason: inspect(reason)
            })

            {:error, title, reason}
        end
      end)

    # Traz os itens recém-criados (com azure_id, relacionamentos) para o banco local.
    Sync.sync_squad(squad)

    created = for {:ok, t, id} <- results, do: {t, id}
    errors = for {:error, t, r} <- results, do: {t, r}

    {:noreply,
     socket
     |> assign(loading: false, results: %{created: created, errors: errors}, titles_text: "")
     |> put_flash(:info, "#{length(created)} item(ns) criado(s) no Azure.")}
  end

  defp parse_titles(text) do
    text
    |> String.split("\n")
    |> Enum.map(&String.trim/1)
    |> Enum.reject(&(&1 == ""))
  end

  defp blank_to_nil(nil), do: nil
  defp blank_to_nil(""), do: nil
  defp blank_to_nil(v), do: v

  defp parse_int(nil), do: nil
  defp parse_int(""), do: nil
  defp parse_int(v) when is_integer(v), do: v

  defp parse_int(v) do
    case Integer.parse(v) do
      {n, _} -> n
      _ -> nil
    end
  end

  defp short(path), do: path |> String.split("\\") |> List.last()

  @impl true
  def render(assigns) do
    assigns = assign(assigns, :preview, parse_titles(assigns.titles_text))

    ~H"""
    <div class="max-w-3xl mx-auto space-y-4">
      <div>
        <h1 class="text-2xl font-bold">Automações</h1>
        <p class="text-sm text-base-content/60">
          Cria várias User Stories / Features de uma vez <strong>no Azure DevOps</strong>,
          numa Área e Iteration escolhidas — útil para quebrar uma US em várias.
        </p>
      </div>

      <div class={[
        "alert alert-soft",
        if(Azure.mode() == :real, do: "alert-info", else: "alert-warning")
      ]}>
        <.icon name="hero-information-circle" class="size-5" />
        <span class="text-sm">
          Modo Azure: <span class="badge badge-sm badge-primary">{Azure.mode()}</span>
          <%= if Azure.mode() == :mock do %>
            — em mock os itens recebem ids fake e nada é enviado ao Azure real.
          <% end %>
        </span>
      </div>

      <form phx-change="change" class="card bg-base-100 shadow">
        <div class="card-body gap-4">
          <div class="grid grid-cols-1 sm:grid-cols-2 gap-3">
            <div class="form-control">
              <label class="label py-1"><span class="label-text text-sm">Squad</span></label>
              <select name="squad_id" class="select select-bordered select-sm">
                <option value="">Selecione...</option>
                <option
                  :for={s <- @squads}
                  value={s.id}
                  selected={@squad && @squad.id == s.id}
                >
                  {s.name}
                </option>
              </select>
            </div>

            <div class="form-control">
              <label class="label py-1"><span class="label-text text-sm">Tipo</span></label>
              <select name="type" class="select select-bordered select-sm">
                <option :for={t <- ~w(story feature task bug)} value={t} selected={@type == t}>
                  {t}
                </option>
              </select>
            </div>

            <div class="form-control">
              <label class="label py-1"><span class="label-text text-sm">Área</span></label>
              <select name="area_path" class="select select-bordered select-sm">
                <option value="">Padrão do projeto</option>
                <option :for={a <- @areas} value={a} selected={@area_path == a}>{short(a)}</option>
              </select>
            </div>

            <div class="form-control">
              <label class="label py-1"><span class="label-text text-sm">Iteration</span></label>
              <select name="iteration_path" class="select select-bordered select-sm">
                <option value="">Padrão do projeto</option>
                <option
                  :for={it <- @iterations}
                  value={it.path || it.name}
                  selected={@iteration_path == (it.path || it.name)}
                >
                  {it.name} ({it.kind})
                </option>
              </select>
            </div>

            <div class="form-control sm:col-span-2">
              <label class="label py-1">
                <span class="label-text text-sm">Feature pai (opcional)</span>
                <span class="label-text-alt text-xs opacity-60">para vincular as US criadas</span>
              </label>
              <select name="parent_id" class="select select-bordered select-sm">
                <option value="">Sem pai</option>
                <option
                  :for={f <- @features}
                  value={f.azure_id}
                  selected={@parent_id == to_string(f.azure_id)}
                >
                  #{f.azure_id} — {f.title}
                </option>
              </select>
            </div>
          </div>

          <div class="form-control">
            <label class="label py-1">
              <span class="label-text text-sm">
                Títulos <span class="opacity-50">(um por linha)</span>
              </span>
            </label>
            <textarea
              name="titles"
              rows="6"
              placeholder="Quebrar checkout em etapas&#10;Validar cupom&#10;Persistir carrinho"
              class="textarea textarea-bordered text-sm font-mono"
            >{@titles_text}</textarea>
          </div>

          <div class="flex items-center justify-between">
            <span class="text-xs text-base-content/50">{length(@preview)} item(ns) a criar</span>
            <button
              type="button"
              phx-click="create"
              class="btn btn-primary btn-sm"
              disabled={@preview == [] or @loading}
            >
              <%= if @loading do %>
                <span class="loading loading-spinner loading-xs"></span> Criando...
              <% else %>
                <.icon name="hero-cloud-arrow-up" class="size-4" /> Criar no Azure
              <% end %>
            </button>
          </div>
        </div>
      </form>

      <div :if={@results} class="card bg-base-100 shadow">
        <div class="card-body gap-2">
          <h3 class="font-semibold text-success">
            ✓ {length(@results.created)} criado(s) no Azure
          </h3>
          <ul class="text-sm space-y-1">
            <li :for={{title, id} <- @results.created} class="text-base-content/70">
              <span class="badge badge-xs badge-ghost">#{id}</span> {title}
            </li>
          </ul>

          <div :if={@results.errors != []} class="mt-2">
            <h4 class="font-semibold text-error text-sm">{length(@results.errors)} falha(s)</h4>
            <ul class="text-xs space-y-1">
              <li :for={{title, reason} <- @results.errors} class="text-error/80">
                {title} — {inspect(reason)}
              </li>
            </ul>
            <.link navigate={~p"/logs"} class="link text-xs">ver logs</.link>
          </div>
        </div>
      </div>
    </div>
    """
  end
end

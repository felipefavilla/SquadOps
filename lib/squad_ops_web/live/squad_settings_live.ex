defmodule SquadOpsWeb.SquadSettingsLive do
  use SquadOpsWeb, :live_view

  on_mount {SquadOpsWeb.UserAuth, :require_authenticated_user}

  alias SquadOps.{Auth, Azure, Squads}
  alias SquadOps.Azure.Sync

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    squad = Squads.get_squad!(id)
    token = Auth.get_token_for_squad(squad.id)

    {:ok,
     assign(socket,
       squad: squad,
       token: token,
       form_values: build_form(squad, token),
       test_result: nil,
       sync_result: nil,
       loading: false,
       page_title: "Configurações — #{squad.name}",
       current_path: "/squads/#{id}/settings"
     )}
  end

  @impl true
  def handle_event("save", %{"settings" => params}, socket) do
    %{squad: squad} = socket.assigns

    with {:ok, _squad} <- Squads.update_squad(squad, %{azure_project: params["azure_project"]}),
         {:ok, token} <-
           Auth.upsert_token(squad.id, %{
             pat_token: params["pat_token"],
             azure_org_url: params["azure_org_url"]
           }) do
      squad = Squads.get_squad!(squad.id)

      {:noreply,
       socket
       |> assign(squad: squad, token: token, form_values: build_form(squad, token))
       |> put_flash(:info, "Configurações salvas.")}
    else
      {:error, changeset} ->
        {:noreply, put_flash(socket, :error, "Erro ao salvar: #{inspect(changeset.errors)}")}
    end
  end

  def handle_event("test", _params, socket) do
    case socket.assigns.token do
      nil ->
        {:noreply, put_flash(socket, :error, "Salve as configurações antes de testar.")}

      token ->
        result = Azure.test_connection(token)
        {:noreply, assign(socket, test_result: result)}
    end
  end

  def handle_event("sync", _params, socket) do
    case socket.assigns.token do
      nil ->
        {:noreply, put_flash(socket, :error, "Salve as configurações antes de sincronizar.")}

      _token ->
        send(self(), :run_sync)
        {:noreply, assign(socket, loading: true, sync_result: nil)}
    end
  end

  @impl true
  def handle_info(:run_sync, socket) do
    result = Sync.sync_squad(socket.assigns.squad)
    {:noreply, assign(socket, loading: false, sync_result: result)}
  end

  defp build_form(squad, token) do
    %{
      "azure_org_url" => (token && token.azure_org_url) || "",
      "pat_token" => "",
      "azure_project" => squad.azure_project || ""
    }
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="max-w-3xl mx-auto space-y-6">
      <div class="flex items-center gap-3">
        <a href={~p"/squads/#{@squad.id}"} class="btn btn-ghost btn-sm">
          <.icon name="hero-arrow-left" class="size-4" /> Voltar
        </a>
        <div class="flex items-center gap-2">
          <div class="w-3 h-3 rounded-full" style={"background-color: #{@squad.color}"}></div>
          <h1 class="text-2xl font-bold">Configurações · {@squad.name}</h1>
        </div>
      </div>

      <div class="alert alert-info alert-soft">
        <.icon name="hero-information-circle" class="size-5" />
        <div>
          <div class="font-semibold">
            Modo atual: <span class="badge badge-sm badge-primary">{Azure.mode()}</span>
          </div>
          <div class="text-xs opacity-70">
            Defina a variável <code>AZURE_MODE=real</code>
            no docker-compose.yml e reinicie para usar a API real.
          </div>
        </div>
      </div>

      <%!-- Form de credenciais --%>
      <form phx-submit="save" class="card bg-base-100 shadow">
        <div class="card-body gap-4">
          <h2 class="card-title text-lg">
            <.icon name="hero-key" class="size-5" /> Credenciais Azure DevOps
          </h2>

          <div class="form-control gap-1">
            <label class="label py-1">
              <span class="label-text text-sm">Organization URL</span>
              <span class="label-text-alt text-xs opacity-60">https://dev.azure.com/sua-org</span>
            </label>
            <input
              type="url"
              name="settings[azure_org_url]"
              value={@form_values["azure_org_url"]}
              placeholder="https://dev.azure.com/minha-empresa"
              class="input input-bordered input-sm"
              required
            />
          </div>

          <div class="form-control gap-1">
            <label class="label py-1">
              <span class="label-text text-sm">Project Name</span>
              <span class="label-text-alt text-xs opacity-60">nome exato do projeto</span>
            </label>
            <input
              type="text"
              name="settings[azure_project]"
              value={@form_values["azure_project"]}
              placeholder="MeuProjeto"
              class="input input-bordered input-sm"
              required
            />
          </div>

          <div class="form-control gap-1">
            <label class="label py-1">
              <span class="label-text text-sm">Personal Access Token (PAT)</span>
              <span class="label-text-alt text-xs opacity-60">
                {if @token, do: "•••••••• (configurado)", else: "obrigatório"}
              </span>
            </label>
            <input
              type="password"
              name="settings[pat_token]"
              placeholder={if @token, do: "Deixe em branco para manter", else: "Cole o token aqui"}
              class="input input-bordered input-sm"
            />
          </div>

          <div class="card-actions justify-end">
            <button type="submit" class="btn btn-primary btn-sm">
              <.icon name="hero-check" class="size-4" /> Salvar
            </button>
          </div>
        </div>
      </form>

      <%!-- Ações --%>
      <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
        <%!-- Testar conexão --%>
        <div class="card bg-base-100 shadow">
          <div class="card-body gap-3">
            <h3 class="font-semibold flex items-center gap-2">
              <.icon name="hero-signal" class="size-5" /> Testar conexão
            </h3>
            <p class="text-sm text-base-content/60">
              Faz uma chamada de leitura ao Azure para validar PAT e URL.
            </p>

            <div :if={@test_result} class="rounded-lg p-3 text-sm">
              <%= case @test_result do %>
                <% {:ok, :real} -> %>
                  <div class="alert alert-success">
                    <.icon name="hero-check-circle" class="size-4" /> Conexão real bem-sucedida.
                  </div>
                <% {:ok, :mock_mode} -> %>
                  <div class="alert alert-warning">
                    <.icon name="hero-exclamation-triangle" class="size-4" />
                    Modo mock — nenhuma chamada real foi feita.
                  </div>
                <% {:error, reason} -> %>
                  <div class="alert alert-error">
                    <.icon name="hero-x-circle" class="size-4" /> Falha: {inspect(reason)}
                  </div>
              <% end %>
            </div>

            <button phx-click="test" class="btn btn-outline btn-sm">
              <.icon name="hero-bolt" class="size-4" /> Testar agora
            </button>
          </div>
        </div>

        <%!-- Sincronizar --%>
        <div class="card bg-base-100 shadow">
          <div class="card-body gap-3">
            <h3 class="font-semibold flex items-center gap-2">
              <.icon name="hero-arrow-path" class="size-5" /> Sincronizar dados
            </h3>
            <p class="text-sm text-base-content/60">
              Puxa sprints e work items do Azure e atualiza o banco local.
            </p>

            <div :if={@sync_result} class="text-sm">
              <%= case @sync_result do %>
                <% {:ok, %{sprints: s, work_items: w, columns: c, mode: m} = res} -> %>
                  <div class={"alert #{if Map.get(res, :work_item_errors, 0) > 0, do: "alert-warning", else: "alert-success"}"}>
                    <.icon name="hero-check-circle" class="size-4" />
                    <div>
                      <div>Sincronizado: {s} sprints, {w} work items, {c} colunas do board.</div>
                      <div :if={Map.get(res, :work_item_errors, 0) > 0} class="text-xs font-semibold">
                        {res.work_item_errors} work item(s) com erro foram pulados — <.link
                          navigate={~p"/logs"}
                          class="link"
                        >ver logs</.link>.
                      </div>
                      <div class="text-xs opacity-70">Modo: {m}</div>
                    </div>
                  </div>
                <% {:error, reason} -> %>
                  <div class="alert alert-error">
                    <.icon name="hero-x-circle" class="size-4" />
                    <div>
                      Falha: {inspect(reason)} — <.link navigate={~p"/logs"} class="link">ver logs</.link>.
                    </div>
                  </div>
              <% end %>
            </div>

            <button phx-click="sync" class="btn btn-primary btn-sm" disabled={@loading}>
              <%= if @loading do %>
                <span class="loading loading-spinner loading-xs"></span> Sincronizando...
              <% else %>
                <.icon name="hero-cloud-arrow-down" class="size-4" /> Sincronizar agora
              <% end %>
            </button>
          </div>
        </div>
      </div>
    </div>
    """
  end
end

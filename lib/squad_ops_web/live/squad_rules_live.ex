defmodule SquadOpsWeb.SquadRulesLive do
  use SquadOpsWeb, :live_view

  on_mount {SquadOpsWeb.UserAuth, :require_authenticated_user}

  alias SquadOps.{Rules, Squads}

  @statuses ~w(new active resolved closed removed)

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    squad = Squads.get_squad!(id)
    rule = Rules.get_or_init(squad.id)

    {:ok,
     assign(socket,
       squad: squad,
       rule: rule,
       tab: "workflow",
       statuses: @statuses,
       page_title: "Regras — #{squad.name}",
       current_path: "/squads/#{id}/rules"
     )}
  end

  @impl true
  def handle_params(params, _uri, socket) do
    tab = params["tab"] || "workflow"
    {:noreply, assign(socket, tab: tab)}
  end

  # --- Workflow ---

  @impl true
  def handle_event("toggle_transition", %{"from" => from, "to" => to}, socket) do
    workflow = socket.assigns.rule.workflow
    transitions = workflow["transitions"] || %{}
    current = transitions[from] || []

    new_list =
      if to in current, do: List.delete(current, to), else: [to | current]

    new_transitions = Map.put(transitions, from, new_list)
    new_workflow = Map.put(workflow, "transitions", new_transitions)

    {:ok, rule} = Rules.update_section(socket.assigns.rule, :workflow, new_workflow)
    {:noreply, assign(socket, rule: Rules.get_or_init(rule.squad_id))}
  end

  def handle_event("update_label", %{"status" => status, "value" => value}, socket) do
    workflow = socket.assigns.rule.workflow
    labels = Map.put(workflow["labels"] || %{}, status, value)
    new_workflow = Map.put(workflow, "labels", labels)

    {:ok, rule} = Rules.update_section(socket.assigns.rule, :workflow, new_workflow)
    {:noreply, assign(socket, rule: Rules.get_or_init(rule.squad_id))}
  end

  # --- Validations ---

  def handle_event("save_validations", %{"v" => params}, socket) do
    validations = %{
      "story_requires_points" => params["story_requires_points"] == "true",
      "bug_requires_assignee" => params["bug_requires_assignee"] == "true",
      "block_invalid_transitions" => params["block_invalid_transitions"] == "true",
      "max_sprint_points" => parse_int(params["max_sprint_points"], 80)
    }

    {:ok, rule} = Rules.update_section(socket.assigns.rule, :validations, validations)

    {:noreply,
     socket
     |> assign(rule: Rules.get_or_init(rule.squad_id))
     |> put_flash(:info, "Validações salvas.")}
  end

  # --- Field Mapping ---

  def handle_event("save_mapping", %{"m" => params}, socket) do
    field_mapping = %{
      "type" => params["type"] || %{},
      "status" => params["status"] || %{}
    }

    {:ok, rule} = Rules.update_section(socket.assigns.rule, :field_mapping, field_mapping)

    {:noreply,
     socket
     |> assign(rule: Rules.get_or_init(rule.squad_id))
     |> put_flash(:info, "Mapeamento salvo.")}
  end

  # --- Sync Policy ---

  def handle_event("save_sync", %{"s" => params}, socket) do
    sync_policy = %{
      "mode" => params["mode"] || "manual",
      "frequency_minutes" => parse_int(params["frequency_minutes"], 60),
      "scope" => params["scope"] || "active_and_future",
      "conflict_resolution" => params["conflict_resolution"] || "azure_wins"
    }

    {:ok, rule} = Rules.update_section(socket.assigns.rule, :sync_policy, sync_policy)

    {:noreply,
     socket
     |> assign(rule: Rules.get_or_init(rule.squad_id))
     |> put_flash(:info, "Política salva.")}
  end

  def handle_event("reset", %{"section" => section}, socket) do
    section_atom = String.to_existing_atom(section)
    {:ok, rule} = Rules.reset_section(socket.assigns.rule, section_atom)

    {:noreply,
     socket
     |> assign(rule: Rules.get_or_init(rule.squad_id))
     |> put_flash(:info, "Seção restaurada para os padrões.")}
  end

  defp parse_int(nil, default), do: default
  defp parse_int("", default), do: default

  defp parse_int(str, default) when is_binary(str) do
    case Integer.parse(str) do
      {n, _} -> n
      _ -> default
    end
  end

  defp parse_int(n, _default) when is_integer(n), do: n

  @impl true
  def render(assigns) do
    ~H"""
    <div class="max-w-4xl mx-auto space-y-4">
      <div class="flex items-center gap-3">
        <a href={~p"/squads/#{@squad.id}"} class="btn btn-ghost btn-sm">
          <.icon name="hero-arrow-left" class="size-4" /> Voltar
        </a>
        <div class="flex items-center gap-2">
          <div class="w-3 h-3 rounded-full" style={"background-color: #{@squad.color}"}></div>
          <h1 class="text-2xl font-bold">Regras de Negócio · {@squad.name}</h1>
        </div>
      </div>

      <%!-- Tabs --%>
      <div role="tablist" class="tabs tabs-boxed bg-base-100 shadow">
        <.tab
          id="workflow"
          current={@tab}
          squad_id={@squad.id}
          icon="hero-arrows-right-left"
          label="Workflow"
        />
        <.tab
          id="validations"
          current={@tab}
          squad_id={@squad.id}
          icon="hero-shield-check"
          label="Validações"
        />
        <.tab
          id="mapping"
          current={@tab}
          squad_id={@squad.id}
          icon="hero-arrows-up-down"
          label="Mapeamento"
        />
        <.tab
          id="sync"
          current={@tab}
          squad_id={@squad.id}
          icon="hero-cloud-arrow-down"
          label="Sincronização"
        />
      </div>

      <%!-- Conteúdo da aba --%>
      <div class="card bg-base-100 shadow">
        <div class="card-body">
          <%= case @tab do %>
            <% "workflow" -> %>
              <.workflow_tab rule={@rule} statuses={@statuses} />
            <% "validations" -> %>
              <.validations_tab rule={@rule} />
            <% "mapping" -> %>
              <.mapping_tab rule={@rule} />
            <% "sync" -> %>
              <.sync_tab rule={@rule} />
          <% end %>
        </div>
      </div>
    </div>
    """
  end

  attr :id, :string, required: true
  attr :current, :string, required: true
  attr :squad_id, :integer, required: true
  attr :icon, :string, required: true
  attr :label, :string, required: true

  defp tab(assigns) do
    ~H"""
    <a
      role="tab"
      href={~p"/squads/#{@squad_id}/rules?tab=#{@id}"}
      class={["tab gap-2", @current == @id && "tab-active"]}
    >
      <.icon name={@icon} class="size-4" />
      {@label}
    </a>
    """
  end

  # --- Aba: Workflow ---

  defp workflow_tab(assigns) do
    ~H"""
    <div class="space-y-6">
      <div class="flex items-start justify-between">
        <div>
          <h2 class="text-lg font-semibold">Transições permitidas</h2>
          <p class="text-sm text-base-content/60">
            Marque para qual status um item PODE ser movido a partir de cada origem.
          </p>
        </div>
        <button phx-click="reset" phx-value-section="workflow" class="btn btn-ghost btn-xs">
          <.icon name="hero-arrow-uturn-left" class="size-3" /> Restaurar padrões
        </button>
      </div>

      <div class="overflow-x-auto">
        <table class="table table-sm">
          <thead>
            <tr>
              <th>De \\ Para</th>
              <th :for={s <- @statuses} class="text-center">{label_for(@rule, s)}</th>
            </tr>
          </thead>
          <tbody>
            <tr :for={from <- @statuses}>
              <td class="font-medium">{label_for(@rule, from)}</td>
              <td :for={to <- @statuses} class="text-center">
                <%= if from == to do %>
                  <span class="text-base-content/20">—</span>
                <% else %>
                  <input
                    type="checkbox"
                    class="checkbox checkbox-sm checkbox-primary"
                    checked={transition_allowed?(@rule, from, to)}
                    phx-click="toggle_transition"
                    phx-value-from={from}
                    phx-value-to={to}
                  />
                <% end %>
              </td>
            </tr>
          </tbody>
        </table>
      </div>

      <div class="divider"></div>

      <div>
        <h2 class="text-lg font-semibold mb-3">Labels personalizados</h2>
        <div class="grid grid-cols-1 sm:grid-cols-2 gap-3">
          <div :for={s <- @statuses} class="form-control">
            <label class="label py-1">
              <span class="label-text text-sm font-mono">{s}</span>
            </label>
            <input
              type="text"
              value={label_for(@rule, s)}
              phx-blur="update_label"
              phx-value-status={s}
              class="input input-bordered input-sm"
            />
          </div>
        </div>
      </div>
    </div>
    """
  end

  defp label_for(rule, status) do
    get_in(rule.workflow, ["labels", status]) || status
  end

  defp transition_allowed?(rule, from, to) do
    list = get_in(rule.workflow, ["transitions", from]) || []
    to in list
  end

  # --- Aba: Validações ---

  defp validations_tab(assigns) do
    ~H"""
    <form phx-submit="save_validations" class="space-y-4">
      <div class="flex items-start justify-between">
        <div>
          <h2 class="text-lg font-semibold">Validações automáticas</h2>
          <p class="text-sm text-base-content/60">
            Regras aplicadas antes de criar ou atualizar work items.
          </p>
        </div>
        <button
          type="button"
          phx-click="reset"
          phx-value-section="validations"
          class="btn btn-ghost btn-xs"
        >
          <.icon name="hero-arrow-uturn-left" class="size-3" /> Restaurar
        </button>
      </div>

      <div class="space-y-3">
        <label class="cursor-pointer flex items-start gap-3 p-3 rounded-lg hover:bg-base-200">
          <input type="hidden" name="v[story_requires_points]" value="false" />
          <input
            type="checkbox"
            name="v[story_requires_points]"
            value="true"
            checked={@rule.validations["story_requires_points"]}
            class="checkbox checkbox-primary mt-0.5"
          />
          <div>
            <div class="font-medium">Story exige Story Points</div>
            <div class="text-xs text-base-content/60">
              Bloqueia mover Stories sem story_points para o status "active".
            </div>
          </div>
        </label>

        <label class="cursor-pointer flex items-start gap-3 p-3 rounded-lg hover:bg-base-200">
          <input type="hidden" name="v[bug_requires_assignee]" value="false" />
          <input
            type="checkbox"
            name="v[bug_requires_assignee]"
            value="true"
            checked={@rule.validations["bug_requires_assignee"]}
            class="checkbox checkbox-primary mt-0.5"
          />
          <div>
            <div class="font-medium">Bug exige Responsável</div>
            <div class="text-xs text-base-content/60">
              Bugs sem assigned_to são mantidos em "new".
            </div>
          </div>
        </label>

        <label class="cursor-pointer flex items-start gap-3 p-3 rounded-lg hover:bg-base-200">
          <input type="hidden" name="v[block_invalid_transitions]" value="false" />
          <input
            type="checkbox"
            name="v[block_invalid_transitions]"
            value="true"
            checked={@rule.validations["block_invalid_transitions"]}
            class="checkbox checkbox-primary mt-0.5"
          />
          <div>
            <div class="font-medium">Bloquear transições não permitidas</div>
            <div class="text-xs text-base-content/60">
              Usa a tabela de Workflow para impedir mudanças de status inválidas.
            </div>
          </div>
        </label>

        <div class="form-control p-3">
          <label class="label py-1">
            <span class="label-text font-medium">Capacidade máxima de Sprint (pontos)</span>
          </label>
          <input
            type="number"
            name="v[max_sprint_points]"
            value={@rule.validations["max_sprint_points"]}
            min="0"
            class="input input-bordered input-sm w-32"
          />
          <div class="text-xs text-base-content/60 mt-1">
            Alerta quando a soma de story_points em um sprint ultrapassa este valor.
          </div>
        </div>
      </div>

      <div class="card-actions justify-end">
        <button type="submit" class="btn btn-primary btn-sm">
          <.icon name="hero-check" class="size-4" /> Salvar
        </button>
      </div>
    </form>
    """
  end

  # --- Aba: Mapeamento ---

  defp mapping_tab(assigns) do
    type_map = assigns.rule.field_mapping["type"] || %{}
    status_map = assigns.rule.field_mapping["status"] || %{}
    assigns = assign(assigns, type_map: type_map, status_map: status_map)

    ~H"""
    <form phx-submit="save_mapping" class="space-y-6">
      <div class="flex items-start justify-between">
        <div>
          <h2 class="text-lg font-semibold">Mapeamento Azure ↔ Local</h2>
          <p class="text-sm text-base-content/60">
            Como os valores recebidos do Azure DevOps são traduzidos para o domínio local.
          </p>
        </div>
        <button
          type="button"
          phx-click="reset"
          phx-value-section="field_mapping"
          class="btn btn-ghost btn-xs"
        >
          <.icon name="hero-arrow-uturn-left" class="size-3" /> Restaurar
        </button>
      </div>

      <div>
        <h3 class="font-semibold mb-2">Tipos de Work Item</h3>
        <div class="space-y-2">
          <div :for={{azure, local} <- @type_map} class="flex items-center gap-2">
            <div class="badge badge-ghost min-w-32 justify-start">{azure}</div>
            <.icon name="hero-arrow-right" class="size-4 opacity-50" />
            <input
              type="text"
              name={"m[type][#{azure}]"}
              value={local}
              class="input input-bordered input-sm flex-1 max-w-48"
            />
          </div>
        </div>
      </div>

      <div>
        <h3 class="font-semibold mb-2">Status</h3>
        <div class="space-y-2">
          <div :for={{azure, local} <- @status_map} class="flex items-center gap-2">
            <div class="badge badge-ghost min-w-32 justify-start">{azure}</div>
            <.icon name="hero-arrow-right" class="size-4 opacity-50" />
            <input
              type="text"
              name={"m[status][#{azure}]"}
              value={local}
              class="input input-bordered input-sm flex-1 max-w-48"
            />
          </div>
        </div>
      </div>

      <div class="card-actions justify-end">
        <button type="submit" class="btn btn-primary btn-sm">
          <.icon name="hero-check" class="size-4" /> Salvar
        </button>
      </div>
    </form>
    """
  end

  # --- Aba: Sincronização ---

  defp sync_tab(assigns) do
    ~H"""
    <form phx-submit="save_sync" class="space-y-5">
      <div class="flex items-start justify-between">
        <div>
          <h2 class="text-lg font-semibold">Política de Sincronização</h2>
          <p class="text-sm text-base-content/60">
            Quando e como puxar dados do Azure DevOps.
          </p>
        </div>
        <button
          type="button"
          phx-click="reset"
          phx-value-section="sync_policy"
          class="btn btn-ghost btn-xs"
        >
          <.icon name="hero-arrow-uturn-left" class="size-3" /> Restaurar
        </button>
      </div>

      <div class="form-control gap-1">
        <label class="label py-1"><span class="label-text font-medium">Modo</span></label>
        <select name="s[mode]" class="select select-bordered select-sm w-full max-w-xs">
          <option value="manual" selected={@rule.sync_policy["mode"] == "manual"}>Manual</option>
          <option value="periodic" selected={@rule.sync_policy["mode"] == "periodic"}>
            Periódico
          </option>
        </select>
      </div>

      <div class="form-control gap-1">
        <label class="label py-1">
          <span class="label-text font-medium">Intervalo (minutos)</span>
        </label>
        <input
          type="number"
          name="s[frequency_minutes]"
          value={@rule.sync_policy["frequency_minutes"]}
          min="5"
          class="input input-bordered input-sm w-32"
        />
        <div class="text-xs text-base-content/60">Usado apenas se modo = Periódico.</div>
      </div>

      <div class="form-control gap-1">
        <label class="label py-1"><span class="label-text font-medium">Escopo</span></label>
        <select name="s[scope]" class="select select-bordered select-sm w-full max-w-xs">
          <option
            value="active_and_future"
            selected={@rule.sync_policy["scope"] == "active_and_future"}
          >
            Apenas sprints ativos e futuros
          </option>
          <option value="all" selected={@rule.sync_policy["scope"] == "all"}>
            Todos os work items
          </option>
        </select>
      </div>

      <div class="form-control gap-1">
        <label class="label py-1">
          <span class="label-text font-medium">Resolução de conflitos</span>
        </label>
        <select name="s[conflict_resolution]" class="select select-bordered select-sm w-full max-w-xs">
          <option
            value="azure_wins"
            selected={@rule.sync_policy["conflict_resolution"] == "azure_wins"}
          >
            Azure vence (sobrescreve local)
          </option>
          <option
            value="local_wins"
            selected={@rule.sync_policy["conflict_resolution"] == "local_wins"}
          >
            Local vence (mantém alterações locais)
          </option>
          <option value="manual" selected={@rule.sync_policy["conflict_resolution"] == "manual"}>
            Manual (gera lista de conflitos)
          </option>
        </select>
      </div>

      <div class="card-actions justify-end">
        <button type="submit" class="btn btn-primary btn-sm">
          <.icon name="hero-check" class="size-4" /> Salvar
        </button>
      </div>
    </form>
    """
  end
end

defmodule SquadOpsWeb.BulkCreateLive do
  use SquadOpsWeb, :live_view

  on_mount {SquadOpsWeb.UserAuth, :require_authenticated_user}

  alias SquadOps.Squads

  @impl true
  def mount(_params, _session, socket) do
    squads = Squads.list_squads()
    first_squad = List.first(squads)

    sprints = if first_squad, do: Squads.list_sprints(first_squad.id), else: []

    {:ok,
     assign(socket,
       squads: squads,
       sprints: sprints,
       selected_squad_id: first_squad && to_string(first_squad.id),
       selected_sprint_id: "",
       selected_type: "story",
       titles_text: "",
       preview: [],
       created: [],
       errors: [],
       page_title: "Criar em Massa",
       current_path: "/bulk-create"
     )}
  end

  @impl true
  def handle_event("squad-changed", %{"squad_id" => squad_id}, socket) do
    sprints =
      case Integer.parse(squad_id) do
        {id, ""} -> Squads.list_sprints(id)
        _ -> []
      end

    {:noreply,
     assign(socket,
       selected_squad_id: squad_id,
       sprints: sprints,
       selected_sprint_id: "",
       preview: []
     )}
  end

  def handle_event(
        "preview",
        %{"titles" => text, "type" => type, "sprint_id" => sprint_id},
        socket
      ) do
    preview =
      text
      |> String.split("\n")
      |> Enum.map(&String.trim/1)
      |> Enum.reject(&(&1 == ""))

    {:noreply,
     assign(socket,
       titles_text: text,
       preview: preview,
       selected_type: type,
       selected_sprint_id: sprint_id
     )}
  end

  def handle_event("create", _params, socket) do
    %{
      selected_squad_id: squad_id_str,
      selected_sprint_id: sprint_id_str,
      selected_type: type,
      preview: titles
    } = socket.assigns

    with {squad_id, ""} <- Integer.parse(squad_id_str || ""),
         true <- titles != [] do
      sprint_id =
        case Integer.parse(sprint_id_str || "") do
          {id, ""} -> id
          _ -> nil
        end

      {created, errors} =
        Enum.reduce(titles, {[], []}, fn title, {ok, err} ->
          attrs = %{
            title: title,
            type: type,
            status: "new",
            squad_id: squad_id,
            sprint_id: sprint_id
          }

          case Squads.create_work_item(attrs) do
            {:ok, item} -> {[item | ok], err}
            {:error, changeset} -> {ok, [{title, changeset} | err]}
          end
        end)

      socket =
        socket
        |> assign(
          created: Enum.reverse(created),
          errors: Enum.reverse(errors),
          preview: [],
          titles_text: ""
        )
        |> put_flash(:info, "#{length(created)} iten(s) criado(s).")

      {:noreply, socket}
    else
      _ ->
        {:noreply,
         put_flash(socket, :error, "Selecione um squad e adicione pelo menos um título.")}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="max-w-2xl mx-auto space-y-4">
      <h1 class="text-2xl font-bold">Criar Work Items em Massa</h1>

      <div class="card bg-base-100 shadow">
        <div class="card-body gap-4">
          <div class="grid grid-cols-1 sm:grid-cols-3 gap-3">
            <div class="form-control">
              <label class="label py-1"><span class="label-text text-sm">Squad</span></label>
              <select
                name="squad_id"
                class="select select-bordered select-sm"
                phx-change="squad-changed"
              >
                <option value="">Selecione...</option>
                <option
                  :for={s <- @squads}
                  value={s.id}
                  selected={@selected_squad_id == to_string(s.id)}
                >
                  {s.name}
                </option>
              </select>
            </div>

            <div class="form-control">
              <label class="label py-1"><span class="label-text text-sm">Sprint</span></label>
              <select
                name="sprint_id"
                class="select select-bordered select-sm"
                phx-change="preview"
                phx-value-titles={@titles_text}
                phx-value-type={@selected_type}
              >
                <option value="">Sem sprint</option>
                <option
                  :for={s <- @sprints}
                  value={s.id}
                  selected={@selected_sprint_id == to_string(s.id)}
                >
                  {s.name} ({s.status})
                </option>
              </select>
            </div>

            <div class="form-control">
              <label class="label py-1"><span class="label-text text-sm">Tipo</span></label>
              <select
                name="type"
                class="select select-bordered select-sm"
                phx-change="preview"
                phx-value-titles={@titles_text}
                phx-value-sprint_id={@selected_sprint_id}
              >
                <option
                  :for={t <- ~w(story feature task bug)}
                  value={t}
                  selected={@selected_type == t}
                >
                  {t}
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
              placeholder="Corrigir bug de login\nAdicionar filtro de datas\nRefatorar módulo de relatórios"
              class="textarea textarea-bordered text-sm font-mono"
              phx-change="preview"
              phx-value-type={@selected_type}
              phx-value-sprint_id={@selected_sprint_id}
            >{@titles_text}</textarea>
          </div>

          <div :if={@preview != []} class="bg-base-200 rounded-lg p-3 space-y-1">
            <p class="text-xs font-medium text-base-content/60 mb-2">
              Preview — {length(@preview)} iten(s)
            </p>
            <div :for={title <- @preview} class="flex items-center gap-2 text-sm">
              <span class="text-success">+</span> {title}
            </div>
          </div>

          <div class="card-actions justify-end">
            <button
              phx-click="create"
              class="btn btn-primary btn-sm"
              disabled={@preview == []}
            >
              Criar {length(@preview)} iten(s)
            </button>
          </div>
        </div>
      </div>

      <div :if={@created != []} class="card bg-base-100 shadow">
        <div class="card-body">
          <h3 class="font-semibold text-success">✓ {length(@created)} iten(s) criado(s)</h3>
          <ul class="text-sm space-y-1 mt-2">
            <li :for={item <- @created} class="text-base-content/70">#{item.id} — {item.title}</li>
          </ul>
        </div>
      </div>
    </div>
    """
  end
end

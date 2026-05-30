defmodule SquadOpsWeb.KpisLive do
  use SquadOpsWeb, :live_view

  on_mount {SquadOpsWeb.UserAuth, :require_authenticated_user}

  alias SquadOps.{Kpis, Squads}

  @impl true
  def mount(_params, _session, socket) do
    squads = Squads.list_squads()
    squad = List.first(squads)

    socket =
      socket
      |> assign(
        squads: squads,
        page_title: "KPIs",
        current_path: "/kpis"
      )
      |> load(squad && squad.id, nil)

    {:ok, socket}
  end

  @impl true
  def handle_event("filter", %{"squad_id" => squad_id, "sprint_id" => sprint_id}, socket) do
    {:noreply, load(socket, parse_int(squad_id), parse_int(sprint_id))}
  end

  defp load(socket, nil, _sprint_id) do
    assign(socket,
      squad_id: nil,
      sprint_id: nil,
      metrics: [],
      sprints: [],
      burndown: %{labels: [], remaining: [], ideal: [], has_data: false}
    )
  end

  defp load(socket, squad_id, sprint_id) do
    metrics = Kpis.sprint_metrics(squad_id)
    sprints = Enum.map(metrics, & &1.sprint)

    sprint_id = sprint_id || default_sprint_id(sprints)
    burndown = if sprint_id, do: Kpis.burndown(sprint_id), else: empty_burndown()

    assign(socket,
      squad_id: squad_id,
      sprint_id: sprint_id,
      metrics: metrics,
      sprints: sprints,
      burndown: burndown
    )
  end

  defp default_sprint_id(sprints) do
    active = Enum.find(sprints, &(&1.status == "active"))
    (active || List.first(sprints)) |> then(&(&1 && &1.id))
  end

  defp empty_burndown, do: %{labels: [], remaining: [], ideal: [], has_data: false}

  defp parse_int(nil), do: nil
  defp parse_int(""), do: nil
  defp parse_int(v) when is_integer(v), do: v

  defp parse_int(v) do
    case Integer.parse(v) do
      {n, _} -> n
      _ -> nil
    end
  end

  # --- Chart configs ---

  defp burndown_data(b) do
    %{
      labels: b.labels,
      datasets: [
        %{
          label: "Restante (real)",
          data: b.remaining,
          borderColor: "#6366f1",
          backgroundColor: "rgba(99,102,241,.15)",
          tension: 0.25,
          fill: true
        },
        %{
          label: "Ideal",
          data: b.ideal,
          borderColor: "#9ca3af",
          borderDash: [6, 4],
          pointRadius: 0,
          fill: false
        }
      ]
    }
  end

  defp efficiency_data(metrics) do
    %{
      labels: Enum.map(metrics, & &1.sprint.name),
      datasets: [
        %{
          label: "Eficiência (%)",
          data: Enum.map(metrics, &Float.round(&1.efficiency * 100, 1)),
          backgroundColor: "#10b981"
        }
      ]
    }
  end

  defp points_data(metrics) do
    %{
      labels: Enum.map(metrics, & &1.sprint.name),
      datasets: [
        %{
          label: "Itens",
          data: Enum.map(metrics, & &1.items),
          backgroundColor: "#6366f1"
        },
        %{
          label: "Pontos",
          data: Enum.map(metrics, &round_pts(&1.points)),
          backgroundColor: "#f59e0b"
        }
      ]
    }
  end

  defp base_options(title) do
    %{
      responsive: true,
      maintainAspectRatio: false,
      plugins: %{legend: %{position: "bottom"}, title: %{display: true, text: title}}
    }
  end

  defp round_pts(n) when is_float(n), do: Float.round(n, 1)
  defp round_pts(n), do: n

  defp pct(f), do: "#{Float.round(f * 100, 1)}%"
  defp r1(f) when is_float(f), do: Float.round(f, 1)
  defp r1(n), do: n

  @impl true
  def render(assigns) do
    ~H"""
    <div class="max-w-6xl mx-auto space-y-5">
      <h1 class="text-2xl font-bold">KPIs & Eficiência</h1>

      <form phx-change="filter" class="card bg-base-100 shadow p-4">
        <div class="flex flex-wrap gap-3">
          <div class="form-control flex-1 min-w-44">
            <label class="label py-1"><span class="label-text text-xs">Squad</span></label>
            <select name="squad_id" class="select select-bordered select-sm">
              <option value="">Selecione...</option>
              <option :for={s <- @squads} value={s.id} selected={@squad_id == s.id}>{s.name}</option>
            </select>
          </div>
          <div class="form-control flex-1 min-w-44">
            <label class="label py-1">
              <span class="label-text text-xs">Sprint (burndown)</span>
            </label>
            <select name="sprint_id" class="select select-bordered select-sm">
              <option value="">—</option>
              <option :for={s <- @sprints} value={s.id} selected={@sprint_id == s.id}>
                {s.name}
              </option>
            </select>
          </div>
        </div>
      </form>

      <div :if={@squad_id == nil} class="card bg-base-100 shadow">
        <div class="card-body items-center text-center py-10 text-base-content/50">
          Selecione um squad para ver os indicadores.
        </div>
      </div>

      <div :if={@squad_id != nil} class="space-y-5">
        <%!-- Burndown --%>
        <div class="card bg-base-100 shadow">
          <div class="card-body gap-2">
            <h2 class="card-title text-base">
              <.icon name="hero-chart-bar-square" class="size-5" /> Burndown do Sprint
            </h2>
            <%= if @burndown.has_data do %>
              <.chart
                id="chart-burndown"
                type="line"
                data={burndown_data(@burndown)}
                options={base_options("Pontos restantes ao longo do sprint")}
              />
            <% else %>
              <p class="text-sm text-base-content/50 py-8 text-center">
                Sem snapshots ainda. O burndown é montado a partir de um snapshot por sync —
                rode algumas sincronizações ao longo do sprint para acumular a série.
              </p>
            <% end %>
          </div>
        </div>

        <div class="grid grid-cols-1 lg:grid-cols-2 gap-5">
          <div class="card bg-base-100 shadow">
            <div class="card-body gap-2">
              <h2 class="card-title text-base">
                <.icon name="hero-bolt" class="size-5" /> Eficiência por Sprint
              </h2>
              <.chart
                :if={@metrics != []}
                id="chart-efficiency"
                type="bar"
                data={efficiency_data(@metrics)}
                options={base_options("US concluídas / planejadas")}
              />
              <p :if={@metrics == []} class="text-sm text-base-content/50 py-8 text-center">
                Sem sprints com dados.
              </p>
            </div>
          </div>

          <div class="card bg-base-100 shadow">
            <div class="card-body gap-2">
              <h2 class="card-title text-base">
                <.icon name="hero-chart-bar" class="size-5" /> Itens e Pontos por Sprint
              </h2>
              <.chart
                :if={@metrics != []}
                id="chart-points"
                type="bar"
                data={points_data(@metrics)}
                options={base_options("Volume por sprint")}
              />
              <p :if={@metrics == []} class="text-sm text-base-content/50 py-8 text-center">
                Sem sprints com dados.
              </p>
            </div>
          </div>
        </div>

        <%!-- Tabela detalhada --%>
        <div class="card bg-base-100 shadow overflow-hidden">
          <div class="card-body gap-2">
            <h2 class="card-title text-base">
              <.icon name="hero-table-cells" class="size-5" /> Detalhe por Sprint
            </h2>
            <table class="table table-sm">
              <thead>
                <tr>
                  <th>Sprint</th>
                  <th class="text-right">Itens</th>
                  <th class="text-right">Pts</th>
                  <th class="text-right">Média</th>
                  <th class="text-right">Mediana</th>
                  <th class="text-right">Desvio</th>
                  <th class="text-right">US (concl/plan)</th>
                  <th class="text-right">Eficiência</th>
                </tr>
              </thead>
              <tbody>
                <tr :if={@metrics == []}>
                  <td colspan="8" class="text-center text-base-content/40 py-6">Sem dados</td>
                </tr>
                <tr :for={m <- @metrics} class="hover">
                  <td class="text-sm">
                    {m.sprint.name}
                    <span class="badge badge-xs badge-ghost ml-1">{m.sprint.status}</span>
                  </td>
                  <td class="text-right">{m.items}</td>
                  <td class="text-right">{round_pts(m.points)}</td>
                  <td class="text-right">{r1(m.mean)}</td>
                  <td class="text-right">{r1(m.median)}</td>
                  <td class="text-right">{r1(m.stddev)}</td>
                  <td class="text-right">{m.completed_us}/{m.planned_us}</td>
                  <td class="text-right font-medium">{pct(m.efficiency)}</td>
                </tr>
              </tbody>
            </table>
          </div>
        </div>
      </div>
    </div>
    """
  end
end

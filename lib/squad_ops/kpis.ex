defmodule SquadOps.Kpis do
  @moduledoc """
  Indicadores de gestão a partir dos work items e dos snapshots de sprint.

  - Quantidade de itens/pontos por sprint (2.2.1)
  - Média/mediana/desvio de story points por sprint na linha do tempo (2.2.2)
  - Eficiência = US concluídas / US planejadas por iteration (2.2.3)
  - Burndown por sprint a partir de `sprint_snapshots` (2.2.4)

  Os estados que contam como "concluído" e o tipo tratado como User Story são
  parametrizáveis em `Rules.kpis` (seção de Regras de Negócio).
  """

  import Ecto.Query

  alias SquadOps.{Repo, Rules}
  alias SquadOps.Squads.{Sprint, SprintSnapshot, WorkItem}

  # --- Captura de snapshot (chamada pelo Sync ao final de um sync OK) ---

  @doc "Grava/atualiza o snapshot de hoje para cada sprint timeboxed ativo do squad."
  def capture_snapshots(squad_id) do
    %{completed_states: completed, story_type: story_type} = config(squad_id)

    active =
      Repo.all(
        from s in Sprint,
          where: s.squad_id == ^squad_id and s.kind == "sprint" and s.status == "active"
      )

    Enum.each(active, &upsert_snapshot(squad_id, &1, completed, story_type))
    {:ok, length(active)}
  end

  defp upsert_snapshot(squad_id, sprint, completed, story_type) do
    items = Repo.all(from w in WorkItem, where: w.sprint_id == ^sprint.id)
    total = sum_points(items)
    done_pts = items |> Enum.filter(&(&1.status in completed)) |> sum_points()
    stories = Enum.filter(items, &(&1.type == story_type))

    attrs = %{
      squad_id: squad_id,
      sprint_id: sprint.id,
      captured_on: Date.utc_today(),
      total_points: total,
      completed_points: done_pts,
      remaining_points: max(total - done_pts, 0.0),
      planned_us: length(stories),
      completed_us: Enum.count(stories, &(&1.status in completed)),
      counts_by_state: Enum.frequencies_by(items, & &1.status)
    }

    case Repo.get_by(SprintSnapshot, sprint_id: sprint.id, captured_on: attrs.captured_on) do
      nil -> %SprintSnapshot{}
      existing -> existing
    end
    |> SprintSnapshot.changeset(attrs)
    |> Repo.insert_or_update()
  end

  # --- Métricas por sprint (tabela + barras) ---

  @doc """
  Métricas por sprint timeboxed do squad, ordenadas por data de início.
  Retorna mapas com itens, pontos, média/mediana/desvio de story points e
  eficiência (US concluídas / US planejadas).
  """
  def sprint_metrics(squad_id) do
    %{completed_states: completed, story_type: story_type} = config(squad_id)

    sprints =
      Repo.all(
        from s in Sprint,
          where: s.squad_id == ^squad_id and s.kind == "sprint",
          order_by: [asc_nulls_last: s.start_date, asc: s.name]
      )

    items_by_sprint =
      Repo.all(from w in WorkItem, where: w.squad_id == ^squad_id and not is_nil(w.sprint_id))
      |> Enum.group_by(& &1.sprint_id)

    Enum.map(sprints, fn sprint ->
      items = Map.get(items_by_sprint, sprint.id, [])
      points = items |> Enum.map(& &1.story_points) |> Enum.reject(&is_nil/1)
      stories = Enum.filter(items, &(&1.type == story_type))
      planned = length(stories)
      done = Enum.count(stories, &(&1.status in completed))

      %{
        sprint: sprint,
        items: length(items),
        points: sum_points(items),
        mean: mean(points),
        median: median(points),
        stddev: stddev(points),
        planned_us: planned,
        completed_us: done,
        efficiency: if(planned > 0, do: done / planned, else: 0.0)
      }
    end)
  end

  # --- Burndown (linha) a partir dos snapshots ---

  @doc """
  Série de burndown de um sprint: rótulos (datas), restante real e linha ideal.
  Vem dos `sprint_snapshots` capturados a cada sync.
  """
  def burndown(sprint_id) do
    snaps =
      Repo.all(
        from s in SprintSnapshot,
          where: s.sprint_id == ^sprint_id,
          order_by: [asc: s.captured_on]
      )

    labels = Enum.map(snaps, &Calendar.strftime(&1.captured_on, "%d/%m"))
    remaining = Enum.map(snaps, & &1.remaining_points)
    total = (List.first(snaps) && List.first(snaps).total_points) || 0.0
    n = length(snaps)

    ideal =
      if n > 1 do
        for i <- 0..(n - 1), do: Float.round(total * (n - 1 - i) / (n - 1), 1)
      else
        remaining
      end

    %{labels: labels, remaining: remaining, ideal: ideal, has_data: n > 0}
  end

  # --- Helpers ---

  defp config(squad_id) do
    kpis = Rules.get_or_init(squad_id).kpis || %{}

    %{
      completed_states: kpis["completed_states"] || ["resolved", "closed"],
      story_type: kpis["story_type"] || "story"
    }
  end

  defp sum_points(items), do: items |> Enum.map(&(&1.story_points || 0)) |> Enum.sum()

  def mean([]), do: 0.0
  def mean(xs), do: Enum.sum(xs) / length(xs)

  def median([]), do: 0.0

  def median(xs) do
    sorted = Enum.sort(xs)
    n = length(sorted)
    mid = div(n, 2)

    if rem(n, 2) == 1 do
      Enum.at(sorted, mid)
    else
      (Enum.at(sorted, mid - 1) + Enum.at(sorted, mid)) / 2
    end
  end

  def stddev(xs) when length(xs) < 2, do: 0.0

  def stddev(xs) do
    m = mean(xs)
    variance = Enum.sum(Enum.map(xs, fn x -> (x - m) * (x - m) end)) / length(xs)
    :math.sqrt(variance)
  end
end

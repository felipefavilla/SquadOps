defmodule SquadOps.Azure.Sync do
  @moduledoc """
  Orchestrates pulling data from Azure DevOps into the local database.

  Steps:
  1. Read the squad's auth token and azure_project.
  2. List sprints (iterations) and upsert into `sprints` (by azure_id).
  3. Query work items via WIQL (scoped per sync_policy.scope).
  4. Fetch work item details in batches.
  5. Upsert into `work_items` by azure_id, applying field_mapping from Rules.

  Resiliência: cada sprint/work item é gravado individualmente. Uma linha que
  falha no changeset é **logada** (via `SquadOps.SyncLogs`) e **pulada** — não
  aborta a sincronização inteira. Todo o run é agrupado por um `run_id`.
  """

  import Ecto.Query

  alias SquadOps.{Auth, Azure, Repo, Rules, SyncLogs}
  alias SquadOps.Squads.{Sprint, WorkItem}

  @wiql_active_and_future """
  SELECT [System.Id] FROM WorkItems
  WHERE [System.TeamProject] = @project
    AND [System.State] <> 'Closed' AND [System.State] <> 'Removed'
  """

  @wiql_all """
  SELECT [System.Id] FROM WorkItems WHERE [System.TeamProject] = @project
  """

  def sync_squad(squad) do
    run_id = SyncLogs.new_run_id()
    SyncLogs.info(run_id, squad.id, "Sincronização iniciada", %{mode: Azure.mode()})

    result =
      with {:ok, token} <- get_token(squad),
           project when is_binary(project) <- project_name(squad),
           rules = Rules.get_or_init(squad.id),
           {:ok, sprint_count} <- sync_sprints(run_id, token, project, squad, rules),
           {:ok, item_stats} <- sync_work_items(run_id, token, project, squad, rules),
           {:ok, columns} <- sync_board_columns(run_id, token, project, squad) do
        Auth.mark_validated(squad.id)

        {:ok,
         %{
           sprints: sprint_count,
           work_items: item_stats.synced,
           work_item_errors: item_stats.failed,
           columns: length(columns),
           mode: Azure.mode()
         }}
      end

    finalize(run_id, squad.id, result)
  end

  defp finalize(run_id, squad_id, {:ok, summary} = result) do
    level = if summary.work_item_errors > 0, do: :warning, else: :info

    apply(SyncLogs, level, [
      run_id,
      squad_id,
      "Sincronização concluída",
      %{
        sprints: summary.sprints,
        work_items: summary.work_items,
        work_item_errors: summary.work_item_errors,
        columns: summary.columns,
        mode: summary.mode
      }
    ])

    result
  end

  defp finalize(run_id, squad_id, {:error, reason} = result) do
    SyncLogs.error(run_id, squad_id, "Sincronização abortada", %{reason: inspect(reason)})
    result
  end

  defp sync_board_columns(run_id, token, project, squad) do
    case Azure.get_board_columns(token, project) do
      {:ok, columns} ->
        rule = Rules.get_or_init(squad.id)
        workflow = Map.put(rule.workflow || %{}, "columns", columns)
        {:ok, _} = Rules.update_section(rule, :workflow, workflow)
        {:ok, columns}

      {:error, :not_found} ->
        # Board "Stories" não existe — tudo bem, mantém colunas atuais
        SyncLogs.info(run_id, squad.id, "Board padrão não encontrado, mantendo colunas atuais")
        {:ok, []}

      err ->
        err
    end
  end

  defp get_token(squad) do
    case Auth.get_token_for_squad(squad.id) do
      nil -> {:error, :no_token_configured}
      token -> {:ok, token}
    end
  end

  defp project_name(%{azure_project: nil}), do: {:error, :no_project_configured}
  defp project_name(%{azure_project: ""}), do: {:error, :no_project_configured}
  defp project_name(%{azure_project: name}), do: name

  defp sync_sprints(run_id, token, project, squad, _rules) do
    case Azure.list_sprints(token, project) do
      {:ok, sprints} ->
        synced =
          Enum.reduce(sprints, 0, fn s, acc ->
            case upsert_sprint(squad.id, s) do
              {:ok, _} ->
                acc + 1

              {:error, changeset} ->
                SyncLogs.warning(run_id, squad.id, "Falha ao salvar sprint", %{
                  azure_id: s[:azure_id],
                  name: s[:name],
                  errors: changeset_errors(changeset)
                })

                acc
            end
          end)

        {:ok, synced}

      err ->
        err
    end
  end

  defp upsert_sprint(squad_id, attrs) do
    existing =
      Repo.one(from s in Sprint, where: s.squad_id == ^squad_id and s.azure_id == ^attrs.azure_id)

    full = Map.put(attrs, :squad_id, squad_id)

    case existing do
      nil -> %Sprint{} |> Sprint.changeset(full) |> Repo.insert()
      sprint -> sprint |> Sprint.changeset(full) |> Repo.update()
    end
  end

  defp sync_work_items(run_id, token, project, squad, rules) do
    wiql = wiql_for(rules)

    with {:ok, ids} <- Azure.query_work_items(token, project, wiql),
         {:ok, items} <- Azure.fetch_work_items(token, ids) do
      sprint_map = sprint_lookup(squad.id)
      mapping = rules.field_mapping || %{}

      stats =
        Enum.reduce(items, %{synced: 0, failed: 0}, fn item, acc ->
          case upsert_work_item(squad.id, item, sprint_map, mapping) do
            {:ok, _} ->
              %{acc | synced: acc.synced + 1}

            {:error, changeset} ->
              SyncLogs.warning(run_id, squad.id, "Falha ao salvar work item", %{
                azure_id: item.azure_id,
                title: item.title,
                errors: changeset_errors(changeset)
              })

              %{acc | failed: acc.failed + 1}
          end
        end)

      {:ok, stats}
    end
  end

  defp wiql_for(%{sync_policy: %{"scope" => "all"}}), do: @wiql_all
  defp wiql_for(_), do: @wiql_active_and_future

  defp sprint_lookup(squad_id) do
    Repo.all(from s in Sprint, where: s.squad_id == ^squad_id, select: {s.azure_id, s.id, s.name})
    |> Enum.flat_map(fn {azure_id, id, name} ->
      [{azure_id, id}, {name, id}]
    end)
    |> Map.new()
  end

  defp upsert_work_item(squad_id, item, sprint_map, mapping) do
    sprint_id = resolve_sprint_id(item, sprint_map)
    type = remap(item.type, mapping["type"])
    status = remap(item.status, mapping["status"])

    attrs = %{
      squad_id: squad_id,
      sprint_id: sprint_id,
      azure_id: item.azure_id,
      title: item.title,
      description: item.description,
      type: type,
      status: status,
      assigned_to: item.assigned_to,
      story_points: item.story_points,
      priority: item.priority,
      area_path: Map.get(item, :area_path),
      parent_azure_id: Map.get(item, :parent_azure_id),
      iteration_path: Map.get(item, :iteration_path),
      azure_created_at: Map.get(item, :azure_created_at),
      azure_changed_at: Map.get(item, :azure_changed_at),
      closed_at: Map.get(item, :closed_at)
    }

    existing = Repo.one(from w in WorkItem, where: w.azure_id == ^item.azure_id)

    case existing do
      nil -> %WorkItem{} |> WorkItem.changeset(attrs) |> Repo.insert()
      wi -> wi |> WorkItem.changeset(attrs) |> Repo.update()
    end
  end

  defp resolve_sprint_id(%{iteration_path: nil}, _), do: nil

  defp resolve_sprint_id(%{iteration_path: path}, sprint_map) do
    last_segment = path |> String.split("\\") |> List.last()
    sprint_map[last_segment] || sprint_map[path]
  end

  defp resolve_sprint_id(_, _), do: nil

  defp remap(value, nil), do: value
  defp remap(value, mapping) when is_map(mapping), do: Map.get(mapping, value, value)

  # Converte os erros de um changeset em um mapa legível para o log/jsonb.
  defp changeset_errors(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {msg, opts} ->
      Enum.reduce(opts, msg, fn {key, value}, acc ->
        String.replace(acc, "%{#{key}}", inspect(value))
      end)
    end)
  end
end

defmodule SquadOps.SyncLogs do
  @moduledoc """
  Persisted log of synchronization runs (Azure → local DB).

  Each `Azure.Sync.sync_squad/1` run gets a `run_id` and emits entries here:
  start/finish (`info`), per-item failures (`warning`) and aborts (`error`).
  The `SyncLogsLive` screen reads these so the user can see exactly what went
  wrong without digging through server logs.
  """

  import Ecto.Query

  alias SquadOps.Repo
  alias SquadOps.SyncLogs.SyncLog

  @doc "Generate an opaque id grouping all log entries of a single sync run."
  def new_run_id, do: Ecto.UUID.generate()

  def info(run_id, squad_id, message, context \\ %{}),
    do: log("info", run_id, squad_id, message, context)

  def warning(run_id, squad_id, message, context \\ %{}),
    do: log("warning", run_id, squad_id, message, context)

  def error(run_id, squad_id, message, context \\ %{}),
    do: log("error", run_id, squad_id, message, context)

  # Logging must never crash the sync — swallow insert errors.
  defp log(level, run_id, squad_id, message, context) do
    %SyncLog{}
    |> SyncLog.changeset(%{
      level: level,
      run_id: run_id,
      squad_id: squad_id,
      message: message,
      context: normalize_context(context)
    })
    |> Repo.insert()
  rescue
    _ -> :error
  end

  @doc "List log entries, newest first. Filters: :squad_id, :level, :run_id, :limit."
  def list_logs(filters \\ []) do
    SyncLog
    |> filter_squad(filters[:squad_id])
    |> filter_level(filters[:level])
    |> filter_run(filters[:run_id])
    |> order_by([l], desc: l.inserted_at, desc: l.id)
    |> limit(^(filters[:limit] || 500))
    |> preload(:squad)
    |> Repo.all()
  end

  def clear_logs(filters \\ []) do
    SyncLog
    |> filter_squad(filters[:squad_id])
    |> Repo.delete_all()
  end

  # jsonb only stores string-keyed primitives; coerce non-JSON values.
  defp normalize_context(context) when is_map(context) do
    Map.new(context, fn {k, v} -> {to_string(k), normalize_value(v)} end)
  end

  defp normalize_context(_), do: %{}

  defp normalize_value(v) when is_binary(v) or is_number(v) or is_boolean(v) or is_nil(v), do: v
  defp normalize_value(v) when is_map(v) and not is_struct(v), do: normalize_context(v)
  defp normalize_value(v) when is_list(v), do: Enum.map(v, &normalize_value/1)
  defp normalize_value(v), do: inspect(v)

  defp filter_squad(query, nil), do: query
  defp filter_squad(query, squad_id), do: where(query, [l], l.squad_id == ^squad_id)

  defp filter_level(query, nil), do: query
  defp filter_level(query, level), do: where(query, [l], l.level == ^level)

  defp filter_run(query, nil), do: query
  defp filter_run(query, run_id), do: where(query, [l], l.run_id == ^run_id)
end

defmodule SquadOps.Sync.Scheduler do
  @moduledoc """
  Periodic background sync with Azure DevOps.

  Every `:auto_sync_interval_ms` (default 5 min) it syncs each squad that has a
  token configured and whose Rules `sync_policy["auto"]` is not `false`. Results
  are broadcast on the `"sync:status"` PubSub topic so LiveViews (the dashboard)
  can show live connection/sync status.

  Disabled in tests via `config :squad_ops, auto_sync: false`.
  """

  use GenServer
  require Logger

  alias SquadOps.{Auth, Rules, Squads}
  alias SquadOps.Azure.Sync

  @topic "sync:status"
  @default_interval_ms 5 * 60 * 1000

  def topic, do: @topic

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc "Trigger a sync pass immediately (out of band)."
  def sync_now, do: GenServer.cast(__MODULE__, :tick)

  @impl true
  def init(_opts) do
    if enabled?() do
      # Primeiro tick logo após o boot, depois no intervalo configurado.
      schedule(5_000)
      {:ok, %{interval: interval_ms()}}
    else
      :ignore
    end
  end

  @impl true
  def handle_info(:tick, state) do
    run_pass()
    schedule(state.interval)
    {:noreply, state}
  end

  @impl true
  def handle_cast(:tick, state) do
    run_pass()
    {:noreply, state}
  end

  defp run_pass do
    for squad <- Squads.list_squads(), eligible?(squad) do
      result = safe_sync(squad)
      Phoenix.PubSub.broadcast(SquadOps.PubSub, @topic, {:sync_status, squad.id, result})
    end
  end

  defp eligible?(squad) do
    Auth.get_token_for_squad(squad.id) != nil and
      Map.get(Rules.get_or_init(squad.id).sync_policy || %{}, "auto", true) != false
  end

  defp safe_sync(squad) do
    Sync.sync_squad(squad)
  rescue
    e ->
      Logger.error("Auto-sync crashed for squad #{squad.id}: #{Exception.message(e)}")
      {:error, :crashed}
  end

  defp schedule(ms), do: Process.send_after(self(), :tick, ms)

  defp enabled?, do: Application.get_env(:squad_ops, :auto_sync, true)

  defp interval_ms,
    do: Application.get_env(:squad_ops, :auto_sync_interval_ms, @default_interval_ms)
end

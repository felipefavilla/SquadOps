defmodule SquadOps.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      SquadOpsWeb.Telemetry,
      SquadOps.Repo,
      {DNSCluster, query: Application.get_env(:squad_ops, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: SquadOps.PubSub},
      # Auto-sync periódico com o Azure (desligado em test via config)
      SquadOps.Sync.Scheduler,
      # Start to serve requests, typically the last entry
      SquadOpsWeb.Endpoint
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: SquadOps.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    SquadOpsWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end

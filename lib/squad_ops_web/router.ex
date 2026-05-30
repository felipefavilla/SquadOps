defmodule SquadOpsWeb.Router do
  use SquadOpsWeb, :router

  alias SquadOpsWeb.UserAuth

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {SquadOpsWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
    plug :fetch_current_user
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  defp fetch_current_user(conn, opts), do: UserAuth.fetch_current_user(conn, opts)

  # Rotas públicas (sem autenticação)
  scope "/", SquadOpsWeb do
    pipe_through :browser

    live "/login", LoginLive
    post "/users/session", UserSessionController, :create
    delete "/users/session", UserSessionController, :delete
  end

  # Rotas protegidas — requerem usuário autenticado
  scope "/", SquadOpsWeb do
    pipe_through [:browser, :require_authenticated]

    live "/", DashboardLive, :index
    live "/connect", ConnectAzureLive, :index
    live "/squads/:id", SquadLive, :index
    live "/squads/:id/settings", SquadSettingsLive, :index
    live "/squads/:id/rules", SquadRulesLive, :index
    live "/backlog", BacklogLive, :index
    live "/bulk-create", BulkCreateLive, :index
    live "/logs", SyncLogsLive, :index
  end

  defp require_authenticated(conn, opts), do: UserAuth.require_authenticated_user(conn, opts)

  # Enable LiveDashboard and Swoosh mailbox preview in development
  if Application.compile_env(:squad_ops, :dev_routes) do
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through :browser

      live_dashboard "/dashboard", metrics: SquadOpsWeb.Telemetry
      forward "/mailbox", Plug.Swoosh.MailboxPreview
    end
  end
end

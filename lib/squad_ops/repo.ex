defmodule SquadOps.Repo do
  use Ecto.Repo,
    otp_app: :squad_ops,
    adapter: Ecto.Adapters.Postgres
end

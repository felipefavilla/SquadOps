defmodule SquadOps.Release do
  @moduledoc """
  Tasks executadas dentro de um release de produção.
  Use via `_build/prod/rel/squad_ops/bin/squad_ops eval "SquadOps.Release.migrate()"`.
  """
  @app :squad_ops

  def migrate do
    load_app()

    for repo <- repos() do
      {:ok, _, _} = Ecto.Migrator.with_repo(repo, &Ecto.Migrator.run(&1, :up, all: true))
    end
  end

  def rollback(repo, version) do
    load_app()
    {:ok, _, _} = Ecto.Migrator.with_repo(repo, &Ecto.Migrator.run(&1, :down, to: version))
  end

  def seed_admin do
    load_app()
    start_repos()

    alias SquadOps.{Accounts, Repo}

    email = System.get_env("ADMIN_EMAIL", "admin@squadops.local")
    password = System.get_env("ADMIN_PASSWORD", "Admin@123")

    case Accounts.get_user_by_email(email) do
      nil -> :ok
      existing -> Repo.delete!(existing)
    end

    case Accounts.create_user(%{
           email: email,
           name: System.get_env("ADMIN_NAME", "Administrador"),
           password: password,
           role: "admin"
         }) do
      {:ok, u} -> IO.puts("Admin OK: #{u.email}")
      {:error, cs} -> IO.inspect(cs.errors, label: "Erros")
    end
  end

  defp repos, do: Application.fetch_env!(@app, :ecto_repos)

  defp load_app, do: Application.load(@app)

  defp start_repos do
    {:ok, _} = Application.ensure_all_started(@app)
  end
end

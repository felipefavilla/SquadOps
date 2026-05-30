defmodule SquadOps.Repo.Migrations.CreateUsers do
  use Ecto.Migration

  def change do
    create table(:users) do
      add :email, :string, null: false
      add :name, :string, null: false
      add :hashed_password, :string, null: false
      add :role, :string, default: "user", null: false

      timestamps()
    end

    create unique_index(:users, [:email])
  end
end

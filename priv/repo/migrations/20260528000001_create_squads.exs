defmodule SquadOps.Repo.Migrations.CreateSquads do
  use Ecto.Migration

  def change do
    create table(:squads) do
      add :name, :string, null: false
      add :description, :text
      add :color, :string, default: "#6366f1"
      add :azure_project, :string

      timestamps()
    end

    create unique_index(:squads, [:name])
  end
end

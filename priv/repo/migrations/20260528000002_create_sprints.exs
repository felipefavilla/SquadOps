defmodule SquadOps.Repo.Migrations.CreateSprints do
  use Ecto.Migration

  def change do
    create table(:sprints) do
      add :squad_id, references(:squads, on_delete: :delete_all), null: false
      add :name, :string, null: false
      add :azure_id, :string
      add :start_date, :date
      add :end_date, :date
      add :status, :string, default: "future"

      timestamps()
    end

    create index(:sprints, [:squad_id])
    create index(:sprints, [:status])
  end
end

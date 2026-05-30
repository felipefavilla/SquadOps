defmodule SquadOps.Repo.Migrations.CreateSprintSnapshots do
  use Ecto.Migration

  def change do
    create table(:sprint_snapshots) do
      add :squad_id, references(:squads, on_delete: :delete_all), null: false
      add :sprint_id, references(:sprints, on_delete: :delete_all), null: false
      add :captured_on, :date, null: false
      add :total_points, :float, null: false, default: 0.0
      add :remaining_points, :float, null: false, default: 0.0
      add :completed_points, :float, null: false, default: 0.0
      add :planned_us, :integer, null: false, default: 0
      add :completed_us, :integer, null: false, default: 0
      add :counts_by_state, :map, null: false, default: %{}

      timestamps()
    end

    create index(:sprint_snapshots, [:squad_id])
    create unique_index(:sprint_snapshots, [:sprint_id, :captured_on])
  end
end

defmodule SquadOps.Repo.Migrations.CreateSyncLogs do
  use Ecto.Migration

  def change do
    create table(:sync_logs) do
      add :squad_id, references(:squads, on_delete: :delete_all)
      add :run_id, :string
      add :level, :string, null: false, default: "info"
      add :message, :string, null: false
      add :context, :map, null: false, default: %{}

      timestamps(updated_at: false)
    end

    create index(:sync_logs, [:squad_id])
    create index(:sync_logs, [:run_id])
    create index(:sync_logs, [:level])
    create index(:sync_logs, [:inserted_at])
  end
end

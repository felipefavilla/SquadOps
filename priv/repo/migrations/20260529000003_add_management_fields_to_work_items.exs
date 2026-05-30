defmodule SquadOps.Repo.Migrations.AddManagementFieldsToWorkItems do
  use Ecto.Migration

  def change do
    alter table(:work_items) do
      add :area_path, :string
      add :parent_azure_id, :integer
      add :iteration_path, :string
      add :azure_created_at, :utc_datetime
      add :azure_changed_at, :utc_datetime
      add :closed_at, :utc_datetime
    end

    create index(:work_items, [:area_path])
    create index(:work_items, [:parent_azure_id])
  end
end

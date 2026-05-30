defmodule SquadOps.Repo.Migrations.CreateWorkItems do
  use Ecto.Migration

  def change do
    create table(:work_items) do
      add :squad_id, references(:squads, on_delete: :delete_all), null: false
      add :sprint_id, references(:sprints, on_delete: :nilify_all)
      add :azure_id, :integer
      add :title, :string, null: false
      add :description, :text
      add :type, :string, null: false, default: "story"
      add :status, :string, null: false, default: "new"
      add :assigned_to, :string
      add :story_points, :integer
      add :priority, :integer, default: 2

      timestamps()
    end

    create index(:work_items, [:squad_id])
    create index(:work_items, [:sprint_id])
    create index(:work_items, [:type])
    create index(:work_items, [:status])
    create unique_index(:work_items, [:azure_id], where: "azure_id IS NOT NULL")
  end
end

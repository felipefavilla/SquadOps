defmodule SquadOps.Repo.Migrations.AddKindToSprints do
  use Ecto.Migration

  def change do
    alter table(:sprints) do
      add :kind, :string, null: false, default: "sprint"
      add :path, :string
    end

    create index(:sprints, [:kind])
  end
end

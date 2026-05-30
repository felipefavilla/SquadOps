defmodule SquadOps.Repo.Migrations.CreateSquadRules do
  use Ecto.Migration

  def change do
    create table(:squad_rules) do
      add :squad_id, references(:squads, on_delete: :delete_all), null: false
      add :workflow, :map, default: %{}
      add :validations, :map, default: %{}
      add :field_mapping, :map, default: %{}
      add :sync_policy, :map, default: %{}

      timestamps()
    end

    create unique_index(:squad_rules, [:squad_id])
  end
end

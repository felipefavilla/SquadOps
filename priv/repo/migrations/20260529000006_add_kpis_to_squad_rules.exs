defmodule SquadOps.Repo.Migrations.AddKpisToSquadRules do
  use Ecto.Migration

  def change do
    alter table(:squad_rules) do
      add :kpis, :map, null: false, default: %{}
    end
  end
end

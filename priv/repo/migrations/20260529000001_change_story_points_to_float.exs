defmodule SquadOps.Repo.Migrations.ChangeStoryPointsToFloat do
  use Ecto.Migration

  def up do
    alter table(:work_items) do
      modify :story_points, :float
    end
  end

  def down do
    alter table(:work_items) do
      modify :story_points, :integer
    end
  end
end

defmodule SquadOps.Rules.SquadRule do
  use Ecto.Schema
  import Ecto.Changeset

  alias SquadOps.Squads.Squad

  schema "squad_rules" do
    field :workflow, :map, default: %{}
    field :validations, :map, default: %{}
    field :field_mapping, :map, default: %{}
    field :sync_policy, :map, default: %{}

    belongs_to :squad, Squad

    timestamps()
  end

  def changeset(rule, attrs) do
    rule
    |> cast(attrs, [:squad_id, :workflow, :validations, :field_mapping, :sync_policy])
    |> validate_required([:squad_id])
    |> unique_constraint(:squad_id)
    |> foreign_key_constraint(:squad_id)
  end
end

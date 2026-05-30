defmodule SquadOps.Squads.SprintSnapshot do
  use Ecto.Schema
  import Ecto.Changeset

  alias SquadOps.Squads.{Squad, Sprint}

  schema "sprint_snapshots" do
    field :captured_on, :date
    field :total_points, :float, default: 0.0
    field :remaining_points, :float, default: 0.0
    field :completed_points, :float, default: 0.0
    field :planned_us, :integer, default: 0
    field :completed_us, :integer, default: 0
    field :counts_by_state, :map, default: %{}

    belongs_to :squad, Squad
    belongs_to :sprint, Sprint

    timestamps()
  end

  @fields ~w(squad_id sprint_id captured_on total_points remaining_points
             completed_points planned_us completed_us counts_by_state)a

  def changeset(snapshot, attrs) do
    snapshot
    |> cast(attrs, @fields)
    |> validate_required([:squad_id, :sprint_id, :captured_on])
    |> unique_constraint([:sprint_id, :captured_on])
  end
end

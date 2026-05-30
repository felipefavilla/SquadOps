defmodule SquadOps.Squads.Sprint do
  use Ecto.Schema
  import Ecto.Changeset

  alias SquadOps.Squads.{Squad, WorkItem}

  @statuses ~w(future active past)

  schema "sprints" do
    field :name, :string
    field :azure_id, :string
    field :start_date, :date
    field :end_date, :date
    field :status, :string, default: "future"

    belongs_to :squad, Squad
    has_many :work_items, WorkItem

    timestamps()
  end

  def changeset(sprint, attrs) do
    sprint
    |> cast(attrs, [:name, :azure_id, :start_date, :end_date, :status, :squad_id])
    |> validate_required([:name, :squad_id])
    |> validate_inclusion(:status, @statuses)
    |> foreign_key_constraint(:squad_id)
  end
end

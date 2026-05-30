defmodule SquadOps.Squads.Squad do
  use Ecto.Schema
  import Ecto.Changeset

  alias SquadOps.Squads.{Sprint, WorkItem}
  alias SquadOps.Auth.Token

  schema "squads" do
    field :name, :string
    field :description, :string
    field :color, :string, default: "#6366f1"
    field :azure_project, :string

    has_many :sprints, Sprint
    has_many :work_items, WorkItem
    has_one :auth_token, Token

    timestamps()
  end

  def changeset(squad, attrs) do
    squad
    |> cast(attrs, [:name, :description, :color, :azure_project])
    |> validate_required([:name])
    |> validate_length(:name, min: 2, max: 100)
    |> unique_constraint(:name)
  end
end

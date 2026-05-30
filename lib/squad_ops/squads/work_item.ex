defmodule SquadOps.Squads.WorkItem do
  use Ecto.Schema
  import Ecto.Changeset

  alias SquadOps.Squads.{Squad, Sprint}

  @types ~w(feature story task bug)
  @statuses ~w(new active resolved closed removed)

  schema "work_items" do
    field :title, :string
    field :description, :string
    field :type, :string, default: "story"
    field :status, :string, default: "new"
    field :assigned_to, :string
    field :story_points, :float
    field :priority, :integer, default: 2
    field :azure_id, :integer
    field :area_path, :string
    field :parent_azure_id, :integer
    field :iteration_path, :string
    field :azure_created_at, :utc_datetime
    field :azure_changed_at, :utc_datetime
    field :closed_at, :utc_datetime

    belongs_to :squad, Squad
    belongs_to :sprint, Sprint

    timestamps()
  end

  def changeset(work_item, attrs) do
    work_item
    |> cast(attrs, [
      :title,
      :description,
      :type,
      :status,
      :assigned_to,
      :story_points,
      :priority,
      :azure_id,
      :area_path,
      :parent_azure_id,
      :iteration_path,
      :azure_created_at,
      :azure_changed_at,
      :closed_at,
      :squad_id,
      :sprint_id
    ])
    |> validate_required([:title, :type, :status, :squad_id])
    |> validate_inclusion(:type, @types)
    |> validate_inclusion(:status, @statuses)
    |> validate_number(:story_points, greater_than_or_equal_to: 0)
    |> validate_number(:priority, greater_than_or_equal_to: 1, less_than_or_equal_to: 4)
    |> foreign_key_constraint(:squad_id)
    |> foreign_key_constraint(:sprint_id)
  end
end

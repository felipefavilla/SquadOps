defmodule SquadOps.Squads.Sprint do
  use Ecto.Schema
  import Ecto.Changeset

  alias SquadOps.Squads.{Squad, WorkItem}

  @statuses ~w(future active past)
  @kinds ~w(sprint backlog)

  schema "sprints" do
    field :name, :string
    field :azure_id, :string
    field :start_date, :date
    field :end_date, :date
    field :status, :string, default: "future"
    field :kind, :string, default: "sprint"
    field :path, :string

    belongs_to :squad, Squad
    has_many :work_items, WorkItem

    timestamps()
  end

  def changeset(sprint, attrs) do
    sprint
    |> cast(attrs, [:name, :azure_id, :start_date, :end_date, :status, :kind, :path, :squad_id])
    |> classify_kind()
    |> validate_required([:name, :squad_id])
    |> validate_inclusion(:status, @statuses)
    |> validate_inclusion(:kind, @kinds)
    |> foreign_key_constraint(:squad_id)
  end

  # Iteration com data de início E fim = sprint timeboxed; sem datas = backlog/análise.
  # Respeita um `kind` já informado explicitamente nos attrs.
  defp classify_kind(changeset) do
    case get_change(changeset, :kind) do
      nil ->
        start = get_field(changeset, :start_date)
        finish = get_field(changeset, :end_date)
        kind = if start && finish, do: "sprint", else: "backlog"
        put_change(changeset, :kind, kind)

      _ ->
        changeset
    end
  end
end

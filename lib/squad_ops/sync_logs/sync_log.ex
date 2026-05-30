defmodule SquadOps.SyncLogs.SyncLog do
  use Ecto.Schema
  import Ecto.Changeset

  alias SquadOps.Squads.Squad

  @levels ~w(info warning error)

  schema "sync_logs" do
    field :run_id, :string
    field :level, :string, default: "info"
    field :message, :string
    field :context, :map, default: %{}

    belongs_to :squad, Squad

    timestamps(updated_at: false)
  end

  def changeset(log, attrs) do
    log
    |> cast(attrs, [:run_id, :level, :message, :context, :squad_id])
    |> validate_required([:level, :message])
    |> validate_inclusion(:level, @levels)
  end
end

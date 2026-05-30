defmodule SquadOps.Auth.Token do
  use Ecto.Schema
  import Ecto.Changeset

  alias SquadOps.Squads.Squad

  schema "auth_tokens" do
    field :pat_token, :string
    field :azure_org_url, :string
    field :validated_at, :naive_datetime

    belongs_to :squad, Squad

    timestamps()
  end

  def changeset(token, attrs) do
    token
    |> cast(attrs, [:pat_token, :azure_org_url, :validated_at, :squad_id])
    |> validate_required([:pat_token, :azure_org_url, :squad_id])
    |> validate_format(:azure_org_url, ~r|^https://dev\.azure\.com/|)
    |> unique_constraint(:squad_id)
    |> foreign_key_constraint(:squad_id)
  end
end

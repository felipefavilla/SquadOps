defmodule SquadOps.Repo.Migrations.CreateAuthTokens do
  use Ecto.Migration

  def change do
    create table(:auth_tokens) do
      add :squad_id, references(:squads, on_delete: :delete_all), null: false
      add :pat_token, :string, null: false
      add :azure_org_url, :string, null: false
      add :validated_at, :naive_datetime

      timestamps()
    end

    create unique_index(:auth_tokens, [:squad_id])
  end
end

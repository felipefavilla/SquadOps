defmodule SquadOps.Fixtures do
  @moduledoc """
  Test fixtures/factories for the SquadOps test suite.

  Provides small builder helpers to create persisted entities for tests
  without external libraries (no Mox, no Faker).
  """

  alias SquadOps.{Accounts, Auth, Repo, Squads}
  alias SquadOps.Squads.{Sprint, WorkItem}

  @doc "Returns a globally-unique integer (per process)."
  def unique_integer, do: System.unique_integer([:positive])

  # --- Users ---

  def user_attrs(attrs \\ %{}) do
    n = unique_integer()

    Map.merge(
      %{
        email: "user#{n}@example.com",
        name: "User #{n}",
        password: "Secret@123",
        role: "user"
      },
      Map.new(attrs)
    )
  end

  def user_fixture(attrs \\ %{}) do
    {:ok, user} = attrs |> user_attrs() |> Accounts.create_user()
    user
  end

  # --- Squads ---

  def squad_attrs(attrs \\ %{}) do
    n = unique_integer()

    Map.merge(
      %{
        name: "Squad #{n}",
        description: "Squad description #{n}",
        color: "#6366f1",
        azure_project: "Project#{n}"
      },
      Map.new(attrs)
    )
  end

  def squad_fixture(attrs \\ %{}) do
    {:ok, squad} = attrs |> squad_attrs() |> Squads.create_squad()
    squad
  end

  # --- Tokens (PAT) ---

  def token_attrs(squad_id, attrs \\ %{}) do
    Map.merge(
      %{
        pat_token: "fake-pat-token-#{unique_integer()}",
        azure_org_url: "https://dev.azure.com/my-org",
        squad_id: squad_id
      },
      Map.new(attrs)
    )
  end

  def token_fixture(squad, attrs \\ %{}) do
    {:ok, token} = Auth.upsert_token(squad.id, token_attrs(squad.id, attrs))
    token
  end

  # --- Sprints ---

  def sprint_fixture(squad, attrs \\ %{}) do
    n = unique_integer()

    default = %{
      name: "Sprint #{n}",
      azure_id: "azure-sprint-#{n}",
      start_date: Date.utc_today(),
      end_date: Date.add(Date.utc_today(), 14),
      status: "active",
      squad_id: squad.id
    }

    {:ok, sprint} =
      %Sprint{}
      |> Sprint.changeset(Map.merge(default, Map.new(attrs)))
      |> Repo.insert()

    sprint
  end

  # --- Work Items ---

  def work_item_fixture(squad, attrs \\ %{}) do
    n = unique_integer()

    default = %{
      title: "Work item #{n}",
      type: "story",
      status: "new",
      priority: 2,
      squad_id: squad.id
    }

    {:ok, item} =
      %WorkItem{}
      |> WorkItem.changeset(Map.merge(default, Map.new(attrs)))
      |> Repo.insert()

    item
  end
end

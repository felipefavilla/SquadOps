defmodule SquadOps.Azure.SyncTest do
  # not async because we mutate System env (AZURE_MODE) and global config
  use SquadOps.DataCase, async: false

  alias SquadOps.{Auth, Rules, Squads}
  alias SquadOps.Azure.Sync
  alias SquadOps.Squads.{Sprint, WorkItem}
  import Ecto.Query
  import SquadOps.Fixtures

  setup do
    previous = System.get_env("AZURE_MODE")
    System.put_env("AZURE_MODE", "mock")

    on_exit(fn ->
      if previous,
        do: System.put_env("AZURE_MODE", previous),
        else: System.delete_env("AZURE_MODE")
    end)

    :ok
  end

  describe "sync_squad/1" do
    test "returns counts and inserts sprints, work_items, and board columns" do
      squad = squad_fixture(%{azure_project: "MockProject"})
      _ = token_fixture(squad)

      assert {:ok, %{sprints: 3, work_items: 3, columns: 4, mode: :mock}} =
               Sync.sync_squad(squad)

      # Sprints were inserted in DB
      sprints = SquadOps.Repo.all(from s in Sprint, where: s.squad_id == ^squad.id)
      assert length(sprints) == 3

      # Work items inserted in DB
      items = SquadOps.Repo.all(from w in WorkItem, where: w.squad_id == ^squad.id)
      assert length(items) == 3

      # workflow["columns"] was populated by Rules.update_section
      rule = Rules.get_or_init(squad.id)
      cols = get_in(rule.workflow, ["columns"]) || []
      assert is_list(cols) and length(cols) == 4

      # Token validation timestamp set
      assert %{validated_at: %NaiveDateTime{}} = Auth.get_token_for_squad(squad.id)
    end

    test "returns :no_token_configured when squad has no token" do
      squad = squad_fixture(%{azure_project: "MockProject"})
      assert {:error, :no_token_configured} = Sync.sync_squad(squad)
    end

    test "fails when squad has no azure_project" do
      squad = squad_fixture(%{azure_project: nil})
      _ = token_fixture(squad)

      # `project_name/1` returns {:error, :no_project_configured} on nil/"",
      # which short-circuits the `with` chain.
      assert {:error, :no_project_configured} = Sync.sync_squad(squad)
    end

    test "is idempotent: a second sync does not duplicate sprints" do
      squad = squad_fixture(%{azure_project: "MockProject"})
      _ = token_fixture(squad)

      assert {:ok, _} = Sync.sync_squad(squad)
      assert {:ok, _} = Sync.sync_squad(squad)

      assert length(Squads.list_sprints(squad.id)) == 3
    end
  end
end

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

      assert {:ok, %{sprints: 5, work_items: 9, columns: 4, mode: :mock, work_item_errors: 0}} =
               Sync.sync_squad(squad)

      # Sprints (iterations) were inserted in DB
      sprints = SquadOps.Repo.all(from s in Sprint, where: s.squad_id == ^squad.id)
      assert length(sprints) == 5

      # Work items inserted in DB
      items = SquadOps.Repo.all(from w in WorkItem, where: w.squad_id == ^squad.id)
      assert length(items) == 9

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

      assert length(Squads.list_sprints(squad.id)) == 5
    end

    test "persists area, parent and iteration classification from Azure" do
      squad = squad_fixture(%{azure_project: "MockProject"})
      _ = token_fixture(squad)

      assert {:ok, _} = Sync.sync_squad(squad)

      # Áreas capturadas
      areas =
        SquadOps.Repo.all(
          from w in WorkItem, where: w.squad_id == ^squad.id, distinct: true, select: w.area_path
        )

      assert Enum.any?(areas, &(&1 =~ "Pagamentos"))

      # Relacionamento pai/filho persistido
      child = SquadOps.Repo.one(from w in WorkItem, where: w.azure_id == 9002)
      assert child.parent_azure_id == 9001
      assert child.story_points == 5.0
      assert %DateTime{} = child.azure_created_at

      # Iteration sem datas classificada como backlog
      backlog =
        SquadOps.Repo.one(
          from s in Sprint, where: s.squad_id == ^squad.id and s.name == "Backlog"
        )

      assert backlog.kind == "backlog"
    end
  end
end

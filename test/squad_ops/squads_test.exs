defmodule SquadOps.SquadsTest do
  use SquadOps.DataCase, async: true

  alias SquadOps.Squads
  alias SquadOps.Squads.{Squad, WorkItem}
  import SquadOps.Fixtures

  describe "squads CRUD" do
    test "list_squads/0 returns squads sorted by name" do
      _b = squad_fixture(%{name: "Bravo"})
      _a = squad_fixture(%{name: "Alpha"})
      _c = squad_fixture(%{name: "Charlie"})

      names = Squads.list_squads() |> Enum.map(& &1.name)
      assert names == ["Alpha", "Bravo", "Charlie"]
    end

    test "get_squad!/1 returns the squad" do
      squad = squad_fixture()
      assert %Squad{id: id} = Squads.get_squad!(squad.id)
      assert id == squad.id
    end

    test "create_squad/1 with valid attrs creates the squad" do
      assert {:ok, %Squad{} = squad} = Squads.create_squad(squad_attrs(%{name: "New Squad"}))
      assert squad.name == "New Squad"
    end

    test "create_squad/1 fails when name is duplicated" do
      _ = squad_fixture(%{name: "Same"})
      assert {:error, changeset} = Squads.create_squad(squad_attrs(%{name: "Same"}))
      assert %{name: _} = errors_on(changeset)
    end

    test "create_squad/1 requires a name" do
      assert {:error, changeset} = Squads.create_squad(%{description: "no name"})
      assert %{name: _} = errors_on(changeset)
    end

    test "update_squad/2 updates fields" do
      squad = squad_fixture()
      assert {:ok, updated} = Squads.update_squad(squad, %{description: "updated"})
      assert updated.description == "updated"
    end

    test "delete_squad/1 deletes the squad" do
      squad = squad_fixture()
      assert {:ok, _} = Squads.delete_squad(squad)
      assert_raise Ecto.NoResultsError, fn -> Squads.get_squad!(squad.id) end
    end
  end

  describe "sprints" do
    test "list_sprints/1 returns sprints in desc start_date order" do
      squad = squad_fixture()

      old = sprint_fixture(squad, %{name: "Older", start_date: ~D[2024-01-01]})
      new = sprint_fixture(squad, %{name: "Newer", start_date: ~D[2024-06-01]})

      sprints = Squads.list_sprints(squad.id)
      assert [first, second] = sprints
      assert first.id == new.id
      assert second.id == old.id
    end

    test "get_active_sprint/1 returns the active sprint" do
      squad = squad_fixture()
      _past = sprint_fixture(squad, %{status: "past"})
      active = sprint_fixture(squad, %{status: "active"})

      assert %{id: id} = Squads.get_active_sprint(squad.id)
      assert id == active.id
    end
  end

  describe "work items" do
    test "create_work_item/1 and list_work_items/2" do
      squad = squad_fixture()
      _ = work_item_fixture(squad, %{title: "A", status: "new"})
      _ = work_item_fixture(squad, %{title: "B", status: "active"})

      items = Squads.list_work_items(squad.id)
      assert length(items) == 2
    end

    test "list_work_items/2 filters by type and status" do
      squad = squad_fixture()
      _ = work_item_fixture(squad, %{type: "story", status: "new"})
      _ = work_item_fixture(squad, %{type: "bug", status: "active"})

      assert [item] = Squads.list_work_items(squad.id, type: "bug")
      assert item.type == "bug"
      assert [_] = Squads.list_work_items(squad.id, status: "active")
    end

    test "work_item_stats/1 groups by status" do
      squad = squad_fixture()
      _ = work_item_fixture(squad, %{status: "new"})
      _ = work_item_fixture(squad, %{status: "new"})
      _ = work_item_fixture(squad, %{status: "active"})
      _ = work_item_fixture(squad, %{status: "resolved"})

      stats = Squads.work_item_stats(squad.id)
      assert stats == %{"new" => 2, "active" => 1, "resolved" => 1}
    end

    test "move_work_item/2 changes status" do
      squad = squad_fixture()
      item = work_item_fixture(squad, %{status: "new"})

      assert {:ok, %WorkItem{status: "active"}} = Squads.move_work_item(item, "active")
    end

    test "list_all_work_items/1 preloads squad and supports filters" do
      squad = squad_fixture()
      _ = work_item_fixture(squad, %{type: "bug"})

      items = Squads.list_all_work_items(squad_id: squad.id, type: "bug")
      assert length(items) == 1
      assert hd(items).squad.id == squad.id
    end
  end

  describe "list_squads_with_stats/0" do
    test "attaches stats to each squad" do
      squad = squad_fixture()
      _ = work_item_fixture(squad, %{status: "new"})
      _ = work_item_fixture(squad, %{status: "active"})

      [s] = Squads.list_squads_with_stats() |> Enum.filter(&(&1.id == squad.id))
      assert s.stats["new"] == 1
      assert s.stats["active"] == 1
    end
  end
end

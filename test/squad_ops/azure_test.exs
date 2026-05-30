defmodule SquadOps.AzureTest do
  # not async because we mutate System env (AZURE_MODE)
  use ExUnit.Case, async: false

  alias SquadOps.Azure

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

  test "mode/0 returns :mock by default" do
    assert Azure.mode() == :mock
  end

  test "mode/0 returns :real when AZURE_MODE=real" do
    System.put_env("AZURE_MODE", "real")
    assert Azure.mode() == :real
  end

  describe "delegations to Mock" do
    test "list_projects/1 returns a list of fake projects" do
      assert {:ok, projects} = Azure.list_projects(nil)
      assert is_list(projects)
      assert Enum.any?(projects, &(&1.name == "Pagamentos"))
    end

    test "list_sprints/3 returns 3 mocked sprints" do
      assert {:ok, sprints} = Azure.list_sprints(nil, "any_project")
      assert length(sprints) == 3
      assert Enum.any?(sprints, &(&1.status == "active"))
    end

    test "query_work_items/3 returns fake IDs" do
      assert {:ok, ids} = Azure.query_work_items(nil, "any_project", "WIQL")
      assert ids == [9001, 9002, 9003]
    end

    test "fetch_work_items/2 returns one item per id" do
      ids = [1, 2, 3]
      assert {:ok, items} = Azure.fetch_work_items(nil, ids)
      assert length(items) == 3
      assert Enum.all?(items, &Map.has_key?(&1, :azure_id))
    end

    test "get_board_columns/4 returns mocked columns" do
      assert {:ok, cols} = Azure.get_board_columns(nil, "any_project")
      assert Enum.any?(cols, &(&1.name == "Done"))
    end

    test "test_connection/1 returns mock_mode" do
      assert {:ok, :mock_mode} = Azure.test_connection(nil)
    end
  end
end

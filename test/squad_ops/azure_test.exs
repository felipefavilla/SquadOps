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

    test "list_sprints/3 returns mocked iterations including a backlog one" do
      assert {:ok, sprints} = Azure.list_sprints(nil, "any_project")
      assert Enum.any?(sprints, &(&1.status == "active"))
      assert Enum.any?(sprints, &(&1.kind == "sprint"))
      assert Enum.any?(sprints, &(&1.kind == "backlog"))
    end

    test "query_work_items/3 returns fake IDs" do
      assert {:ok, ids} = Azure.query_work_items(nil, "any_project", "WIQL")
      assert 9001 in ids
      assert length(ids) > 3
    end

    test "fetch_work_items/2 returns the known mock items with management fields" do
      {:ok, ids} = Azure.query_work_items(nil, "any_project", "WIQL")
      assert {:ok, items} = Azure.fetch_work_items(nil, ids)
      assert length(items) == length(ids)
      assert Enum.all?(items, &Map.has_key?(&1, :area_path))
      # há relacionamento pai/filho no mock
      assert Enum.any?(items, &(&1.parent_azure_id != nil))
    end

    test "get_board_columns/4 returns mocked columns" do
      assert {:ok, cols} = Azure.get_board_columns(nil, "any_project")
      assert Enum.any?(cols, &(&1.name == "Done"))
    end

    test "test_connection/1 returns mock_mode" do
      assert {:ok, :mock_mode} = Azure.test_connection(nil)
    end

    test "create_work_item/4 returns a fake azure id" do
      assert {:ok, %{azure_id: id}} =
               Azure.create_work_item(nil, "MockProject", "story", %{title: "X"})

      assert is_integer(id)
    end
  end
end
